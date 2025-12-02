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

  // 지도 조작 및 애니메이션을 위한 컨트롤러
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _mapAnimationController;
  Animation<Matrix4>? _mapAnimation;

  Size? _mapContainerSize;
  Poi? _focusedPoi; // 사용자가 방금 선택한 POI
  int? _lastCenteredPoiId; // 지도가 마지막으로 센터링(이동)을 완료한 POI ID
  int? _currentBuildingId; // 현재 로드된 건물 이미지 ID (이미지 교체 감지용)

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
    final result = await context.push<Poi>('/home/search', extra: searchMode);
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

    // 가장 최근에 선택되었던 POI의 종류에 맞는 마커가 지도 중앙에 올 수 있게 _focusedPoi만 업데이트
    // 실제 이동은 build() 메서드의 LayoutBuilder가 감지하여 수행
    setState(() {
      _focusedPoi = result;
    });
  }

  // 지도를 특정 POI로 부드럽게 이동시키는 함수
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
      _departure = null;
      _destination = null;
      _waypoints.clear();

      // 상태 초기화
      _focusedPoi = null;
      _lastCenteredPoiId = null;
      _currentBuildingId = null;

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
                  color: AppColors.grey200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Builder(
                  builder: (context) {
                    final pathState = ref.watch(pathSelectionProvider);

                    // 지도에 표시할 기준 POI (최근 선택한 곳 -> 목적지 -> 출발지 순)
                    final displayPoi =
                        _focusedPoi ??
                        pathState.destination ??
                        pathState.departure ??
                        pathState.waypoint1 ??
                        pathState.waypoint2;

                    // 목적지가 없을 경우 안내 문구 표시
                    if (displayPoi == null) {
                      return const Center(
                        child: Text(
                          '장소를 선택하면\n지도에서 위치를 확인할 수 있어요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.grey400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }

                    // 건물이 바뀌면 Matrix 초기화 (꼬임 방지)
                    if (_currentBuildingId != displayPoi.buildingId) {
                      _currentBuildingId = displayPoi.buildingId;
                      // 건물이 바뀌었으므로 지난 포커스 기록도 초기화하여 다시 센터링되게 함
                      _lastCenteredPoiId = null;
                      _transformationController.value = Matrix4.identity();
                    }

                    final buildingName = MapUtilFunctions.getBuildingName(
                      displayPoi.buildingId,
                    );
                    final floorString = "${displayPoi.floor}F";
                    final imagePath = MapUtilFunctions.getImagePath(
                      buildingName,
                      floorString,
                      '1x',
                    );

                    final poisToShow =
                        [
                              pathState.departure,
                              pathState.waypoint1,
                              pathState.waypoint2,
                              pathState.destination,
                            ]
                            .where(
                              (p) =>
                                  p != null &&
                                  p.buildingId == displayPoi.buildingId &&
                                  p.floor == displayPoi.floor,
                            )
                            .toList();

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // 1. 사이즈 저장
                          if (_mapContainerSize != constraints.biggest) {
                            _mapContainerSize = constraints.biggest;
                          }

                          // 2. 사용자가 지금 선택한 POI가 마지막으로 이동한 POI와 다르다면 무조건 이동 트리거 발생
                          if (_mapContainerSize != null &&
                              displayPoi.id != _lastCenteredPoiId) {
                            // 이동 처리했다고 기록 (무한루프 방지)
                            _lastCenteredPoiId = displayPoi.id;

                            // 화면이 다 그려진 후 애니메이션 실행
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _moveMapToPoi(displayPoi);
                            });
                          }

                          final containerSize = constraints.biggest;
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
                              Positioned.fill(
                                child: InteractiveViewer(
                                  // 건물 변경시에만 위젯 재생성
                                  key: ValueKey(displayPoi.buildingId),
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
                                // 마커 좌표 변환 및 표시 (기존 동일)
                                final transformation =
                                    _transformationController.value;
                                final initialScreenX =
                                    poi!.xCoord * scaleX + imageOffsetX;
                                final initialScreenY =
                                    poi.yCoord * scaleY + imageOffsetY;

                                final transformedX =
                                    transformation.storage[0] * initialScreenX +
                                    transformation.storage[4] * initialScreenY +
                                    transformation.storage[12];
                                final transformedY =
                                    transformation.storage[1] * initialScreenX +
                                    transformation.storage[5] * initialScreenY +
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
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          poi.name,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.text,
                                            shadows: [
                                              Shadow(
                                                offset: Offset(0, 0),
                                                blurRadius: 3,
                                                color: Colors.white,
                                              ),
                                            ],
                                          ),
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
