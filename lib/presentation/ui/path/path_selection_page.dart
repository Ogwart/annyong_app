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

  // 지도 조작을 위한 컨트롤러
  final TransformationController _transformationController =
      TransformationController();

  // 지도가 초기화되었는지 여부
  bool _isMapInitialized = false;
  // 현재 보고 있는 목적지 ID (변경 감지용)
  int? _currentDestinationId;

  @override
  void initState() {
    super.initState();
    // 마커 위치 동기화를 위해 리스너 등록
    _transformationController.addListener(() {
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFromState();
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
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

      // 목적지가 변경되었다면 지도 초기화 플래그 리셋
      if (pathState.destination?.id != _currentDestinationId) {
        _currentDestinationId = pathState.destination?.id;
        _isMapInitialized = false;
      }
    });
  }

  Future<void> _selectLocation(
    SearchMode searchMode, {
    int? waypointIndex,
  }) async {
    final result = await context.push<Poi>('/home/search', extra: searchMode);

    if (result == null) return;

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

  void _addWaypoint() {
    if (_waypoints.length >= 2) return;
    setState(() {
      _waypoints.add(null);
    });
  }

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

  void _handleFindPath() {
    debugPrint('----------- [_handleFindPath Start] -----------');
    final pathState = ref.read(pathSelectionProvider);
    final Poi? startPoi = pathState.departure;
    final Poi? endPoi = pathState.destination;

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
      _isMapInitialized = false; // 리셋 시 지도 위치도 초기화 가능하도록
    });
    ref.read(pathSelectionProvider.notifier).resetPath();
  }

  bool get _isFindPathEnabled {
    return _departure != null && _destination != null;
  }

  // 지도를 목적지 중심으로 이동시키는 함수
  void _centerMapOnPoi(Poi poi, Size containerSize) {
    if (containerSize.width == 0 || containerSize.height == 0) return;

    final buildingName = MapUtilFunctions.getBuildingName(poi.buildingId);
    final floorString = "${poi.floor}F";

    // 1. 원본 이미지 크기 (1x)
    final baseOriginalSize = MapUtilFunctions.getImageOriginalSize(
      buildingName,
      floorString,
      '1x',
    );

    // 2. 컨테이너에 맞춘 화면상 이미지 크기
    final displayedImageSize = MapUtilFunctions.getDisplayedImageSize(
      containerSize,
      baseOriginalSize,
    );

    // 3. 스케일 비율 (원본 -> 화면 표시 크기)
    final scaleX = displayedImageSize.width / baseOriginalSize.width;
    final scaleY = displayedImageSize.height / baseOriginalSize.height;

    // 4. 이미지가 화면 중앙에 정렬되면서 생긴 여백(Offset) 계산
    final imageOffsetX = (containerSize.width - displayedImageSize.width) / 2;
    final imageOffsetY = (containerSize.height - displayedImageSize.height) / 2;

    // 5. 목표 줌 레벨 (기본 3배 확대)
    const double targetZoom = 3.0;

    // 6. 화면 중앙으로 오게 하기 위한 이동 거리(Translation) 계산
    // POI의 화면상 좌표: (poi.x * scaleX) + imageOffsetX
    // 중앙 정렬 공식: (ContainerCenter) - (TargetPoint * Zoom)
    final targetX =
        (containerSize.width / 2) -
        ((poi.xCoord * scaleX + imageOffsetX) * targetZoom);
    final targetY =
        (containerSize.height / 2) -
        ((poi.yCoord * scaleY + imageOffsetY) * targetZoom);

    // 7. Matrix 적용
    final targetMatrix = Matrix4.identity()
      ..translate(targetX, targetY)
      ..scale(targetZoom);

    _transformationController.value = targetMatrix;
    _isMapInitialized = true;
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
            // 지도 미리보기 영역
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.grey200, // 배경색
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Builder(
                  builder: (context) {
                    final pathState = ref.watch(pathSelectionProvider);
                    final endPoi = pathState.destination;

                    // 목적지가 없을 경우 안내 문구 표시
                    if (endPoi == null) {
                      return const Center(
                        child: Text(
                          '목적지를 선택하면\n지도에서 위치를 확인할 수 있어요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.grey400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }

                    // 목적지 기준 지도 정보
                    final buildingName = MapUtilFunctions.getBuildingName(
                      endPoi.buildingId,
                    );
                    final floorString = "${endPoi.floor}F";
                    // 미리보기라서 확대 많이 안할거라 1배율 이미지 사용
                    final imagePath = MapUtilFunctions.getImagePath(
                      buildingName,
                      floorString,
                      '1x',
                    );

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final containerSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );

                          // 초기화가 안 되었을 때만 위치 중앙 정렬 실행
                          if (!_isMapInitialized) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _centerMapOnPoi(endPoi, containerSize);
                            });
                          }

                          // 1. 원본 이미지 크기
                          final baseOriginalSize =
                              MapUtilFunctions.getImageOriginalSize(
                                buildingName,
                                floorString,
                                '1x',
                              );

                          // 2. 화면 표시 크기
                          final displayedImageSize =
                              MapUtilFunctions.getDisplayedImageSize(
                                containerSize,
                                baseOriginalSize,
                              );

                          // 3. 스케일 및 오프셋 계산 (마커 위치 계산용)
                          final scaleX =
                              displayedImageSize.width / baseOriginalSize.width;
                          final scaleY =
                              displayedImageSize.height /
                              baseOriginalSize.height;
                          final imageOffsetX =
                              (containerSize.width - displayedImageSize.width) /
                              2;
                          final imageOffsetY =
                              (containerSize.height -
                                  displayedImageSize.height) /
                              2;

                          return Stack(
                            children: [
                              // InteractiveViewer: 지도 확대/축소/이동
                              Positioned.fill(
                                child: InteractiveViewer(
                                  transformationController:
                                      _transformationController,
                                  boundaryMargin: const EdgeInsets.all(500),
                                  minScale: 1.0,
                                  maxScale: 6.0,
                                  panEnabled: true,
                                  scaleEnabled: true,
                                  child: Image.asset(
                                    imagePath,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              // 마커 표시
                              Builder(
                                builder: (context) {
                                  // 현재 변환 행렬
                                  final transformation =
                                      _transformationController.value;

                                  // 초기 화면상 좌표 (줌 1배 기준)
                                  final initialScreenX =
                                      endPoi.xCoord * scaleX + imageOffsetX;
                                  final initialScreenY =
                                      endPoi.yCoord * scaleY + imageOffsetY;

                                  // 변환 행렬 적용 (확대/이동 후 좌표)
                                  final transformedX =
                                      transformation.storage[0] *
                                          initialScreenX +
                                      transformation.storage[4] *
                                          initialScreenY +
                                      transformation.storage[12];
                                  final transformedY =
                                      transformation.storage[1] *
                                          initialScreenX +
                                      transformation.storage[5] *
                                          initialScreenY +
                                      transformation.storage[13];

                                  // 마커 위치 보정
                                  final markerOffset =
                                      MapUtilFunctions.markerOffset;

                                  return Positioned(
                                    left: transformedX - 12 + markerOffset.dx,
                                    top: transformedY - 24 + markerOffset.dy,
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 24,
                                        ),
                                        // POI 이름 라벨 (선택 사항)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: AppColors.grey300,
                                              width: 0.5,
                                            ),
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
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
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
