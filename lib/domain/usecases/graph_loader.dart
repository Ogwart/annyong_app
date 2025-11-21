import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/usecases/path_finder.dart';

class GraphLoader {
  const GraphLoader._();

  static Future<PathFinder> loadFromAssets({
    String verticesAssetPath = 'assets/graph/vertex.json',
    String edgesAssetPath = 'assets/graph/edge.json',
  }) async {
    final vertexJsonString = await rootBundle.loadString(verticesAssetPath);
    final edgeJsonString = await rootBundle.loadString(edgesAssetPath);

    final vertexList = json.decode(vertexJsonString) as List<dynamic>; // 정점 파싱
    final vertices = <int, Vertex>{}; // ID-정점 맵

    // 정점 데이터 처리
    for (final rawVertex in vertexList) {
      try {
        if (rawVertex is! Map<String, dynamic>) {
          throw const FormatException('vertex 항목이 Map 형태가 아닙니다.');
        }
        final vertex = Vertex.fromJson(rawVertex);
        vertices[vertex.id] = vertex;
      } catch (error, stackTrace) {
        debugPrint('잘못된 정점 데이터가 무시되었습니다: $error');
        debugPrint('$stackTrace');
      }
    }

    final edgeList = json.decode(edgeJsonString) as List<dynamic>; // 엣지 파싱
    final adjacencyList = <int, List<Edge>>{}; // 인접 리스트 맵

    // 엣지 데이터 처리
    for (final rawEdge in edgeList) {
      if (rawEdge is! Map<String, dynamic>) {
        debugPrint('잘못된 엣지 데이터가 무시되었습니다: $rawEdge');
        continue;
      }

      final v1Id = _tryParseInt(rawEdge['vertex1_id']);
      final v2Id = _tryParseInt(rawEdge['vertex2_id']);
      final length = _sanitizeLength(rawEdge['length']);
      final rawWay = rawEdge['way'] as String?;
      final wayType = WayTypeParser.from(rawWay);

      // 정점 오류 처리
      if (v1Id == null || v2Id == null) {
        debugPrint('정점 ID가 없어 엣지를 무시했습니다: $rawEdge');
        continue;
      }
      if (v1Id < 0 || v2Id < 0) {
        debugPrint('미지원 정점 ID여서 엣지를 무시했습니다: $rawEdge');
        continue;
      }
      if (v1Id == v2Id) {
        debugPrint('동일한 정점 간 엣지여서 무시했습니다: $rawEdge');
        continue;
      }

      adjacencyList
          .putIfAbsent(v1Id, () => [])
          .add(
            Edge(
              toVertexId: v2Id,
              length: length,
              way: wayType,
              isReversed: false,
            ),
          );

      adjacencyList
          .putIfAbsent(v2Id, () => [])
          .add(
            Edge(
              toVertexId: v1Id,
              length: length,
              way: wayType,
              isReversed: true,
            ),
          );
    }

    return PathFinder(vertices: vertices, adjacencyList: adjacencyList);
  }
}

int? _tryParseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

double _sanitizeLength(dynamic value) {
  if (value is num) {
    final cleaned = value.toDouble();
    return cleaned <= 0 ? 0.1 : cleaned;
  }
  return 0.1;
}
