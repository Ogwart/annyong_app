import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteService {
  static const String _favoritePoiIdsKey = 'favorite_poi_ids';
  static const int _maxFavorites = 10;

  /// 즐겨찾기 POI ID 리스트 가져오기
  static Future<List<int>> getFavoritePoiIds() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_favoritePoiIdsKey);
    if (jsonString == null) {
      return [];
    }
    try {
      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded.map((e) => e as int).toList();
    } catch (e) {
      return [];
    }
  }

  /// 즐겨찾기 POI ID 리스트 저장하기
  static Future<void> saveFavoritePoiIds(List<int> poiIds) async {
    if (poiIds.length > _maxFavorites) {
      throw Exception('즐겨찾기는 최대 $_maxFavorites개까지 저장할 수 있습니다.');
    }
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(poiIds);
    await prefs.setString(_favoritePoiIdsKey, jsonString);
  }

  /// 즐겨찾기 추가
  static Future<bool> addFavorite(int poiId) async {
    final favorites = await getFavoritePoiIds();
    if (favorites.contains(poiId)) {
      return false; // 이미 즐겨찾기에 있음
    }
    if (favorites.length >= _maxFavorites) {
      return false; // 최대 개수 초과
    }
    favorites.add(poiId);
    await saveFavoritePoiIds(favorites);
    return true;
  }

  /// 즐겨찾기 제거
  static Future<bool> removeFavorite(int poiId) async {
    final favorites = await getFavoritePoiIds();
    if (!favorites.contains(poiId)) {
      return false; // 즐겨찾기에 없음
    }
    favorites.remove(poiId);
    await saveFavoritePoiIds(favorites);
    return true;
  }

  /// 즐겨찾기 여부 확인
  static Future<bool> isFavorite(int poiId) async {
    final favorites = await getFavoritePoiIds();
    return favorites.contains(poiId);
  }

  /// 초기 즐겨찾기 설정 (5호관 1층 POI 3개)
  static Future<void> initializeDefaultFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_favoritePoiIdsKey)) {
      // 5호관 1층 POI 3개: 소화기(1), 계단(2), 출입문(3)
      await saveFavoritePoiIds([1, 2, 3]);
    }
  }
}

