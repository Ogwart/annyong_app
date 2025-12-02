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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';

class PathSelectionPage extends ConsumerStatefulWidget {
  const PathSelectionPage({super.key});

  @override
  ConsumerState<PathSelectionPage> createState() => _PathSelectionPageState();
}

class _PathSelectionPageState extends ConsumerState<PathSelectionPage>
    with SingleTickerProviderStateMixin {
  String? _departure;
  String? _destination;
  final List<String?> _waypoints = [];

  // [상태 추가] 현재 사용자가 보고 있는 건물 및 층 (수동 조작용)
  String _currentBuilding = '5호관';
  String _currentFloor = '1F';

  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _mapAnimationController;
  Animation<Matrix4>? _mapAnimation;

  Size? _mapContainerSize;
  Poi? _focusedPoi;
  int? _lastCenteredPoiId;
  int? _currentBuildingId;

  @override
  void initState() {
    super.initState();
    // 마커 위치 동기화를 위해 리스너 등록
    _transformationController.addListener(() {
      if (mounted) setState(() {});
    });

    _mapAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _mapAnimationController.addListener(() {
      if (_mapAnimation != null) {
        _transformationController.value = _mapAnimation!.value;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFromState();
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _mapAnimationController.dispose();
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
    });
  }

  Future<void> _selectLocation(
    SearchMode searchMode, {
    int? waypointIndex,
  }) async {
    final result = await context.push<Poi>(
      '/home/search',
      extra: {'searchMode': searchMode, 'returnResult': true},
    );
    if (result == null) return;

    final notifier = ref.read(pathSelectionProvider.notifier);
    switch (searchMode) {
      case SearchMode.departure:
        notifier.setDeparture(result);
        break;
      case SearchMode.destination:
        notifier.setDestination(result);
        break;
      case SearchMode.waypoint1:
        notifier.setWaypoint1(result);
        break;
      case SearchMode.waypoint2:
        notifier.setWaypoint2(result);
        break;
      case SearchMode.normal:
        break;
    }

    // 가장 최근에 선택되었던 POI의 종류에 맞는 마커가 지도 중앙에 올 수 있게 _focusedPoi 업데이트
    // 지도 수동 조작 시 엉뚱한 건물로 튀는 것을 막기 위해 _currentBuilding, _currentFloor도 함께 동기화
    // 실제 이동은 build() 메서드의 LayoutBuilder가 감지하여 수행
    setState(() {
      _focusedPoi = result;
      _currentBuilding = MapUtilFunctions.getBuildingName(result.buildingId);
      _currentFloor = '${result.floor}F';
    });
  }

  // 경로에 포함된 건물들 사이만 순환할 수 있도록 리스트화하는 함수
  void _cycleBuildings(Set<String> involvedBuildings) {
    if (involvedBuildings.isEmpty) return;

    setState(() {
      _focusedPoi = null; // 수동 조작 시 포커스 해제

      // 현재 건물 목록 리스트화
      final buildingList = involvedBuildings.toList();
      // 현재 건물의 인덱스 찾기 (없으면 0)
      final currentIndex = buildingList.indexOf(_currentBuilding);

      // 다음 건물 인덱스 (순환)
      final nextIndex = (currentIndex + 1) % buildingList.length;
      _currentBuilding = buildingList[nextIndex];

      // 건물 변경 시 기본 1층으로 초기화
      _currentFloor = '1F';
    });
  }

  // 층 수동 조작 시 호출되는 함수들
  // 수동조작이 들어오면 _focusedPoi 기반으로 보여주던 것을 해제하고, 바로 전환
  void _changeFloor(String floor) {
    setState(() {
      // 수동 조작 시 현재 보고 있는 건물을 저장
      if (_focusedPoi != null) {
        _currentBuilding = MapUtilFunctions.getBuildingName(
          _focusedPoi!.buildingId,
        );
      }

      // 포커스 해제 및 층 변경
      _focusedPoi = null;
      _currentFloor = floor;
    });
  }

  void _moveMapToPoi(Poi poi) {
    if (_mapContainerSize == null) return;

    // 애니메이션 충돌 방지
    _mapAnimationController.stop();

    final buildingName = MapUtilFunctions.getBuildingName(poi.buildingId);
    final floorString = "${poi.floor}F";
    final baseOriginalSize = MapUtilFunctions.getImageOriginalSize(
      buildingName,
      floorString,
      '1x',
    );

    final displayedImageSize = MapUtilFunctions.getDisplayedImageSize(
      _mapContainerSize!,
      baseOriginalSize,
    );

    final scaleX = displayedImageSize.width / baseOriginalSize.width;
    final scaleY = displayedImageSize.height / baseOriginalSize.height;

    const double targetZoom = 3.0;

    final imageOffsetX =
        (_mapContainerSize!.width - displayedImageSize.width) / 2;
    final imageOffsetY =
        (_mapContainerSize!.height - displayedImageSize.height) / 2;

    final targetX =
        -((poi.xCoord * scaleX + imageOffsetX) * targetZoom -
            _mapContainerSize!.width / 2);
    final targetY =
        -((poi.yCoord * scaleY + imageOffsetY) * targetZoom -
            _mapContainerSize!.height / 2);

    final targetMatrix = Matrix4.identity()
      ..translate(targetX, targetY)
      ..scale(targetZoom);

    _mapAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: targetMatrix,
        ).animate(
          CurvedAnimation(
            parent: _mapAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    _mapAnimationController.forward(from: 0);
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
      // 상태 초기화
      _departure = null;
      _destination = null;
      _waypoints.clear();
      _focusedPoi = null;
      _lastCenteredPoiId = null;
      _currentBuildingId = null;

      // 초기화 시 기본 뷰로 복귀
      _currentBuilding = '5호관';
      _currentFloor = '1F';

      _mapAnimation =
          Matrix4Tween(
            begin: _transformationController.value,
            end: Matrix4.identity(),
          ).animate(
            CurvedAnimation(
              parent: _mapAnimationController,
              curve: Curves.easeInOut,
            ),
          );
      _mapAnimationController.forward(from: 0);
    });
    ref.read(pathSelectionProvider.notifier).resetPath();
  }

  bool get _isFindPathEnabled {
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
            // 지도 미리보기 영역
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
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
                child: Builder(
                  builder: (context) {
                    final pathState = ref.watch(pathSelectionProvider);

                    // 1. 현재 선택된 모든 POI를 수집하여 건물 분석
                    final allSelectedPois = [
                      pathState.departure,
                      pathState.waypoint1,
                      pathState.waypoint2,
                      pathState.destination,
                    ].whereType<Poi>().toList();

                    // 경로에 포함된 건물들의 이름 목록 (중복 제거)
                    final includeBuildingNames = allSelectedPois
                        .map(
                          (p) => MapUtilFunctions.getBuildingName(p.buildingId),
                        )
                        .toSet();

                    // 2. 지도에 표시할 건물/층 결정
                    String buildingToShow = _currentBuilding;
                    String floorToShow = _currentFloor;

                    if (_focusedPoi != null) {
                      buildingToShow = MapUtilFunctions.getBuildingName(
                        _focusedPoi!.buildingId,
                      );
                      floorToShow = '${_focusedPoi!.floor}F';
                    }

                    // 건물이 바뀌면 Matrix 초기화
                    final targetBuildingId = MapUtilFunctions.getBuildingId(
                      buildingToShow,
                    );
                    if (_currentBuildingId != targetBuildingId) {
                      _currentBuildingId = targetBuildingId;
                      _lastCenteredPoiId = null;
                      _transformationController.value = Matrix4.identity();
                    }

                    // 이미지 경로
                    final imagePath = MapUtilFunctions.getImagePath(
                      buildingToShow,
                      floorToShow,
                      '1x',
                    );

                    // 현재 보여지는 건물/층에 있는 마커만 필터링
                    final currentFloorNum = MapUtilFunctions.getFloorNumber(
                      floorToShow,
                    );
                    final poisToShow = allSelectedPois
                        .where(
                          (p) =>
                              p.buildingId == targetBuildingId &&
                              p.floor == currentFloorNum,
                        )
                        .toList();

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (_mapContainerSize != constraints.biggest) {
                                _mapContainerSize = constraints.biggest;
                              }

                              // _focusedPoi가 존재하고, 아직 센터링하지 않았다면 이동
                              if (_focusedPoi != null &&
                                  _mapContainerSize != null &&
                                  _focusedPoi!.id != _lastCenteredPoiId) {
                                _lastCenteredPoiId = _focusedPoi!.id;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _moveMapToPoi(_focusedPoi!);
                                });
                              }

                              final containerSize = constraints.biggest;
                              final baseOriginalSize =
                                  MapUtilFunctions.getImageOriginalSize(
                                    buildingToShow,
                                    floorToShow,
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
                                  Positioned.fill(
                                    child: InteractiveViewer(
                                      key: ValueKey(
                                        targetBuildingId,
                                      ), // 건물 변경 시 리셋
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
                                  ...poisToShow.map((poi) {
                                    final transformation =
                                        _transformationController.value;
                                    final initialScreenX =
                                        poi!.xCoord * scaleX + imageOffsetX;
                                    final initialScreenY =
                                        poi.yCoord * scaleY + imageOffsetY;
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

                                    String iconPath =
                                        'assets/icons/svg/stopover_marker.svg';
                                    if (poi.id == pathState.departure?.id) {
                                      iconPath =
                                          'assets/icons/svg/destination_marker.svg';
                                    } else if (poi.id ==
                                        pathState.destination?.id) {
                                      iconPath =
                                          'assets/icons/svg/arrival_marker.svg';
                                    }
                                    const double iconSize = 35.0;

                                    return Positioned(
                                      left: transformedX - (iconSize / 2),
                                      top: transformedY - (iconSize / 2),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: iconSize,
                                            height: iconSize,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: SvgPicture.asset(iconPath),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Stack(
                                              children: [
                                                Text(
                                                  poi.name,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    foreground: Paint()
                                                      ..style =
                                                          PaintingStyle.stroke
                                                      ..strokeWidth = 3
                                                      ..color = Colors.white,
                                                  ),
                                                ),
                                                Text(
                                                  poi.name,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
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

                          // 건물 전환 버튼: 건물간 이동일 때에만 랜더링(스위칭 아이콘 추가)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: Builder(
                              builder: (context) {
                                // 경로 상 건물이 2개 이상일 때만 버튼 활성화
                                final isMultiBuilding =
                                    includeBuildingNames.length > 1;

                                // 건물이 1개 이하라면 버튼을 아예 숨김
                                if (!isMultiBuilding) {
                                  return const SizedBox.shrink();
                                }

                                return GestureDetector(
                                  onTap: () =>
                                      _cycleBuildings(includeBuildingNames),
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
                                          buildingToShow,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: AppColors.text,
                                          ),
                                        ),
                                        // 여러 건물일 경우 전환 아이콘 표시
                                        if (isMultiBuilding) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.swap_horiz_rounded,
                                            size: 16,
                                            color: AppColors.text,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // 층 이동 버튼: 출발지/목적지/경유지가 포함된 층에는 빨간 뱃지 달기
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children:
                                  MapUtilFunctions.getAvailableFloors(
                                    buildingToShow,
                                  ).map((floor) {
                                    final bool hasPointOnThisFloor =
                                        [
                                          pathState.departure,
                                          pathState.waypoint1,
                                          pathState.waypoint2,
                                          pathState.destination,
                                        ].any((poi) {
                                          // POI가 존재하고, 현재 보고 있는 건물이며, 버튼의 층과 일치하는지 확인
                                          return poi != null &&
                                              poi.buildingId ==
                                                  targetBuildingId &&
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
                                            isSelected: floorToShow == floor,
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
                      ),
                    );
                  },
                ),
              ),
            ),

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
