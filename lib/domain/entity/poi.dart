class Poi {
  final int id;
  final String name;
  final String? description;
  final int categoryId;
  final int buildingId;
  final int floor;
  final double xCoord;
  final double yCoord;
  final String? vertex;

  const Poi({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.buildingId,
    required this.floor,
    required this.xCoord,
    required this.yCoord,
    required this.vertex,
  });

  factory Poi.fromJson(Map<String, dynamic> json) {
    return Poi(
      id: json['poi_id'] as int,
      name: json['poi_name'] as String? ?? '',
      description: json['description'] as String?,
      categoryId: json['poi_category_id'] as int,
      buildingId: json['building_id'] as int,
      floor: json['floor'] as int? ?? 0,
      xCoord: (json['x_coord'] as num?)?.toDouble() ?? 0,
      yCoord: (json['y_coord'] as num?)?.toDouble() ?? 0,
      vertex: json['vertex'] as String?,
    );
  }
}

