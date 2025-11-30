import 'dart:developer';
import 'package:annyong/domain/entity/beacon.dart';
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/gps_service.dart';
import 'package:annyong/presentation/viewmodels/navigation_state.dart';
import 'package:annyong/presentation/viewmodels/navigation_view_model.dart'; // 상수 사용을 위해

//실내외 전환 알고리즘 
class HandoverService {
  final GpsService _locationService = LocationService();
  final PoiRepository _poiRepository = PoiRepository();

  // Handover 관련 내부 상태 변수들 (ViewModel에서 이동)
  String? _targetDoorBeaconMac;
  Beacon? _pendingEntryBeacon;

  // RSSI 임계값 (상수)
  static const int rssiThresholdReady = NavigationViewModel.rssiThresholdReady;
  static const int rssiThresholdExit = NavigationViewModel.rssiThresholdExit;

  /// 메인 핸드오버 체크 로직
  /// 현재 상태(currentState)를 받아서, 변경이 필요한 경우 새로운 상태를 반환.
  /// 변경이 없으면 null을 반환 (최적화).
  Future<NavigationState?> checkHandoverLogic({
    required NavigationState currentState,
    required String? nearestBeaconType,
    required String? nearestBeaconMac,
    required int? currentRssi,
  }) async {
    // 이미 HandoverService 내부 변수로 관리하므로 state 내부는 건드리지 않음
    
    switch (currentState.handoverStatus) {
      // -----------------------------------------------------------------------
      // 1. Indoor -> Ready
      // -----------------------------------------------------------------------
      case HandoverStatus.indoor:
        if (nearestBeaconType == 'door' &&
            currentRssi != null &&
            currentRssi >= rssiThresholdReady) {
          
          _targetDoorBeaconMac = nearestBeaconMac;
          await _locationService.startLocationStream(); // GPS ON
          
          log("[Handover] Ready: Door beacon detected. GPS Start.");
          return currentState.copyWith(handoverStatus: HandoverStatus.handoverReady);
        }
        break;

      // -----------------------------------------------------------------------
      // 2. Ready -> Indoor (Cancel) OR Transitioning
      // -----------------------------------------------------------------------
      case HandoverStatus.handoverReady:
        // 취소 조건
        if (nearestBeaconMac != _targetDoorBeaconMac ||
            (currentRssi != null && currentRssi < rssiThresholdReady - 10)) {
          _locationService.stopLocationStream(); // GPS OFF
          _targetDoorBeaconMac = null;
          
          log("[Handover] Cancelled.");
          return currentState.copyWith(handoverStatus: HandoverStatus.indoor);
        }

        // 진입 조건 (Connect Edge)
        bool isOnConnect = false;
        if (currentState.matchingMode == MapMatchingMode.onEdge &&
            currentState.currentEdge?.way == WayType.connect) {
          isOnConnect = true;
        }

        if (isOnConnect) {
          log("[Handover] Transitioning: Entered CONNECT edge.");
          return currentState.copyWith(handoverStatus: HandoverStatus.transitioning);
        }
        break;

      // -----------------------------------------------------------------------
      // 3. Transitioning -> Outdoor
      // -----------------------------------------------------------------------
      case HandoverStatus.transitioning:
        bool beaconLost = (nearestBeaconMac != _targetDoorBeaconMac) ||
            (currentRssi == null || currentRssi < rssiThresholdExit);
        bool gpsReady = _locationService.isGpsSignalGood();
        bool walkedEnough = currentState.edgeAccumulatedDistance > (3.0 * NavigationViewModel.pixelsPerMeter);

        if ((beaconLost && walkedEnough) || gpsReady) {
          log("[Handover] COMPLETE: Switched to Outdoor.");
          return currentState.copyWith(handoverStatus: HandoverStatus.outdoor);
        }
        break;

      // -----------------------------------------------------------------------
      // 4. Outdoor -> Checking (실내 진입 감지)
      // -----------------------------------------------------------------------
      case HandoverStatus.outdoor:
        if (nearestBeaconType == 'door' &&
            currentRssi != null &&
            currentRssi >= rssiThresholdReady) {
          
          // 진입 비콘 정보 저장
          if (nearestBeaconMac != null) {
            _pendingEntryBeacon = await _poiRepository.findBeaconByMac(nearestBeaconMac);
          }

          log("[Handover] Detect Entry: Asking user...");
          return currentState.copyWith(handoverStatus: HandoverStatus.outdoorChecking);
        }
        break;

      // -----------------------------------------------------------------------
      // 5. Checking -> Outdoor (Cancel)
      // -----------------------------------------------------------------------
      case HandoverStatus.outdoorChecking:
        // 사용자가 응답하기 전에 멀어지면 자동 취소
        if (nearestBeaconMac == null || (currentRssi != null && currentRssi < -85)) {
          _pendingEntryBeacon = null;
          return currentState.copyWith(handoverStatus: HandoverStatus.outdoor);
        }
        break;
    }

    return null; // 상태 변경 없음
  }

  // ---------------------------------------------------------------------------
  // 사용자 응답 처리 메서드
  // ---------------------------------------------------------------------------

  /// "네, 들어왔습니다" 처리
  Future<NavigationState> confirmIndoorEntry(NavigationState currentState) async {
    _locationService.stopLocationStream(); // GPS 끄기

    NavigationState nextState = currentState.copyWith(
      handoverStatus: HandoverStatus.indoor,
    );

    // 위치 보정 수행
    if (_pendingEntryBeacon != null) {
      final targetVertex = await _resolveTargetVertexFromBeacon(_pendingEntryBeacon!);
      
      if (targetVertex != null) {
        // [중요] 여기서 위치 스냅 로직을 수행해서 리턴
        nextState = nextState.copyWith(
          x: targetVertex.x,
          y: targetVertex.y,
          floor: _pendingEntryBeacon!.floor,
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
      } else {
        // Vertex 못 찾으면 층수만 변경
        nextState = nextState.copyWith(floor: _pendingEntryBeacon!.floor);
      }
    }

    _pendingEntryBeacon = null;
    return nextState;
  }

  /// "아니요" 처리
  NavigationState rejectIndoorEntry(NavigationState currentState) {
    _pendingEntryBeacon = null;
    return currentState.copyWith(handoverStatus: HandoverStatus.outdoor);
  }

  /// 네비게이션 종료 시 리소스 정리
  void dispose() {
    _locationService.stopLocationStream();
    _targetDoorBeaconMac = null;
    _pendingEntryBeacon = null;
  }

  // --- Helper: 비콘 -> Vertex 변환 ---
  Future<Vertex?> _resolveTargetVertexFromBeacon(Beacon beacon) async {
    if (beacon.nearPoiIds.isEmpty) return null;
    final int targetPoiId = beacon.nearPoiIds.first;
    final pois = await _poiRepository.getPoisByIds([targetPoiId]);
    if (pois.isEmpty) return null;
    final targetPoi = pois.first;
    if (targetPoi.vertexId == null) return null;
    return await _poiRepository.getVertexById(targetPoi.vertexId!);
  }
}