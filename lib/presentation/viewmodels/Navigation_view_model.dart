import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'dart:math' as math;

/// 사용자의 현재 위치 및 네비게이션 상태
class NavigationState {
  /// 현재 X 좌표 (미터 단위)
  final double x;

  /// 현재 Y 좌표 (미터 단위)
  final double y;

  /// 현재 층수
  final int floor;

  /// 사용자가 바라보는 방향 (라디안, 0 = 북쪽, 시계방향)
  final double heading;

  /// 현재까지의 총 걸음수
  final int stepCount;

  /// 초기 걸음수 (측정 시작 시점)
  final int initialStepCount;

  NavigationState({
    this.x = 0.0,
    this.y = 0.0,
    this.floor = 1,
    this.heading = 0.0,
    this.stepCount = 0,
    this.initialStepCount = 0,
  });

  NavigationState copyWith({
    double? x,
    double? y,
    int? floor,
    double? heading,
    int? stepCount,
    int? initialStepCount,
  }) {
    return NavigationState(
      x: x ?? this.x,
      y: y ?? this.y,
      floor: floor ?? this.floor,
      heading: heading ?? this.heading,
      stepCount: stepCount ?? this.stepCount,
      initialStepCount: initialStepCount ?? this.initialStepCount,
    );
  }
}

class NavigationViewModel extends AsyncNotifier<NavigationState> {
  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<dynamic>? _imuSubscription; // IMU 센서 스트림 (방향 데이터)
  int _lastStepCount = 0;

  @override
  FutureOr<NavigationState> build() async {
    // 초기 상태 설정
    final initialState = NavigationState();

    // IMU 센서 스트림 구독 시작
    await _startImuSubscription();

    // 걸음수 스트림 구독 시작
    await _startStepCountSubscription();

    return initialState;
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
            // 음수가 되지 않도록 360을 더한 후 모듈로 연산
            final correctedHeadingDegrees =
                (headingDegrees - buildingOffsetDegrees + 360) % 360;
            final headingRadians = correctedHeadingDegrees * math.pi / 180.0;
            updateHeading(headingRadians);
          }
        },
        onError: (error) {
          print('Compass error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('Failed to initialize compass: $e');
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
            // 걸음수가 증가했으므로 위치 업데이트
            _updatePositionOnStep(stepIncrease);
            _lastStepCount = newStepCount;
          }

          // 상태 업데이트
          state = AsyncValue.data(currentState.copyWith(stepCount: movedSteps));
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

  /// 걸음수 증가 시 위치 업데이트
  ///
  /// 1걸음당 7.8픽셀
  void _updatePositionOnStep(int stepIncrease) {
    final currentState = state.value;
    if (currentState == null) return;
    const double pixelsPerStep = 7.8;
    for (int i = 0; i < stepIncrease; i++) {
      final dx = pixelsPerStep * math.cos(currentState.heading);
      final dy = pixelsPerStep * math.sin(currentState.heading);

      // 새로운 위치 계산
      final newX = currentState.x + dx;
      final newY = currentState.y + dy;

      // 상태 업데이트
      state = AsyncValue.data(currentState.copyWith(x: newX, y: newY));
    }
  }

  /// 비콘 신호로 위치 보정
  ///
  /// TODO: 비콘 데이터 준비 후 구현
  /// 비콘 신호 세기가 -40 이상일 때 해당 비콘의 위치로 사용자 위치를 강제 보정
  ///
  /// 예시 구현:
  /// ```dart
  /// void correctPositionWithBeacon({
  ///   required double beaconX,
  ///   required double beaconY,
  ///   required int beaconFloor,
  ///   required double signalStrength, // RSSI 값 (dBm)
  /// }) {
  ///   if (signalStrength >= -40) {
  ///     final currentState = state.value;
  ///     if (currentState != null) {
  ///       state = AsyncValue.data(
  ///         currentState.copyWith(
  ///           x: beaconX,
  ///           y: beaconY,
  ///           floor: beaconFloor,
  ///         ),
  ///       );
  ///     }
  ///   }
  /// }
  /// ```
  void correctPositionWithBeacon({
    required double beaconX,
    required double beaconY,
    required int beaconFloor,
    required double signalStrength, // RSSI 값 (dBm)
  }) {
    // TODO: 비콘 데이터 준비 후 구현
    // if (signalStrength >= -40) {
    //   final currentState = state.value;
    //   if (currentState != null) {
    //     state = AsyncValue.data(
    //       currentState.copyWith(
    //         x: beaconX,
    //         y: beaconY,
    //         floor: beaconFloor,
    //       ),
    //     );
    //   }
    // }
  }

  /// 초기 위치 설정 (출발지 설정)
  void setInitialPosition({
    required double x,
    required double y,
    required int floor,
    double? heading,
  }) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(
        currentState.copyWith(
          x: x,
          y: y,
          floor: floor,
          heading: heading ?? currentState.heading,
        ),
      );
    }
  }

  /// 출발 POI로부터 초기 위치 설정
  void setInitialPositionFromPoi(Poi departurePoi, {double? heading}) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(
        currentState.copyWith(
          x: departurePoi.xCoord,
          y: departurePoi.yCoord,
          floor: departurePoi.floor,
          heading: heading ?? currentState.heading,
          stepCount: 0,
          initialStepCount: 0,
        ),
      );
    }
  }

  /// 방향(heading) 업데이트 (IMU 센서에서 호출)
  void updateHeading(double heading) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(heading: heading));
    }
  }

  /// 구독 취소 (페이지 종료 시 호출)
  void stopNavigation() {
    _stepCountSubscription?.cancel();
    _imuSubscription?.cancel();
    _stepCountSubscription = null;
    _imuSubscription = null;
  }
}

/// NavigationViewModel Provider
final navigationViewModelProvider =
    AsyncNotifierProvider<NavigationViewModel, NavigationState>(() {
      return NavigationViewModel();
    });
