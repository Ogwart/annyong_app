import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/favorite_service.dart';

class HomePageUtilFunctions {
  /// 건물, 층, 해상도에 따라 이미지 경로 생성
  static String getImagePath(String building, String floor, String resolution) {
    // 건물에 따라 폴더명 결정
    String buildingPrefix;
    if (building == '5호관') {
      buildingPrefix = '5';
    } else if (building == '하이테크관') {
      buildingPrefix = '8';
    } else {
      buildingPrefix = '5';
    }

    // 층수에서 숫자만 추출
    final floorNumber = floor.replaceAll('F', '');

    return 'assets/map/${buildingPrefix}_${floorNumber}F/${buildingPrefix}_${floorNumber}F_$resolution.jpg';
  }

  /// 건물에 따라 사용 가능한 층 리스트 반환
  static List<String> getAvailableFloors(String building) {
    switch (building) {
      case '5호관':
        return ['2F', '1F'];
      case '하이테크관':
        return ['1F'];
      default:
        return ['1F'];
    }
  }

  /// 건물 이름을 건물 ID로 변환
  static int getBuildingId(String building) {
    switch (building) {
      case '5호관':
        return 1;
      case '하이테크관':
        return 2;
      default:
        return 1;
    }
  }

  /// 층 문자열을 층 번호로 변환
  static int getFloorNumber(String floor) {
    return int.tryParse(floor.replaceAll('F', '')) ?? 1;
  }

  /// 스케일 값에 따라 해상도 문자열 반환
  static String getResolutionFromScale(double scale) {
    if (scale < 1.0) {
      return '1x';
    } else if (scale < 2.0) {
      return '2x';
    } else {
      return '4x';
    }
  }

  /// 건물과 층에 맞는 즐겨찾기 POI 필터링
  static List<Poi> getFilteredFavoritePois(
    List<Poi> favoritePois,
    String building,
    String floor,
  ) {
    final buildingId = getBuildingId(building);
    final floorNumber = getFloorNumber(floor);
    return favoritePois
        .where(
          (poi) => poi.buildingId == buildingId && poi.floor == floorNumber,
        )
        .toList();
  }

  /// SharedPreferences에서 즐겨찾기 POI 목록 로드
  static Future<List<Poi>> loadFavoritePois() async {
    try {
      final favoriteIds = await FavoriteService.getFavoritePoiIds();
      final poiRepository = PoiRepository();
      final allPois = await poiRepository.fetchPois();
      return allPois.where((poi) => favoriteIds.contains(poi.id)).toList();
    } catch (e) {
      return [];
    }
  }
}
