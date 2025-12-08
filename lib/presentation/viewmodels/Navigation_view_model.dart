import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui'; // Offset 사용을 위해 필요

import 'package:annyong/domain/entity/beacon.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/beacon_scan_service.dart';
import 'package:annyong/domain/usecases/handover_service.dart';
import 'package:annyong/presentation/viewmodels/navigation_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationViewModel extends AsyncNotifier<NavigationState> {
  final PoiRepository _poiRepository = PoiRepository();
  final BeaconScanService _beaconScanService = BeaconScanService();
  final HandoverService _handoverService = HandoverService();

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<dynamic>? _imuSubscription;
  Timer? _beaconMonitorTimer;

  int _lastStepCount = 0;

  // [최적화] 자주 쓰이는 변수 캐싱
  double _strideLength = 0.7;
  double _smoothedHeading = 0.0;

  // [상수 설정]
  static const double pixelsPerMeter = 10.0; // 1px = 10cm
  static const double vertexBufferMeters = 2.0; // 정점 버퍼 2m
  static const int rssiThresholdReady =
      -75; // Handover 준비 기준 RSSI (HandoverService에서 참조)
  static const int rssiThresholdExit = -85; // 실외 전환 기준 RSSI

  @override
  FutureOr<NavigationState> build() async {
    return NavigationState();
  }

  // 네비게이션 시작
  Future<void> startNavigation(List<Vertex> path) async {
    if (path.isEmpty) return;

    // 1. 보폭 미리 로드 (매 걸음마다 로드하면 딜레이 발생하므로 여기서 한 번만)
    final prefs = await SharedPreferences.getInstance();
    _strideLength = prefs.getDouble('stride_length') ?? 0.7;

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
    _smoothedHeading = initialHeading;

    state = AsyncValue.data(
      NavigationState(
        x: startVertex.x,
        y: startVertex.y,
        floor: 1, // 초기값, 추후 비콘으로 보정될 수 있음
        buildingId: 1, // 초기값, 추후 비콘으로 보정
        heading: initialHeading,
        rawPixelX: startVertex.x,
        rawPixelY: startVertex.y,
        stepCount: 0,
        initialStepCount: 0,
        matchingMode: MapMatchingMode.onVertex, // 시작은 Vertex 위
        currentVertex: startVertex,
        handoverStatus: HandoverStatus.indoor,
      ),
    );

    await _startImuSubscription();
    await _startStepCountSubscription();
    _startBeaconMonitoring();
  }

  /// IMU 센서 스트림 구독
  Future<void> _startImuSubscription() async {
    try {
      final compassEvents = FlutterCompass.events;
      if (compassEvents == null) return;

      // 건물 기울기 보정값: 북동쪽 30도 방향을 기준 북쪽으로 설정
      const double buildingOffsetDegrees = 30.0;

      _imuSubscription = compassEvents.listen(
        (CompassEvent event) {
          final headingDegrees = event.heading;

          if (headingDegrees != null) {
            // 건물 기울기 보정
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

  // [최적화] 헤딩 스무딩 적용 (Low-Pass Filter)
  void updateHeading(double newHeading) {
    final currentState = state.value;
    if (currentState != null) {
      // 급격한 회전 방지를 위한 가중 평균 (이전 70%, 현재 30%)
      // 실제로는 0<->360 경계 처리가 필요하지만 약식으로 적용
      _smoothedHeading = _smoothedHeading * 0.7 + newHeading * 0.3;
      state = AsyncValue.data(currentState.copyWith(heading: _smoothedHeading));
    }
  }

  /// 걸음수 스트림
  Future<void> _startStepCountSubscription() async {
    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) async {
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
          if (movedSteps < 0) return;

          // 걸음수가 증가했는지 확인
          final stepIncrease = newStepCount - _lastStepCount;
          if (stepIncrease > 0) {
            await _updatePositionOnStep(stepIncrease, movedSteps);
            _lastStepCount = newStepCount;
          } else {
            state = AsyncValue.data(
              currentState.copyWith(stepCount: movedSteps),
            );
          }
        },
        onError: (error) {
          debugPrint("[Step Error] 걸음 수 센서 오류: $error");
        },
        cancelOnError: false,
      );
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // [중요] 비콘 모니터링: 위치 보정, 층/건물 변경, 핸드오버 처리
  void _startBeaconMonitoring() {
    _beaconMonitorTimer?.cancel();
    _beaconMonitorTimer = Timer.periodic(const Duration(milliseconds: 1000), (
      timer,
    ) async {
      final currentState = state.value;
      if (currentState == null) return;

      // BeaconScanService가 필터링해준 '가장 신뢰할 수 있는' 비콘 가져오기
      final nearest = await _beaconScanService.getNearestTrackedBeacon();

      // 1. 층/건물 변경 감지 (가장 우선)
      // 비콘 서비스가 리턴했다는 것은 이미 진입 조건(RSSI > -68.5)을 만족했다는 의미
      if (nearest != null) {
        bool isFloorChanged = currentState.floor != nearest.beacon.floor;
        bool isBuildingChanged =
            currentState.buildingId != nearest.beacon.buildingId;

        if (isFloorChanged || isBuildingChanged) {
          debugPrint(
            "[Change Detected] Floor: ${currentState.floor}->${nearest.beacon.floor}, Building: ${currentState.buildingId}->${nearest.beacon.buildingId}",
          );

          // 해당 층/건물의 좌표계로 강제 이동 및 맵 매칭 초기화
          state = AsyncValue.data(
            currentState.copyWith(
              floor: nearest.beacon.floor,
              buildingId: nearest.beacon.buildingId,
              x: nearest.beacon.xCoord.toDouble(),
              y: nearest.beacon.yCoord.toDouble(),
              rawPixelX: nearest.beacon.xCoord.toDouble(),
              rawPixelY: nearest.beacon.yCoord.toDouble(),
              matchingMode: MapMatchingMode.outOfEdge, // 새로운 층이므로 매칭 해제
              currentEdge: null,
              currentVertex: null,
              handoverStatus: HandoverStatus.indoor, // 실내 상태로 확정
            ),
          );
          return; // 층이 바뀌었으면 아래 로직 생략
        }
      }

      // 2. 핸드오버 로직 위임
      final newState = await _handoverService.checkHandoverLogic(
        currentState: currentState,
        nearestBeaconType: nearest?.beacon.type,
        nearestBeaconMac: nearest?.beacon.macId,
        currentRssi: nearest?.rssi.toInt(),
      );

      if (newState != null) {
        state = AsyncValue.data(newState);
      }

      // 3. 같은 층 내 위치 보정 (실내 주행 중일 때)
      if (currentState.handoverStatus == HandoverStatus.indoor &&
          nearest != null) {
        correctPositionWithBeacon(beacon: nearest.beacon, rssi: nearest.rssi);
      }
    });
  }

  // [최적화] 걸음 처리 로직
  Future<void> _updatePositionOnStep(int stepIncrease, int newStepCount) async {
    final currentState = state.value;
    if (currentState == null) return;

    double currentHeading = currentState.heading;

    // 엣지 스내핑: 엣지 위에 있고 각도 차이가 작다면 엣지 방향을 따름
    if (currentState.matchingMode == MapMatchingMode.onEdge &&
        currentState.currentEdge != null &&
        currentState.lastVertex != null) {
      final edge = currentState.currentEdge!;
      final otherId = edge.getOtherVertexId(currentState.lastVertex!.id);
      final otherV = await _poiRepository.getVertexById(otherId);

      if (otherV != null) {
        double edgeDx = otherV.x - currentState.lastVertex!.x;
        double edgeDy = otherV.y - currentState.lastVertex!.y;
        double edgeAngle = math.atan2(edgeDx, -edgeDy);

        double diff = (currentHeading - edgeAngle).abs();
        if (diff > math.pi) diff = 2 * math.pi - diff;

        // 약 30도 이내면 엣지 방향으로 강제 정렬 (직진성 강화)
        if (diff < 0.52) {
          currentHeading = edgeAngle;
        }
      }
    }

    // 미리 로드한 strideLength 사용
    double pixelDistPerStep = _strideLength * pixelsPerMeter;

    final dx = pixelDistPerStep * math.sin(currentHeading) * stepIncrease;
    final dy = -pixelDistPerStep * math.cos(currentHeading) * stepIncrease;

    final newRawX = currentState.rawPixelX + dx;
    final newRawY = currentState.rawPixelY + dy;

    var nextState = currentState.copyWith(
      rawPixelX: newRawX,
      rawPixelY: newRawY,
      stepCount: newStepCount,
    );

    // 2. Map Matching Logic
    switch (currentState.matchingMode) {
      case MapMatchingMode.onEdge:
        nextState = await _handleOnEdge(
          nextState,
          stepIncrease,
          pixelDistPerStep,
        );
        break;
      case MapMatchingMode.onVertex:
        nextState = await _handleOnVertex(nextState, dx, dy);
        break;
      case MapMatchingMode.outOfEdge:
        nextState = await _handleOutOfEdge(nextState);
        break;
    }

    // 3. Handover 상태 체크 (뷰모델 레벨에서의 추가 체크가 필요하다면)
    if (nextState.handoverStatus != HandoverStatus.indoor) {
      final handoverUpdate = await _handoverService.checkHandoverLogic(
        currentState: nextState,
        nearestBeaconType: null,
        nearestBeaconMac: null,
        currentRssi: null,
      );

      if (handoverUpdate != null) {
        nextState = handoverUpdate;
      }
    }

    state = AsyncValue.data(nextState);
  }

  /// 비콘 신호를 이용한 강력한 위치 보정
  Future<void> correctPositionWithBeacon({
    required Beacon beacon,
    required double rssi,
  }) async {
    // BeaconScanService가 이미 필터링했으므로 RSSI 신뢰 가능.
    // 아주 가까울 때(-62 이상)만 강제 스냅
    if (rssi < -62) return;

    final Vertex? targetVertex = await _resolveTargetVertexFromBeacon(beacon);
    if (targetVertex != null) {
      _snapPositionToVertex(targetVertex, beacon.floor, beacon.buildingId);
    }
  }

  /// 비콘 정보로부터 보정할 목표 Vertex를 결정하는 로직
  Future<Vertex?> _resolveTargetVertexFromBeacon(Beacon beacon) async {
    if (beacon.nearPoiIds.isEmpty) {
      return null;
    }

    final int targetPoiId = beacon.nearPoiIds.first;
    final List<Poi> pois = await _poiRepository.getPoisByIds([targetPoiId]);
    if (pois.isEmpty) return null;

    final Poi targetPoi = pois.first;
    if (targetPoi.vertexId == null) return null;

    return await _poiRepository.getVertexById(targetPoi.vertexId!);
  }

  /// 상태를 특정 Vertex 위치로 강제 이동 (초기화)
  void _snapPositionToVertex(Vertex vertex, int floor, int buildingId) {
    final s = state.value;
    if (s == null) return;

    state = AsyncValue.data(
      s.copyWith(
        x: vertex.x,
        y: vertex.y,
        floor: floor,
        buildingId: buildingId,
        rawPixelX: vertex.x,
        rawPixelY: vertex.y,
        matchingMode: MapMatchingMode.onVertex,
        currentVertex: vertex,
        currentEdge: null,
        lastVertex: vertex,
        edgeAccumulatedDistance: 0.0,
        vertexBufferX: 0.0,
        vertexBufferY: 0.0,
      ),
    );

    log(
      "[Correction] Snapped to POI-linked Vertex: ${vertex.id} (Beacon Floor: $floor)",
    );
  }

  // --- Map Matching Logic: OnEdge ---
  Future<NavigationState> _handleOnEdge(
    NavigationState s,
    int stepIncrease,
    double pixelDistPerStep,
  ) async {
    if (s.currentEdge == null || s.lastVertex == null) return s;

    final edge = s.currentEdge!;
    double projectedDist = pixelDistPerStep * stepIncrease;
    double newAccumulated = s.edgeAccumulatedDistance + projectedDist;

    final startV = s.lastVertex!;
    final endVId = edge.getOtherVertexId(startV.id);
    final endV = await _poiRepository.getVertexById(endVId);

    if (endV == null) return s;

    double edgeLen = edge.length; // 픽셀
    double ratio = newAccumulated / edgeLen;
    if (ratio > 1.0) ratio = 1.0;

    double mapX = startV.x + (endV.x - startV.x) * ratio;
    double mapY = startV.y + (endV.y - startV.y) * ratio;

    if (newAccumulated >= edgeLen) {
      return s.copyWith(
        matchingMode: MapMatchingMode.onVertex,
        currentVertex: endV,
        x: endV.x,
        y: endV.y,
        vertexBufferX: 0,
        vertexBufferY: 0,
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
    NavigationState s,
    double dx,
    double dy,
  ) async {
    double newAccX = s.vertexBufferX + dx;
    double newAccY = s.vertexBufferY + dy;
    double dist = math.sqrt(newAccX * newAccX + newAccY * newAccY);

    if (dist < (vertexBufferMeters * pixelsPerMeter)) {
      return s.copyWith(
        vertexBufferX: newAccX,
        vertexBufferY: newAccY,
        x: s.currentVertex!.x,
        y: s.currentVertex!.y,
      );
    }

    bool isVerticalMove = newAccY.abs() > newAccX.abs();
    bool isPositive = isVerticalMove ? (newAccY > 0) : (newAccX > 0);

    final candidates = await _poiRepository.getEdgesForVertex(
      s.currentVertex!.id,
    );

    final (
      selectedEdge,
      targetStartV,
      accumulatedLen,
    ) = await _findBestNextPath(
      startVertex: s.currentVertex!,
      candidates: candidates,
      isVertical: isVerticalMove,
      isPositive: isPositive,
      requiredLength: dist,
    );

    if (selectedEdge != null && targetStartV != null) {
      return s.copyWith(
        matchingMode: MapMatchingMode.onEdge,
        currentEdge: selectedEdge,
        lastVertex: targetStartV,
        edgeAccumulatedDistance: accumulatedLen,
        x: targetStartV.x,
        y: targetStartV.y,
        vertexBufferX: 0,
        vertexBufferY: 0,
        rawPixelX: targetStartV.x,
        rawPixelY: targetStartV.y,
      );
    } else {
      return s.copyWith(matchingMode: MapMatchingMode.outOfEdge);
    }
  }

  // --- Map Matching Logic: OutOfEdge ---
  Future<NavigationState> _handleOutOfEdge(NavigationState s) async {
    final candidates = await _poiRepository.findNearestEdges(
      s.rawPixelX,
      s.rawPixelY,
      count: 5,
    );

    if (candidates.isEmpty) return s.copyWith(x: s.rawPixelX, y: s.rawPixelY);

    final best = candidates.first;
    final edge = best.$1;
    final v1 = best.$2;
    final v2 = best.$3;
    final distToEdge = best.$4;

    if (distToEdge > (5.0 * pixelsPerMeter)) {
      return s.copyWith(x: s.rawPixelX, y: s.rawPixelY);
    }

    final snapped = _getProjectedPoint(s.rawPixelX, s.rawPixelY, v1, v2);

    double userDx = math.sin(s.heading);
    double userDy = -math.cos(s.heading);
    double edgeDx = v2.x - v1.x;
    double edgeDy = v2.y - v1.y;
    double dot = (userDx * edgeDx) + (userDy * edgeDy);

    Vertex newLastV = (dot >= 0) ? v1 : v2;
    double distOnEdge = _getDistanceBetween(
      newLastV.x,
      newLastV.y,
      snapped.dx,
      snapped.dy,
    );

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
    List<Edge> dirs = [];
    for (var edge in candidates) {
      if (isVertical && edge.way != WayType.vertical) continue;
      if (!isVertical && edge.way != WayType.horizon) continue;

      final otherId = edge.getOtherVertexId(startVertex.id);
      final otherV = await _poiRepository.getVertexById(otherId);
      if (otherV == null) continue;

      double diff = isVertical
          ? (otherV.y - startVertex.y)
          : (otherV.x - startVertex.x);
      if ((isPositive && diff > 0) || (!isPositive && diff < 0)) {
        dirs.add(edge);
      }
    }

    if (dirs.isEmpty) return (null, null, 0.0);
    Edge currentEdge = dirs.first;
    Vertex currentStartV = startVertex;
    double remaining = requiredLength;

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
          final next = nextEdges.firstWhere(
            (e) =>
                e.getOtherVertexId(nextVId) != currentStartV.id &&
                e.way == currentEdge.way,
          );
          currentEdge = next;
          currentStartV = nextV;
        } catch (e) {
          return (currentEdge, currentStartV, len);
        }
      }
    }
    return (null, null, 0.0);
  }

  Offset _getProjectedPoint(double px, double py, Vertex v1, Vertex v2) {
    double x1 = v1.x;
    double y1 = v1.y;
    double x2 = v2.x;
    double y2 = v2.y;
    double dx = x2 - x1;
    double dy = y2 - y1;
    if (dx == 0 && dy == 0) return Offset(x1, y1);
    double t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy);
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    return Offset(x1 + t * dx, y1 + t * dy);
  }

  double _getDistanceBetween(double x1, double y1, double x2, double y2) {
    return math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
  }

  // 7. 사용자 응답 처리 (UI 호출용)
  Future<void> confirmIndoorEntry() async {
    final s = state.value;
    if (s == null) return;

    final newState = await _handoverService.confirmIndoorEntry(s);
    state = AsyncValue.data(newState);
  }

  void rejectIndoorEntry() {
    final s = state.value;
    if (s == null) return;

    final newState = _handoverService.rejectIndoorEntry(s);
    state = AsyncValue.data(newState);
  }

  void stopNavigation() {
    _stepCountSubscription?.cancel();
    _imuSubscription?.cancel();
    _beaconMonitorTimer?.cancel();

    _stepCountSubscription = null;
    _imuSubscription = null;
    _beaconMonitorTimer = null;

    _handoverService.dispose();

    state = AsyncValue.data(NavigationState());
  }
}

final navigationViewModelProvider =
    AsyncNotifierProvider<NavigationViewModel, NavigationState>(() {
      return NavigationViewModel();
    });
