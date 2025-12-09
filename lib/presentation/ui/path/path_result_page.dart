import 'package:annyong/domain/usecases/path_finder.dart';
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'package:annyong/presentation/widgets/path_page/cost_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/providers/path_finder_provider.dart';
import 'package:annyong/domain/usecases/path_description_builder.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/path_page/cost_card.dart';
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

// 경로를 그리기 위한 페인터 클래스
class PathPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  PathPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // 1. 경로 생성 (하나의 Path로 연결)
    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        // 불연속적인 점(선분의 시작점이 이전 선분의 끝점과 다를 경우) 처리
        // points 구조: [p1, p2, p3, p4, ...] (이미 연결된 순서로 온다고 가정해야 함)
        // 하지만 호출부 로직을 보면 [시작1, 끝1, 시작2, 끝2] 형태로 들어옴
        // 따라서 i가 홀수일 때(끝점)는 lineTo, 짝수일 때(시작점)는 체크 필요

        // 호출부 로직: pathPoints.add(Offset(p1x, p1y)); pathPoints.add(Offset(p2x, p2y));
        // 즉, i=0(시작), i=1(끝), i=2(시작), i=3(끝) ...

        if (i % 2 == 0) {
          // 새로운 선분의 시작점
          // 이전 선분의 끝점(points[i-1])과 현재 시작점(points[i])이 같으면 이어그리기(아무것도 안 함, 다음 루프에서 lineTo로 이어짐)
          // 다르면 끊어서 이동
          if (points[i] != points[i - 1]) {
            path.moveTo(points[i].dx, points[i].dy);
          }
        } else {
          // 선분의 끝점
          path.lineTo(points[i].dx, points[i].dy);
        }
      }
    }

    // 2. 테두리 그리기 (흰색, 더 두껍게)
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, borderPaint);

    // 3. 경로 그리기 (기존 색상, 기존 두께)
    final pathPaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, pathPaint);

    // 화살표
    final arrowPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.fill;

    // 경로를 따라가며 일정 간격마다 화살표 배치
    for (final metric in path.computeMetrics()) {
      const double dashWidth = 20.0; // 화살표 간격
      const double arrowSize = 1.5; // 화살표 크기

      double distance = dashWidth;
      while (distance < metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          final position = tangent.position;
          final angle = -tangent.angle; // Canvas 좌표계와 atan2 방향 고려

          canvas.save();
          canvas.translate(position.dx, position.dy);
          canvas.rotate(angle); // 진행 방향으로 회전

          // 화살표 모양 그리기 (삼각형)
          final arrowPath = Path()
            ..moveTo(-arrowSize, -arrowSize) // 왼쪽 위
            ..lineTo(arrowSize, 0) // 오른쪽 중앙 (화살표 끝)
            ..lineTo(-arrowSize, arrowSize) // 왼쪽 아래
            ..close();

          canvas.drawPath(arrowPath, arrowPaint);
          canvas.restore();
        }
        distance += 40.0; // 다음 화살표까지 거리
      }
    }
  }

  @override
  bool shouldRepaint(covariant PathPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

class PathResultPage extends ConsumerStatefulWidget {
  final Poi start;
  final Poi end;
  final List<Poi> waypoints;

  const PathResultPage({
    super.key,
    required this.start,
    required this.end,
    this.waypoints = const [],
  });

  @override
  ConsumerState<PathResultPage> createState() => _PathResultPageState();
}

class _PathResultPageState extends ConsumerState<PathResultPage> {
  final TransformationController _transformationController =
      TransformationController();

  late String _currentBuilding;
  late String _currentFloor;
  PathResult? _cachedPathResult; // 경로 탐색 결과 캐싱용

  @override
  void initState() {
    super.initState();
    _currentBuilding = MapUtilFunctions.getBuildingName(
      widget.start.buildingId,
    );
    _currentFloor = '${widget.start.floor}F';

    _transformationController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _onStartNavigation() {
    // 실제 네비게이션 화면(PathNaviPage)으로 이동
    context.push(
      '/home/pathSelection/pathNavi',
      extra: {
        'start': widget.start,
        'end': widget.end,
        'waypoints': widget.waypoints,
        // 캐싱된 결과가 있다면 함께 전달
        'preCalculatedPath': _cachedPathResult?.path,
        'preCalculatedCost': _cachedPathResult?.totalCost,
      },
    );
  }

  void _cycleBuildings(Set<String> involvedBuildings) {
    if (involvedBuildings.isEmpty) return;

    setState(() {
      final buildingList = involvedBuildings.toList();
      final currentIndex = buildingList.indexOf(_currentBuilding);
      final nextIndex = (currentIndex + 1) % buildingList.length;

      _currentBuilding = buildingList[nextIndex];
      _currentFloor = '1F';
      _transformationController.value = Matrix4.identity();
    });
  }

  void _changeFloor(String floor) {
    setState(() {
      _currentFloor = floor;
    });
  }

  // 정점 ID가 현재 맵(건물/층)에 포함되는지 확인하는 헬퍼 함수
  bool _isVertexOnCurrentMap(int vertexId) {
    if (_currentBuilding == '5호관') {
      if (_currentFloor == '1F') {
        return vertexId < 500;
      } else if (_currentFloor == '2F') {
        return vertexId >= 500 && vertexId < 1000;
      }
    } else if (_currentBuilding == '60주년' || _currentBuilding == '60주년기념관') {
      return vertexId >= 1000;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final pathfinderAsync = ref.watch(pathFinderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('경로 탐색 결과')),
      body: SafeArea(
        child: pathfinderAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('오류 발생: $err')),
          data: (pathFinder) {
            // 경로 계산 로직
            // 캐싱된 결과가 없을 때에만 경로 탐색 실행
            if (_cachedPathResult == null) {
              final List<int> visitOrder = [
                widget.start.vertexId ?? -1,
                ...widget.waypoints.map((e) => e.vertexId ?? -1),
                widget.end.vertexId ?? -1,
              ];

              if (visitOrder.contains(-1)) {
                return const Center(child: Text("유효하지 않은 위치 정보가 있습니다."));
              }

              // 결과 저장
              _cachedPathResult = pathFinder.findPathWithWaypoints(visitOrder);
            }

            final result = _cachedPathResult;
            if (result == null || result.path.isEmpty) {
              return const Center(child: Text('경로를 찾을 수 없습니다'));
            }

            final jsonResult = PathDescriptionBuilder().build(
              pathFinder,
              result.path,
              result.totalCost,
            );
            final double totalCost = jsonResult['total_cost'] ?? 0.0;

            final allPois = [widget.start, ...widget.waypoints, widget.end];
            final involvedBuildings = allPois
                .map((p) => MapUtilFunctions.getBuildingName(p.buildingId))
                .toSet();

            final currentBuildingId = MapUtilFunctions.getBuildingId(
              _currentBuilding,
            );
            final currentFloorNum = MapUtilFunctions.getFloorNumber(
              _currentFloor,
            );

            final mapImagePath = MapUtilFunctions.getImagePath(
              _currentBuilding,
              _currentFloor,
              '2x',
            );

            final List<Map<String, dynamic>> markersToShow = [];
            void addMarkerIfMatch(Poi poi, String type, String label) {
              if (poi.buildingId == currentBuildingId &&
                  poi.floor == currentFloorNum) {
                markersToShow.add({'poi': poi, 'type': type, 'label': label});
              }
            }

            addMarkerIfMatch(widget.start, 'start', '출발지');
            for (int i = 0; i < widget.waypoints.length; i++) {
              addMarkerIfMatch(widget.waypoints[i], 'waypoint', '경유지${i + 1}');
            }
            addMarkerIfMatch(widget.end, 'end', '목적지');

            return Column(
              children: [
                // 1. Stack 영역: 지도 + (오버레이된) CostCard
                Expanded(
                  child: Stack(
                    children: [
                      // --------------- 지도 영역 ---------------
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.white,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final containerSize = constraints.biggest;
                            final baseOriginalSize =
                                MapUtilFunctions.getImageOriginalSize(
                                  _currentBuilding,
                                  _currentFloor,
                                  '1x',
                                );

                            final displayedImageSize =
                                MapUtilFunctions.getDisplayedImageSize(
                                  containerSize,
                                  baseOriginalSize,
                                );

                            final scaleX =
                                displayedImageSize.width /
                                baseOriginalSize.width;
                            final scaleY =
                                displayedImageSize.height /
                                baseOriginalSize.height;
                            final imageOffsetX =
                                (containerSize.width -
                                    displayedImageSize.width) /
                                2;
                            final imageOffsetY =
                                (containerSize.height -
                                    displayedImageSize.height) /
                                2;

                            // 경로 좌표 계산 로직
                            final List<Offset> pathPoints = [];

                            if (result.path.length > 1) {
                              for (int i = 0; i < result.path.length - 1; i++) {
                                final int fromId = result.path[i];
                                final int toId = result.path[i + 1];
                                final v1 = pathFinder.vertices[fromId];
                                final v2 = pathFinder.vertices[toId];

                                // 두 정점이 모두 유효하고, 현재 보고 있는 층 지도 위에 있을 때만 선분 추가
                                if (v1 != null &&
                                    v2 != null &&
                                    _isVertexOnCurrentMap(fromId) &&
                                    _isVertexOnCurrentMap(toId)) {
                                  final p1x = v1.x * scaleX;
                                  final p1y = v1.y * scaleY;
                                  final p2x = v2.x * scaleX;
                                  final p2y = v2.y * scaleY;

                                  // 선분 (시작점, 끝점) 추가
                                  pathPoints.add(Offset(p1x, p1y));
                                  pathPoints.add(Offset(p2x, p2y));
                                }
                              }
                            }

                            return Stack(
                              children: [
                                // 지도 이미지 및 경로 그리기
                                Positioned.fill(
                                  child: InteractiveViewer(
                                    transformationController:
                                        _transformationController,
                                    minScale: 1.0,
                                    maxScale: 4.0,
                                    child: Center(
                                      child: SizedBox(
                                        width: displayedImageSize.width,
                                        height: displayedImageSize.height,
                                        child: Stack(
                                          children: [
                                            // 1. 지도 이미지
                                            Image.asset(
                                              mapImagePath,
                                              fit: BoxFit.contain,
                                              width: displayedImageSize.width,
                                              height: displayedImageSize.height,
                                            ),
                                            // 2. 경로 선 그리기
                                            IgnorePointer(
                                              child: CustomPaint(
                                                size: Size(
                                                  displayedImageSize.width,
                                                  displayedImageSize.height,
                                                ),
                                                painter: PathPainter(
                                                  points: pathPoints,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // 마커 오버레이
                                ...markersToShow.map((markerData) {
                                  final Poi poi = markerData['poi'];
                                  final String type = markerData['type'];
                                  final String label = markerData['label'];

                                  final currentMatrix =
                                      _transformationController.value;
                                  final currentZoom = currentMatrix
                                      .getMaxScaleOnAxis();

                                  final localX =
                                      poi.xCoord * scaleX + imageOffsetX;
                                  final localY =
                                      poi.yCoord * scaleY + imageOffsetY;

                                  final screenX =
                                      currentMatrix.storage[0] * localX +
                                      currentMatrix.storage[4] * localY +
                                      currentMatrix.storage[12];
                                  final screenY =
                                      currentMatrix.storage[1] * localX +
                                      currentMatrix.storage[5] * localY +
                                      currentMatrix.storage[13];

                                  String iconPath;
                                  if (type == 'start') {
                                    iconPath =
                                        'assets/icons/svg/departure_marker.svg';
                                  } else if (type == 'end') {
                                    iconPath =
                                        'assets/icons/svg/destination_marker.svg';
                                  } else {
                                    iconPath =
                                        'assets/icons/svg/stopover_marker.svg';
                                  }

                                  const double iconSize = 35.0;
                                  final bool showLabel = currentZoom >= 2;

                                  return Positioned(
                                    left: screenX - (iconSize / 2),
                                    top: screenY - (iconSize / 2),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: iconSize,
                                          height: iconSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withAlpha(
                                                  20,
                                                ),
                                                blurRadius: 6,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: SvgPicture.asset(iconPath),
                                        ),
                                        if (showLabel)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Stack(
                                              children: [
                                                Text(
                                                  label,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    foreground: Paint()
                                                      ..style =
                                                          PaintingStyle.stroke
                                                      ..strokeWidth = 3
                                                      ..color = Colors.white,
                                                  ),
                                                ),
                                                Text(
                                                  label,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.text,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }),

                                // 건물 전환 버튼
                                if (involvedBuildings.length > 1)
                                  Positioned(
                                    bottom: 16,
                                    left: 16,
                                    child: GestureDetector(
                                      onTap: () =>
                                          _cycleBuildings(involvedBuildings),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(10),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _currentBuilding,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: AppColors.text,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.swap_horiz_rounded,
                                              size: 16,
                                              color: AppColors.text,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                // 층 이동 버튼
                                Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children:
                                        MapUtilFunctions.getAvailableFloors(
                                          _currentBuilding,
                                        ).map((floor) {
                                          final bool hasPointOnThisFloor =
                                              allPois.any((poi) {
                                                return poi.buildingId ==
                                                        currentBuildingId &&
                                                    '${poi.floor}F' == floor;
                                              });

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              alignment: Alignment.topRight,
                                              children: [
                                                FloorButton(
                                                  floor: floor,
                                                  isSelected:
                                                      _currentFloor == floor,
                                                  onTap: () =>
                                                      _changeFloor(floor),
                                                ),
                                                if (hasPointOnThisFloor)
                                                  Positioned(
                                                    top: 6,
                                                    right: 6,
                                                    child: Container(
                                                      width: 12,
                                                      height: 12,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            AppColors.warning,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // CostCard 오버레이
                      Positioned(
                        top: 24,
                        left: 20,
                        right: 20,
                        child: CostCard(
                          departure: widget.start.name,
                          destination: widget.end.name,
                          totalCost: totalCost,
                          waypoints: widget.waypoints,
                        ),
                      ),
                    ],
                  ),
                ),

                // 하단 버튼 영역
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(5),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _onStartNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '길안내 시작',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
