import 'package:collection/collection.dart';
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/usecases/path_finder.dart';

class PathDescriptionBuilder {
  Map<String, dynamic> build(
    PathFinder pathFinder,
    List<int> path,
    double totalCost,
  ) {
    // 1. 예외 처리: 경로가 너무 짧을 때
    if (path.length < 2) {
      return {"status": "error", "message": "경로가 너무 짧습니다.", "path": []};
    }

    List<Map<String, dynamic>> steps = []; // 결과를 담는 리스트
    Edge? previousEdge;
    int? previousFromId;

    // 2. 경로 순회하며 steps 리스트 생성
    for (int i = 0; i < path.length - 1; i++) {
      final fromId = path[i];
      final toId = path[i + 1];

      final currentEdge = pathFinder.adjacencyList[fromId]?.firstWhereOrNull(
        (edge) => edge.toVertexId == toId,
      );

      // 엣지 정보가 없을 경우 오류 처리
      if (currentEdge == null) {
        steps.add({
          "sequence": i + 1,
          "vertex1_id": fromId,
          "vertex2_id": toId,
          "way": "UNKNOWN",
        });
        continue;
      }

      // 방향&행동 계산
      final instruction = _resolveInstruction(
        pathFinder: pathFinder,
        currentEdge: currentEdge,
        previousEdge: previousEdge,
        previousFromId: previousFromId,
        currentFromId: fromId,
        currentToId: toId,
      );

      // 결과 추가
      steps.add({
        "sequence": i + 1,
        "vertex1_id": fromId,
        "vertex2_id": toId,
        "way": instruction,
      });

      // 이전 엣지 업데이트 -> 사용자 시선 방향 계산용
      if (currentEdge.way.supportsTurnCalculation) {
        previousEdge = currentEdge;
        previousFromId = fromId;
      } else {
        previousEdge = null;
        previousFromId = null;
      }
    }

    // 3. 최종 결과 반환
    return {
      "total_cost": double.parse(totalCost.toStringAsFixed(2)),
      "count": steps.length,
      "routes": steps,
    };
  }

  String _resolveInstruction({
    required PathFinder pathFinder,
    required Edge currentEdge,
    Edge? previousEdge,
    int? previousFromId,
    required int currentFromId,
    required int currentToId,
  }) {
    final wayInstruction = _getWayInstruction(currentEdge);
    if (wayInstruction.isNotEmpty) {
      return wayInstruction;
    }

    if (previousEdge != null && previousFromId != null) {
      return _getTurnInstruction(
        pathFinder,
        previousEdge,
        currentEdge,
        previousFromId,
        currentFromId,
        currentToId,
      );
    }

    return "직진";
  }

  String _getWayInstruction(Edge edge) {
    switch (edge.way) {
      case WayType.up:
        return edge.isReversed ? "계단 내림" : "계단 오름";
      case WayType.down:
        return edge.isReversed ? "계단 오름" : "계단 내림";
      case WayType.connect:
        return "연결 통로";
      case WayType.horizon:
      case WayType.vertical:
      case WayType.unknown:
        return "";
    }
  }

  String _getTurnInstruction(
    PathFinder pathFinder,
    Edge previousEdge,
    Edge currentEdge,
    int previousFromId,
    int currentFromId,
    int currentToId,
  ) {
    if (previousEdge.way == currentEdge.way) {
      return "직진";
    }

    final vertices = pathFinder.vertices;
    final previousFrom = vertices[previousFromId];
    final currentFrom = vertices[currentFromId];
    final currentTo = vertices[currentToId];

    if (previousFrom == null || currentFrom == null || currentTo == null) {
      return "직진";
    }

    final dx1 = currentFrom.x - previousFrom.x;
    final dy1 = currentFrom.y - previousFrom.y;

    final dx2 = currentTo.x - currentFrom.x;
    final dy2 = currentTo.y - currentFrom.y;

    final crossProduct = (dx1 * dy2) - (dy1 * dx2);

    const tolerance = 1e-6;

    if (crossProduct > tolerance) {
      return "우회전";
    } else if (crossProduct < -tolerance) {
      return "좌회전";
    } else {
      return "직진";
    }
  }
}
