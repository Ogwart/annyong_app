import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/presentation/viewmodels/navigation_state.dart';
import 'package:annyong/domain/usecases/path_finder.dart';

// 1. 데이터 클래스 수정: imagePath 추가
class GuidanceInfo {
  final String message;
  final IconData icon; // Fallback용 아이콘
  final Color iconColor;
  final String? imagePath; // [New] PNG 이미지 경로

  GuidanceInfo({
    required this.message,
    required this.icon,
    this.iconColor = AppColors.primary,
    this.imagePath,
  });
}

int _getFloor(int vertexId) {
  if (vertexId >= 1 && vertexId < 500) {
    return 1;
  } else if (vertexId >= 500 && vertexId < 1000) {
    return 2;
  } else if (vertexId >= 1000) {
    return 1;
  }
  return 1;
}

GuidanceInfo calculateGuidance(
  NavigationState state,
  List<int> path,
  PathFinder pathFinder,
  Poi end,
) {
  if (state.matchingMode == MapMatchingMode.outOfEdge) {
    return GuidanceInfo(
      message: "경로를 이탈했습니다",
      icon: Icons.error_outline,
      iconColor: Colors.red,
    );
  }

  double currentX = state.x;
  double currentY = state.y;
  int currentFloor = state.floor;

  Vertex? targetVertex;

  if (state.matchingMode == MapMatchingMode.onVertex &&
      state.currentVertex != null) {
    int currentIndex = path.indexOf(state.currentVertex!.id);
    if (currentIndex != -1 && currentIndex + 1 < path.length) {
      targetVertex = pathFinder.vertices[path[currentIndex + 1]];
    }
  } else if (state.matchingMode == MapMatchingMode.onEdge &&
      state.currentEdge != null &&
      state.lastVertex != null) {
    int targetId = state.currentEdge!.getOtherVertexId(state.lastVertex!.id);
    targetVertex = pathFinder.vertices[targetId];
  }

  if (targetVertex == null) {
    // 근처 정점 찾기 로직 (기존 유지)
    double minDistance = double.infinity;
    int closestIndex = -1;
    for (int i = 0; i < path.length; i++) {
      int vId = path[i];
      final v = pathFinder.vertices[vId];
      if (v != null) {
        int vFloor = _getFloor(vId);
        if (vFloor == currentFloor) {
          double dist = math.sqrt(
            math.pow(v.x - currentX, 2) + math.pow(v.y - currentY, 2),
          );
          if (dist < minDistance) {
            minDistance = dist;
            closestIndex = i;
          }
        }
      }
    }
    if (closestIndex != -1 && closestIndex + 1 < path.length) {
      targetVertex = pathFinder.vertices[path[closestIndex + 1]];
    }
  }

  if (targetVertex == null) {
    double distToEnd = math.sqrt(
      math.pow(end.xCoord - currentX, 2) + math.pow(end.yCoord - currentY, 2),
    );
    int endFloor = _getFloor(end.vertexId ?? 0);
    if (currentFloor == endFloor && distToEnd < 10.0) {
      // 도착 시에는 별도 PNG가 없다면 아이콘 유지, 혹은 guide_departure 사용?
      // 여기서는 아이콘(Flag)을 유지합니다.
      return GuidanceInfo(message: "목적지에 도착했습니다", icon: Icons.flag);
    }
    return GuidanceInfo(message: "경로 재탐색 필요", icon: Icons.refresh);
  }

  // 층간 이동 (계단) 로직
  int targetFloor = _getFloor(targetVertex.id);
  if (targetFloor != currentFloor) {
    if (targetFloor > currentFloor) {
      return GuidanceInfo(
        message: "계단을 올라가세요",
        icon: Icons.arrow_upward,
        iconColor: AppColors.secondary,
        imagePath: 'assets/icons/guide_tile/guide_upstair.png', // [New]
      );
    } else {
      return GuidanceInfo(
        message: "계단을 내려가세요",
        icon: Icons.arrow_downward,
        iconColor: AppColors.secondary,
        imagePath: 'assets/icons/guide_tile/guide_downstair.png', // [New]
      );
    }
  }

  // 방향 계산 로직
  double dx = targetVertex.x - currentX;
  double dy = targetVertex.y - currentY;
  double targetAngle = math.atan2(dx, -dy);
  double currentHeading = state.heading;
  double diff = targetAngle - currentHeading;
  if (diff > math.pi) diff -= 2 * math.pi;
  if (diff < -math.pi) diff += 2 * math.pi;
  double diffDeg = diff * 180 / math.pi;

  String msg;
  IconData icon;
  String? imagePath; // [New]

  if (diffDeg.abs() < 25) {
    msg = "직진하세요";
    icon = Icons.arrow_upward_rounded;
    imagePath = 'assets/icons/guide_tile/guide_straight.png'; // [New]
  } else if (diffDeg > 0) {
    msg = "우회전하세요";
    icon = Icons.turn_right_rounded;
    imagePath = 'assets/icons/guide_tile/guide_right.png'; // [New]
  } else {
    msg = "좌회전하세요";
    icon = Icons.turn_left_rounded;
    imagePath = 'assets/icons/guide_tile/guide_left.png'; // [New]
  }

  // 목적지 근처 도달 시
  if (targetVertex.id == end.vertexId) {
    double dist = math.sqrt(math.pow(dx, 2) + math.pow(dy, 2));
    if (dist < 10.0) {
      msg = "목적지가 바로 앞입니다";
      icon = Icons.flag;
      imagePath = null; // 도착 아이콘은 기본 Flag Icon 사용 (PNG가 있다면 경로 입력)
    }
  }

  return GuidanceInfo(
    message: msg,
    icon: icon,
    iconColor: AppColors.primary,
    imagePath: imagePath, // [New]
  );
}
