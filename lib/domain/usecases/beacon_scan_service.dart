import 'package:annyong/domain/repository/beacon_repository.dart';
import 'package:flutter/foundation.dart';

/// 비콘 스캔 서비스
/// 주변 비콘을 검색하여 MAC 주소를 반환
class BeaconScanService {
  final BeaconRepository _beaconRepository;

  BeaconScanService(this._beaconRepository);

  /// 주변 비콘을 검색하여 가장 가까운 비콘의 MAC 주소를 반환
  /// 실제 구현에서는 Bluetooth 플러그인을 사용하여 스캔
  /// 현재는 모의 데이터를 반환 (테스트용)
  Future<String?> scanNearbyBeacon() async {
    try {
      // TODO: 실제 비콘 스캔 플러그인으로 교체 필요
      // 예: flutter_beacon, flutter_blue_plus 등

      // 현재는 모의 데이터 반환
      // 실제 구현 시에는 Bluetooth 스캔을 통해 가장 가까운 비콘의 MAC 주소를 반환
      await Future.delayed(const Duration(milliseconds: 500)); // 스캔 시뮬레이션

      // 테스트용: beacon.json의 첫 번째 비콘 MAC 주소 반환
      // 실제 구현에서는 스캔된 비콘 중 가장 가까운 비콘의 MAC 주소를 반환
      final beacons = await _beaconRepository.fetchBeacons();
      if (beacons.isNotEmpty) {
        // 모의 데이터: 첫 번째 비콘 반환
        // 실제로는 RSSI 값이 가장 높은(가장 가까운) 비콘을 반환해야 함
        return beacons.first.macId;
      }

      return null;
    } catch (e) {
      debugPrint('비콘 스캔 실패: $e');
      return null;
    }
  }

  /// 여러 비콘을 스캔하여 MAC 주소 리스트를 반환
  /// 실제 구현에서는 Bluetooth 스캔을 통해 여러 비콘의 MAC 주소를 반환
  Future<List<String>> scanMultipleBeacons() async {
    try {
      // TODO: 실제 비콘 스캔 플러그인으로 교체 필요

      // 현재는 모의 데이터 반환
      await Future.delayed(const Duration(milliseconds: 500)); // 스캔 시뮬레이션

      final beacons = await _beaconRepository.fetchBeacons();
      // 모의 데이터: 처음 3개의 비콘 반환
      // 실제로는 RSSI 값이 높은(가까운) 비콘들을 반환해야 함
      return beacons.take(3).map((b) => b.macId).toList();
    } catch (e) {
      debugPrint('비콘 스캔 실패: $e');
      return [];
    }
  }
}
