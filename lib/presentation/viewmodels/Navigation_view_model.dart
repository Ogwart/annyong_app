import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui';
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
  double _strideLength = 0.7;
  double _smoothedHeading = 0.0;

  static const double pixelsPerMeter = 10.0;
  static const double vertexBufferMeters = 2.0;

  @override
  FutureOr<NavigationState> build() async {
    return NavigationState();
  }

  Future<void> startNavigation(List<Vertex> path) async {
    if (path.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    _strideLength = prefs.getDouble('stride_length') ?? 0.7;

    final startVertex = path[0];
    double initialHeading = 0.0;

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
        floor: 1,
        buildingId: 1,
        heading: initialHeading,
        rawPixelX: startVertex.x,
        rawPixelY: startVertex.y,
        stepCount: 0,
        initialStepCount: 0,
        matchingMode: MapMatchingMode.onVertex,
        currentVertex: startVertex,
        handoverStatus: HandoverStatus.indoor,
      ),
    );

    await _startImuSubscription();
    await _startStepCountSubscription();
    _startBeaconMonitoring();
  }

  Future<void> _startImuSubscription() async {
    try {
      final compassEvents = FlutterCompass.events;
      if (compassEvents == null) return;

      const double buildingOffsetDegrees = 30.0;

      _imuSubscription = compassEvents.listen(
        (CompassEvent event) {
          final headingDegrees = event.heading;
          if (headingDegrees != null) {
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

  void updateHeading(double newHeading) {
    final currentState = state.value;
    if (currentState != null) {
      _smoothedHeading = _smoothedHeading * 0.7 + newHeading * 0.3;
      state = AsyncValue.data(currentState.copyWith(heading: _smoothedHeading));
    }
  }

  Future<void> _startStepCountSubscription() async {
    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) async {
          final currentState = state.value;
          if (currentState == null) return;

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

          final movedSteps = newStepCount - newInitialStepCount;
          if (movedSteps < 0) return;

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

  void _startBeaconMonitoring() {
    _beaconMonitorTimer?.cancel();
    _beaconMonitorTimer = Timer.periodic(const Duration(milliseconds: 1000), (
      timer,
    ) async {
      final currentState = state.value;
      if (currentState == null) return;

      final nearest = await _beaconScanService.getNearestTrackedBeacon();

      if (nearest != null) {
        bool isFloorChanged = currentState.floor != nearest.beacon.floor;
        bool isBuildingChanged =
            currentState.buildingId != nearest.beacon.buildingId;

        if (isFloorChanged || isBuildingChanged) {
          debugPrint("[Change Detected] Floor/Building Changed");
          state = AsyncValue.data(
            currentState.copyWith(
              floor: nearest.beacon.floor,
              buildingId: nearest.beacon.buildingId,
              x: nearest.beacon.xCoord.toDouble(),
              y: nearest.beacon.yCoord.toDouble(),
              rawPixelX: nearest.beacon.xCoord.toDouble(),
              rawPixelY: nearest.beacon.yCoord.toDouble(),
              matchingMode: MapMatchingMode.outOfEdge,
              currentEdge: null,
              currentVertex: null,
              handoverStatus: HandoverStatus.indoor,
            ),
          );
          return;
        }
      }

      final newState = await _handoverService.checkHandoverLogic(
        currentState: currentState,
        nearestBeaconType: nearest?.beacon.type,
        nearestBeaconMac: nearest?.beacon.macId,
        currentRssi: nearest?.rssi.toInt(),
      );

      if (newState != null) {
        state = AsyncValue.data(newState);
      }

      if (currentState.handoverStatus == HandoverStatus.indoor &&
          nearest != null) {
        correctPositionWithBeacon(beacon: nearest.beacon, rssi: nearest.rssi);
      }
    });
  }

  Future<void> _updatePositionOnStep(int stepIncrease, int newStepCount) async {
    final currentState = state.value;
    if (currentState == null) return;

    double currentHeading = currentState.heading;

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

        if (diff < 0.52) {
          currentHeading = edgeAngle;
        }
      }
    }

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

  Future<void> correctPositionWithBeacon({
    required Beacon beacon,
    required double rssi,
  }) async {
    if (rssi < -62) return;

    final Vertex? targetVertex = await _resolveTargetVertexFromBeacon(beacon);
    if (targetVertex != null) {
      _snapPositionToVertex(targetVertex, beacon.floor, beacon.buildingId);
    }
  }

  Future<Vertex?> _resolveTargetVertexFromBeacon(Beacon beacon) async {
    if (beacon.nearPoiIds.isEmpty) return null;
    final int targetPoiId = beacon.nearPoiIds.first;
    final List<Poi> pois = await _poiRepository.getPoisByIds([targetPoiId]);
    if (pois.isEmpty) return null;
    final Poi targetPoi = pois.first;
    if (targetPoi.vertexId == null) return null;
    return await _poiRepository.getVertexById(targetPoi.vertexId!);
  }

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
  }

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

    double edgeLen = edge.length;
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
