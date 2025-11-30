import 'package:annyong/domain/entity/calibration_route.dart';
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:flutter/foundation.dart';

/// 보폭 측정 서비스
/// [PoiRepository]에 의존하여 원본 POI 데이터를 가져오고,
/// 보폭 측정에 사용할 최적의 경로(편도/왕복)를 탐색
class CalibrationService {
  final PoiRepository _poiRepo;

  CalibrationService(this._poiRepo);

  // ===========================================================================
  // 보폭 측정 경로 탐색
  // ===========================================================================

  /// 보폭 측정을 위한 최적의 경로를 찾아 반환
  /// 1순위: 7m 근방(5.6m 이상)의 편도(one-way)
  /// 2순위: 가장 긴 직선 경로를 왕복(round-trip)
  Future<CalibrationRoute?> findTargetRoute(
    Poi startPoi, {
    double idealDistance = 7.0, // 목표 거리
  }) async {
    // 최소 편도 거리 설정
    final double minOneWayDistance = idealDistance * 0.8; // 5.6m
    // 측정 불가 거리 설정
    final double minRoundTripDistance = 1.0;

    // 1. 시작 POI에 연결된 "시작 정점(Vertex)"을 가져옴
    if (startPoi.vertexId == null) {
      debugPrint("[FindRoute] 실패: 시작 POI(${startPoi.name})에 vertexId가 없습니다.");
      return null;
    }

    final Vertex? startVertex = await _poiRepo.getVertexById(
      startPoi.vertexId!,
    );
    if (startVertex == null) {
      debugPrint(
        "[FindRoute] 실패: Vertex ID(${startPoi.vertexId})에 해당하는 정점 데이터를 찾을 수 없습니다.",
      );
      return null;
    }

    // [(도착점 Vertex, 누적 경로 거리)]
    List<(Vertex, double)> availablePaths = [];

    // 경로 탐색 시작
    // 시작 정점에 연결된 모든 엣지(이웃)를 탐색 시작
    final List<Edge> startEdges = await _poiRepo.getEdgesForVertex(
      startVertex.id,
    );

    debugPrint(
      "[FindRoute] 탐색 시작: Vertex ${startVertex.id}의 연결된 엣지 수: ${startEdges.length}개",
    );

    // 양쪽 2개의 이웃 방향(각 엣지 방향)으로 "직선 경로"를 찾음
    for (var startEdge in startEdges) {
      // 계단 엣지는 제외 (length가 0이고 way가 up/down인 경우)
      if (startEdge.way.isStair && startEdge.length == 0) {
        continue;
      }

      final (endVertex, distance) = await _traceStraightPath(
        currentVertexId: startEdge.getOtherVertexId(startVertex.id),
        prevVertexId: startVertex.id,
        currentWay: startEdge.way,
        accumulatedDistance: startEdge.length,
        idealDistance: idealDistance,
      );

      debugPrint(
        "[FindRoute] 경로 탐색 결과: 거리 $distance m, 도착 Vertex ${endVertex?.id}",
      );

      if (endVertex != null) {
        availablePaths.add((endVertex, distance));
      } else {}
    }

    // 유효한 직선 경로가 아예 없는 경우
    if (availablePaths.isEmpty) {
      debugPrint("[FindRoute] 실패: 유효한 직선 경로를 찾지 못했습니다.");
      return null;
    }

    // 찾은 경로들 중 가장 긴 경로 선택
    availablePaths.sort((a, b) => b.$2.compareTo(a.$2)); // 내림차순 정렬
    final (bestVertex, bestDistance) = availablePaths.first;

    // 측정 불가 조건 체크
    if (bestDistance < minRoundTripDistance) {
      debugPrint(
        "[FindRoute] 실패: 최장 경로($bestDistance m)가 최소 기준($minRoundTripDistance m)보다 짧습니다.",
      );
      return null;
    }

    // 마지막 Vertex에 연결된 POI 찾기
    final List<Poi> destinationPois = await _poiRepo.getPoisByVertexId(
      bestVertex.id,
    );

    if (destinationPois.isEmpty) {
      debugPrint(
        "[FindRoute] 실패: 도착 지점(Vertex ${bestVertex.id})에 연결된 POI가 없습니다.",
      );
      return null;
    }

    // 가장 가까운 POI 선택 (Vertex와의 거리가 가장 가까운 것)
    Poi destinationPoi = destinationPois.first;
    double minDistance = _poiRepo.getStraightLineDistance(
      destinationPoi,
      bestVertex,
    );
    for (final poi in destinationPois) {
      final distance = _poiRepo.getStraightLineDistance(poi, bestVertex);
      if (distance < minDistance) {
        minDistance = distance;
        destinationPoi = poi;
      }
    }

    // 편도/왕복 모드 및 총 거리 결정
    final bool isOneWay = bestDistance >= minOneWayDistance;

    final double totalDistance = isOneWay
        ? bestDistance // 5.6m 이상 (편도)
        : bestDistance * 2.0; // 1m~5.6m (왕복)

    final String mode = isOneWay ? "one-way" : "round-trip";

    // 결정된 거리, 모드 반환
    debugPrint("[FindRoute] 성공: 경로 발견 (${totalDistance}m, $mode)");
    return CalibrationRoute(
      startPoi: startPoi,
      destinationPoi: destinationPoi,
      totalDistance: totalDistance,
      mode: mode,
    );
  }

  /// 한쪽 방향으로 "직선"이 끝날 때까지 탐색하는 헬퍼 함수
  /// (마지막 직선 Vertex, 거기까지의 총 경로 상 누적 거리)를 반환
  /// "직선"이 끝나거나, 누적 거리가 7m 이상인 경우 탐색 종료
  Future<(Vertex?, double)> _traceStraightPath({
    required int currentVertexId, // 탐색을 시작할 정점
    required int prevVertexId,
    required WayType currentWay, // "horizon" 또는 "vertical" 등
    required double accumulatedDistance, // 누적 거리
    required double idealDistance, // 7m
  }) async {
    // 1. 루프를 위한 상태 변수 초기화
    int pId = prevVertexId; // V1
    int cId = currentVertexId; // V2
    WayType wayToFollow = currentWay; // "horizon" 등
    double accDist = accumulatedDistance;
    Vertex? lastStraightVertex;

    // 무한 루프에 빠지는 것을 막기 위해 최대 1000번의 깊이까지만 허용
    int safetyCounter = 0;
    const int maxIterations = 1000;

    // 직선 경로가 끊길 때까지 while 루프
    while (true) {
      if (++safetyCounter > maxIterations) {
        debugPrint(
          "[Warning] _traceStraightPath: 무한 루프 감지로 인해 강제 종료됨(VertexID: $cId)",
        );
        break;
      }

      final currentVertex = await _poiRepo.getVertexById(cId);
      if (currentVertex == null) {
        break; // 맵 데이터 오류
      }

      // 마지막 유효 정점 기록
      lastStraightVertex = currentVertex;

      // [탐색 종료 조건 1: 목표 거리 도달]
      if (accDist >= idealDistance) {
        break; // 7m를 넘었으므로 탐색 성공
      }

      // 현재 정점(cId)에 연결된 모든 엣지(Edge)를 가져옴
      final List<Edge> edges = await _poiRepo.getEdgesForVertex(cId);

      // 다음 엣지 찾기 (단, 왔던 길(pId) 제외)
      Edge? nextEdge;
      for (var edge in edges) {
        final otherVertexId = edge.getOtherVertexId(cId);
        if (otherVertexId != pId) {
          // 계단 엣지는 제외
          if (edge.way.isStair && edge.length == 0) {
            continue;
          }
          nextEdge = edge;
          break; // 복도식 구조라 다음 엣지는 1개뿐
        }
      }

      // 탐색 종료 조건 2: 꺾이거나 막다른 길
      // 막다른 길 : 다음 엣지가 없거나
      // 꺾임 : 다음 엣지의 'way'가 현재 'wayToFollow'와 다르면
      if (nextEdge == null) {
        break;
      }
      if (nextEdge.way != wayToFollow) {
        break;
      }

      // 다음 루프 준비
      // 거리 누적
      accDist += nextEdge.length;

      // 정점 ID 갱신
      pId = cId;
      cId = nextEdge.getOtherVertexId(pId);
    }

    // 마지막 직선 경로의 Vertex와, 거기까지의 총 누적 거리 반환
    return (lastStraightVertex, accDist);
  }
}
