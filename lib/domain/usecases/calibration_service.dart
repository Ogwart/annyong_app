// lib/domain/usecases/calibration_service.dart
import 'dart:collection';
import 'package:annyong/domain/entity/calibration_route.dart';
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/presentation/util/pixels_to_meters.dart';

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
  static const double _optimalMin = 3.0;
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

    // =========================================================================
    // [성능 최적화] 데이터 미리 가져오기 (Pre-fetching)
    // =========================================================================
    final Map<int, List<Edge>> localEdgesMap = {};
    final Map<int, List<Poi>> localPoisMap = {};

    final Queue<int> loadQueue = Queue();
    final Set<int> loadedVertices = {};

    loadQueue.add(startVertexId);
    loadedVertices.add(startVertexId);

    int safetyCount = 0;
    while (loadQueue.isNotEmpty && safetyCount < 200) {
      final currentId = loadQueue.removeFirst();
      safetyCount++;

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
    // =========================================================================

    final List<_CalibrationCandidate> candidates = [];
    final initialEdges = localEdgesMap[startVertexId] ?? [];

    // [수정] 출발 POI와 시작 정점 사이의 거리 계산 (픽셀 -> 미터 변환)
    final startOffsetMeters = pointsToMeters(
      startPoi.xCoord,
      startPoi.yCoord,
      startVertex.x,
      startVertex.y,
    );

    // DFS 탐색 시작
    for (final edge in initialEdges) {
      if (!_isWalkable(edge.way)) continue;

      // [수정] 엣지 길이도 미터로 변환
      final edgeLengthMeters = pixelsToMeters(edge.length);

      // await 삭제
      _recursiveSearchSync(
        currentVertexId: edge.toVertexId,
        path: [startVertexId, edge.toVertexId],
        currentDistance:
            startOffsetMeters + edgeLengthMeters, // 초기 거리 = 오프셋 + 첫 엣지
        turnCount: 0,
        currentWay: edge.way,
        candidates: candidates,
        edgesMap: localEdgesMap, // 로컬 캐시 전달
        poisMap: localPoisMap, // 로컬 캐시 전달
      );
    }

    if (candidates.isEmpty) return null;

    // 점수순 정렬 (POI 있음 > 랜드마크임 > 거리 적절함 순서)
    // [DEBUG] 정렬 전 모든 후보 출력
    print("--- Calibration Candidates (Total: ${candidates.length}) ---");
    for (int i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      print(
        "[$i] Path: ${c.vertexPath}, Dist: ${c.distance.toStringAsFixed(2)}m, "
        "Turn: ${c.turnCount}, POI: ${c.destinationPoi?.name}, "
        "Landmark: ${c.isLandmark}, Score: ${c.score.toStringAsFixed(1)}",
      );
    }
    print("---------------------------------------------------------");

    candidates.sort((a, b) => b.score.compareTo(a.score));

    final best = candidates.first;
    print(
      "BEST >> Path: ${best.vertexPath}, Dist: ${best.distance.toStringAsFixed(2)}m, Score: ${best.score}",
    );

    // 경로상의 모든 Vertex 객체 가져오기 (선을 꺾어서 그리기 위해 필요)
    final List<Vertex> pathVertices = [];
    for (final vId in best.vertexPath) {
      final v = await _poiRepo.getVertexById(vId);
      if (v != null) pathVertices.add(v);
    }

    print(
      "CalibrationService: pathVertices count: ${pathVertices.length}, IDs: ${best.vertexPath}",
    );

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

  void _recursiveSearchSync({
    required int currentVertexId,
    required List<int> path,
    required double currentDistance,
    required int turnCount,
    required WayType currentWay,
    required List<_CalibrationCandidate> candidates,
    required Map<int, List<Edge>> edgesMap, // 데이터 소스
    required Map<int, List<Poi>> poisMap, // 데이터 소스
  }) {
    // _recursiveSearchSync 함수 초입에 로그 추가
    print("Node $currentVertexId, Dist: $currentDistance");

    // 1. 탐색 거리 한계 (13m 넘으면 무조건 중단)
    if (currentDistance > _extendedMax) return;

    // 현재 위치 정보 조회
    // [성능 개선] await 없이 Map에서 즉시 조회
    final pois = poisMap[currentVertexId] ?? [];
    final nextEdges = edgesMap[currentVertexId] ?? [];

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
    // 막다른 길(갈 곳이 없음)이거나, 코너(방향이 꺾임)인 경우 랜드마크로 인정
    final bool isLandmark = (validNextPaths == 0) || isCorner;

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
          isLandmark: isLandmark, // 막다른 길이면 가산점
        ),
      );
    }
    // B. 확장 거리 (8.7 ~ 13.0m) 구간
    // 여기서는 'POI가 있는 경우' 혹은 '막다른 길'인 경우만 후보로 인정
    // (허공에 12m 걷게 하는 것은 방지)
    else if (currentDistance > _optimalMax && currentDistance <= _extendedMax) {
      if (pois.isNotEmpty || isLandmark) {
        candidates.add(
          _CalibrationCandidate(
            vertexPath: List.from(path),
            distance: currentDistance,
            turnCount: turnCount,
            destinationPoi: pois.isNotEmpty ? pois.first : null,
            isLandmark: isLandmark,
          ),
        );
      }
    }

    // 다음 경로 탐색
    for (final nextEdge in nextEdges) {
      // 왔던 길 되돌아가기 방지
      if (path.length >= 2 && nextEdge.toVertexId == path[path.length - 2]) {
        continue;
      }
      if (!_isWalkable(nextEdge.way)) continue;

      int nextTurnCount = turnCount;
      if (currentWay != nextEdge.way && nextEdge.way.supportsTurnCalculation) {
        nextTurnCount++;
      }

      if (nextTurnCount > _maxTurn) continue;

      // [수정] 다음 엣지 길이 미터 변환
      final nextEdgeLengthMeters = pixelsToMeters(nextEdge.length);

      _recursiveSearchSync(
        currentVertexId: nextEdge.toVertexId,
        path: [...path, nextEdge.toVertexId],
        currentDistance: currentDistance + nextEdgeLengthMeters, // 미터 단위 누적
        turnCount: nextTurnCount,
        currentWay: nextEdge.way,
        candidates: candidates,
        edgesMap: edgesMap,
        poisMap: poisMap,
      );
    }
  }

  bool _isWalkable(WayType way) {
    return way == WayType.horizon || way == WayType.vertical;
  }
}
