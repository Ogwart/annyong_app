// domain/entity/building.dart

class Building {
  final int id;
  final String name;

  const Building({required this.id, required this.name});

  factory Building.fromJson(Map<String, dynamic> json) {
    return Building(
      id: json['building_id'] as int,
      name: json['buidling_name'] as String? ?? '',
    );
  }
}
