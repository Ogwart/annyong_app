import 'dart:async';
import 'package:annyong/domain/repository/beacon_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class KalmanFilter {
  final double R;
  final double Q;

  double _x = 0.0; // 예측값
  double _p = 0.0; // 오차 공분산
  bool _isInitialized = false;

  KalmanFilter({required this.R, required this.Q});

  double filter(double measurement) {
    if (!_isInitialized) {
      _x = measurement;
      _p = 1.0;
      _isInitialized = true;
      return _x;
    }

    // 예측: 정지 상태를 가정하므로 이전 값을 그대로 예측값으로 사용
    double pPred = _p + Q;

    // 보정
    double k = pPred / (pPred + R); // 칼만 이득 (Kalman Gain)
    _x = _x + k * (measurement - _x); // 새로운 추정값
    _p = (1 - k) * pPred; // 새로운 오차 공분산

    return _x;
  }
}

/// 비콘 스캔 서비스 (싱글톤)
/// 앱 생명주기 동안 백그라운드(앱이 실행되는 동안)에서 지속적으로 스캔 수행
class BeaconScanService {
  static final BeaconScanService _instance = BeaconScanService._internal();

  factory BeaconScanService() {
    return _instance;
  }

  BeaconScanService._internal();

  final BeaconRepository _beaconRepository = BeaconRepository();

  // ---------------- Configuration Variables ----------------
  // 칼만 필터 R, Q 값 초기화
  static const double _kalmanR = 40.0;
  static const double _kalmanQ = 0.3;

  // 1m 기준 RSSI (TxPower)
  static const int _rssiAtOneMeter = -56;

  // 히스테리시스 경계 (진입/이탈)
  static const double _incomingCriterion = -68.0;
  static const double _outgoingCriterion = -78.0;

  static const String _beaconName = 'Holy-IOT';
  // ---------------------------------------------------------

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // 감지된 비콘별 상태 관리
  final Map<String, KalmanFilter> _kalmanFilters = {};
  final Map<String, bool> _beaconInRangeStatus = {}; // MAC ID -> isInside

  // 현재 인접한 POI ID 리스트를 브로드캐스트하기 위한 스트림 컨트롤러
  final StreamController<List<int>> _poiStreamController =
      StreamController<List<int>>.broadcast();
  Stream<List<int>> get nearbyPoiStream => _poiStreamController.stream;

  // 현재 감지된 유효한 POI ID 목록 캐싱
  List<int> _currentNearbyPoiIds = [];
  List<int> get currentNearbyPoiIds => _currentNearbyPoiIds;

  bool _isScanning = false;

  /// 비콘 스캐닝 시작 (앱 실행 시 호출)
  Future<void> startBackgroundScan() async {
    if (_isScanning) return;

    // Bluetooth 지원 여부 및 켜짐 상태 확인은 호출부(Splash)에서 권한 체크 후 수행한다고 가정
    // 안전을 위해 한 번 더 체크
    if (await FlutterBluePlus.isSupported == false) return;
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      return;
    }

    debugPrint(
      '----------- [BeaconScanService] Background Scan Started -----------',
    );
    _isScanning = true;

    // 등록된 비콘 정보 로드
    final registeredBeacons = await _beaconRepository.fetchBeacons();
    final registeredMacAddresses = registeredBeacons
        .map((b) => b.macId.toLowerCase())
        .toSet();

    // 스캔 시작 (지속 스캔)
    await FlutterBluePlus.startScan(
      // timeout을 null로 주거나 아주 길게 주어 지속 스캔 (Android의 경우)
      // 또는 스트림이 끊기지 않도록 관리
      androidUsesFineLocation: false,
      continuousUpdates: true,
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) async {
        // 이번 스캔 루프에서 유효한(In Range) 비콘들의 MAC 집합
        Set<String> validMacs = {};

        for (ScanResult result in results) {
          final device = result.device;
          final rawRssi = result.rssi.toDouble();
          final macAddress = device.remoteId.str
              .replaceAll(':', '')
              .toLowerCase();

          // 1. 타겟 비콘 필터링
          if (device.platformName.isNotEmpty &&
              device.platformName != _beaconName) {
            continue;
          }
          if (!registeredMacAddresses.contains(macAddress)) continue;

          // 2. 칼만 필터 적용
          _kalmanFilters.putIfAbsent(
            macAddress,
            () => KalmanFilter(R: _kalmanR, Q: _kalmanQ),
          );
          final filteredRssi = _kalmanFilters[macAddress]!.filter(rawRssi);

          // 3. 히스테리시스 로직 적용
          bool isCurrentlyIn = _beaconInRangeStatus[macAddress] ?? false;
          bool newState = isCurrentlyIn;

          if (!isCurrentlyIn && filteredRssi >= _incomingCriterion) {
            // 진입 조건 충족
            newState = true;
            debugPrint(
              '[Beacon Enter] MAC: $macAddress | Raw: $rawRssi | Filtered: ${filteredRssi.toStringAsFixed(2)}',
            );
          } else if (isCurrentlyIn && filteredRssi < _outgoingCriterion) {
            // 이탈 조건 충족
            newState = false;
            debugPrint(
              '[Beacon Exit] MAC: $macAddress | Raw: $rawRssi | Filtered: ${filteredRssi.toStringAsFixed(2)}',
            );
          }

          _beaconInRangeStatus[macAddress] = newState;

          if (newState) {
            validMacs.add(macAddress);
          }
        }

        // 4. 유효한 비콘들의 POI ID 수집 및 업데이트
        if (validMacs.isNotEmpty) {
          final Set<int> newPoiIds = {};
          for (final mac in validMacs) {
            final poiIds = await _beaconRepository.getNearPoiIdsByMac(mac);
            newPoiIds.addAll(poiIds);
          }

          // 상태가 변경되었을 때만 스트림 전송 (단순화된 비교)
          if (!_listEquals(_currentNearbyPoiIds, newPoiIds.toList())) {
            _currentNearbyPoiIds = newPoiIds.toList();
            _poiStreamController.add(_currentNearbyPoiIds);
            debugPrint(
              '[BeaconService] Detected POIs Updated: $_currentNearbyPoiIds',
            );
          }
        } else {
          if (_currentNearbyPoiIds.isNotEmpty) {
            _currentNearbyPoiIds = [];
            _poiStreamController.add([]);
            debugPrint('[BeaconService] All POIs lost.');
          }
        }
      },
      onError: (e) {
        debugPrint('[BeaconService] Scan Error: $e');
      },
    );
  }

  /// 비콘 스캐닝 종료 (앱 종료 시 호출)
  Future<void> stopBackgroundScan() async {
    debugPrint(
      '----------- [BeaconScanService] Background Scan Stopped -----------',
    );
    _isScanning = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
    // 상태 초기화
    _kalmanFilters.clear();
    _beaconInRangeStatus.clear();
    _currentNearbyPoiIds.clear();
  }

  /// (구) 메서드 호환성 유지: 현재 지속 스캔 중 감지된 값을 즉시 반환
  Future<List<int>> scanNearbyBeaconsAndGetPoiIds() async {
    // 이미 백그라운드 스캔이 돌고 있다면 현재 캐시된 값 반환
    if (_isScanning) {
      return _currentNearbyPoiIds;
    } else {
      // 스캔이 돌고 있지 않다면(예: 권한 문제로 시작 안됨 등),
      // 잠시 켰다가 값을 가져오도록 유도하거나 빈 값 반환
      // 여기서는 일시적으로 3초간 스캔 후 반환하도록 구현 (기존 로직과 유사하게)
      await startBackgroundScan();
      await Future.delayed(const Duration(seconds: 3));
      final result = List<int>.from(_currentNearbyPoiIds);
      // MeasureNoticePage 등에서 일회성으로 부른 경우라면
      // 앱 전체 생명주기와 별개로 동작할 수 있으므로 상황에 따라 stop을 호출할지 결정해야 함.
      // 요구사항 5에 따라 앱 전체에서 돈다고 했으므로 stop 하지 않음.
      return result;
    }
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
