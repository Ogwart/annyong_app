// lib/domain/entity/calibration_route.dart
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/entity/poi.dart';

/// 보폭 측정을 위한 경로 정보
class CalibrationRoute {
  /// 출발 POI (보폭 측정 시작은 항상 특정 장소에서 하므로 유지)
  final Poi startPoi;

  /// 목적지 Vertex (길 안내의 실질적 목표 지점)
  final Vertex destinationVertex;

  /// 목적지 POI (목적지 Vertex에 POI가 있다면 포함, 없으면 null)
  final Poi? destinationPoi;

  /// 총 이동 거리 (미터)
  final double totalDistance;

  /// 측정 모드: "one-way" (편도) 등
  final String mode;

  CalibrationRoute({
    required this.startPoi,
    required this.destinationVertex, // 필수 (길 안내용)
    this.destinationPoi, // 선택 (정보 표시용)
    required this.totalDistance,
    required this.mode,
  });
}
