import 'dart:async';
import 'package:annyong/domain/entity/beacon.dart'; // [Fix] Beacon 타입 임포트
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
  static const double _kalmanQ = 0.3;

  static const int _rssiAtOneMeter = -56;

  static const double _incomingCriterion = -68.0;
  static const double _outgoingCriterion = -78.0;

  static const String _beaconName = 'Holy-IOT';

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  final Map<String, KalmanFilter> _kalmanFilters = {};
  final Map<String, bool> _beaconInRangeStatus = {};

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

    await FlutterBluePlus.startScan(
      androidUsesFineLocation: false,
      continuousUpdates: true,
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) async {
        Set<String> validMacs = {};

        for (ScanResult result in results) {
          final device = result.device;
          final rawRssi = result.rssi.toDouble();
          final macAddress = device.remoteId.str
              .replaceAll(':', '')
              .toLowerCase();

          if (device.platformName.isNotEmpty &&
              device.platformName != _beaconName) {
            continue;
          }
          if (!registeredMacAddresses.contains(macAddress)) continue;

          _kalmanFilters.putIfAbsent(
            macAddress,
            () => KalmanFilter(R: _kalmanR, Q: _kalmanQ),
          );
          final filteredRssi = _kalmanFilters[macAddress]!.filter(rawRssi);

          bool isCurrentlyIn = _beaconInRangeStatus[macAddress] ?? false;
          bool newState = isCurrentlyIn;

          if (!isCurrentlyIn && filteredRssi >= _incomingCriterion) {
            newState = true;
            debugPrint(
              '[Beacon Enter] MAC: $macAddress | Raw: $rawRssi | Filtered: ${filteredRssi.toStringAsFixed(2)}',
            );
          } else if (isCurrentlyIn && filteredRssi < _outgoingCriterion) {
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

        if (validMacs.isNotEmpty) {
          final Set<int> newPoiIds = {};
          for (final mac in validMacs) {
            final poiIds = await _beaconRepository.getNearPoiIdsByMac(mac);
            newPoiIds.addAll(poiIds);
          }

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

  Future<void> stopBackgroundScan() async {
    debugPrint(
      '----------- [BeaconScanService] Background Scan Stopped -----------',
    );
    _isScanning = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
    _kalmanFilters.clear();
    _beaconInRangeStatus.clear();
    _currentNearbyPoiIds.clear();
  }

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
