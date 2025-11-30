import 'package:annyong/domain/entity/graph_models.dart';

// 맵 매칭(현위치 추정) 모드
enum MapMatchingMode {
  onEdge,    
  onVertex,  
  outOfEdge, // 경로 이탈 
}

// 실내외 전환(Handover) 상태
enum HandoverStatus {
  indoor,          // 순수 실내 모드
  handoverReady,   // 문 근처(Door 비콘) 감지 -> GPS 신호 받기 시작
  transitioning,   // Connect Edge 진입 -> 문 통과 중
  outdoor,         // 실외 확정
}

class NavigationState {
  // --- 1. UI용 좌표 (맵 매칭 및 보정된 결과) ---
  final double x;
  final double y;
  final int floor;
  final double heading; 

  // --- 2. 픽셀 좌표 (백그라운드 추적용) ---
  final double rawPixelX;
  final double rawPixelY;
  final int stepCount;
  final int initialStepCount;

  // --- 3. 현위치 추정 알고리즘 상태 ---
  final MapMatchingMode matchingMode;

  // [OnEdge 상태용]
  final Edge? currentEdge;        // 현재 걷고 있는 엣지
  final Vertex? lastVertex;       // 방금 지나온 정점 (출발점)
  final double edgeAccumulatedDistance; // 현재 엣지에서 진행한 거리 (픽셀)

  // [OnVertex 상태용]
  final Vertex? currentVertex;    // 현재 머물고 있는 정점
  final double vertexBufferX;     // 정점 위에서 X축 이동 누적량
  final double vertexBufferY;     // 정점 위에서 Y축 이동 누적량

  // --- 4. 실내외 전환 상태 ---
  final HandoverStatus handoverStatus;

  NavigationState({
    this.x = 0.0,
    this.y = 0.0,
    this.floor = 1,
    this.heading = 0.0,
    this.rawPixelX = 0.0,
    this.rawPixelY = 0.0,
    this.stepCount = 0,
    this.initialStepCount = 0,
    this.matchingMode = MapMatchingMode.outOfEdge,
    this.currentEdge,
    this.lastVertex,
    this.edgeAccumulatedDistance = 0.0,
    this.currentVertex,
    this.vertexBufferX = 0.0,
    this.vertexBufferY = 0.0,
    this.handoverStatus = HandoverStatus.indoor,
  });

  NavigationState copyWith({
    double? x,
    double? y,
    int? floor,
    double? heading,
    double? rawPixelX,
    double? rawPixelY,
    int? stepCount,
    int? initialStepCount,
    MapMatchingMode? matchingMode,
    Edge? currentEdge,
    Vertex? lastVertex,
    double? edgeAccumulatedDistance,
    Vertex? currentVertex,
    double? vertexBufferX,
    double? vertexBufferY,
    HandoverStatus? handoverStatus,
  }) {
    return NavigationState(
      x: x ?? this.x,
      y: y ?? this.y,
      floor: floor ?? this.floor,
      heading: heading ?? this.heading,
      rawPixelX: rawPixelX ?? this.rawPixelX,
      rawPixelY: rawPixelY ?? this.rawPixelY,
      stepCount: stepCount ?? this.stepCount,
      initialStepCount: initialStepCount ?? this.initialStepCount,
      matchingMode: matchingMode ?? this.matchingMode,
      currentEdge: currentEdge ?? this.currentEdge,
      lastVertex: lastVertex ?? this.lastVertex,
      edgeAccumulatedDistance: edgeAccumulatedDistance ?? this.edgeAccumulatedDistance,
      currentVertex: currentVertex ?? this.currentVertex,
      vertexBufferX: vertexBufferX ?? this.vertexBufferX,
      vertexBufferY: vertexBufferY ?? this.vertexBufferY,
      handoverStatus: handoverStatus ?? this.handoverStatus,
    );
  }
}