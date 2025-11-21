import 'dart:convert';

import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/entity/poi_category.dart';
import 'package:flutter/services.dart' show rootBundle;

class PoiRepository {
  PoiRepository._();

  static final PoiRepository _instance = PoiRepository._();

  factory PoiRepository() => _instance;

  List<PoiCategory>? _cachedCategories;
  List<Poi>? _cachedPois;

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
}
