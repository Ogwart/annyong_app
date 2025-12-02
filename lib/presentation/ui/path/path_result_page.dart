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

  // 현재 보고 있는 건물과 층 상태
  late String _currentBuilding;
  late String _currentFloor;

  @override
  void initState() {
    super.initState();
    // 초기화 기준: 출발지의 건물/층으로 설정
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
      '/home/pathSelection/pathNavi',
      extra: {
        'start': widget.start,
        'end': widget.end,
        'waypoints': widget.waypoints,
      },
    );
  }

  // 건물 변경 (순환)
  void _cycleBuildings(Set<String> involvedBuildings) {
    if (involvedBuildings.isEmpty) return;

    setState(() {
      final buildingList = involvedBuildings.toList();
      final currentIndex = buildingList.indexOf(_currentBuilding);
      final nextIndex = (currentIndex + 1) % buildingList.length;

      _currentBuilding = buildingList[nextIndex];
      _currentFloor = '1F'; // 건물 변경 시 1층으로 초기화

      // 맵 배율/위치 초기화 (선택 사항)
      _transformationController.value = Matrix4.identity();
    });
  }

  // 층 변경
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
            // 1. 경로 탐색 및 데이터 준비
            final List<int> visitOrder = [
              widget.start.vertexId ?? -1,
              ...widget.waypoints.map((e) => e.vertexId ?? -1),
              widget.end.vertexId ?? -1,
            ];

            if (visitOrder.contains(-1)) {
              return const Center(child: Text("유효하지 않은 위치 정보가 있습니다."));
            }

            // 경로 탐색
            final result = pathFinder.findPathWithWaypoints(visitOrder);

            if (result == null || result.path.isEmpty) {
              return const Center(child: Text('경로를 찾을 수 없습니다'));
            }

            // 경로 정보 생성
            final jsonResult = PathDescriptionBuilder().build(
              pathFinder,
              result.path,
              result.totalCost,
            );
            final double totalCost = jsonResult['total_cost'] ?? 0.0;

            // 2. 경로에 포함된 모든 POI 및 건물 분석
            final allPois = [widget.start, ...widget.waypoints, widget.end];
            final involvedBuildings = allPois
                .map((p) => MapUtilFunctions.getBuildingName(p.buildingId))
                .toSet();

            // 3. 현재 뷰 설정 (상태 변수 사용)
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

            // 4. 현재 건물/층에 있는 마커 필터링
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
                // ------------------ 요약 정보 ------------------
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CostCard(
                    departure: widget.start.name,
                    destination: widget.end.name,
                    totalCost: totalCost,
                    waypoints: widget.waypoints,
                  ),
                ),

                // ------------------ 지도 미리보기 영역 ------------------
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.grey200, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(2, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
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
                            displayedImageSize.width / baseOriginalSize.width;
                        final scaleY =
                            displayedImageSize.height / baseOriginalSize.height;
                        final imageOffsetX =
                            (containerSize.width - displayedImageSize.width) /
                            2;
                        final imageOffsetY =
                            (containerSize.height - displayedImageSize.height) /
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
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // 지도 확대 축소와 별개로 마커 크기는 일정하도록 마커 오버레이
                            ...markersToShow.map((markerData) {
                              final Poi poi = markerData['poi'];
                              final String type = markerData['type'];
                              final String label = markerData['label'];

                              // 1. 현재 줌 레벨 확인
                              final currentMatrix =
                                  _transformationController.value;
                              final currentZoom = currentMatrix
                                  .getMaxScaleOnAxis();

                              // 2. 화면 좌표 계산
                              // (POI 좌표 -> 표시 이미지 좌표 -> 현재 줌/이동 적용된 화면 좌표)
                              final localX = poi.xCoord * scaleX + imageOffsetX;
                              final localY = poi.yCoord * scaleY + imageOffsetY;

                              final screenX =
                                  currentMatrix.storage[0] * localX +
                                  currentMatrix.storage[4] * localY +
                                  currentMatrix.storage[12];
                              final screenY =
                                  currentMatrix.storage[1] * localX +
                                  currentMatrix.storage[5] * localY +
                                  currentMatrix.storage[13];

                              // 3. 아이콘 선택
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
                              // 2배율 이상일 때만 마커 하단에 설명 텍스트 표시
                              final bool showLabel = currentZoom >= 2;

                              return Positioned(
                                left: screenX - (iconSize / 2),
                                top: screenY - (iconSize / 2),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 마커 아이콘 + 그림자
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
                                    // 라벨 텍스트
                                    if (showLabel)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Stack(
                                          children: [
                                            // 텍스트 외곽선 (Stroke)
                                            Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                foreground: Paint()
                                                  ..style = PaintingStyle.stroke
                                                  ..strokeWidth = 3
                                                  ..color = Colors.white,
                                              ),
                                            ),
                                            // 텍스트 본문 (Fill)
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

                            // 건물 전환 버튼: 경로에 포함된 건물이 2개 이상일 때만 표시
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
                                      color: AppColors.grey200,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
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

                            // 층 이동 버튼: 해당 층에 POI가 있으면 뱃지 표시
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children:
                                    MapUtilFunctions.getAvailableFloors(
                                      _currentBuilding,
                                    ).map((floor) {
                                      // 뱃지 조건 확인
                                      final bool hasPointOnThisFloor = allPois
                                          .any((poi) {
                                            return poi.buildingId ==
                                                    currentBuildingId &&
                                                '${poi.floor}F' == floor;
                                          });

                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.topRight,
                                          children: [
                                            FloorButton(
                                              floor: floor,
                                              isSelected:
                                                  _currentFloor == floor,
                                              onTap: () => _changeFloor(floor),
                                            ),
                                            // 빨간 뱃지
                                            if (hasPointOnThisFloor)
                                              Positioned(
                                                top: 6,
                                                right: 6,
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.warning,
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
                ),

                // ------------------ 길안내 시작 버튼 ------------------
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _onStartNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
