import 'dart:async';
import 'dart:developer';
import 'package:annyong/domain/entity/beacon.dart';
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/gps_service.dart';
import 'package:annyong/domain/usecases/beacon_scan_service.dart';
import 'package:annyong/presentation/viewmodels/navigation_state.dart';

class HandoverService {
  final GpsService _locationService = GpsService();
  final PoiRepository _poiRepository = PoiRepository();
  final BeaconScanService _beaconScanService = BeaconScanService();

  String? _targetDoorBeaconMac;
  Beacon? _pendingEntryBeacon;

  // GPS 변화량 감지용
  double? _baselineGpsAccuracy; // HandoverReady 시작 시점의 baseline
  double? _currentGpsAccuracy;
  StreamSubscription<dynamic>? _gpsSubscription;

  // RSSI 임계값 상수 정의 (일관성 확보)
  static const int rssiThresholdStrong =
      -70; // 강한 신호 (HandoverReady -> Transitioning)
  static const int rssiThresholdWeak = -73; // 약한 신호 (Transitioning -> Outdoor)
  static const int rssiThresholdEntry = -68; // 실내 진입 감지 (Outdoor -> Checking)

  // GPS 정확도 임계값
  static const double gpsBaselineMin = 5.0; // 최소 baseline (m)
  static const double gpsBaselineMax = 100.0; // 최대 baseline (m)
  static const double gpsImprovementAbsolute = 3.0; // 절대값 개선 기준 (m)
  static const double gpsImprovementRatio = 0.35; // 비율 개선 기준 (40%)

  Future<NavigationState?> checkHandoverLogic({
    required NavigationState currentState,
    required String? nearestBeaconType,
    required String? nearestBeaconMac,
    required int? currentRssi,
  }) async {
    switch (currentState.handoverStatus) {
      // 1. Indoor -> HandoverReady
      case HandoverStatus.indoor:
        // BeaconScanService가 리턴한 비콘은 이미 신호가 양호함. Door 타입이면 바로 준비.
        if (nearestBeaconType == 'door') {
          _targetDoorBeaconMac = nearestBeaconMac;
          await _locationService.startLocationStream(); // GPS ON
          await _startMonitoringGpsAccuracy(); // [New] 변화량 감지 시작 (async)

          log("[Handover] {indoor}: Door beacon ($nearestBeaconMac) detected.");
          return currentState.copyWith(
            handoverStatus: HandoverStatus.handoverReady,
          );
        }
        break;

      // 2. HandoverReady -> Transitioning OR Cancel OR Outdoor
      case HandoverStatus.handoverReady:
        if (_targetDoorBeaconMac == null) {
          // 타겟 door 비콘이 없으면 Indoor로 복귀
          log("[Handover] {ready}: Target door beacon MAC is null -> Indoor");
          return currentState.copyWith(handoverStatus: HandoverStatus.indoor);
        }

        // [추가] 다른 door 비콘이 감지되면 타겟 변경
        if (nearestBeaconType == 'door' &&
            nearestBeaconMac != null &&
            nearestBeaconMac != _targetDoorBeaconMac) {
          // 새로운 door 비콘의 신호 확인
          final newDoorBeacon = await _beaconScanService.getBeaconByMac(
            nearestBeaconMac,
          );

          if (newDoorBeacon != null) {
            // 현재 타겟 비콘의 신호 확인
            final currentTargetBeacon = await _beaconScanService.getBeaconByMac(
              _targetDoorBeaconMac!,
            );

            // 새로운 door 비콘이 더 강한 신호를 가지고 있으면 타겟 변경
            bool shouldSwitch = false;
            if (currentTargetBeacon == null) {
              // 현재 타겟이 끊겼으면 무조건 변경
              shouldSwitch = true;
            } else if (newDoorBeacon.rssi > currentTargetBeacon.rssi) {
              // 새로운 비콘이 더 강한 신호를 가지고 있으면 변경
              shouldSwitch = true;
            }

            if (shouldSwitch) {
              _targetDoorBeaconMac = nearestBeaconMac;
              // GPS baseline 리셋 (새로운 door 비콘 기준으로 다시 측정)
              _stopMonitoringGpsAccuracy();
              await _startMonitoringGpsAccuracy();
              log(
                "[Handover] {ready}: Target door beacon changed to $nearestBeaconMac (RSSI: ${newDoorBeacon.rssi.toStringAsFixed(1)})",
              );
            }
          }
        }

        // door 비콘의 신호를 직접 확인
        final doorBeacon = await _beaconScanService.getBeaconByMac(
          _targetDoorBeaconMac!,
        );

        if (doorBeacon == null) {
          // door 비콘이 스캔되지 않음 (완전히 끊김)
          log(
            "[Handover] {ready}: Door beacon lost (MAC: $_targetDoorBeaconMac) -> Transitioning",
          );
          return currentState.copyWith(
            handoverStatus: HandoverStatus.transitioning,
          );
        }

        // door 비콘의 RSSI 확인
        final doorRssi = doorBeacon.rssi;
        bool beaconWeak = doorRssi < rssiThresholdWeak;

        if (beaconWeak) {
          log(
            "[Handover] {ready}: Door beacon weak (RSSI: ${doorRssi.toStringAsFixed(1)}, MAC: $_targetDoorBeaconMac) -> Transitioning",
          );
          return currentState.copyWith(
            handoverStatus: HandoverStatus.transitioning,
          );
        }

        // door 비콘이 여전히 강하면 대기 (GPS 데이터 계속 누적됨)
        break;

      // 3. Transitioning -> Outdoor
      case HandoverStatus.transitioning:
        // [간소화] GPS 절대값만 확인 (8m 미만이면 실외)
        // _currentGpsAccuracy가 null이면 lastPosition에서 가져오기
        double? currentAccuracy = _currentGpsAccuracy;

        if (currentAccuracy == null) {
          final lastPos = _locationService.lastPosition;
          if (lastPos != null) {
            currentAccuracy = lastPos.accuracy;
            _currentGpsAccuracy = currentAccuracy;
          }
        }

        // GPS 정확도가 8m 미만이면 실외로 판단
        if (currentAccuracy != null && currentAccuracy <= 8.0) {
          _stopMonitoringGpsAccuracy();
          _locationService.stopLocationStream();
          _targetDoorBeaconMac = null;
          log(
            "[Handover] COMPLETE: Switched to Outdoor (GPS Accuracy: ${currentAccuracy.toStringAsFixed(1)}m < 8.0m)",
          );
          return currentState.copyWith(handoverStatus: HandoverStatus.outdoor);
        } else {
          // GPS 정확도가 8m 이상이면 실내로 복귀
          _stopMonitoringGpsAccuracy();
          _locationService.stopLocationStream();
          _targetDoorBeaconMac = null;
          log(
            "[Handover] Reset to Indoor: GPS accuracy too high (${currentAccuracy?.toStringAsFixed(1) ?? 'N/A'}m > 8.0m)",
          );
          return currentState.copyWith(handoverStatus: HandoverStatus.indoor);
        }

      // 4. Outdoor -> Checking (실내 진입 감지)
      case HandoverStatus.outdoor:
        if (nearestBeaconType == 'door') {
          // [개선] 실내 진입 감지 조건 강화
          // 1. Door 비콘 타입 확인
          // 2. RSSI 신호 강도 확인 (임계값 이상)
          // 3. 비콘 MAC 주소 유효성 확인
          bool isValidSignal =
              (currentRssi != null && currentRssi > rssiThresholdEntry);
          bool isValidBeacon = (nearestBeaconMac != null);

          if (isValidSignal && isValidBeacon) {
            // 진입하려는 비콘 정보 저장 (나중에 건물/층 정보 사용)
            _pendingEntryBeacon = await _poiRepository.findBeaconByMac(
              nearestBeaconMac,
            );

            // 비콘 정보가 정상적으로 조회되었는지 확인
            if (_pendingEntryBeacon != null) {
              log(
                "[Handover] Detect Entry: Door beacon detected (RSSI: $currentRssi, MAC: $nearestBeaconMac)",
              );
              return currentState.copyWith(
                handoverStatus: HandoverStatus.outdoorChecking,
              );
            } else {
              log(
                "[Handover] Entry Detection Failed: Beacon not found in repository (MAC: $nearestBeaconMac)",
              );
            }
          } else {
            log(
              "[Handover] Entry Detection Skipped: Weak signal (RSSI: $currentRssi) or invalid beacon",
            );
          }
        }
        break;

      // 5. Checking -> Cancel
      case HandoverStatus.outdoorChecking:
        // 응답 전 비콘이 사라지면 다시 실외 상태로
        if (nearestBeaconMac == null) {
          _pendingEntryBeacon = null;
          return currentState.copyWith(handoverStatus: HandoverStatus.outdoor);
        }
        break;
    }
    return null;
  }

  Future<NavigationState> confirmIndoorEntry(
    NavigationState currentState,
  ) async {
    _locationService.stopLocationStream();

    // 기본적으로 비콘 정보를 따름
    int targetFloor = 1;
    int targetBuilding = 1;
    Vertex? targetVertex;

    if (_pendingEntryBeacon != null) {
      targetFloor = _pendingEntryBeacon!.floor;
      targetBuilding = _pendingEntryBeacon!.buildingId;
      targetVertex = await _resolveTargetVertexFromBeacon(_pendingEntryBeacon!);
    }

    NavigationState nextState = currentState.copyWith(
      handoverStatus: HandoverStatus.indoor,
      floor: targetFloor,
      buildingId: targetBuilding, // [New] 건물 ID 업데이트
    );

    // 위치 보정 (스냅)
    if (targetVertex != null) {
      nextState = nextState.copyWith(
        x: targetVertex.x,
        y: targetVertex.y,
        rawPixelX: targetVertex.x,
        rawPixelY: targetVertex.y,
        matchingMode: MapMatchingMode.onVertex,
        currentVertex: targetVertex,
        currentEdge: null,
        lastVertex: targetVertex,
        edgeAccumulatedDistance: 0.0,
        vertexBufferX: 0.0,
        vertexBufferY: 0.0,
      );
      log("[Handover] Snapped to Entry Vertex: ${targetVertex.id}");
    }

    _pendingEntryBeacon = null;
    return nextState;
  }

  NavigationState rejectIndoorEntry(NavigationState currentState) {
    _pendingEntryBeacon = null;
    return currentState.copyWith(handoverStatus: HandoverStatus.outdoor);
  }

  void dispose() {
    _stopMonitoringGpsAccuracy();
    _locationService.stopLocationStream();
    _targetDoorBeaconMac = null;
    _pendingEntryBeacon = null;
  }

  // --- GPS 정확도 모니터링 헬퍼 ---
  Future<void> _startMonitoringGpsAccuracy() async {
    _baselineGpsAccuracy = null;
    _currentGpsAccuracy = null;
    _gpsSubscription?.cancel();

    // [방법 1] getCurrentPosition() 즉시 호출하여 baseline 빠르게 설정
    final currentPos = await _locationService.getCurrentPosition();
    if (currentPos != null) {
      final acc = currentPos.accuracy;
      _currentGpsAccuracy = acc;

      // baseline 설정 (범위 필터링 적용)
      if (acc >= gpsBaselineMin && acc <= gpsBaselineMax) {
        _baselineGpsAccuracy = acc;
        log(
          "[Handover] GPS Baseline set immediately: $acc (from getCurrentPosition)",
        );
      } else if (acc > 0 && acc < gpsBaselineMin) {
        // 실외에서 정확도가 좋은 경우 (5m 미만)도 baseline으로 설정
        _baselineGpsAccuracy = acc;
        log(
          "[Handover] GPS Baseline set immediately: $acc (outdoor, good signal)",
        );
      } else {
        log(
          "[Handover] GPS Baseline skipped (immediate): $acc (out of range: $gpsBaselineMin~${gpsBaselineMax}m)",
        );
      }
    }

    // 스트림 구독 시작 (baseline 업데이트용)
    _gpsSubscription = _locationService.positionStream.listen((position) {
      final acc = position.accuracy;
      _currentGpsAccuracy = acc;

      // [개선] GPS baseline 필터링 추가
      // 첫 데이터를 기준값으로 설정하되, 비정상적인 값은 제외
      // 실내 수준(5~100m)의 합리적인 값만 baseline으로 설정
      // [수정] 범위 밖 값도 baseline으로 설정 (실외에서도 작동하도록)
      // [수정] 이미 baseline이 설정되었으면 업데이트하지 않음 (getCurrentPosition으로 먼저 설정됨)
      if (_baselineGpsAccuracy == null) {
        if (acc >= gpsBaselineMin && acc <= gpsBaselineMax) {
          _baselineGpsAccuracy = acc;
          log("[Handover] GPS Baseline set: $acc (from stream)");
        } else if (acc > 0 && acc < gpsBaselineMin) {
          // 실외에서 정확도가 좋은 경우 (5m 미만)도 baseline으로 설정
          _baselineGpsAccuracy = acc;
          log("[Handover] GPS Baseline set: $acc (outdoor, good signal)");
        } else {
          log(
            "[Handover] GPS Baseline skipped: $acc (out of range: $gpsBaselineMin~${gpsBaselineMax}m)",
          );
        }
      }
    });
  }

  void _stopMonitoringGpsAccuracy() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _baselineGpsAccuracy = null;
    _currentGpsAccuracy = null;
  }

  Future<Vertex?> _resolveTargetVertexFromBeacon(Beacon beacon) async {
    if (beacon.nearPoiIds.isEmpty) return null;
    final pois = await _poiRepository.getPoisByIds([beacon.nearPoiIds.first]);
    if (pois.isEmpty || pois.first.vertexId == null) return null;
    return await _poiRepository.getVertexById(pois.first.vertexId!);
  }
}
