import 'package:annyong/domain/entity/graph_models.dart';
import 'package:collection/collection.dart';
import 'dart:math';

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

    // A* 알고리즘
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
