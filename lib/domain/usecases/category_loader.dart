import 'package:annyong/domain/entity/poi_category.dart';
import 'package:annyong/domain/repository/poi_repository.dart';

class CategoryLoader {
  final PoiRepository _poiRepo;
  CategoryLoader(this._poiRepo);

  Future<List<PoiCategory>> getCategory() async {
    return await _poiRepo.fetchCategories();
  }
}
