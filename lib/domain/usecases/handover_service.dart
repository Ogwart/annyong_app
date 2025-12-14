import 'dart:async';
import 'dart:developer';
import 'package:annyong/domain/entity/beacon.dart';
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/gps_service.dart';
import 'package:annyong/presentation/viewmodels/navigation_state.dart';

class HandoverService {
  final GpsService _locationService = GpsService();
  final PoiRepository _poiRepository = PoiRepository();

  String? _targetDoorBeaconMac;
  Beacon? _pendingEntryBeacon;

  // GPS 변화량 감지용
  double? _baselineGpsAccuracy; // HandoverReady 시작 시점의 baseline
  double? _currentGpsAccuracy;
  StreamSubscription<dynamic>? _gpsSubscription;

  // RSSI 임계값 상수 정의 (일관성 확보)
  static const int rssiThresholdStrong =
      -70; // 강한 신호 (HandoverReady -> Transitioning)
  static const int rssiThresholdWeak = -85; // 약한 신호 (Transitioning -> Outdoor)
  static const int rssiThresholdEntry = -80; // 실내 진입 감지 (Outdoor -> Checking)

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
          _startMonitoringGpsAccuracy(); // [New] 변화량 감지 시작

          log("[Handover] {indoor}: Door beacon ($nearestBeaconMac) detected.");
          return currentState.copyWith(
            handoverStatus: HandoverStatus.handoverReady,
          );
        }
        break;

      // 2. HandoverReady -> Transitioning OR Cancel OR Outdoor
      case HandoverStatus.handoverReady:
        // [수정] HandoverReady에서는 GPS 검사 없이 데이터 수집만 수행
        // 비콘이 Lost되거나 Weak해지면 Transitioning으로 전환하여 GPS 검사 시작

        // 1. 비콘 Lost 또는 Weak 확인
        bool beaconLost = (nearestBeaconMac != _targetDoorBeaconMac);
        bool beaconWeak =
            (currentRssi != null && currentRssi < rssiThresholdWeak);

        if (beaconLost || beaconWeak) {
          log("[Handover] {ready}: Beacon Lost or Weak (RSSI: $currentRssi)");
          // Transitioning으로 넘어가서 즉시 검사 수행
          return currentState.copyWith(
            handoverStatus: HandoverStatus.transitioning,
          );
        }

        // 2. 비콘이 여전히 강하면 대기 (GPS 데이터 계속 누적됨)
        break;

      // 3. Transitioning -> Outdoor
      case HandoverStatus.transitioning:
        // [수정] 진입 즉시 GPS 검사 수행
        // GPS 변화량 검사 + 절댓값 검사

        bool isGpsImproved = false;
        double? referenceAccuracy = _baselineGpsAccuracy;

        if (referenceAccuracy != null &&
            _currentGpsAccuracy != null &&
            referenceAccuracy > 0) {
          // 1. 비율 개선 검사
          double improvementRatio =
              (referenceAccuracy - _currentGpsAccuracy!) / referenceAccuracy;
          if (improvementRatio >= gpsImprovementRatio) {
            isGpsImproved = true;
            log(
              "[Handover] GPS Improved: $referenceAccuracy -> $_currentGpsAccuracy (${(improvementRatio * 100).toStringAsFixed(1)}%)",
            );
          }
          // 2. 절대값 개선 검사 (추가 안전장치)
          double absoluteImprovement = referenceAccuracy - _currentGpsAccuracy!;
          if (absoluteImprovement >= gpsImprovementAbsolute) {
            isGpsImproved = true;
            log(
              "[Handover] GPS Absolute Improved: $referenceAccuracy -> $_currentGpsAccuracy (${absoluteImprovement.toStringAsFixed(1)}m)",
            );
          }
        } else {
          log("[Handover] GPS Data Insufficient");
        }

        if (isGpsImproved) {
          // GPS 개선 확인 -> Outdoor 전환
          _stopMonitoringGpsAccuracy();
          _locationService.stopLocationStream();
          _targetDoorBeaconMac = null;
          log("[Handover] COMPLETE: Switched to Outdoor (GPS Improved)");
          return currentState.copyWith(handoverStatus: HandoverStatus.outdoor);
        } else {
          // GPS 개선 안됨 -> 단순 음영 구역이거나 아직 실내 -> Indoor 복귀
          _stopMonitoringGpsAccuracy();
          _locationService.stopLocationStream();
          _targetDoorBeaconMac = null;
          log("[Handover] Reset to Indoor: GPS not improved (Shadow Area?)");
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
  void _startMonitoringGpsAccuracy() {
    _baselineGpsAccuracy = null;
    _currentGpsAccuracy = null;
    _gpsSubscription?.cancel();

    _gpsSubscription = _locationService.positionStream.listen((position) {
      final acc = position.accuracy;
      _currentGpsAccuracy = acc;

      // [개선] GPS baseline 필터링 추가
      // 첫 데이터를 기준값으로 설정하되, 비정상적인 값은 제외
      // 실내 수준(5~100m)의 합리적인 값만 baseline으로 설정
      if (_baselineGpsAccuracy == null) {
        if (acc >= gpsBaselineMin && acc <= gpsBaselineMax) {
          _baselineGpsAccuracy = acc;
          log("[Handover] GPS Baseline set: $acc (filtered)");
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
