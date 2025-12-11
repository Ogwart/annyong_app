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
  static const double _kalmanQ = 0.5;

  // 실험적 1m 기준 RSSI (TxPower): -56;
  // 히스테리시스 경계 (진입/이탈)
  static const double _incomingCriterion = -68.5;
  static const double _outgoingCriterion = -73.5;

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

  /// 비콘 신호 처리 통합 로직 (실제 신호 + 가상 신호 공용)
  /// [rssi] : 실제 측정값 또는 Ghost Packet(-99.0)
  void _processBeaconSignal(String macAddress, double rssi) async {
    // 1. 칼만 필터 적용
    _kalmanFilters.putIfAbsent(
      macAddress,
      () => KalmanFilter(R: _kalmanR, Q: _kalmanQ),
    );
    final filteredRssi = _kalmanFilters[macAddress]!.filter(rssi);

    // 2. 히스테리시스 로직 적용
    bool isCurrentlyIn = _beaconInRangeStatus[macAddress] ?? false;
    bool newState = isCurrentlyIn;

    if (!isCurrentlyIn && filteredRssi >= _incomingCriterion) {
      // 진입 조건 충족
      newState = true;
      debugPrint(
        '[Beacon Enter] MAC: $macAddress | Input: $rssi | Filtered: ${filteredRssi.toStringAsFixed(2)}',
      );
    } else if (isCurrentlyIn && filteredRssi < _outgoingCriterion) {
      // 이탈 조건 충족
      newState = false;
      debugPrint(
        '[Beacon Exit] MAC: $macAddress | Input: $rssi | Filtered: ${filteredRssi.toStringAsFixed(2)}',
      );
    }

    // 상태 변경 여부 확인
    if (newState != isCurrentlyIn) {
      _beaconInRangeStatus[macAddress] = newState;
      // 상태가 변경되었으므로 전체 POI 목록 갱신 필요
      // 메인 스레드를 블로킹하지 않도록 unawaited 사용
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
  // TODO: 추후 이 기법의 안정성이 확보되면 주석처리 or 삭제할 예정
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
