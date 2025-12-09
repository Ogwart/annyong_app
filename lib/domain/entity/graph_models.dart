enum WayType {
  horizon,
  vertical,
  up,
  down,
  connect,
  unknown;

  bool get supportsTurnCalculation {
    return this == WayType.horizon || this == WayType.vertical;
  }

  bool get isStair {
    return this == WayType.up || this == WayType.down;
  }
}

class WayTypeParser {
  static WayType from(String? value) {
    if (value == null) return WayType.unknown;

    switch (value.toLowerCase()) {
      case 'horizon':
        return WayType.horizon;
      case 'vertical':
        return WayType.vertical;
      case 'up':
        return WayType.up;
      case 'down':
        return WayType.down;
      case 'connect':
        return WayType.connect;
      default:
        return WayType.unknown;
    }
  }
}

class Vertex {
  final int id;
  final double x;
  final double y;

  Vertex({required this.id, required this.x, required this.y});

  factory Vertex.fromJson(Map<String, dynamic> json) {
    return Vertex(
      id: json['vertex_id'] as int,
      x: (json['x_coord'] as num).toDouble(),
      y: (json['y_coord'] as num).toDouble(),
    );
  }
}

class Edge {
  final int toVertexId;
  final double pixelLength; // 픽셀 거리 (네비게이션 맵 매칭용)
  final double meterLength; // 실제 미터 거리 (보폭 측정/안내용)
  final WayType way;
  final bool isReversed;

  Edge({
    required this.toVertexId,
    required this.pixelLength,
    required this.meterLength,
    required this.way,
    this.isReversed = false,
  });

  Edge copyWith({
    int? toVertexId,
    double? pixelLength,
    double? meterLength,
    WayType? way,
    bool? isReversed,
  }) {
    return Edge(
      toVertexId: toVertexId ?? this.toVertexId,
      pixelLength: pixelLength ?? this.pixelLength,
      meterLength: meterLength ?? this.meterLength,
      way: way ?? this.way,
      isReversed: isReversed ?? this.isReversed,
    );
  }

  int getOtherVertexId(int currentVertexId) {
    return toVertexId;
  }
}
