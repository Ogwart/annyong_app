import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class GpsService {
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamController<Position>? _positionStreamController;

  // 현재 GPS 위치 및 정확도 캐싱
  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  // GPS 정확도가 이 값(미터)보다 낮아야(좋아야) 실외로 인정
  static const double _requiredAccuracyMeters = 9.0;

  /// 위치 데이터 스트림 노출 (HandoverService에서 변화량 감지용)
  /// [수정] startLocationStream()이 만드는 스트림과 동일한 스트림을 공유
  Stream<Position> get positionStream {
    if (_positionStreamController != null) {
      return _positionStreamController!.stream;
    }
    // fallback: 스트림이 시작되지 않았으면 새로 생성
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );
  }

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
    // [수정] StreamController를 사용하여 스트림 공유
    _positionStreamController = StreamController<Position>.broadcast();

    // 배터리 절약을 위해 평소엔 끄고, 필요할 때만 High Accuracy로 켭니다.
    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 5m 이동 시 갱신
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _lastPosition = position;
            // StreamController를 통해 모든 구독자에게 전달
            _positionStreamController?.add(position);
          },
        );
  }

  /// GPS 스트림 종료
  void stopLocationStream() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _positionStreamController?.close();
    _positionStreamController = null;
    _lastPosition = null;
  }

  /// 현재 GPS 신호가 실외 판정을 내리기에 충분한 품질인지 확인
  bool isGpsSignalGood() {
    if (_lastPosition == null) return false;
    return _lastPosition!.accuracy < _requiredAccuracyMeters;
  }

  /// 현재 위치를 즉시 가져오기 (baseline 설정용)
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[GPS] 위치 서비스가 꺼져 있습니다.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[GPS] 위치 권한이 거부되었습니다.');
          return null;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _lastPosition = position;
      return position;
    } catch (e) {
      debugPrint('[GPS] getCurrentPosition error: $e');
      return null;
    }
  }
}
