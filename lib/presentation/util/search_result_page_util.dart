import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';

class SearchResultPageUtil {
  /// 현재 건물과 층에 맞는 POI 필터링
  static List<Poi> getFilteredPoisForCurrentBuildingAndFloor(
    List<Poi> allPois,
    String building,
    String floor,
  ) {
    final buildingIds = MapUtilFunctions.getBuildingIds(building);
    final floorNumber = MapUtilFunctions.getFloorNumber(floor);
    return allPois
        .where(
          (poi) =>
              buildingIds.contains(poi.buildingId) && poi.floor == floorNumber,
        )
        .toList();
  }

  /// POI 데이터 로드 및 카테고리 필터링
  static Future<List<Poi>> loadPois(
    PoiRepository repository, {
    int? categoryId,
  }) async {
    final pois = await repository.fetchPois();
    if (categoryId != null) {
      return pois.where((poi) => poi.categoryId == categoryId).toList();
    }
    return pois;
  }
}
