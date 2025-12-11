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
  double? _baselineGpsAccuracy;
  double? _currentGpsAccuracy;
  StreamSubscription<dynamic>? _gpsSubscription;

  // 뷰모델의 임계값 상수 사용 (또는 직접 정의)
  static const int rssiThresholdReady = -75;

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

          log("[Handover] Ready: Door beacon ($nearestBeaconMac) detected.");
          return currentState.copyWith(
            handoverStatus: HandoverStatus.handoverReady,
          );
        }
        break;

      // 2. HandoverReady -> Transitioning OR Cancel
      case HandoverStatus.handoverReady:
        // 타겟 문 비콘이 사라지거나 바뀌면 취소
        if (nearestBeaconMac != _targetDoorBeaconMac) {
          _stopMonitoringGpsAccuracy(); // [New] 모니터링 종료
          _locationService.stopLocationStream();
          _targetDoorBeaconMac = null;
          log("[Handover] Cancelled: Lost door beacon.");
          return currentState.copyWith(handoverStatus: HandoverStatus.indoor);
        }

        // [조건 강화] GPS 정확도 변화량 체크
        bool isGpsImproved = false;
        if (_baselineGpsAccuracy != null && _currentGpsAccuracy != null) {
          // 정확도 수치가 작아질수록 좋은 것 (예: 11.0 -> 6.0 = 5.0 개선)
          // 3.0m 이상 개선되면 실외 징후로 판단
          if ((_baselineGpsAccuracy! - _currentGpsAccuracy!) >= 3.0) {
            isGpsImproved = true;
            log(
              "[Handover] GPS Improved: $_baselineGpsAccuracy -> $_currentGpsAccuracy",
            );
          }
        }

        // [조건 완화] 맵 매칭(Connect Edge)에 의존하지 않고,
        // Door 비콘 신호가 충분히 강하거나(-70 이상), GPS 신호가 잡히기 시작하면 전환 시작
        // [수정] RSSI 강도 또는 GPS 정확도 개선 시 전환
        bool isStrongSignal = (currentRssi != null && currentRssi > -70);

        if (isStrongSignal || isGpsImproved) {
          log("[Handover] Transitioning: Strong Signal or GPS Improved.");
          return currentState.copyWith(
            handoverStatus: HandoverStatus.transitioning,
          );
        }
        break;

      // 3. Transitioning -> Outdoor
      case HandoverStatus.transitioning:
        // 문 비콘 신호가 완전히 끊기거나(null), 다른 비콘으로 바뀌면 실외로 간주
        // (BeaconScanService의 Ghost Packet 로직에 의해 서서히 끊김)
        bool beaconLost = (nearestBeaconMac != _targetDoorBeaconMac);
        // bool gpsReady = _locationService.isGpsSignalGood(); // [삭제] 절대값 기준 대신 변화율 사용

        // [수정] GPS 변화율 계산 (baseline 대비 40% 이상 개선)
        bool isSignificantImprovement = false;
        if (_baselineGpsAccuracy != null &&
            _currentGpsAccuracy != null &&
            _baselineGpsAccuracy! > 0) {
          double improvementRatio =
              (_baselineGpsAccuracy! - _currentGpsAccuracy!) /
              _baselineGpsAccuracy!;
          if (improvementRatio >= 0.40) {
            isSignificantImprovement = true;
          }
        }

        // [수정] GPS 신호가 좋아도, 비콘이 여전히 강력하게 잡히고 있다면 아직 실내(문 근처)일 수 있음.
        // 따라서 "비콘 신호가 끊김(beaconLost)" 또는 "GPS가 좋으면서 비콘 신호가 약해짐" 조건으로 강화
        // [수정] 비콘 신호 임계값 -85dBm 미만으로 강화
        bool weakBeacon =
            (currentRssi != null && currentRssi < -85); // 예: -85dBm 미만이면 약함

        // Case 1: 비콘이 끊긴 경우
        if (beaconLost) {
          if (isSignificantImprovement) {
            // 비콘 끊김 + GPS 개선됨 -> 확실한 실외
            log(
              "[Handover] COMPLETE: Switched to Outdoor (BeaconLost + GPS Improved)",
            );
            return currentState.copyWith(
              handoverStatus: HandoverStatus.outdoor,
            );
          } else {
            // 비콘 끊김 + GPS 개선 안됨 -> 실내 음영 구역일 가능성 -> Indoor 복귀
            _stopMonitoringGpsAccuracy();
            _locationService.stopLocationStream();
            _targetDoorBeaconMac = null;
            log(
              "[Handover] Reset to Indoor: Beacon lost but GPS bad (Shadow Area?)",
            );
            return currentState.copyWith(handoverStatus: HandoverStatus.indoor);
          }
        }
        // Case 2: 비콘은 잡히지만 신호가 약하고 GPS가 크게 개선된 경우
        else if (isSignificantImprovement && weakBeacon) {
          log(
            "[Handover] COMPLETE: Switched to Outdoor (Weak Beacon + GPS Improved)",
          );
          return currentState.copyWith(handoverStatus: HandoverStatus.outdoor);
        }
        break;

      // 4. Outdoor -> Checking (실내 진입 감지)
      case HandoverStatus.outdoor:
        if (nearestBeaconType == 'door') {
          // 진입하려는 비콘 정보 저장 (나중에 건물/층 정보 사용)
          if (nearestBeaconMac != null) {
            _pendingEntryBeacon = await _poiRepository.findBeaconByMac(
              nearestBeaconMac,
            );
          }
          log("[Handover] Detect Entry: Asking user...");
          return currentState.copyWith(
            handoverStatus: HandoverStatus.outdoorChecking,
          );
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

      // 첫 데이터(또는 초기 데이터)를 기준값으로 설정
      // 단, 너무 터무니없는 값(100m 이상)은 제외하고, 실내 수준(10~30m)일 때 잡는 것이 좋음
      if (_baselineGpsAccuracy == null) {
        _baselineGpsAccuracy = acc;
        log("[Handover] GPS Baseline set: $acc");
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
