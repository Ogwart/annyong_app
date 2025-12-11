import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class GpsService {
  StreamSubscription<Position>? _positionStreamSubscription;

  // 현재 GPS 위치 및 정확도 캐싱
  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  // GPS 정확도가 이 값(미터)보다 낮아야(좋아야) 실외로 인정
  static const double _requiredAccuracyMeters = 7.0;

  /// 위치 데이터 스트림 노출 (HandoverService에서 변화량 감지용)
  Stream<Position> get positionStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // 미세한 변화 감지를 위해 필터 제거
    ),
  );

  /// GPS 스트림 시작 (핸드오버 '준비' 단계에서 호출)
  Future<void> startLocationStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[GPS] 위치 서비스가 꺼져 있습니다.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[GPS] 위치 권한이 거부되었습니다.');
        return;
      }
    }

    if (_positionStreamSubscription != null) return;

    debugPrint('[GPS] Warm-up Started (Handover Detected)');

    // 배터리 절약을 위해 평소엔 끄고, 필요할 때만 High Accuracy로 켭니다.
    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 5m 이동 시 갱신
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          _lastPosition = position;
          debugPrint(
            '[GPS] Updated: ${position.latitude}, ${position.longitude} (Acc: ${position.accuracy})',
          );
        });
  }

  /// GPS 스트림 종료
  void stopLocationStream() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _lastPosition = null;
    debugPrint('[GPS] Stream Stopped');
  }

  /// 현재 GPS 신호가 실외 판정을 내리기에 충분한 품질인지 확인
  bool isGpsSignalGood() {
    if (_lastPosition == null) return false;
    return _lastPosition!.accuracy < _requiredAccuracyMeters;
  }
}
