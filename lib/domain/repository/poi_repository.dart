import 'dart:convert';
import 'dart:math'; // [추가] 거리 계산을 위해 추가

import 'package:annyong/domain/entity/beacon.dart';
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
  List<Beacon>? _cachedBeacons;

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

  /// Edge 데이터 로드 및 캐싱 (수정됨: 좌표 기반 거리 계산 적용)
  Future<void> _loadEdges() async {
    if (_cachedAdjacencyList != null) {
      return;
    }

    await _loadVertices(); // Vertex가 먼저 로드되어야 좌표를 참조할 수 있음

    final raw = await rootBundle.loadString('assets/graph/edge.json');
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    _cachedAdjacencyList = {};

    for (final rawEdge in decoded) {
      if (rawEdge is! Map<String, dynamic>) {
        continue;
      }

      final v1Id = _tryParseInt(rawEdge['vertex1_id']);
      final v2Id = _tryParseInt(rawEdge['vertex2_id']);
      final rawWay = rawEdge['way'] as String?;
      final wayType = WayTypeParser.from(rawWay);

      if (v1Id == null ||
          v2Id == null ||
          v1Id < 0 ||
          v2Id < 0 ||
          v1Id == v2Id) {
        continue;
      }

      // [수정] 정점 정보를 가져와서 거리 직접 계산
      final v1 = _cachedVertices?[v1Id];
      final v2 = _cachedVertices?[v2Id];

      if (v1 == null || v2 == null) {
        debugPrint('존재하지 않는 정점을 연결하는 엣지여서 무시했습니다: $v1Id <-> $v2Id');
        continue;
      }

      final double dx = v1.x - v2.x;
      final double dy = v1.y - v2.y;
      final double length = sqrt(dx * dx + dy * dy);

      _cachedAdjacencyList!
          .putIfAbsent(v1Id, () => [])
          .add(
            Edge(
              toVertexId: v2Id,
              length: length, // 계산된 거리 사용
              way: wayType,
              isReversed: false,
            ),
          );

      _cachedAdjacencyList!
          .putIfAbsent(v2Id, () => [])
          .add(
            Edge(
              toVertexId: v1Id,
              length: length, // 계산된 거리 사용
              way: wayType,
              isReversed: true,
            ),
          );
    }
  }

  //비콘 데이터 로드 및 캐싱
  Future<List<Beacon>> fetchBeacons() async {
    if (_cachedBeacons != null) return _cachedBeacons!;
    try {
      final raw = await rootBundle.loadString('assets/poi/beacon.json');
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      _cachedBeacons = decoded
          .map((item) => Beacon.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('비콘 데이터 로드 실패: $e');
      _cachedBeacons = [];
    }
    return _cachedBeacons!;
  }

  int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  // _sanitizeLength는 더 이상 사용되지 않지만, 다른 유틸리티 용도로 남겨두거나 삭제 가능합니다.
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

  /// POI ID 리스트로 POI 조회
  Future<List<Poi>> getPoisByIds(List<int> poiIds) async {
    final pois = await fetchPois();
    final poiMap = {for (var poi in pois) poi.id: poi};
    return poiIds
        .map((id) => poiMap[id])
        .where((poi) => poi != null)
        .cast<Poi>()
        .toList();
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

  Future<Beacon?> findBeaconByMac(String macId) async {
    final beacons = await fetchBeacons();
    try {
      return beacons.firstWhere(
        (b) => b.macId.toLowerCase() == macId.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // ===========================================================================
  // [NEW] 맵 매칭 & 위치 보정용 헬퍼 함수들
  // ===========================================================================

  /// 특정 좌표(x, y)에서 가장 가까운 Edge N개를 찾아서 반환
  Future<List<(Edge, Vertex, Vertex, double)>> findNearestEdges(
    double x,
    double y, {
    int count = 3,
  }) async {
    await _loadVertices();
    await _loadEdges();

    final List<(Edge, Vertex, Vertex, double)> candidates = [];
    final visitedEdgeKeys = <String>{};

    _cachedAdjacencyList?.forEach((startVId, edges) {
      final startV = _cachedVertices![startVId];
      if (startV == null) return;

      for (var edge in edges) {
        final endV = _cachedVertices![edge.toVertexId];
        if (endV == null) return;

        // 중복 방지 (양방향 엣지 하나로 취급)
        final key = startVId < edge.toVertexId
            ? '$startVId-${edge.toVertexId}'
            : '${edge.toVertexId}-$startVId';

        if (visitedEdgeKeys.contains(key)) continue;
        visitedEdgeKeys.add(key);

        final dist = _getDistanceToSegment(x, y, startV, endV);
        candidates.add((edge, startV, endV, dist));
      }
    });

    candidates.sort((a, b) => a.$4.compareTo(b.$4));
    return candidates.take(count).toList();
  }

  /// 점(px, py)와 선분(v1-v2) 사이의 최단 거리 계산
  double _getDistanceToSegment(double px, double py, Vertex v1, Vertex v2) {
    final double x1 = v1.x;
    final double y1 = v1.y;
    final double x2 = v2.x;
    final double y2 = v2.y;

    final double dx = x2 - x1;
    final double dy = y2 - y1;

    if (dx == 0 && dy == 0) {
      return sqrt(pow(px - x1, 2) + pow(py - y1, 2));
    }

    final double t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy);

    double closestX, closestY;
    if (t < 0) {
      closestX = x1;
      closestY = y1;
    } else if (t > 1) {
      closestX = x2;
      closestY = y2;
    } else {
      closestX = x1 + t * dx;
      closestY = y1 + t * dy;
    }

    return sqrt(pow(px - closestX, 2) + pow(py - closestY, 2));
  }
}
