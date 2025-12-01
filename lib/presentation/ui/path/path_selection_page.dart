import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/ui/search/search_page.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/widgets/path_page/location_input_tile.dart';
import 'package:annyong/presentation/widgets/path_page/add_waypoint_button.dart';
import 'package:annyong/presentation/widgets/path_page/reset_button.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';

class PathSelectionPage extends ConsumerStatefulWidget {
  const PathSelectionPage({super.key});

  @override
  ConsumerState<PathSelectionPage> createState() => _PathSelectionPageState();
}

class _PathSelectionPageState extends ConsumerState<PathSelectionPage> {
  String? _departure;
  String? _destination;
  final List<String?> _waypoints = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFromState();
    });
  }

  void _updateFromState() {
    final pathState = ref.read(pathSelectionProvider);
    setState(() {
      _departure = pathState.departure?.name;
      _destination = pathState.destination?.name;
      _waypoints.clear();
      if (pathState.waypoint1 != null) {
        _waypoints.add(pathState.waypoint1!.name);
      }
      if (pathState.waypoint2 != null) {
        _waypoints.add(pathState.waypoint2!.name);
      }
    });
  }

  Future<void> _selectLocation(
    SearchMode searchMode, {
    int? waypointIndex,
  }) async {
    final result = await context.push<Poi>('/home/search', extra: searchMode);

    if (result == null) return;

    // Provider의 Notifier만 호출하고, 실제 상태 변경은
    // ref.listen이 감지하여 _updateFromState()를 실행하고 화면을 갱신하도록 함
    final notifier = ref.read(pathSelectionProvider.notifier);

    switch (searchMode) {
      case SearchMode.departure:
        notifier.setDeparture(result);
      case SearchMode.destination:
        notifier.setDestination(result);
      case SearchMode.waypoint1:
        notifier.setWaypoint1(result);
      case SearchMode.waypoint2:
        notifier.setWaypoint2(result);
      case SearchMode.normal:
        debugPrint('Normal mode selected, no action taken.');
        break;
    }
  }

  // 경유지 추가 로직
  void _addWaypoint() {
    if (_waypoints.length >= 2) return; // 경유지는 최대 2개까지만 허용
    setState(() {
      _waypoints.add(null);
    });
  }

  // 경유지 삭제 로직
  void _removeWaypoint(int index) {
    setState(() {
      _waypoints.removeAt(index);
      if (index == 0) {
        ref.read(pathSelectionProvider.notifier).setWaypoint1(null);
      } else if (index == 1) {
        ref.read(pathSelectionProvider.notifier).setWaypoint2(null);
      }
    });
  }

  // 스왑 로직은 오류가 많아서 보류
  // void _swapDepartureDestination() {
  //   // final temp = _departureController.text;
  //   // _departureController.text = _destinationController.text;
  //   // _destinationController.text = temp;
  //   // setState(() {});
  //   ref.read(pathSelectionProvider.notifier).swapDepartureDestination();
  // }

  // 길찾기 버튼 클릭 시 실행 로직
  void _handleFindPath() {
    debugPrint('----------- [_handleFindPath Start] -----------');
    final pathState = ref.read(pathSelectionProvider);
    final Poi? startPoi = pathState.departure;
    final Poi? endPoi = pathState.destination;

    // null이 아닌 경유지만 필터링하여 경유지 리스트 생성
    final List<Poi> activeWaypoints = [];
    if (pathState.waypoint1 != null) {
      activeWaypoints.add(pathState.waypoint1!);
    }
    if (pathState.waypoint2 != null) {
      activeWaypoints.add(pathState.waypoint2!);
    }

    debugPrint('출발지 POI: ${startPoi!.vertexId}');
    debugPrint('경유지 POI: ${activeWaypoints.map((e) => e.vertexId).toList()}');
    debugPrint('목적지 POI: ${endPoi!.vertexId}');
    debugPrint('----------- [_handleFindPath End] -----------');

    context.go(
      '/home/pathSelection/pathResult',
      extra: {'start': startPoi, 'end': endPoi, 'waypoints': activeWaypoints},
    );
  }

  void _reset() {
    setState(() {
      _departure = null;
      _destination = null;
      _waypoints.clear();
    });
    ref.read(pathSelectionProvider.notifier).resetPath();
  }

  bool get _isFindPathEnabled {
    // 목적지와 출발지가 모두 설정되어야 경로 검색 버튼이 활성화되도록
    return _departure != null && _destination != null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pathSelectionProvider, (previous, next) {
      _updateFromState();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('길찾기 검색')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // 출발지 입력 버튼
                  LocationInputTile(
                    label: '출발지',
                    value: _departure,
                    onTap: () => _selectLocation(SearchMode.departure),
                  ),
                  const SizedBox(height: 12),
                  // 경유지 입력 버튼들
                  for (var i = 0; i < _waypoints.length; i++) ...[
                    LocationInputTile(
                      label: '경유지 ${i + 1}',
                      value: _waypoints[i],
                      onTap: () => _selectLocation(
                        i == 0 ? SearchMode.waypoint1 : SearchMode.waypoint2,
                        waypointIndex: i,
                      ),
                      trailing: IconButton(
                        onPressed: () => _removeWaypoint(i),
                        icon: Icon(Icons.delete_outline, color: AppColors.text),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // 경유지 추가 버튼
                  if (_waypoints.length < 2) ...[
                    Center(child: AddWaypointButton(onTap: _addWaypoint)),
                    const SizedBox(height: 12),
                  ],
                  // 목적지 입력 버튼
                  LocationInputTile(
                    label: '목적지',
                    value: _destination,
                    onTap: () => _selectLocation(SearchMode.destination),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 초기화 버튼
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ResetButton(onTap: _reset),
              ),
            ),
            // 지도 미리보기
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Builder(
                  builder: (context) {
                    final pathState = ref.watch(pathSelectionProvider);
                    final startPoi = pathState.departure;
                    final endPoi = pathState.destination;

                    if (startPoi == null || endPoi == null) {
                      return const Center(
                        child: Text(
                          '가고 싶은 장소를 선택해주세요',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.grey400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }

                    // 목적지 기준 지도 표시
                    final buildingName = MapUtilFunctions.getBuildingName(
                      endPoi.buildingId,
                    );
                    final floorString = "${endPoi.floor}F";
                    final imagePath = MapUtilFunctions.getImagePath(
                      buildingName,
                      floorString,
                      '1x', // 미리보기이므로 1x 사용
                    );

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final containerSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );

                        const double zoomLevel = 3.0; // 확대 배율

                        // 1. 원본 이미지 크기 (1x)
                        final baseOriginalSize =
                            MapUtilFunctions.getImageOriginalSize(
                              buildingName,
                              floorString,
                              '1x',
                            );

                        // 2. 컨테이너에 맞춘 기본 스케일 (BoxFit.contain 기준)
                        final fitSize = MapUtilFunctions.getDisplayedImageSize(
                          containerSize,
                          baseOriginalSize,
                        );
                        final baseScale =
                            fitSize.width /
                            baseOriginalSize.width; // Aspect ratio maintained

                        // 3. 최종 스케일 (확대 적용)
                        final currentScale = baseScale * zoomLevel;

                        // 4. 확대된 이미지의 실제 크기
                        final scaledImageWidth =
                            baseOriginalSize.width * currentScale;
                        final scaledImageHeight =
                            baseOriginalSize.height * currentScale;

                        // 5. 이미지 내에서의 마커 위치 (Zoomed coordinates)
                        final markerImageX = endPoi.xCoord * currentScale;
                        final markerImageY = endPoi.yCoord * currentScale;

                        // 6. 이미지를 이동시켜 마커를 중앙에 위치시키기 위한 오프셋
                        final imageLeft =
                            (containerSize.width / 2) - markerImageX;
                        final imageTop =
                            (containerSize.height / 2) - markerImageY;

                        final markerOffset = MapUtilFunctions.markerOffset;

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              // 지도 이미지
                              Positioned(
                                left: imageLeft,
                                top: imageTop,
                                width: scaledImageWidth,
                                height: scaledImageHeight,
                                child: Image.asset(imagePath, fit: BoxFit.fill),
                              ),
                              // 목적지 마커 (컨테이너 중앙에 고정)
                              Positioned(
                                left:
                                    containerSize.width / 2 -
                                    12 +
                                    markerOffset.dx,
                                top:
                                    containerSize.height / 2 -
                                    24 +
                                    markerOffset.dy,
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                    // 선택사항: POI 이름 표시
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        endPoi.name,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            // 길찾기 실행 버튼
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isFindPathEnabled ? _handleFindPath : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFindPathEnabled
                        ? AppColors.primary
                        : AppColors.grey300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: AppColors.grey300,
                  ),
                  child: Text(
                    '길찾기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _isFindPathEnabled
                          ? Colors.white
                          : AppColors.grey400,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
