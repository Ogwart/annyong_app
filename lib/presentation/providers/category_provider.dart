// ignore_for_file: unused_element

import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/category_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _poiRepositoryProvider = Provider((ref) {
  return PoiRepository();
});

final _categoryUsecaseProvider = Provider((ref) {
  return CategoryLoader(ref.watch(_poiRepositoryProvider));
});
