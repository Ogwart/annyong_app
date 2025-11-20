import 'dart:convert';
import 'dart:math';

import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/entity/poi_category.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class PoiRepository {
  PoiRepository._();

  static final PoiRepository _instance = PoiRepository._();

  factory PoiRepository() => _instance;

  List<PoiCategory>? _cachedCategories;
  List<Poi>? _cachedPois;
  Map<int, Vertex>? _cachedVertices;
  Map<int, List<Edge>>? _cachedAdjacencyList;

  Future<List<PoiCategory>> fetchCategories() async {
    if (_cachedCategories != null) {
      return _cachedCategories!;
    }

    final raw = await rootBundle.loadString('assets/poi/poi_category.json');
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    _cachedCategories = decoded
        .map((item) => PoiCategory.fromJson(item as Map<String, dynamic>))
        .toList();
    return _cachedCategories!;
  }

  Future<List<Poi>> fetchPois() async {
    if (_cachedPois != null) {
      return _cachedPois!;
    }

    final raw = await rootBundle.loadString('assets/poi/poi.json');
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    _cachedPois = decoded
        .map((item) => Poi.fromJson(item as Map<String, dynamic>))
        .toList();
    return _cachedPois!;
  }

  /// Vertex 데이터 로드 및 캐싱
  Future<void> _loadVertices() async {
    if (_cachedVertices != null) {
      return;
    }

    final raw = await rootBundle.loadString('assets/graph/vertex.json');
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    _cachedVertices = {};

    for (final rawVertex in decoded) {
      try {
        if (rawVertex is! Map<String, dynamic>) {
          continue;
        }
        final vertex = Vertex.fromJson(rawVertex);
        _cachedVertices![vertex.id] = vertex;
      } catch (error) {
        debugPrint('잘못된 정점 데이터가 무시되었습니다: $error');
      }
    }
  }

  /// Edge 데이터 로드 및 캐싱
  Future<void> _loadEdges() async {
    if (_cachedAdjacencyList != null) {
      return;
    }

    await _loadVertices(); // Vertex가 먼저 로드되어야 함

    final raw = await rootBundle.loadString('assets/graph/edge.json');
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    _cachedAdjacencyList = {};

    for (final rawEdge in decoded) {
      if (rawEdge is! Map<String, dynamic>) {
        continue;
      }

      final v1Id = _tryParseInt(rawEdge['vertex1_id']);
      final v2Id = _tryParseInt(rawEdge['vertex2_id']);
      final length = _sanitizeLength(rawEdge['length']);
      final rawWay = rawEdge['way'] as String?;
      final wayType = WayTypeParser.from(rawWay);

      if (v1Id == null ||
          v2Id == null ||
          v1Id < 0 ||
          v2Id < 0 ||
          v1Id == v2Id) {
        continue;
      }

      _cachedAdjacencyList!
          .putIfAbsent(v1Id, () => [])
          .add(
            Edge(
              toVertexId: v2Id,
              length: length,
              way: wayType,
              isReversed: false,
            ),
          );

      _cachedAdjacencyList!
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

  /// Vertex ID로 Vertex 조회
  Future<Vertex?> getVertexById(int vertexId) async {
    await _loadVertices();
    return _cachedVertices?[vertexId];
  }

  /// Vertex ID로 연결된 모든 POI 조회
  Future<List<Poi>> getPoisByVertexId(int vertexId) async {
    final pois = await fetchPois();
    return pois.where((poi) => poi.vertexId == vertexId).toList();
  }

  /// Vertex ID로 연결된 모든 Edge 조회
  Future<List<Edge>> getEdgesForVertex(int vertexId) async {
    await _loadEdges();
    return _cachedAdjacencyList?[vertexId] ?? [];
  }

  /// 두 점 사이의 유클리드 거리 계산 (POI와 Vertex)
  double getStraightLineDistance(Poi poi, Vertex vertex) {
    final dx = poi.xCoord - vertex.x;
    final dy = poi.yCoord - vertex.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// 두 Vertex 사이의 유클리드 거리 계산
  double getStraightLineDistanceBetweenVertices(Vertex v1, Vertex v2) {
    final dx = v1.x - v2.x;
    final dy = v1.y - v2.y;
    return sqrt(dx * dx + dy * dy);
  }
}
