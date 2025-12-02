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

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  /// buildingId를 건물 이름으로 변환
  String _getBuildingName(int buildingId) {
    switch (buildingId) {
      case 1:
      case 2:
        return '5호관';
      case 3:
        return '하이테크관';
      default:
        return '5호관';
    }
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

  @override
  Widget build(BuildContext context) {
    final pathfinderAsync = ref.watch(pathFinderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('경로 미리보기')),
      body: SafeArea(
        child: pathfinderAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('오류 발생', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          data: (pathFinder) {
            // 방문해야 할 모든 지점의 Vertex ID를 순서대로 리스트화
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

            // 현재 보여줄 건물/층 정보 (출발지 기준)
            final buildingName = _getBuildingName(widget.start.buildingId);
            final floorString = '${widget.start.floor}F';
            final int currentBuildingId = widget.start.buildingId;
            final int currentFloor = widget.start.floor;

            // 지도 이미지 경로
            final mapImagePath = MapUtilFunctions.getImagePath(
              buildingName,
              floorString,
              '2x',
            );

            // 마커 데이터 구성
            final List<Map<String, dynamic>> markersToShow = [];

            // 1. 출발지
            if (widget.start.buildingId == currentBuildingId &&
                widget.start.floor == currentFloor) {
              markersToShow.add({
                'poi': widget.start,
                'type': 'start',
                'label': '출발지',
              });
            }
            // 2. 경유지
            for (int i = 0; i < widget.waypoints.length; i++) {
              final wp = widget.waypoints[i];
              if (wp.buildingId == currentBuildingId &&
                  wp.floor == currentFloor) {
                markersToShow.add({
                  'poi': wp,
                  'type': 'waypoint',
                  'label': '경유지${i + 1}',
                });
              }
            }
            // 3. 도착지
            if (widget.end.buildingId == currentBuildingId &&
                widget.end.floor == currentFloor) {
              markersToShow.add({
                'poi': widget.end,
                'type': 'end',
                'label': '목적지',
              });
            }

            return Column(
              children: [
                // ------------------ 요약 정보 카드 ------------------
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CostCard(
                    departure: widget.start.name,
                    destination: widget.end.name,
                    totalCost: totalCost,
                    waypoints: widget.waypoints,
                  ),
                ),

                // ------------------ 지도 미리보기 ------------------
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.grey200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final containerSize = constraints.biggest;
                        final baseOriginalSize =
                            MapUtilFunctions.getImageOriginalSize(
                              buildingName,
                              floorString,
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
