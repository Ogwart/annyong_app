import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'package:annyong/presentation/widgets/path_page/cost_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/providers/path_finder_provider.dart';
import 'package:annyong/domain/usecases/path_description_builder.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

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
    context.push(
      '/home/pathSelection/pathResult',
      extra: {
        'start': widget.start,
        'end': widget.end,
        'waypoints': widget.waypoints,
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
            final List<int> visitOrder = [
              widget.start.vertexId ?? -1,
              ...widget.waypoints.map((e) => e.vertexId ?? -1),
              widget.end.vertexId ?? -1,
            ];

            if (visitOrder.contains(-1)) {
              return const Center(child: Text("유효하지 않은 위치 정보가 있습니다."));
            }

            final result = pathFinder.findPathWithWaypoints(visitOrder);

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
                // 화면의 나머지 공간(버튼 제외)을 차지하며, CostCard가 지도 위에 뜸
                Expanded(
                  child: Stack(
                    children: [
                      // --------------- 지도 영역 ---------------
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.white, // 지도 배경색
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

                            return Stack(
                              children: [
                                // 지도 이미지
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
                                        child: Image.asset(
                                          mapImagePath,
                                          fit: BoxFit.contain,
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
                                                color: Colors.black.withOpacity(
                                                  0.2,
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
                                              color: Colors.black.withOpacity(
                                                0.1,
                                              ),
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

                      // --------------- CostCard 오버레이 ---------------
                      Positioned(
                        top: 24, // 상단 여백
                        left: 20, // 좌측 여백
                        right: 20, // 우측 여백
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

                // 2. 하단 버튼 영역
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
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
