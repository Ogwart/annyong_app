import 'package:annyong/domain/entity/poi.dart';

/// 보폭 측정을 위한 경로 정보
class CalibrationRoute {
  /// 출발 POI
  final Poi startPoi;

  /// 목적지 POI
  final Poi destinationPoi;

  /// 총 이동 거리 (미터)
  final double totalDistance;

  /// 측정 모드: "one-way" (편도) 또는 "round-trip" (왕복)
  final String mode;

  CalibrationRoute({
    required this.startPoi,
    required this.destinationPoi,
    required this.totalDistance,
    required this.mode,
  });
}
