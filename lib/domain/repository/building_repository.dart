import 'dart:convert';
import 'package:annyong/domain/entity/building.dart';
import 'package:flutter/services.dart' show rootBundle;

class BuildingRepository {
  BuildingRepository._();

  static final BuildingRepository _instance = BuildingRepository._();

  factory BuildingRepository() => _instance;

  List<Building>? _cachedBuildings;

  Future<List<Building>> fetchBuildings() async {
    if (_cachedBuildings != null) {
      return _cachedBuildings!;
    }

    final raw = await rootBundle.loadString('assets/poi/building.json');
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    _cachedBuildings = decoded
        .map((item) => Building.fromJson(item as Map<String, dynamic>))
        .toList();
    return _cachedBuildings!;
  }
}
