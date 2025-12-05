//import 'dart:convert';
import 'dart:math' as math;
import 'package:annyong/domain/usecases/path_finder.dart';
import 'package:annyong/presentation/widgets/path_page/cost_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:annyong/presentation/util/get_building_name.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/providers/path_finder_provider.dart';
import 'package:annyong/domain/usecases/path_description_builder.dart';
import 'package:annyong/presentation/viewmodels/navigation_view_model.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/ui/path/path_result_page.dart';
import 'package:flutter_svg/svg.dart';
import 'package:vector_math/vector_math_64.dart' as math64;
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'package:go_router/go_router.dart';

class PathNaviPage extends ConsumerStatefulWidget {
  final Poi start;
  final Poi end;
  final List<Poi> waypoints;

  // 계산된 경로를 받는 파라미터
  final List<int>? preCalculatedPath;
  final double? preCalculatedCost;

  const PathNaviPage({
    super.key,
    required this.start,
    required this.end,
    this.waypoints = const [],
    this.preCalculatedPath,
    this.preCalculatedCost,
  });

  @override
  ConsumerState<PathNaviPage> createState() => _PathNaviPageState();
}

class RippleMarker extends StatefulWidget {
  const RippleMarker({super.key});

  @override
  State<RippleMarker> createState() => _RippleMarkerState();
}

class _RippleMarkerState extends State<RippleMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 60,
          height: 60,
          child: Center(
            child: Container(
              width: 60 * _controller.value, // 최대 크기 60
              height: 60 * _controller.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withAlpha(
                  ((1 - _controller.value) * 100).toInt(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PathNaviPageState extends ConsumerState<PathNaviPage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _mapAnimationController;
  Animation<Matrix4>? _mapAnimation;
  //Size? _mapContainerSize;
  bool _isMapInitialized = false;
  // 경로 탐색 결과 캐싱
  PathResult? _cachedPathResult;

  // 현재 보고 있는 건물과 층 상태
  late String _currentBuilding;
  late String _currentFloor;

  @override
  void initState() {
    super.initState();
    // 초기 상태 설정
    _currentBuilding = getBuildingName(widget.start.buildingId);
    _currentFloor = '${widget.start.floor}F';

    // 페이지 진입 시 길 안내 시작
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final navigationNotifier = ref.read(navigationViewModelProvider.notifier);
    //   // 출발 POI로 초기 위치 설정
    //   navigationNotifier.setInitialPositionFromPoi(widget.start);
    // });

    _mapAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _mapAnimationController.addListener(() {
      if (_mapAnimation != null) {
        _transformationController.value = _mapAnimation!.value;
      }
    });

    _transformationController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _mapAnimationController.dispose();
    // 페이지 종료 시 길 안내 종료 및 초기화
    // 위젯 빌드 중 상태 변경을 방지하기 위해 다음 프레임에 실행
    Future.microtask(() {
      try {
        final navigationNotifier = ref.read(
          navigationViewModelProvider.notifier,
        );
        navigationNotifier.stopNavigation();
      } catch (e) {
        // dispose 후 ref 접근 시 오류 무시
      }
    });
    super.dispose();
  }

  /// POI 마커를 조건에 맞게 생성하는 헬퍼 메서드
  Widget _buildPoiMarker({
    required Poi poi,
    required String type, // 'departure', 'destination', 'waypoint'
    required double scaleX,
    required double scaleY,
    required double imageOffsetX,
    required double imageOffsetY,
  }) {
    // 아이콘 및 색상 결정
    String iconPath;
    String label;

    if (type == 'departure') {
      iconPath = 'assets/icons/svg/departure_marker.svg';
      label = '출발지';
    } else if (type == 'destination') {
      iconPath = 'assets/icons/svg/destination_marker.svg';
      label = '목적지';
    } else {
      iconPath = 'assets/icons/svg/stopover_marker.svg';
      label = '경유지';
    }

    // 좌표 변환
    final localX = poi.xCoord * scaleX + imageOffsetX;
    final localY = poi.yCoord * scaleY + imageOffsetY;

    final currentMatrix = _transformationController.value;
    final screenX =
        currentMatrix.storage[0] * localX +
        currentMatrix.storage[4] * localY +
        currentMatrix.storage[12];
    final screenY =
        currentMatrix.storage[1] * localX +
        currentMatrix.storage[5] * localY +
        currentMatrix.storage[13];

    // 줌 레벨에 따른 라벨 표시 여부 (예: 2배 이상일 때 표시)
    final currentZoom = currentMatrix.getMaxScaleOnAxis();
    final bool showLabel = currentZoom >= 2.0;
    const double iconSize = 35.0;

    return Positioned(
      left: screenX - (iconSize / 2),
      top: screenY - (iconSize / 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 마커 아이콘
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2), // alpha 수정
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SvgPicture.asset(iconPath),
          ),
          // 라벨 (선택적 표시)
          if (showLabel)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Stack(
                children: [
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
  }

  // 초기 위치로 지도 이동
  void _animateToStart(
    Size containerSize,
    Size displayedImageSize,
    Size originalSize,
  ) {
    if (_isMapInitialized) return;

    // 1. 스케일 계산
    final scaleX = displayedImageSize.width / originalSize.width;
    final scaleY = displayedImageSize.height / originalSize.height;

    // 2. 이미지 오프셋 (중앙 정렬 보정)
    final imageOffsetX = (containerSize.width - displayedImageSize.width) / 2;
    final imageOffsetY = (containerSize.height - displayedImageSize.height) / 2;

    // 3. 목표 줌 레벨 설정
    const double targetZoom = 3.0;

    // 4. 목표 중심점 계산 (출발지 좌표 기준)
    // 이미지 내에서의 절대 좌표
    final targetX = widget.start.xCoord * scaleX + imageOffsetX;
    final targetY = widget.start.yCoord * scaleY + imageOffsetY;

    // 5. 화면 중앙에 위치시키기 위한 Translation 계산
    final translateX = (containerSize.width / 2) - (targetX * targetZoom);
    final translateY = (containerSize.height / 2) - (targetY * targetZoom);

    // 6. 목표 매트릭스 생성
    final targetMatrix = Matrix4.identity()
      ..translateByVector3(math64.Vector3(translateX, translateY, 0))
      ..scale(targetZoom);

    // 7. 애니메이션
    _mapAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: targetMatrix,
        ).animate(
          CurvedAnimation(
            parent: _mapAnimationController,
            curve: Curves.easeInOutCubic,
          ),
        );

    _mapAnimationController.forward(from: 0);
    _isMapInitialized = true;
  }

  // 건물 전환
  void _cycleBuildings(Set<String> involvedBuildings) {
    if (involvedBuildings.isEmpty) return;

    setState(() {
      final buildingList = involvedBuildings.toList();
      final currentIndex = buildingList.indexOf(_currentBuilding);
      final nextIndex = (currentIndex + 1) % buildingList.length;

      _currentBuilding = buildingList[nextIndex];
      _currentFloor = '1F';
      _transformationController.value = Matrix4.identity();
      // 건물 전환 시 애니메이션 초기화 (필요시)
      _isMapInitialized = false;
    });
  }

  // 층 전환
  void _changeFloor(String floor) {
    setState(() {
      _currentFloor = floor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pathfinderAsync = ref.watch(pathFinderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('길찾기 결과')),
      body: SafeArea(
        child: pathfinderAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
          ),
          data: (pathFinder) {
            // 캐싱된 경로가 없을 때
            if (_cachedPathResult == null) {
              // 1. 만약 이전 페이지에서 넘겨준 계산된 경로가 있다면 그걸 사용
              if (widget.preCalculatedPath != null &&
                  widget.preCalculatedCost != null) {
                _cachedPathResult = PathResult(
                  path: widget.preCalculatedPath!,
                  totalCost: widget.preCalculatedCost!,
                );
              }
              // 2. 없다면 직접 계산
              else {
                final List<int> visitOrder = [
                  widget.start.vertexId ?? -1,
                  ...widget.waypoints.map((e) => e.vertexId ?? -1),
                  widget.end.vertexId ?? -1,
                ];

                if (!visitOrder.contains(-1)) {
                  _cachedPathResult = pathFinder.findPathWithWaypoints(
                    visitOrder,
                  );
                }
              }

              // 경로 시작 지점으로 초기 위치 설정 (한번만 실행)
              final calculatedPath = _cachedPathResult;
              if (calculatedPath != null && calculatedPath.path.isNotEmpty) {
                final startVertexId = calculatedPath.path.first;
                final startVertex = pathFinder.vertices[startVertexId];

                if (startVertex != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref
                        .read(navigationViewModelProvider.notifier)
                        .setInitialPosition(
                          x: startVertex.x,
                          y: startVertex.y,
                          floor: widget.start.floor,
                        );
                  });
                }
              }
            }

            final result = _cachedPathResult;

            // 경로 못 찾았을 때 UI 처리
            if (result == null || result.path.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.route_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '경로를 찾을 수 없습니다',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '출발지: ${widget.start.name}\n도착지: ${widget.end.name}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }

            // JSON 결과 생성 및 출력
            final jsonResult = PathDescriptionBuilder().build(
              pathFinder,
              result.path,
              result.totalCost,
            );

            // 유효한 경로 찾았을 때 UI 렌더링
            final double totalCost = jsonResult['total_cost'] ?? 0.0;

            // 사용자의 현재 건물과 층 정보 가져오기
            final navigationState = ref.watch(navigationViewModelProvider);

            // 관련된 건물 목록 추출 (건물 전환 버튼용)
            final allPois = [widget.start, ...widget.waypoints, widget.end];
            final involvedBuildings = allPois
                .map((p) => getBuildingName(p.buildingId))
                .toSet();

            // 지도 이미지 경로 (2x 해상도 사용) - 현재 선택된 건물/층 기준
            final mapImagePath = MapUtilFunctions.getImagePath(
              _currentBuilding,
              _currentFloor,
              '2x',
            );

            return Column(
              children: [
                // ------------------출발, 경유, 도착, 총 비용------------------
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CostCard(
                    departure: widget.start.name,
                    destination: widget.end.name,
                    totalCost: totalCost,
                    waypoints: widget.waypoints,
                  ),
                ),
                // ------------------지도 및 사용자 위치------------------
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final containerSize = constraints.biggest;

                        // 1. 현재 보고 있는 지도의 건물 ID와 층수 계산
                        final int currentMapBuildingId =
                            MapUtilFunctions.getBuildingId(_currentBuilding);
                        final int currentMapFloorNum =
                            MapUtilFunctions.getFloorNumber(_currentFloor);

                        // 현재 보고 있는 지도의 건물 ID와 층수
                        final int currentBuildingId =
                            MapUtilFunctions.getBuildingId(_currentBuilding);
                        final int currentFloorNum =
                            MapUtilFunctions.getFloorNumber(_currentFloor);

                        // path_result_page에서는 '1x'를 기준으로 계산했음. 동일하게 맞춤
                        final calcOriginalSize =
                            MapUtilFunctions.getImageOriginalSize(
                              _currentBuilding,
                              _currentFloor,
                              '1x',
                            );

                        final displayedImageSize =
                            MapUtilFunctions.getDisplayedImageSize(
                              containerSize,
                              calcOriginalSize,
                            );

                        final scaleX =
                            displayedImageSize.width / calcOriginalSize.width;
                        final scaleY =
                            displayedImageSize.height / calcOriginalSize.height;
                        final imageOffsetX =
                            (containerSize.width - displayedImageSize.width) /
                            2;
                        final imageOffsetY =
                            (containerSize.height - displayedImageSize.height) /
                            2;

                        // 초기 진입 시 애니메이션 실행 (지도 초기화 안 됐을 때만)
                        if (!_isMapInitialized) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _animateToStart(
                              containerSize,
                              displayedImageSize,
                              calcOriginalSize,
                            );
                          });
                        }

                        // 경로 좌표 계산 로직 (path_result_page 복사)
                        final List<Offset> pathPoints = [];

                        if (result.path.length > 1) {
                          for (int i = 0; i < result.path.length - 1; i++) {
                            final int fromId = result.path[i];
                            final int toId = result.path[i + 1];
                            final v1 = pathFinder.vertices[fromId];
                            final v2 = pathFinder.vertices[toId];

                            // 현재 층에 해당하는지 확인
                            // 5호관 1층: 0~499, 2층: 500~999, 60주년 1층: 1000~
                            bool isVertexOnMap(int id) {
                              if (_currentBuilding == '5호관') {
                                if (_currentFloor == '1F') return id < 500;
                                if (_currentFloor == '2F') {
                                  return id >= 500 && id < 1000;
                                }
                              } else if (_currentBuilding.contains('60주년')) {
                                return id >= 1000;
                              }
                              return false;
                            }

                            if (v1 != null &&
                                v2 != null &&
                                isVertexOnMap(fromId) &&
                                isVertexOnMap(toId)) {
                              final p1x = v1.x * scaleX;
                              final p1y = v1.y * scaleY;
                              final p2x = v2.x * scaleX;
                              final p2y = v2.y * scaleY;

                              pathPoints.add(Offset(p1x, p1y));
                              pathPoints.add(Offset(p2x, p2y));
                            }
                          }
                        }

                        return Stack(
                          children: [
                            // InteractiveViewer로 감싼 지도 및 경로
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
                                        // 지도 이미지
                                        Image.asset(
                                          mapImagePath,
                                          fit: BoxFit.contain,
                                          width: displayedImageSize.width,
                                          height: displayedImageSize.height,
                                        ),
                                        // 경로 그리기
                                        IgnorePointer(
                                          child: CustomPaint(
                                            size: Size(
                                              displayedImageSize.width,
                                              displayedImageSize.height,
                                            ),
                                            painter: PathPainter(
                                              // path_result_page.dart에서 import됨
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

                            // 사용자 위치 마커 (InteractiveViewer 좌표 변환 적용)
                            navigationState.when(
                              data: (state) {
                                // 만약 사용자의 현재층/건물이 보고 있는 지도 층/건물과 다르다면 숨김
                                if (state.buildingId != currentMapBuildingId ||
                                    state.floor != currentMapFloorNum) {
                                  return const SizedBox.shrink();
                                }

                                double currentX = state.x;
                                double currentY = state.y;
                                int currentFloor = state.floor;

                                // 초기화되지 않은 좌표(0,0)인 경우 출발지 정보 사용
                                if (state.x == 0 && state.y == 0) {
                                  currentX = widget.start.xCoord;
                                  currentY = widget.start.yCoord;
                                  currentFloor = widget.start.floor;

                                  // 경로 시작점(Vertex)이 있으면 해당 위치 사용
                                  if (result.path.isNotEmpty) {
                                    final startVertex =
                                        pathFinder.vertices[result.path.first];
                                    if (startVertex != null) {
                                      currentX = startVertex.x;
                                      currentY = startVertex.y;
                                    }
                                  }
                                }

                                // 1. 층 확인
                                if (currentFloor != widget.start.floor) {
                                  return const SizedBox.shrink();
                                }

                                // 사용자 좌표 -> 화면 좌표 변환
                                // state.x, state.y는 원본 좌표계 기준이라 가정
                                // path_result_page와 동일하게 스케일 적용
                                // 단, 기존 코드에서 0.19를 곱하던 것은 하드코딩된 값이므로,
                                // 여기서는 계산된 scaleX, scaleY를 사용하는 것이 정확함.
                                // 하지만 기존 코드가 0.19를 쓴 이유(지도 원본 해상도 차이 등)를 고려해야 함.
                                // 일단 위에서 계산한 scaleX, scaleY를 사용하여 동적으로 맞춤.

                                final localX = currentX * scaleX + imageOffsetX;
                                final localY = currentY * scaleY + imageOffsetY;

                                // Matrix 적용하여 현재 화면상 좌표 계산
                                final currentMatrix =
                                    _transformationController.value;
                                final screenX =
                                    currentMatrix.storage[0] * localX +
                                    currentMatrix.storage[4] * localY +
                                    currentMatrix.storage[12];
                                final screenY =
                                    currentMatrix.storage[1] * localX +
                                    currentMatrix.storage[5] * localY +
                                    currentMatrix.storage[13];

                                return Positioned(
                                  left: screenX - 30, // Ripple 최대 크기(60)의 절반
                                  top:
                                      screenY -
                                      42, // 아이콘 위치 보정 (24 + 36의 중간점 고려)
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const RippleMarker(),
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          color: AppColors.primary,
                                          size: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),

                            // 마커가 현재 보고있는 지도의 층/건물과 일치할 때만 랜더링
                            // 출발지 마커
                            if (widget.start.buildingId ==
                                    currentMapBuildingId &&
                                widget.start.floor == currentMapFloorNum)
                              _buildPoiMarker(
                                poi: widget.start,
                                type: 'departure',
                                scaleX: scaleX,
                                scaleY: scaleY,
                                imageOffsetX: imageOffsetX,
                                imageOffsetY: imageOffsetY,
                              ),

                            // 경유지 마커들
                            ...widget.waypoints.map((waypoint) {
                              if (waypoint.buildingId == currentMapBuildingId &&
                                  waypoint.floor == currentMapFloorNum) {
                                return _buildPoiMarker(
                                  poi: waypoint,
                                  type: 'waypoint',
                                  scaleX: scaleX,
                                  scaleY: scaleY,
                                  imageOffsetX: imageOffsetX,
                                  imageOffsetY: imageOffsetY,
                                );
                              }
                              return const SizedBox.shrink();
                            }),

                            // 목적지 마커
                            if (widget.end.buildingId == currentMapBuildingId &&
                                widget.end.floor == currentMapFloorNum)
                              _buildPoiMarker(
                                poi: widget.end,
                                type: 'destination',
                                scaleX: scaleX,
                                scaleY: scaleY,
                                imageOffsetX: imageOffsetX,
                                imageOffsetY: imageOffsetY,
                              ),

                            // 상단 상태 정보 (CountSteps)
                            CountSteps(navigationState: navigationState),

                            // 건물 전환 버튼 (경로에 포함된 건물이 2개 이상일 때)
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
                                      borderRadius: BorderRadius.circular(12),
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
                                      // 해당 층에 마커가 있는지 확인 (빨간 뱃지용)
                                      final bool hasPointOnThisFloor = allPois
                                          .any((poi) {
                                            // 현재 건물의 층에 해당하는 POI가 있는지 확인
                                            // 건물 이름 비교가 필요함
                                            final poiBuildingName =
                                                getBuildingName(poi.buildingId);
                                            return poiBuildingName ==
                                                    _currentBuilding &&
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
                      }, // LayoutBuilder builder
                    ), // LayoutBuilder
                  ), // Container
                ), // Expanded
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
                      onPressed: () => context.go('/home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '안내 종료',
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
            ); // Column
          },
        ),
      ),
    );
  }
}

class CountSteps extends StatelessWidget {
  const CountSteps({super.key, required this.navigationState});

  final AsyncValue<NavigationState> navigationState;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: navigationState.when(
        data: (state) {
          final headingDegrees = (state.heading * 180 / math.pi) % 360;
          String directionText;
          if (headingDegrees >= 337.5 || headingDegrees < 22.5) {
            directionText = '북';
          } else if (headingDegrees >= 22.5 && headingDegrees < 67.5) {
            directionText = '북동';
          } else if (headingDegrees >= 67.5 && headingDegrees < 112.5) {
            directionText = '동';
          } else if (headingDegrees >= 112.5 && headingDegrees < 157.5) {
            directionText = '남동';
          } else if (headingDegrees >= 157.5 && headingDegrees < 202.5) {
            directionText = '남';
          } else if (headingDegrees >= 202.5 && headingDegrees < 247.5) {
            directionText = '남서';
          } else if (headingDegrees >= 247.5 && headingDegrees < 292.5) {
            directionText = '서';
          } else {
            directionText = '북서';
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 걸음수
                Row(
                  children: [
                    const Icon(
                      Icons.directions_walk,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${state.stepCount}걸음',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                // 방향
                Row(
                  children: [
                    Icon(Icons.navigation, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$directionText (${headingDegrees.toStringAsFixed(0)}°)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}
