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
          _locationService.stopLocationStream();
          _targetDoorBeaconMac = null;
          log("[Handover] Cancelled: Lost door beacon.");
          return currentState.copyWith(handoverStatus: HandoverStatus.indoor);
        }

        // [조건 완화] 맵 매칭(Connect Edge)에 의존하지 않고,
        // Door 비콘 신호가 충분히 강하거나(-70 이상), GPS 신호가 잡히기 시작하면 전환 시작
        bool isStrongSignal = (currentRssi != null && currentRssi > -70);

        if (isStrongSignal) {
          log("[Handover] Transitioning: Strong Door Signal.");
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
        bool gpsReady = _locationService.isGpsSignalGood();

        if (beaconLost || gpsReady) {
          log("[Handover] COMPLETE: Switched to Outdoor.");
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
    _locationService.stopLocationStream();
    _targetDoorBeaconMac = null;
    _pendingEntryBeacon = null;
  }

  Future<Vertex?> _resolveTargetVertexFromBeacon(Beacon beacon) async {
    if (beacon.nearPoiIds.isEmpty) return null;
    final pois = await _poiRepository.getPoisByIds([beacon.nearPoiIds.first]);
    if (pois.isEmpty || pois.first.vertexId == null) return null;
    return await _poiRepository.getVertexById(pois.first.vertexId!);
  }
}
