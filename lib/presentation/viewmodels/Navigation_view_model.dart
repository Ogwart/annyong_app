import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/location_service.dart';
import 'package:annyong/domain/usecases/beacon_scan_service.dart';
import 'package:annyong/presentation/viewmodels/navigation_state.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter_compass/flutter_compass.dart';

//상태를 따로 navigation_state 파일에 정의
class NavigationViewModel extends AsyncNotifier<NavigationState> {
  final PoiRepository _poiRepository = PoiRepository();
  final LocationService _locationService = LocationService();
  final BeaconScanService _beaconScanService = BeaconScanService();

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<dynamic>? _imuSubscription; // IMU 센서 스트림 (방향 데이터)
  int _lastStepCount = 0;
  //1초에 비콘 신호 1번만 받도록 하는 타이머 
  Timer? _beaconMonitorTimer; 

  // [상수 설정]
  static const double pixelsPerMeter = 10.0; // 1px = 10cm
  static const double stepLengthMeters = 0.7; // 1걸음 = 70cm
  static const double vertexBufferMeters = 2.0; // 정점 버퍼 2m

  // 실내외 전환 RSSI 임계값
  static const int rssiThresholdReady = -65;
  static const int rssiThresholdExit = -90;

  // 현재 타겟팅된 Door 비콘 (Handover용)
  String? _targetDoorBeaconMac;

  //안내 시작했을 때만 IMU 센서값을 받기 시작하도록 수정
  @override
  FutureOr<NavigationState> build() async {
    return NavigationState();
  }


  // 네비게이션 시작 (경로 산출 후에 호출됨)
  Future<void> startNavigation(List<Vertex> path) async {
    if (path.isEmpty) return;

    // 초기화: 첫 번째 Vertex에서 시작
    final startVertex = path[0];
    double initialHeading = 0.0;

    // 초기 방향 설정 (다음 경로를 바라보도록)
    if (path.length > 1) {
      final nextVertex = path[1];
      double dx = nextVertex.x - startVertex.x;
      double dy = nextVertex.y - startVertex.y;
      initialHeading = math.atan2(dx, -dy);
    }

    state = AsyncValue.data(NavigationState(
      x: startVertex.x,
      y: startVertex.y,
      floor: 1, // 필요 시 path/vertex 정보에서 가져옴
      heading: initialHeading,
      rawPixelX: startVertex.x,
      rawPixelY: startVertex.y,
      stepCount: 0,
      initialStepCount: 0,
      matchingMode: MapMatchingMode.onVertex, // 시작은 Vertex 위
      currentVertex: startVertex,
      handoverStatus: HandoverStatus.indoor,
    ));

    await _startImuSubscription();
    await _startStepCountSubscription();
    _startBeaconMonitoring();
  }

  /// IMU 센서 스트림 구독
  Future<void> _startImuSubscription() async {
    try {
      // 나침반 이벤트 스트림
      final compassEvents = FlutterCompass.events;
      if (compassEvents == null) {
        return;
      }

      // 건물 기울기 보정값: 북동쪽 30도 방향을 기준 북쪽으로 설정
      const double buildingOffsetDegrees = 30.0;

      _imuSubscription = compassEvents.listen(
        (CompassEvent event) {
          final headingDegrees = event.heading;

          if (headingDegrees != null) {
            // 건물 기울기 보정: 나침반의 30도 방향을 0도(북쪽)로 취급
            final correctedHeadingDegrees =
                (headingDegrees - buildingOffsetDegrees + 360) % 360;
            final headingRadians = correctedHeadingDegrees * math.pi / 180.0;
            updateHeading(headingRadians);
          }
        },
        onError: (error) {},
        cancelOnError: false,
      );
    } catch (e) {
      log("$e");
    }
  }

  /// 걸음수 스트림
  Future<void> _startStepCountSubscription() async {
    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          final currentState = state.value;
          if (currentState == null) return;

          // 첫 번째 이벤트면 초기 걸음수로 설정
          int newStepCount = event.steps;
          int newInitialStepCount = currentState.initialStepCount;

          if (newInitialStepCount == 0) {
            newInitialStepCount = newStepCount;
            _lastStepCount = newStepCount;
            state = AsyncValue.data(
              currentState.copyWith(
                initialStepCount: newInitialStepCount,
                stepCount: 0,
              ),
            );
            return;
          }

          // 측정 시작 후 이동한 걸음수 계산
          final movedSteps = newStepCount - newInitialStepCount;
          if (movedSteps < 0) return; // 음수 방지

          // 걸음수가 증가했는지 확인
          final stepIncrease = newStepCount - _lastStepCount;
          if (stepIncrease > 0) {
            // 걸음수가 증가했으므로 위치 업데이트 (걸음수도 함께 업데이트)
            _updatePositionOnStep(stepIncrease, movedSteps);
            _lastStepCount = newStepCount;
          } else {
            // 걸음수는 증가하지 않았지만 상태 업데이트 (다른 이유로 변경될 수 있음)
            state = AsyncValue.data(
              currentState.copyWith(stepCount: movedSteps),
            );
          }
        },
        onError: (error) {
          state = AsyncValue.error(error, StackTrace.current);
        },
        cancelOnError: false,
      );
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // 비콘 모니터링 (주기적 폴링)
  void _startBeaconMonitoring() {
    _beaconMonitorTimer?.cancel();
    _beaconMonitorTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      final currentState = state.value;
      if (currentState == null || currentState.handoverStatus == HandoverStatus.outdoor) return;

      // 1. 가장 가까운 비콘 조회
      final nearest = await _beaconScanService.getNearestTrackedBeacon();
      
      // 2. Handover 로직 체크
      await checkHandoverLogic(
        nearestBeaconType: nearest?.beacon.type,
        nearestBeaconMac: nearest?.beacon.macId,
        currentRssi: nearest?.rssi.toInt(),
      );

      // 3. 위치 보정 (실내 주행 중일 때, 신호가 강하면)
      if (currentState.handoverStatus == HandoverStatus.indoor && nearest != null) {
          await correctPositionWithBeacon(
            beacon: nearest.beacon, // 비콘 객체 통째로 전달
            rssi: nearest.rssi,
          );
      }
    });
  }

  /// 걸음수 증가 시 위치 업데이트
  void _updatePositionOnStep(int stepIncrease, int newStepCount) {
    final currentState = state.value;
    if (currentState == null) return;

    // 각 걸음마다 이동 거리 계산
    // 나침반 좌표계(0도=북쪽, 시계방향)를 화면 좌표계(x=동쪽, y=남쪽)로 변환
    // 북쪽(0도) → y 감소, 동쪽(90도) → x 증가, 남쪽(180도) → y 증가, 서쪽(270도) → x 감소
    final pixelsPerStep = stepLengthMeters * pixelsPerMeter;
    final dx = pixelsPerStep * math.sin(s.heading) * stepIncrease;
    final dy = -pixelsPerStep * math.cos(s.heading) * stepIncrease; // 화면 좌표계

    final newRawX = currentState.rawPixelX + dx;
    final newRawY = currentState.rawPixelY + dy;

    var nextState = currentState.copyWith(
      rawPixelX: newRawX,
      rawPixelY: newRawY,
      stepCount: newStepCount,
    );

    // 2. Map Matching Logic
    switch (s.matchingMode) {
      case MapMatchingMode.onEdge:
        nextState = await _handleOnEdge(nextState, stepIncrease, pixelsPerStep);
        break;
      case MapMatchingMode.onVertex:
        nextState = await _handleOnVertex(nextState, dx, dy);
        break;
      case MapMatchingMode.outOfEdge:
        nextState = await _handleOutOfEdge(nextState);
        break;
    }

    //TODO
    // 3. Handover 상태 체크 (걸음마다)
    // 여기서는 비콘 정보 없이 위치 기반 체크만 수행 (Connect Edge 진입 등)
    // 비콘 정보는 Timer에서 별도로 체크함
    state = AsyncValue.data(nextState);
    
    // 위치 변경 후 핸드오버 로직 재확인 (비콘값은 null로 넘겨서 위치기반 로직만 타게 함)
    // (실제로는 비콘값도 캐싱해서 같이 넘기는게 좋음)
  }

  /// 비콘 신호를 이용한 강력한 위치 보정 
  /// [beaconVertex]: 비콘이 위치한(혹은 가장 가까운) 정점 정보
  void correctPositionWithBeacon({
    required Vertex beaconVertex, // 좌표 대신 Vertex 객체를 통째로 받음
    required int beaconFloor,
    required double rssi,
  }) {
    // 1. 신호 강도 체크 (너무 약하면 보정 안 함)
    // -65dBm은 꽤 가까운 거리(약 1~2m)
    if (signalStrength < -65) return;

		// 2. 비콘과 연결된 Vertex 찾기 (전략 패턴: 나중에 로직 수정 용이)
    final Vertex? targetVertex = await _resolveTargetVertexFromBeacon(beacon);

    if (targetVertex != null) {
      // 3. 찾은 Vertex 위치로 강제 스냅(Snap)
      _snapPositionToVertex(targetVertex, beacon.floor);
    }
  }
		
  /// [전략] 비콘 정보로부터 보정할 목표 Vertex를 결정하는 로직
  /// 나중에 비콘의 x,y를 직접 쓰거나 다른 로직으로 바꿀 때 이 함수만 수정하면 됨
  Future<Vertex?> _resolveTargetVertexFromBeacon(Beacon beacon) async {
    // A. near_poi_ids가 비어있으면 보정 불가
    if (beacon.nearPoiIds.isEmpty) {
      // (옵션) 비상시 비콘 자체 좌표를 쓸 수도 있음. 필요하면 여기서 처리.
      return null;
    }

    // B. 첫 번째 연결된 POI ID 사용
    final int targetPoiId = beacon.nearPoiIds.first;

    // C. POI 정보 조회
    final List<Poi> pois = await _poiRepository.getPoisByIds([targetPoiId]);
    if (pois.isEmpty) return null;

    final Poi targetPoi = pois.first;

    // D. POI와 연결된 Vertex ID 확인
    if (targetPoi.vertexId == null) return null;

    // E. 최종 Vertex 객체 조회 및 반환
    return await _poiRepository.getVertexById(targetPoi.vertexId!);
  }

  /// [실행] 상태를 특정 Vertex 위치로 강제 이동 (초기화)
  void _snapPositionToVertex(Vertex vertex, int floor) {
    final s = state.value;
    if (s == null) return;

    // 이미 해당 정점 근처(2m 이내)에 있다면, 굳이 튀게 보정하지 않고 부드럽게 유지 (옵션)
    // double dist = _getDistanceBetween(s.x, s.y, vertex.x, vertex.y);
    // if (dist < 2.0 * pixelsPerMeter && s.floor == floor) return;

    state = AsyncValue.data(s.copyWith(
      // 1. UI 좌표 이동
      x: vertex.x,
      y: vertex.y,
      floor: floor,

      // 2. 픽셀 좌표 리셋 (가장 중요: 드리프트 제거)
      rawPixelX: vertex.x,
      rawPixelY: vertex.y,

      // 3. 맵 매칭 상태: 정점 위(OnVertex)로 고정
      matchingMode: MapMatchingMode.onVertex,
      currentVertex: vertex,
      
      // 4. 엣지 및 버퍼 초기화
      currentEdge: null,
      lastVertex: vertex, // 방금 이 정점을 지났다고 기록
      edgeAccumulatedDistance: 0.0,
      vertexBufferX: 0.0,
      vertexBufferY: 0.0,
    ));

    log("[Correction] Snapped to POI-linked Vertex: ${vertex.id} (Beacon Floor: $floor)");
  }
   
    

  /// 방향(heading) 업데이트 (IMU 센서에서 호출)
  void updateHeading(double heading) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(heading: heading));
    }
  }

  // --- Map Matching Logic: OnEdge ---
  Future<NavigationState> _handleOnEdge(
      NavigationState s, int stepIncrease, double pixelDistPerStep) async {
    if (s.currentEdge == null || s.lastVertex == null) return s;

    final edge = s.currentEdge!;
    // 투영 거리 계산 (단순화: 걸은 거리 그대로 Edge 진행도로 반영)
    double projectedDist = pixelDistPerStep * stepIncrease;
    double newAccumulated = s.edgeAccumulatedDistance + projectedDist;

    // Edge 위 좌표 계산
    // 시작점(lastVertex)에서 도착점(otherVertex) 방향으로 보간
    final startV = s.lastVertex!;
    final endVId = edge.getOtherVertexId(startV.id);
    final endV = await _poiRepository.getVertexById(endVId);
    
    if (endV == null) return s;

    double edgeLen = edge.length; // 픽셀
    double ratio = newAccumulated / edgeLen;
    if (ratio > 1.0) ratio = 1.0;

    double mapX = startV.x + (endV.x - startV.x) * ratio;
    double mapY = startV.y + (endV.y - startV.y) * ratio;

    // 길이 소진 체크
    if (newAccumulated >= edgeLen) {
      // Vertex 도착
      return s.copyWith(
        matchingMode: MapMatchingMode.onVertex,
        currentVertex: endV,
        x: endV.x,
        y: endV.y,
        vertexBufferX: 0,
        vertexBufferY: 0,
        // 남은 거리는 버림 (단순화)
      );
    }

    return s.copyWith(
      x: mapX,
      y: mapY,
      edgeAccumulatedDistance: newAccumulated,
    );
  }

  // --- Map Matching Logic: OnVertex ---
  Future<NavigationState> _handleOnVertex(
      NavigationState s, double dx, double dy) async {
    double newAccX = s.vertexBufferX + dx;
    double newAccY = s.vertexBufferY + dy;
    double dist = math.sqrt(newAccX * newAccX + newAccY * newAccY);

    // 2m 버퍼링
    if (dist < (vertexBufferMeters * pixelsPerMeter)) {
      return s.copyWith(
        vertexBufferX: newAccX,
        vertexBufferY: newAccY,
        x: s.currentVertex!.x,
        y: s.currentVertex!.y,
      );
    }

    // 2m 초과 시 방향 결정
    bool isVerticalMove = newAccY.abs() > newAccX.abs();
    bool isPositive = isVerticalMove ? (newAccY > 0) : (newAccX > 0);

    final candidates = await _poiRepository.getEdgesForVertex(s.currentVertex!.id);

    // 짧은 엣지 체이닝 로직 포함
    final (selectedEdge, targetStartV, accumulatedLen) = await _findBestNextPath(
      startVertex: s.currentVertex!,
      candidates: candidates,
      isVertical: isVerticalMove,
      isPositive: isPositive,
      requiredLength: dist,
    );

    if (selectedEdge != null && targetStartV != null) {
      // OnEdge 전환
      // 주의: targetStartV는 Edge의 시작점임.
      // selectedEdge의 끝점 정보를 알기 위해 로직 필요할 수 있음 (OnEdge 로직에서 getOtherVertexId 사용하므로 OK)
      
      return s.copyWith(
        matchingMode: MapMatchingMode.onEdge,
        currentEdge: selectedEdge,
        lastVertex: targetStartV,
        edgeAccumulatedDistance: accumulatedLen,
        x: targetStartV.x, // 시작점에서 다시 그리기 시작 (단순화)
        y: targetStartV.y,
        vertexBufferX: 0,
        vertexBufferY: 0,
        // Raw PDR 좌표도 맵 매칭 위치로 동기화 (Drift 제거)
        rawPixelX: targetStartV.x,
        rawPixelY: targetStartV.y,
      );
    } else {
      // 갈 곳 없음 -> 이탈
      return s.copyWith(matchingMode: MapMatchingMode.outOfEdge);
    }
  }

  // --- Map Matching Logic: OutOfEdge ---
  Future<NavigationState> _handleOutOfEdge(NavigationState s) async {
    final candidates = await _poiRepository.findNearestEdges(s.rawPixelX, s.rawPixelY, count: 5);

    if (candidates.isEmpty) return s.copyWith(x: s.rawPixelX, y: s.rawPixelY);

    final best = candidates.first;
    final edge = best.$1;
    final v1 = best.$2;
    final v2 = best.$3;
    final distToEdge = best.$4;

    // 5m 이상 떨어져 있으면 붙이지 않음
    if (distToEdge > (5.0 * pixelsPerMeter)) {
      return s.copyWith(x: s.rawPixelX, y: s.rawPixelY);
    }

    // Snap Point 계산
    final snapped = _getProjectedPoint(s.rawPixelX, s.rawPixelY, v1, v2);

    // 방향(Heading) 고려하여 lastVertex 결정
    double userDx = math.sin(s.heading);
    double userDy = -math.cos(s.heading);
    double edgeDx = v2.x - v1.x;
    double edgeDy = v2.y - v1.y;
    double dot = (userDx * edgeDx) + (userDy * edgeDy);

    Vertex newLastV = (dot >= 0) ? v1 : v2;
    double distOnEdge = _getDistanceBetween(newLastV.x, newLastV.y, snapped.dx, snapped.dy);

    return s.copyWith(
      matchingMode: MapMatchingMode.onEdge,
      currentEdge: edge,
      lastVertex: newLastV,
      edgeAccumulatedDistance: distOnEdge,
      x: snapped.dx,
      y: snapped.dy,
      rawPixelX: snapped.dx,
      rawPixelY: snapped.dy,
    );
  }

  // --- Helper Methods ---
  Future<(Edge?, Vertex?, double)> _findBestNextPath({
    required Vertex startVertex,
    required List<Edge> candidates,
    required bool isVertical,
    required bool isPositive,
    required double requiredLength,
  }) async {
    // 1. 방향 필터링
    List<Edge> dirs = [];
    for (var edge in candidates) {
      if (isVertical && edge.way != WayType.vertical) continue;
      if (!isVertical && edge.way != WayType.horizon) continue;

      final otherId = edge.getOtherVertexId(startVertex.id);
      final otherV = await _poiRepository.getVertexById(otherId);
      if (otherV == null) continue;

      double diff = isVertical ? (otherV.y - startVertex.y) : (otherV.x - startVertex.x);
      if ((isPositive && diff > 0) || (!isPositive && diff < 0)) {
        dirs.add(edge);
      }
    }

    if (dirs.isEmpty) return (null, null, 0.0);
    Edge currentEdge = dirs.first;
    Vertex currentStartV = startVertex;
    double remaining = requiredLength;

    // Short Edge Chaining
    while (true) {
      final len = currentEdge.length;
      if (remaining < len) {
        return (currentEdge, currentStartV, remaining);
      } else {
        remaining -= len;
        final nextVId = currentEdge.getOtherVertexId(currentStartV.id);
        final nextV = await _poiRepository.getVertexById(nextVId);
        if (nextV == null) break;

        final nextEdges = await _poiRepository.getEdgesForVertex(nextVId);
        try {
          // 직진 방향의 다음 Edge 찾기
          final next = nextEdges.firstWhere((e) =>
              e.getOtherVertexId(nextVId) != currentStartV.id &&
              e.way == currentEdge.way);
          currentEdge = next;
          currentStartV = nextV;
        } catch (e) {
          // 막다른 길
          return (currentEdge, currentStartV, len);
        }
      }
    }
    return (null, null, 0.0);
  }

  Offset _getProjectedPoint(double px, double py, Vertex v1, Vertex v2) {
    double x1 = v1.x; double y1 = v1.y;
    double x2 = v2.x; double y2 = v2.y;
    double dx = x2 - x1; double dy = y2 - y1;
    if (dx == 0 && dy == 0) return Offset(x1, y1);
    double t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy);
    if (t < 0) t = 0; if (t > 1) t = 1;
    return Offset(x1 + t * dx, y1 + t * dy);
  }

  double _getDistanceBetween(double x1, double y1, double x2, double y2) {
    return math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
  }

  // --- Handover Logic ---
  Future<void> checkHandoverLogic({
    required String? nearestBeaconType,
    required String? nearestBeaconMac,
    required int? currentRssi,
  }) async {
    final s = state.value;
    if (s == null || s.handoverStatus == HandoverStatus.outdoor) return;

    switch (s.handoverStatus) {
      case HandoverStatus.indoor:
        // Door 비콘 감지 시 GPS 예열
        if (nearestBeaconType == 'door' &&
            currentRssi != null &&
            currentRssi >= rssiThresholdReady) {
          _targetDoorBeaconMac = nearestBeaconMac;
          await _locationService.startLocationStream();
          state = AsyncValue.data(s.copyWith(
            handoverStatus: HandoverStatus.handoverReady,
          ));
          log("[Handover] Ready: Door beacon detected. GPS Start.");
        }
        break;

      case HandoverStatus.handoverReady:
        // 취소 조건: 문에서 멀어짐
        if (nearestBeaconMac != _targetDoorBeaconMac ||
            (currentRssi != null && currentRssi < rssiThresholdReady - 10)) {
          _locationService.stopLocationStream();
          _targetDoorBeaconMac = null;
          state = AsyncValue.data(s.copyWith(handoverStatus: HandoverStatus.indoor));
          log("[Handover] Cancelled.");
          return;
        }

        // Connect Edge 진입 확인
        bool isOnConnect = false;
        if (s.matchingMode == MapMatchingMode.onEdge &&
            s.currentEdge?.way == WayType.connect) {
          isOnConnect = true;
        }

        if (isOnConnect) {
          state = AsyncValue.data(s.copyWith(
            handoverStatus: HandoverStatus.transitioning,
          ));
          log("[Handover] Transitioning: Entered CONNECT edge.");
        }
        break;

      case HandoverStatus.transitioning:
        // 실외 판정: 비콘 끊김 OR GPS 확보
        bool beaconLost = (nearestBeaconMac != _targetDoorBeaconMac) ||
                          (currentRssi == null || currentRssi < rssiThresholdExit);
        bool gpsReady = _locationService.isGpsSignalGood();
        bool walkedEnough = s.edgeAccumulatedDistance > (3.0 * pixelsPerMeter);

        if ((beaconLost && walkedEnough) || gpsReady) {
          _switchToOutdoorMode();
        }
        break;
      default:
        break;
    }
  }

  void _switchToOutdoorMode() {
    final s = state.value!;
    state = AsyncValue.data(s.copyWith(handoverStatus: HandoverStatus.outdoor));
    log("[Handover] COMPLETE: Switched to Outdoor.");
    // UI 전환 콜백 등 추가
  }


  /// 구독 취소 및 초기화 (페이지 종료 시 호출)
  void stopNavigation() {
    _stepCountSubscription?.cancel();
    _imuSubscription?.cancel();
    _stepCountSubscription = null;
    _imuSubscription = null;

    // 상태를 초기값으로 리셋
    state = AsyncValue.data(NavigationState());
  }
}

/// NavigationViewModel Provider
final navigationViewModelProvider =
    AsyncNotifierProvider<NavigationViewModel, NavigationState>(() {
      return NavigationViewModel();
    });
