import 'dart:collection';
import 'dart:math'; // sqrt, pow 사용
import 'package:annyong/domain/entity/calibration_route.dart';
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:flutter/material.dart';

/// 내부 계산용 후보 객체
class _CalibrationCandidate {
  final List<int> vertexPath;
  final double distance;
  final Poi? destinationPoi;
  final int turnCount;
  final bool isLandmark;
  final double linearity; // [New] 직진성 점수 (0.0 ~ 1.0)

  _CalibrationCandidate({
    required this.vertexPath,
    required this.distance,
    this.destinationPoi,
    required this.turnCount,
    this.isLandmark = false,
    required this.linearity,
  });

  double get score {
    double baseScore = 0.0;

    // 1. POI 여부
    if (destinationPoi != null) {
      baseScore += 50000.0;
    } else if (isLandmark) {
      baseScore += 10000.0;
    }

    // 2. 직진성 (매우 중요)
    // 직진성이 1에 가까울수록(직선일수록) 높은 점수
    // 0.9 미만이면 감점 폭을 크게 둠
    if (linearity >= 0.9) {
      baseScore += 5000.0;
    } else {
      baseScore -= (1.0 - linearity) * 10000.0;
    }

    // 3. 회전 수 페널티
    baseScore -= (turnCount * 1000.0); // 회전 페널티 강화

    // 4. 거리 적합성 (이상적 거리 7.5m)
    final distancePenalty = (distance - 7.5).abs() * 100.0;
    baseScore -= distancePenalty;

    return baseScore;
  }
}

class CalibrationService {
  final PoiRepository _poiRepo;

  CalibrationService(this._poiRepo);

  static const double _optimalMin = 3.0;
  static const double _optimalMax = 10.0;
  static const double _extendedMax = 15.0;
  static const int _maxTurn = 2;

  // [New] 최소 직진성 임계값 (0.8 = 실제 이동거리의 80% 이상이 직선 변위여야 함)
  static const double _minLinearity = 0.8;

  Future<CalibrationRoute?> findTargetRoute(Poi startPoi) async {
    debugPrint("-------[findTargetRoute Start]------");
    if (startPoi.vertexId == null) return null;

    final startVertexId = startPoi.vertexId!;
    final startVertex = await _poiRepo.getVertexById(startVertexId);
    if (startVertex == null) return null;

    // --- Pre-fetching Logic (기존과 동일) ---
    final Map<int, List<Edge>> localEdgesMap = {};
    final Map<int, List<Poi>> localPoisMap = {};
    final Queue<int> loadQueue = Queue();
    final Set<int> loadedVertices = {};
    final Map<int, Vertex> localVertexMap = {}; // [New] 좌표 계산용 버텍스 캐시

    loadQueue.add(startVertexId);
    loadedVertices.add(startVertexId);
    // 시작 정점 캐싱
    localVertexMap[startVertexId] = startVertex;

    int safetyCount = 0;
    while (loadQueue.isNotEmpty && safetyCount < 300) {
      // 안전 카운트 약간 증가
      final currentId = loadQueue.removeFirst();
      safetyCount++;

      // 버텍스 정보 캐싱 (직진성 계산을 위해 필요)
      if (!localVertexMap.containsKey(currentId)) {
        final v = await _poiRepo.getVertexById(currentId);
        if (v != null) localVertexMap[currentId] = v;
      }

      final edges = await _poiRepo.getEdgesForVertex(currentId);
      localEdgesMap[currentId] = edges;

      final pois = await _poiRepo.getPoisByVertexId(currentId);
      localPoisMap[currentId] = pois;

      for (final edge in edges) {
        if (!loadedVertices.contains(edge.toVertexId)) {
          loadedVertices.add(edge.toVertexId);
          loadQueue.add(edge.toVertexId);
        }
      }
    }
    // -------------------------------------

    final List<_CalibrationCandidate> candidates = [];
    final initialEdges = localEdgesMap[startVertexId] ?? [];

    debugPrint("[DFS] start DFS...");
    for (final edge in initialEdges) {
      if (!_isWalkable(edge.way)) continue;

      _recursiveSearchSync(
        startVertex: startVertex, // [New] 시작점 전달 (직진성 계산용)
        currentVertexId: edge.toVertexId,
        path: [startVertexId, edge.toVertexId],
        currentDistance: edge.meterLength,
        turnCount: 0,
        currentWay: edge.way,
        candidates: candidates,
        edgesMap: localEdgesMap,
        poisMap: localPoisMap,
        vertexMap: localVertexMap, // [New] 좌표 맵 전달
      );
    }
    debugPrint("[DFS] Done! Candidates count: ${candidates.length}");

    if (candidates.isEmpty) return null;

    // 점수순 정렬
    candidates.sort((a, b) => b.score.compareTo(a.score));

    final best = candidates.first;

    // 디버깅용: 베스트 경로 정보 출력
    debugPrint(
      "Best Path: Dist=${best.distance.toStringAsFixed(1)}m, Linearity=${best.linearity.toStringAsFixed(2)}",
    );

    final List<Vertex> pathVertices = [];
    for (final vId in best.vertexPath) {
      final v = await _poiRepo.getVertexById(vId);
      if (v != null) pathVertices.add(v);
    }

    if (pathVertices.isEmpty) return null;
    final endVertex = await _poiRepo.getVertexById(best.vertexPath.last);

    return CalibrationRoute(
      startPoi: startPoi,
      destinationVertex: endVertex!,
      destinationPoi: best.destinationPoi,
      pathVertices: pathVertices,
      totalDistance: best.distance,
      mode: "one-way",
    );
  }

  void _recursiveSearchSync({
    required Vertex startVertex,
    required int currentVertexId,
    required List<int> path,
    required double currentDistance,
    required int turnCount,
    required WayType currentWay,
    required List<_CalibrationCandidate> candidates,
    required Map<int, List<Edge>> edgesMap,
    required Map<int, List<Poi>> poisMap,
    required Map<int, Vertex> vertexMap,
  }) {
    // 1. 탐색 거리 한계
    if (currentDistance > _extendedMax) return;

    // 2. 현재 정점 정보
    final currentVertex = vertexMap[currentVertexId];
    if (currentVertex == null) return; // 데이터 오류 시 중단

    // [New] 직진성(Linearity) 계산
    // 직선 거리(변위) / 누적 거리
    double displacement = _calcEuclideanDist(startVertex, currentVertex);
    // 0으로 나누기 방지
    double linearity = (currentDistance > 0)
        ? (displacement / currentDistance)
        : 1.0;

    // [New] 직진성이 너무 떨어지면(구불구불하면) 가지치기 (Pruning)
    // 단, 아주 짧은 거리(<2m)에서는 계산 오차가 있을 수 있으므로 제외
    if (currentDistance > 2.0 && linearity < _minLinearity) {
      return;
    }

    final pois = poisMap[currentVertexId] ?? [];
    final nextEdges = edgesMap[currentVertexId] ?? [];

    // 3. 랜드마크 판별
    int validNextPaths = 0;
    bool isCorner = false;

    for (final e in nextEdges) {
      // [Fix] 단순 직전 노드 체크가 아니라, 전체 경로에 포함되어 있는지 확인 (사이클 방지)
      if (path.contains(e.toVertexId)) continue;

      if (_isWalkable(e.way)) {
        validNextPaths++;
        if (e.way != currentWay && e.way.supportsTurnCalculation) {
          isCorner = true;
        }
      }
    }
    // 막다른 길 or 코너
    final bool isLandmark = (validNextPaths == 0) || isCorner;

    // 4. 후보 등록 (조건 강화)
    // 3~10m (최적), 10~15m (확장)
    bool isDistanceOk =
        (currentDistance >= _optimalMin && currentDistance <= _extendedMax);

    // [조건] POI가 있거나 랜드마크여야 함. (허공 X)
    // [조건] 직진성이 보장되어야 함 (위에서 가지치기 했지만 한 번 더 확인)
    if (isDistanceOk && (pois.isNotEmpty || isLandmark)) {
      // "거리"가 조건에 맞더라도, "직선 거리(변위)"가 너무 짧으면(제자리 걸음) 제외
      // 예: 10m 걸었는데 출발지로부터 2m 거리라면 제외
      if (displacement >= _optimalMin * 0.8) {
        candidates.add(
          _CalibrationCandidate(
            vertexPath: List.from(path),
            distance: currentDistance,
            turnCount: turnCount,
            destinationPoi: pois.isNotEmpty ? pois.first : null,
            isLandmark: isLandmark,
            linearity: linearity, // 저장
          ),
        );
      }
    }

    // 5. 다음 경로 탐색
    for (final nextEdge in nextEdges) {
      // [Fix] 사이클 방지: 경로에 이미 포함된 노드는 방문하지 않음
      if (path.contains(nextEdge.toVertexId)) continue;

      if (!_isWalkable(nextEdge.way)) continue;

      int nextTurnCount = turnCount;
      if (currentWay != nextEdge.way && nextEdge.way.supportsTurnCalculation) {
        nextTurnCount++;
      }

      if (nextTurnCount > _maxTurn) continue;

      _recursiveSearchSync(
        startVertex: startVertex,
        currentVertexId: nextEdge.toVertexId,
        path: [...path, nextEdge.toVertexId],
        currentDistance: currentDistance + nextEdge.meterLength,
        turnCount: nextTurnCount,
        currentWay: nextEdge.way,
        candidates: candidates,
        edgesMap: edgesMap,
        poisMap: poisMap,
        vertexMap: vertexMap,
      );
    }
  }

  bool _isWalkable(WayType way) {
    return way == WayType.horizon || way == WayType.vertical;
  }

  // PoiRepository에 1px=0.1m 상수가 적용되었다고 가정하고
  // 여기서도 미터 단위 거리 계산을 위해 스케일 적용 (만약 Repository에서 가져온 Vertex 좌표가 픽셀이라면)
  // 하지만 여기서는 Vertex.x, Vertex.y 값 자체(픽셀)로 계산하고 비율을 구하므로 스케일은 상쇄됨.
  // 다만 displacement 값을 미터로 쓰려면 스케일링 필요.
  double _calcEuclideanDist(Vertex v1, Vertex v2) {
    final dx = v1.x - v2.x;
    final dy = v1.y - v2.y;
    // 픽셀 거리 * 0.1 => 미터 거리
    return sqrt(dx * dx + dy * dy) * 0.1;
  }
}
