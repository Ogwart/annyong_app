import 'package:annyong/domain/entity/graph_models.dart';
import 'package:collection/collection.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

class PathResult {
  final List<int> path;
  final double totalCost;

  PathResult({required this.path, required this.totalCost});
}

class PathFinder {
  final Map<int, Vertex> vertices;
  final Map<int, List<Edge>> adjacencyList;

  PathFinder({required this.vertices, required this.adjacencyList});

  double _heuristic(int currentId, int goalId) {
    final current = vertices[currentId];
    final goal = vertices[goalId];

    if (current == null || goal == null) return double.infinity;

    final dx = current.x - goal.x;
    final dy = current.y - goal.y;
    return sqrt(dx * dx + dy * dy);
  }

  List<int> _reconstructPath(Map<int, int> cameFrom, int currentId) {
    final path = <int>[currentId];
    while (cameFrom.containsKey(currentId)) {
      currentId = cameFrom[currentId]!;
      path.insert(0, currentId);
    }
    return path;
  }

  PathResult? findShortestPath(int startId, int goalId) {
    // 시작점과 종료점 유효성 검사
    if (!vertices.containsKey(startId) || !vertices.containsKey(goalId)) {
      return null;
    }

    final openSet = PriorityQueue<_PrioQueueEntry>();
    final cameFrom = <int, int>{};
    final gCost = <int, double>{startId: 0.0};

    openSet.add(
      _PrioQueueEntry(fCost: _heuristic(startId, goalId), vertexId: startId),
    );

    // A* 알고리즘 메인 루프
    while (openSet.isNotEmpty) {
      final currentId = openSet.removeFirst().vertexId;

      if (currentId == goalId) {
        return PathResult(
          path: _reconstructPath(cameFrom, currentId),
          totalCost: gCost[goalId]!,
        );
      }

      final edges = adjacencyList[currentId];
      if (edges == null) continue;

      for (final edge in edges) {
        final neighborId = edge.toVertexId;
        final tentativeGCost = gCost[currentId]! + edge.length;

        if (tentativeGCost < (gCost[neighborId] ?? double.infinity)) {
          cameFrom[neighborId] = currentId;
          gCost[neighborId] = tentativeGCost;

          final fCost = tentativeGCost + _heuristic(neighborId, goalId);
          openSet.add(_PrioQueueEntry(fCost: fCost, vertexId: neighborId));
        }
      }
    }

    return null;
  }

  // 다중 경유지가 있을때 탐색 방법
  PathResult? findPathWithWaypoints(List<int> orderedVertexIds) {
    if (orderedVertexIds.length < 2) return null;

    List<int> fullPath = [];
    double totalCost = 0.0;

    debugPrint('----------- [findPathWithWaypoints Start] -----------');
    // [출발, 경유1, 경유2, 도착] 리스트를 순회하며 구간별 경로 계산
    for (int i = 0; i < orderedVertexIds.length - 1; i++) {
      final startId = orderedVertexIds[i];
      final endId = orderedVertexIds[i + 1];

      // 구간 경로 탐색
      final result = findShortestPath(startId, endId);

      // 경로가 하나라도 끊기면 전체 실패 처리
      if (result == null) {
        return null;
      }

      // 경로 병합 로직
      if (fullPath.isEmpty) {
        fullPath.addAll(result.path);
      } else if (result.path.isNotEmpty) {
        // 이어 붙일 때 중복 제거
        fullPath.addAll(result.path.sublist(1));
      }

      totalCost += result.totalCost;
    }
    debugPrint('경로 탐색 완료: 총비용 $totalCost, 총길이 ${fullPath.length}');
    debugPrint('----------- [findPathWithWaypoints End] -----------');
    return PathResult(path: fullPath, totalCost: totalCost);
  }
}

class _PrioQueueEntry implements Comparable<_PrioQueueEntry> {
  final double fCost;
  final int vertexId;

  _PrioQueueEntry({required this.fCost, required this.vertexId});

  @override
  int compareTo(_PrioQueueEntry other) {
    return fCost.compareTo(other.fCost);
  }
}
