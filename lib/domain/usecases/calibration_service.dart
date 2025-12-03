// lib/domain/usecases/calibration_service.dart

import 'package:annyong/domain/entity/calibration_route.dart';
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:flutter/foundation.dart';

/// 내부 계산용 후보 객체
class _CalibrationCandidate {
  final List<int> vertexPath; // 경로상 정점 ID 리스트
  final double distance; // 총 거리
  final Poi? destinationPoi; // 도착지 POI
  final int turnCount; // 꺾인 횟수
  final bool isLandmark; // 물리적 랜드마크(코너, 막다른길) 여부

  _CalibrationCandidate({
    required this.vertexPath,
    required this.distance,
    this.destinationPoi,
    required this.turnCount,
    this.isLandmark = false,
  });

  /// 점수 계산 로직 개선
  /// 사용자 인지 가능성(POI > 랜드마크 > 거리 적합성) 순으로 점수 부여
  double get score {
    double baseScore = 0.0;

    // [1순위] 확실한 목적지(POI)가 있는가?
    // 거리가 조금 멀더라도 POI가 있으면 압도적으로 높은 점수 부여
    if (destinationPoi != null) {
      baseScore += 50000.0;
    }
    // [2순위] POI는 없지만 물리적 특징(코너, 막다른 길)이 있는가?
    // 허공에 멈추는 것보다는 코너까지 가는게 명확함
    else if (isLandmark) {
      baseScore += 10000.0;
    }

    // [3순위] 회전 수 페널티 (직진이 최고)
    // 회전 1회당 500점 감점 (POI 유무를 뒤집을 정도는 아니게 설정)
    baseScore -= (turnCount * 500.0);

    // [4순위] 거리 적합성 (이상적 거리 7.5m)
    // 너무 멀어질수록 감점 (1m당 100점 감점)
    final distancePenalty = (distance - 7.5).abs() * 100.0;
    baseScore -= distancePenalty;

    return baseScore;
  }
}

class CalibrationService {
  final PoiRepository _poiRepo;

  CalibrationService(this._poiRepo);

  // ===========================================================================
  // 상수 정의
  // ===========================================================================
  // 최적 거리 범위
  static const double _optimalMin = 5.0;
  static const double _optimalMax = 10.0;

  // 확장 허용 범위 (POI가 있다면 여기까지 허용)
  static const double _extendedMax = 15.0;

  // 꺾임 허용 횟수
  static const int _maxTurn = 2;

  // ===========================================================================
  // 메인 로직
  // ===========================================================================

  Future<CalibrationRoute?> findTargetRoute(Poi startPoi) async {
    if (startPoi.vertexId == null) return null;

    final startVertexId = startPoi.vertexId!;
    final startVertex = await _poiRepo.getVertexById(startVertexId);
    if (startVertex == null) return null;

    final List<_CalibrationCandidate> candidates = [];
    final initialEdges = await _poiRepo.getEdgesForVertex(startVertexId);

    // DFS 탐색 시작
    for (final edge in initialEdges) {
      if (!_isWalkable(edge.way)) continue;

      await _recursiveSearch(
        currentVertexId: edge.toVertexId,
        path: [startVertexId, edge.toVertexId],
        currentDistance: edge.length,
        turnCount: 0,
        currentWay: edge.way,
        candidates: candidates,
      );
    }

    if (candidates.isEmpty) return null;

    // 점수순 정렬 (POI 있음 > 랜드마크임 > 거리 적절함 순서)
    candidates.sort((a, b) => b.score.compareTo(a.score));

    final best = candidates.first;
    // 경로상의 모든 Vertex 객체 가져오기 (선을 꺾어서 그리기 위해 필요)
    final List<Vertex> pathVertices = [];
    for (final vId in best.vertexPath) {
      final v = await _poiRepo.getVertexById(vId);
      if (v != null) pathVertices.add(v);
    }

    if (pathVertices.isEmpty) return null; // 로직상 희박

    final endVertex = await _poiRepo.getVertexById(best.vertexPath.last);

    // 만약 POI가 없는 곳이 당첨되었다면, 사용자에게 보여줄 힌트 텍스트 생성
    String? hintDescription;
    if (best.destinationPoi == null && best.isLandmark) {
      hintDescription = "길이 끝나는 곳(혹은 코너)까지 이동";
    }

    // destinationPoi가 null일 때를 대비해,
    // 화면에 보여줄 가상의 이름이 필요하다면 UI단에서 처리하거나
    // 여기서 임시 POI를 만들 수도 있지만,
    // 앞서 정한대로 'Entity는 Nullable POI'를 유지합니다.

    return CalibrationRoute(
      startPoi: startPoi,
      destinationVertex: endVertex!,
      destinationPoi: best.destinationPoi, // null일 수 있음 (UI에서 처리 필요)
      pathVertices: pathVertices, // [NEW] 전체 경로 리스트 전달
      totalDistance: best.distance,
      mode: "one-way",
    );
  }

  // ===========================================================================
  // 재귀 탐색 (DFS)
  // ===========================================================================

  Future<void> _recursiveSearch({
    required int currentVertexId,
    required List<int> path,
    required double currentDistance,
    required int turnCount,
    required WayType currentWay,
    required List<_CalibrationCandidate> candidates,
  }) async {
    // 1. 탐색 거리 한계 (13m 넘으면 무조건 중단)
    if (currentDistance > _extendedMax) return;

    // 현재 위치 정보 조회
    final pois = await _poiRepo.getPoisByVertexId(currentVertexId);
    final nextEdges = await _poiRepo.getEdgesForVertex(currentVertexId);

    // 2. 물리적 특징(Landmark) 판별
    // 더 이상 갈 길이 없거나(막다른 길), 길이 갈라지는 곳(교차로)인지 확인
    // (여기서는 단순화를 위해 '다음 엣지가 없으면 막다른 길'로 간주)
    // 단, 왔던 길은 제외해야 하므로 (edge count - 1) 등을 고려해야 정확하지만
    // 여기서는 '직진 불가능' 상황 등을 랜드마크로 볼 수 있음.

    // 유효한 다음 경로 개수 (왔던 길 제외)
    int validNextPaths = 0;
    bool isCorner = false;

    for (final e in nextEdges) {
      if (path.length >= 2 && e.toVertexId == path[path.length - 2]) continue;
      if (_isWalkable(e.way)) {
        validNextPaths++;
        // 진행 방향이 바뀌면 코너
        if (e.way != currentWay && e.way.supportsTurnCalculation) {
          isCorner = true;
        }
      }
    }

    // 랜드마크 여부: POI가 없더라도 멈추기 좋은 지점인가?
    // - 막다른 길 (validNextPaths == 0)
    // - 코너 직전 (isCorner == true 인데 여기서 멈춘다면? -> 이건 애매함. 코너는 꺾고 나서가 아니라 꺾이는 지점)
    // 여기서는 단순하게 "갈 길이 없으면 막다른 길"로 간주
    final bool isDeadEnd = (validNextPaths == 0);

    // =========================================================
    // [후보 등록 로직]
    // =========================================================

    // A. 최적 거리 (6.3 ~ 8.7m) 구간
    if (currentDistance >= _optimalMin && currentDistance <= _optimalMax) {
      candidates.add(
        _CalibrationCandidate(
          vertexPath: List.from(path),
          distance: currentDistance,
          turnCount: turnCount,
          destinationPoi: pois.isNotEmpty ? pois.first : null,
          isLandmark: isDeadEnd, // 막다른 길이면 가산점
        ),
      );
    }
    // B. 확장 거리 (8.7 ~ 13.0m) 구간
    // 여기서는 'POI가 있는 경우' 혹은 '막다른 길'인 경우만 후보로 인정
    // (허공에 12m 걷게 하는 것은 방지)
    else if (currentDistance > _optimalMax && currentDistance <= _extendedMax) {
      if (pois.isNotEmpty || isDeadEnd) {
        candidates.add(
          _CalibrationCandidate(
            vertexPath: List.from(path),
            distance: currentDistance,
            turnCount: turnCount,
            destinationPoi: pois.isNotEmpty ? pois.first : null,
            isLandmark: isDeadEnd,
          ),
        );
      }
    }

    // 다음 경로 탐색
    for (final nextEdge in nextEdges) {
      // 왔던 길 되돌아가기 방지
      if (path.length >= 2 && nextEdge.toVertexId == path[path.length - 2])
        continue;
      if (!_isWalkable(nextEdge.way)) continue;

      int nextTurnCount = turnCount;
      if (currentWay != nextEdge.way && nextEdge.way.supportsTurnCalculation) {
        nextTurnCount++;
      }

      if (nextTurnCount > _maxTurn) continue;

      await _recursiveSearch(
        currentVertexId: nextEdge.toVertexId,
        path: [...path, nextEdge.toVertexId],
        currentDistance: currentDistance + nextEdge.length,
        turnCount: nextTurnCount,
        currentWay: nextEdge.way,
        candidates: candidates,
      );
    }
  }

  bool _isWalkable(WayType way) {
    return way == WayType.horizon || way == WayType.vertical;
  }
}
