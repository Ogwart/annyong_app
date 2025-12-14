import 'dart:async';
import 'package:annyong/domain/entity/beacon.dart';
import 'package:annyong/domain/repository/beacon_repository.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class KalmanFilter {
  final double R;
  final double Q;

  double _x = 0.0; // 예측값
  double _p = 0.0; // 오차 공분산
  bool _isInitialized = false;

  KalmanFilter({required this.R, required this.Q});

  double get currentEstimate => _x;

  double filter(double measurement) {
    if (!_isInitialized) {
      _x = measurement;
      _p = 1.0;
      _isInitialized = true;
      return _x;
    }

    double pPred = _p + Q;

    double k = pPred / (pPred + R);
    _x = _x + k * (measurement - _x);
    _p = (1 - k) * pPred;

    return _x;
  }
}

class BeaconScanService {
  static final BeaconScanService _instance = BeaconScanService._internal();

  factory BeaconScanService() {
    return _instance;
  }

  BeaconScanService._internal();

  final BeaconRepository _beaconRepository = BeaconRepository();
  final PoiRepository _poiRepository = PoiRepository(); // [Fix] 필드 추가

  static const double _kalmanR = 40.0;
  static const double _kalmanQ = 0.2;

  // 실험적 1m 기준 RSSI (TxPower): -56;
  // 히스테리시스 경계 (진입/이탈)
  static const double _incomingCriterion = -76.0;
  static const double _outgoingCriterion = -83.0;

  static const String _beaconName = 'Holy-IOT';

  // timeout 관련 변수 정의
  // 칼만필터+히스테리시스만으로는 사용자의 급격한 이탈을 잡을 수 없음. 따라서 비콘 신호가 끊기면 이탈로 간주
  static const int _coastingDurationMs = 3000; // 신호가 끊겨도 유지하는 관성 주행 시간
  static const double _ghostRssi = -99.0; // 가상 패킷으로 주입할 가상 패킷 RSSI 값
  static const int _maintenanceTimerPeriodMs = 1000; // 체크 타이머 주기
  // ---------------------------------------------------------

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _maintenanceTimer; // 주기적으로 Coasting/Ghost Packet 체크하는 타이머

  final Map<String, KalmanFilter> _kalmanFilters = {};
  final Map<String, bool> _beaconInRangeStatus = {}; // MAC ID -> isInside
  final Map<String, DateTime> _lastSeenTime = {}; // MAC ID -> 마지막 수신 시각

  final StreamController<List<int>> _poiStreamController =
      StreamController<List<int>>.broadcast();
  Stream<List<int>> get nearbyPoiStream => _poiStreamController.stream;

  List<int> _currentNearbyPoiIds = [];
  List<int> get currentNearbyPoiIds => _currentNearbyPoiIds;

  bool _isScanning = false;

  // 현재 추적 중인 비콘 중 가장 가까운 비콘 정보 반환
  Future<({Beacon beacon, double rssi})?> getNearestTrackedBeacon() async {
    String? bestMac;
    double bestRssi = -999.0;

    for (var entry in _beaconInRangeStatus.entries) {
      if (entry.value == true) {
        final mac = entry.key;
        final rssi = _kalmanFilters[mac]?.currentEstimate ?? -100.0;

        if (rssi > bestRssi) {
          bestRssi = rssi;
          bestMac = mac;
        }
      }
    }

    if (bestMac != null) {
      final beacon = await _poiRepository.findBeaconByMac(bestMac);
      if (beacon != null) {
        return (beacon: beacon, rssi: bestRssi);
      }
    }
    return null;
  }

  Future<void> startBackgroundScan() async {
    if (_isScanning) return;

    if (await FlutterBluePlus.isSupported == false) return;
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      return;
    }

    debugPrint(
      '----------- [BeaconScanService] Background Scan Started -----------',
    );
    _isScanning = true;

    final registeredBeacons = await _beaconRepository.fetchBeacons();
    final registeredMacAddresses = registeredBeacons
        .map((b) => b.macId.toLowerCase())
        .toSet();

    // 1. 스캔 시작 (지속 스캔)
    await FlutterBluePlus.startScan(
      androidUsesFineLocation: false,
      continuousUpdates: true,
    );

    // 2. 유지보수 타이머 시작 (Coasting & Ghost Packet 로직용)
    _startMaintenanceTimer(registeredMacAddresses);

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (ScanResult result in results) {
          final device = result.device;
          final macAddress = device.remoteId.str
              .replaceAll(':', '')
              .toLowerCase();

          // 타겟 비콘 필터링
          if (device.platformName.isNotEmpty &&
              device.platformName != _beaconName) {
            continue;
          }
          if (!registeredMacAddresses.contains(macAddress)) continue;

          // 실제 신호 수신 처리
          final rawRssi = result.rssi.toDouble();
          _lastSeenTime[macAddress] = DateTime.now(); // 마지막 수신 시각 갱신

          // 로직 통합 처리 (실제 데이터)
          _processBeaconSignal(macAddress, rawRssi);
        }
      },
      onError: (e) {
        debugPrint('[BeaconService] Scan Error: $e');
      },
    );
  }

  /// timeout 감지를 위한 유지보수 타이머
  void _startMaintenanceTimer(Set<String> registeredMacs) {
    _maintenanceTimer?.cancel();
    _maintenanceTimer = Timer.periodic(
      const Duration(milliseconds: _maintenanceTimerPeriodMs),
      (timer) {
        final now = DateTime.now();

        // 메모리에 올라와 있는(한 번이라도 스캔된) 비콘들을 대상으로 상태 점검
        // _lastSeenTime에 키가 있다는 것은 한 번이라도 스캔되었다는 뜻
        final knownMacs = _lastSeenTime.keys.toList();

        for (final mac in knownMacs) {
          final lastSeen = _lastSeenTime[mac]!;
          final difference = now.difference(lastSeen).inMilliseconds;

          if (difference < _coastingDurationMs) {
            // [Coasting 단계]: _coastingDurationMs만큼 기다림 -> 아무것도 하지 않음 (기존 값 유지)
            // 등 가리거나 수신 오류로 못받았던 것일 수도 있으니 바로 timeout시키지 않고 대기
          } else {
            // [Termination 단계]: 기다림 한계 초과 -> 가상 패킷(Ghost Packet) 주입 시작
            // 이정도까지 패킷 수신이 없다는 건 오류가 아니라 진짜 나간 걸로 간주하고 칼만필터값 낮추기
            // 혹여 N초 이상의 오류일 수도 있으므로 바로 끊기보단 자연스럽게 나간 것처럼 보이게 하기 위함임
            _processBeaconSignal(mac, _ghostRssi);
          }
        }
      },
    );
  }

  // 비콘별 이탈 대기 타이머를 관리할 맵
  final Map<String, Timer> _exitDebounceTimers = {};

  /// 비콘 신호 처리 통합 로직 (Debounce 적용)
  void _processBeaconSignal(String macAddress, double rssi) async {
    // 1. 칼만 필터 적용
    _kalmanFilters.putIfAbsent(
      macAddress,
      () => KalmanFilter(R: _kalmanR, Q: _kalmanQ),
    );
    final filteredRssi = _kalmanFilters[macAddress]!.filter(rssi);

    bool isCurrentlyIn = _beaconInRangeStatus[macAddress] ?? false;

    // ------------------------------------------------------------------
    // Case 1: 진입 로직 (즉시 진입)
    // ------------------------------------------------------------------
    if (!isCurrentlyIn && filteredRssi >= _incomingCriterion) {
      // 혹시 이탈 대기 중이었다면(Timer가 돌고 있었다면) 취소!
      // "어? 나가는 줄 알았는데 다시 신호가 좋아졌네? 그럼 계속 In 상태야."
      if (_exitDebounceTimers.containsKey(macAddress)) {
        _exitDebounceTimers[macAddress]?.cancel();
        _exitDebounceTimers.remove(macAddress);
        debugPrint('[Beacon] $macAddress 진입 신호 감지 -> 이탈 대기 취소');
      }

      // 상태 업데이트 (In)
      _updateStatus(macAddress, true, rssi, filteredRssi);
    }
    // ------------------------------------------------------------------
    // Case 2: 이탈 로직 (지연 이탈 - Debounce)
    // ------------------------------------------------------------------
    else if (isCurrentlyIn && filteredRssi < _outgoingCriterion) {
      // 이미 이탈 타이머가 돌고 있다면? -> 건드리지 말고 냅둔다. (기다리는 중)
      if (_exitDebounceTimers.containsKey(macAddress)) return;

      // 타이머가 없다면? -> "어? 신호 약한데? 진짜 나간 건지 2초만 지켜보자" (타이머 시작)
      _exitDebounceTimers[macAddress] = Timer(const Duration(seconds: 2), () {
        // 2초 뒤에도 이 타이머가 취소되지 않고 살아있다면 -> 진짜 이탈 확정!
        _updateStatus(macAddress, false, rssi, filteredRssi);
        _exitDebounceTimers.remove(macAddress);
      });
    }
    // ------------------------------------------------------------------
    // Case 3: 신호 회복 (이탈 대기 중이었는데 다시 좋아짐)
    // ------------------------------------------------------------------
    else if (isCurrentlyIn && filteredRssi >= _outgoingCriterion) {
      // 이탈 기준(-83)보다는 크고, 진입 기준(-76)보다는 작은 "애매한 구간"이거나
      // 혹은 아주 좋아진 경우 모두 포함.

      // 2초 안에 다시 신호가 이탈 기준 이상으로 올라오면 이탈 취소! (핑퐁 방지 핵심)
      if (_exitDebounceTimers.containsKey(macAddress)) {
        _exitDebounceTimers[macAddress]?.cancel();
        _exitDebounceTimers.remove(macAddress);
        debugPrint('[Beacon] $macAddress 신호 회복(-83 이상) -> 이탈 대기 취소.');
      }
    }
  }

  /// 상태 변경을 실제로 수행하고 로그를 찍는 헬퍼 함수
  void _updateStatus(
    String macAddress,
    bool newState,
    double rawRssi,
    double filteredRssi,
  ) {
    bool isCurrentlyIn = _beaconInRangeStatus[macAddress] ?? false;

    // 상태가 변했을 때만 실행
    if (newState != isCurrentlyIn) {
      _beaconInRangeStatus[macAddress] = newState;

      // 로그 출력
      String tag = newState ? '[Beacon Enter]' : '[Beacon Exit]';
      debugPrint(
        '$tag MAC: $macAddress | Input: $rawRssi | Filtered: ${filteredRssi.toStringAsFixed(2)}',
      );

      // 상태가 변경되었으므로 전체 POI 목록 갱신 필요
      _updateNearbyPois().catchError((error) {
        debugPrint('[BeaconService] Error updating nearby POIs: $error');
      });
    }
  }

  /// 현재 'In Range' 상태인 비콘들을 기반으로 POI 목록 갱신 및 브로드캐스트
  Future<void> _updateNearbyPois() async {
    final activeMacs = _beaconInRangeStatus.entries
        .where((entry) => entry.value == true) // 진입 상태인 것만 필터링
        .map((entry) => entry.key)
        .toSet();

    if (activeMacs.isNotEmpty) {
      final Set<int> newPoiIds = {};
      // 병렬 처리로 성능 개선 및 메인 스레드 블로킹 감소
      final futures = activeMacs.map(
        (mac) => _beaconRepository.getNearPoiIdsByMac(mac),
      );
      final results = await Future.wait(futures);

      for (final poiIds in results) {
        newPoiIds.addAll(poiIds);
      }

      final newList = newPoiIds.toList();
      if (!_listEquals(_currentNearbyPoiIds, newList)) {
        _currentNearbyPoiIds = newList;
        _poiStreamController.add(_currentNearbyPoiIds);
        debugPrint(
          '[BeaconService] Detected POIs Updated: $_currentNearbyPoiIds',
        );
      }
    } else {
      // 활성화된 비콘이 하나도 없음
      if (_currentNearbyPoiIds.isNotEmpty) {
        _currentNearbyPoiIds = [];
        _poiStreamController.add([]);
        debugPrint('[BeaconService] All POIs lost.');
      }
    }
  }

  /// 비콘 스캐닝 종료 (앱 종료 시 호출)
  Future<void> stopBackgroundScan() async {
    debugPrint(
      '----------- [BeaconScanService] Background Scan Stopped -----------',
    );
    _isScanning = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    // 타이머 종료
    _maintenanceTimer?.cancel();
    _maintenanceTimer = null;

    await FlutterBluePlus.stopScan();
    _kalmanFilters.clear();
    _beaconInRangeStatus.clear();
    _lastSeenTime.clear();
    _currentNearbyPoiIds.clear();
  }

  /// (구) 메서드 호환성 유지
  Future<List<int>> scanNearbyBeaconsAndGetPoiIds() async {
    if (_isScanning) {
      return _currentNearbyPoiIds;
    } else {
      await startBackgroundScan();
      await Future.delayed(const Duration(seconds: 3));
      final result = List<int>.from(_currentNearbyPoiIds);
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
