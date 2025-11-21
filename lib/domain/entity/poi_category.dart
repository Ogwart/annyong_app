class PoiCategory {
  final int id;
  final String name;

  const PoiCategory({required this.id, required this.name});

  factory PoiCategory.fromJson(Map<String, dynamic> json) {
    return PoiCategory(
      id: json['poi_category_id'] as int,
      name: json['poi_category_name'] as String? ?? '',
    );
  }
}
