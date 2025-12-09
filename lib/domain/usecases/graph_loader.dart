import 'dart:convert';
import 'dart:math'; // 거리 계산(sqrt, pow)을 위해 추가
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
      final rawWay = rawEdge['way'] as String?;
      final wayType = WayTypeParser.from(rawWay);

      // 정점 ID 유효성 검사
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

      // 두 정점 객체 가져오기 (좌표 계산용)
      final v1 = vertices[v1Id];
      final v2 = vertices[v2Id];

      if (v1 == null || v2 == null) {
        debugPrint('존재하지 않는 정점을 연결하는 엣지여서 무시했습니다: $v1Id <-> $v2Id');
        continue;
      }

      // [수정됨] 두 정점 사이의 유클리드 거리 계산 (length 속성 대체)
      final double dx = v1.x - v2.x;
      final double dy = v1.y - v2.y;
      final double pixelLength = sqrt(dx * dx + dy * dy); // 픽셀 거리
      final double meterLength = pixelLength * 0.1; // 미터 거리

      // 인접 리스트에 추가 (양방향)
      adjacencyList
          .putIfAbsent(v1Id, () => [])
          .add(
            Edge(
              toVertexId: v2Id,
              pixelLength: pixelLength,
              meterLength: meterLength,
              way: wayType,
              isReversed: false,
            ),
          );

      adjacencyList
          .putIfAbsent(v2Id, () => [])
          .add(
            Edge(
              toVertexId: v1Id,
              pixelLength: pixelLength,
              meterLength: meterLength,
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
