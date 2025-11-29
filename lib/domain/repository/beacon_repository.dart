import 'dart:convert';
import 'package:annyong/domain/entity/beacon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;

class BeaconRepository {
  // JSON 파일 경로 상수
  static const String _beaconDataPath = 'assets/poi/beacon.json';

  // 전체 비콘 데이터 로드
  Future<List<Beacon>> fetchBeacons() async {
    try {
      final String responseBody = await rootBundle.loadString(_beaconDataPath);
      final List<dynamic> jsonList = jsonDecode(responseBody);

      return jsonList.map((json) => Beacon.fromJson(json)).toList();
    } catch (e) {
      throw Exception('비콘 데이터 로드 실패: $e');
    }
  }

  // 특정 층(Floor)에 있는 비콘만 필터링하여 반환
  Future<List<Beacon>> getBeaconsByFloor(int buildingId, int floor) async {
    final allBeacons = await fetchBeacons();
    return allBeacons
        .where((b) => b.buildingId == buildingId && b.floor == floor)
        .toList();
  }

  // 특정 MAC ID로 비콘 검색
  Future<Beacon?> findBeaconByMac(String macId) async {
    final allBeacons = await fetchBeacons();
    try {
      return allBeacons.firstWhere((b) => b.macId == macId);
    } catch (e) {
      return null;
    }
  }

  // 특정 MAC ID 비콘의 인접 POI 리스트 반환
  Future<List<int>> getNearPoiIdsByMac(String macId) async {
    try {
      final allBeacons = await fetchBeacons();
      final targetBeacon = allBeacons.firstWhere((b) => b.macId == macId);

      return targetBeacon.nearPoiIds;
    } catch (e) {
      // 해당 MAC ID가 존재하지 않는 경우 빈 리스트 반환
      debugPrint('해당 MAC ID($macId)를 가진 비콘이 없습니다.');
      return [];
    }
  }
}
