import 'dart:async';
import 'package:annyong/domain/repository/beacon_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 비콘 스캔 서비스
/// 주변 비콘을 검색하여 MAC 주소를 반환
class BeaconScanService {
  final BeaconRepository _beaconRepository;

  // 비콘 설정 상수
  static const String _beaconName = 'Holy-IOT';
  static const int _minRssi = -65; // RSSI 최소값 (더 약한 신호)
  static const int _maxRssi = -40; // RSSI 최대값 (더 강한 신호)
  static const Duration _scanDuration = Duration(seconds: 2); // 스캔 지속 시간 (2초)

  BeaconScanService(this._beaconRepository);

  /// 주변 비콘을 검색하여 인접 비콘의 인접 POI ID 리스트를 반환
  /// RSSI가 -40~-70 사이인 비콘들을 찾고, 각 비콘의 인접 POI를 합쳐서 중복 제거 후 반환
  Future<List<int>> scanNearbyBeaconsAndGetPoiIds() async {
    try {
      // Bluetooth 권한 확인
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint('Bluetooth가 지원되지 않는 기기입니다.');
        return [];
      }

      // Bluetooth 상태 확인
      BluetoothAdapterState adapterState =
          await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint('Bluetooth가 켜져있지 않습니다.');
        return [];
      }

      // beacon.json에서 등록된 비콘 MAC 주소 목록 가져오기
      final registeredBeacons = await _beaconRepository.fetchBeacons();
      final registeredMacAddresses = registeredBeacons
          .map((b) => b.macId.toLowerCase())
          .toSet();

      // 스캔 시작
      debugPrint('----------- [FlutterBluePlus.startScan Start] -----------');
      await FlutterBluePlus.startScan(
        timeout: _scanDuration,
        androidUsesFineLocation: false,
      );

      // 스캔 결과 수집
      final Set<String> nearbyBeaconMacs = {};
      StreamSubscription<List<ScanResult>>? scanSubscription;
      final Completer<void> scanCompleter = Completer<void>();

      // 스캔 결과 스트림 구독 (2초 동안만)
      scanSubscription = FlutterBluePlus.scanResults.listen(
        (List<ScanResult> results) {
          for (ScanResult result in results) {
            final device = result.device;
            final rssi = result.rssi;
            // MAC 주소에서 콜론 제거하고 소문자로 변환 (beacon.json 형식과 일치시키기)
            final macAddress = device.remoteId.str
                .replaceAll(':', '')
                .toLowerCase();

            debugPrint(
              '[Scaned Beacon] MAC: $macAddress | Name: ${device.platformName} | RSSI: $rssi',
            );

            // 1. 이름이 "Holy-IOT"인지 확인
            if (device.platformName.isNotEmpty &&
                device.platformName != _beaconName) {
              debugPrint(' -> [Ignored] 이름 없음/HolyIOT 아닌 비콘: $macAddress');
              continue;
            }

            // 2. MAC 주소가 beacon.json에 등록되어 있는지 확인
            if (!registeredMacAddresses.contains(macAddress)) {
              debugPrint(' -> [Ignored] 등록되지 않은 비콘: $macAddress');
              continue;
            }

            // 3. RSSI가 -40~-70 사이인지 확인 (인접 비콘 판단)
            if (rssi >= _minRssi && rssi <= _maxRssi) {
              nearbyBeaconMacs.add(macAddress);
              _beaconRepository.findBeaconByMac(macAddress).then((
                matchedBeacon,
              ) {
                debugPrint(
                  ' -> [Matched] 인접 비콘 발견: MAC=$macAddress, RSSI=$rssi, Name=${device.platformName}, ID: ${matchedBeacon?.beaconId}',
                );
              });
            }
          }
        },
        onError: (error) {
          debugPrint('스캔 스트림 오류: $error');
          if (!scanCompleter.isCompleted) {
            scanCompleter.complete();
          }
        },
      );

      // 2초 후 스캔 중지 및 구독 취소
      Future.delayed(_scanDuration, () async {
        await scanSubscription?.cancel();
        await FlutterBluePlus.stopScan();
        debugPrint('----------- [FlutterBluePlus.startScan End] -----------');
        if (!scanCompleter.isCompleted) {
          scanCompleter.complete();
        }
      });

      // 스캔 완료 대기
      await scanCompleter.future;

      if (nearbyBeaconMacs.isEmpty) {
        debugPrint('인접 비콘이 발견되지 않았습니다.');
        return [];
      }

      // 인접 비콘들의 인접 POI ID를 모두 수집 (중복 제거)
      final Set<int> allNearPoiIds = {};

      for (final macAddress in nearbyBeaconMacs) {
        final nearPoiIds = await _beaconRepository.getNearPoiIdsByMac(
          macAddress,
        );
        allNearPoiIds.addAll(nearPoiIds);
      }

      debugPrint(
        '인접 비콘 ${nearbyBeaconMacs.length}개 발견, 추천 POI ${allNearPoiIds.length}개',
      );

      return allNearPoiIds.toList();
    } catch (e) {
      debugPrint('비콘 스캔 실패: $e');
      await FlutterBluePlus.stopScan();
      return [];
    }
  }

  /// 여러 비콘을 스캔하여 MAC 주소 리스트를 반환
  /// (하위 호환성을 위해 유지)
  @Deprecated('scanNearbyBeaconsAndGetPoiIds()를 사용하세요')
  Future<List<String>> scanMultipleBeacons() async {
    try {
      // Bluetooth 권한 확인
      if (await FlutterBluePlus.isSupported == false) {
        return [];
      }

      // Bluetooth 상태 확인
      BluetoothAdapterState adapterState =
          await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        return [];
      }

      // beacon.json에서 등록된 비콘 MAC 주소 목록 가져오기
      final registeredBeacons = await _beaconRepository.fetchBeacons();
      final registeredMacAddresses = registeredBeacons
          .map((b) => b.macId.toLowerCase())
          .toSet();

      // 스캔 시작
      await FlutterBluePlus.startScan(
        timeout: _scanDuration,
        androidUsesFineLocation: false,
      );

      final Set<String> nearbyBeaconMacs = {};

      // 스캔 결과 스트림 구독
      await for (List<ScanResult> results in FlutterBluePlus.scanResults) {
        for (ScanResult result in results) {
          final device = result.device;
          final rssi = result.rssi;
          // MAC 주소에서 콜론 제거하고 소문자로 변환 (beacon.json 형식과 일치시키기)
          final macAddress = device.remoteId.str
              .replaceAll(':', '')
              .toLowerCase();

          // 1. 이름이 "Holy-IOT"인지 확인
          if (device.platformName.isNotEmpty &&
              device.platformName != _beaconName) {
            continue;
          }

          // 2. MAC 주소가 beacon.json에 등록되어 있는지 확인
          if (!registeredMacAddresses.contains(macAddress)) {
            continue;
          }

          // 3. RSSI가 -35~-70 사이인지 확인
          if (rssi >= _minRssi && rssi <= _maxRssi) {
            nearbyBeaconMacs.add(macAddress);
          }
        }
      }

      // 스캔 중지
      await FlutterBluePlus.stopScan();

      return nearbyBeaconMacs.toList();
    } catch (e) {
      debugPrint('비콘 스캔 실패: $e');
      await FlutterBluePlus.stopScan();
      return [];
    }
  }
}
