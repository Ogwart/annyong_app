import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/presentation/viewmodels/navigation_view_model.dart';
import 'package:annyong/presentation/widgets/path_page/cost_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/providers/path_finder_provider.dart';
import 'package:annyong/domain/usecases/path_description_builder.dart';
import 'package:annyong/presentation/viewmodels/navigation_state.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/ui/path/outdoor_page.dart';
import 'package:annyong/domain/usecases/path_finder.dart';
import 'package:annyong/presentation/ui/path/path_result_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_math/vector_math_64.dart' as math64;
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'dart:math' as math;

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
              width: 60 * _controller.value,
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

class PathNaviPage extends ConsumerStatefulWidget {
  final Poi start;
  final Poi end;
  final List<Poi> waypoints;

  const PathNaviPage({
    super.key,
    required this.start,
    required this.end,
    this.waypoints = const [],
  });

  @override
  ConsumerState<PathNaviPage> createState() => _PathNaviPageState();
}

class _PathNaviPageState extends ConsumerState<PathNaviPage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _mapAnimationController;
  Animation<Matrix4>? _mapAnimation;
  bool _isMapInitialized = false;
  bool _isNavigationStarted = false;
  PathResult? _cachedPathResult;
  late String _currentBuilding;
  late String _currentFloor;

  @override
  void initState() {
    super.initState();
    _currentBuilding = MapUtilFunctions.getBuildingName(
      widget.start.buildingId,
    );
    _currentFloor = '${widget.start.floor}F';

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

  void _animateToStart(
    Size containerSize,
    Size displayedImageSize,
    Size originalSize,
  ) {
    if (_isMapInitialized) return;

    final scaleX = displayedImageSize.width / originalSize.width;
    final scaleY = displayedImageSize.height / originalSize.height;
    final imageOffsetX = (containerSize.width - displayedImageSize.width) / 2;
    final imageOffsetY = (containerSize.height - displayedImageSize.height) / 2;

    const double targetZoom = 3.0;
    final targetX = widget.start.xCoord * scaleX + imageOffsetX;
    final targetY = widget.start.yCoord * scaleY + imageOffsetY;

    final translateX = (containerSize.width / 2) - (targetX * targetZoom);
    final translateY = (containerSize.height / 2) - (targetY * targetZoom);

    final targetMatrix = Matrix4.identity()
      ..translateByVector3(math64.Vector3(translateX, translateY, 0))
      ..scale(targetZoom);

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

  void _cycleBuildings(Set<String> involvedBuildings) {
    if (involvedBuildings.isEmpty) return;

    setState(() {
      final buildingList = involvedBuildings.toList();
      final currentIndex = buildingList.indexOf(_currentBuilding);
      final nextIndex = (currentIndex + 1) % buildingList.length;

      _currentBuilding = buildingList[nextIndex];
      _currentFloor = '1F';
      _transformationController.value = Matrix4.identity();
      _isMapInitialized = false;
    });
  }

  void _changeFloor(String floor) {
    setState(() {
      _currentFloor = floor;
    });
  }

  bool _isVertexOnCurrentMap(int vertexId) {
    if (_currentBuilding == '5호관') {
      if (_currentFloor == '1F') return vertexId < 500;
      if (_currentFloor == '2F') return vertexId >= 500 && vertexId < 1000;
    } else if (_currentBuilding.contains('60주년')) {
      return vertexId >= 1000;
    }
    return false;
  }

  Widget _buildPoiMarker({
    required Poi poi,
    required String type,
    required double scaleX,
    required double scaleY,
    required double imageOffsetX,
    required double imageOffsetY,
  }) {
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

    final currentZoom = currentMatrix.getMaxScaleOnAxis();
    final bool showLabel = currentZoom >= 2.0;

    const double iconSize = 35.0;

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
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SvgPicture.asset(iconPath),
          ),
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

  @override
  Widget build(BuildContext context) {
    // 네비게이션 상태 구독
    final navigationState = ref.watch(navigationViewModelProvider);

    // 상태 리스너: 'outdoorChecking' 상태가 되면 다이얼로그 띄우기
    ref.listen(navigationViewModelProvider, (previous, next) {
      final wasChecking =
          previous?.value?.handoverStatus == HandoverStatus.outdoorChecking;
      final isChecking =
          next.value?.handoverStatus == HandoverStatus.outdoorChecking;

      if (!wasChecking && isChecking) {
        _showIndoorConfirmationDialog(context);
      }
    });

    final pathfinderAsync = ref.watch(pathFinderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('실시간 길안내')),
      body: pathfinderAsync.when(
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
          final List<int> visitOrder = [
            widget.start.vertexId ?? -1,
            ...widget.waypoints.map((e) => e.vertexId ?? -1),
            widget.end.vertexId ?? -1,
          ];

          if (visitOrder.contains(-1)) {
            return const Center(child: Text("유효하지 않은 위치 정보가 있습니다."));
          }

          if (_cachedPathResult == null) {
            // 처음 한 번만 실행됨
            _cachedPathResult = pathFinder.findPathWithWaypoints(visitOrder);
            debugPrint("✅ [PathNaviPage] 경로 계산 완료 (1회)");
          }

          // 저장된 결과 사용
          final result = _cachedPathResult;

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

          // 경로가 산출되었으므로 현위치 추정 시작
          // ===============================================================
          if (!_isNavigationStarted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // [Fix] result.path(List<int>)를 List<Vertex>로 변환하여 전달
                final List<Vertex> pathVertices = [];
                for (var id in result.path) {
                  if (pathFinder.vertices.containsKey(id)) {
                    pathVertices.add(pathFinder.vertices[id]!);
                  }
                }

                ref
                    .read(navigationViewModelProvider.notifier)
                    .startNavigation(pathVertices);

                setState(() {
                  _isNavigationStarted = true;
                });
              }
            });
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

          return navigationState.when(
            data: (state) {
              if (state.handoverStatus == HandoverStatus.outdoor) {
                return const OutdoorPage();
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CostCard(
                      departure: widget.start.name,
                      destination: widget.end.name,
                      totalCost: totalCost,
                      waypoints: widget.waypoints,
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final containerSize = constraints.biggest;

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
                              displayedImageSize.height /
                              calcOriginalSize.height;

                          final imageOffsetX =
                              (containerSize.width - displayedImageSize.width) /
                              2;
                          final imageOffsetY =
                              (containerSize.height -
                                  displayedImageSize.height) /
                              2;

                          if (!_isMapInitialized) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _animateToStart(
                                containerSize,
                                displayedImageSize,
                                calcOriginalSize,
                              );
                            });
                          }

                          final List<Offset> pathPoints = [];

                          if (result.path.length > 1) {
                            for (int i = 0; i < result.path.length - 1; i++) {
                              final int fromId = result.path[i];
                              final int toId = result.path[i + 1];
                              final v1 = pathFinder.vertices[fromId];
                              final v2 = pathFinder.vertices[toId];

                              if (v1 != null &&
                                  v2 != null &&
                                  _isVertexOnCurrentMap(fromId) &&
                                  _isVertexOnCurrentMap(toId)) {
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
                                          Image.asset(
                                            mapImagePath,
                                            fit: BoxFit.contain,
                                            width: displayedImageSize.width,
                                            height: displayedImageSize.height,
                                          ),
                                          IgnorePointer(
                                            child: CustomPaint(
                                              size: Size(
                                                displayedImageSize.width,
                                                displayedImageSize.height,
                                              ),
                                              painter: PathPainter(
                                                points: pathPoints,
                                                color: AppColors.path,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.start.buildingId ==
                                      currentBuildingId &&
                                  widget.start.floor == currentFloorNum)
                                _buildPoiMarker(
                                  poi: widget.start,
                                  type: 'departure',
                                  scaleX: scaleX,
                                  scaleY: scaleY,
                                  imageOffsetX: imageOffsetX,
                                  imageOffsetY: imageOffsetY,
                                ),
                              ...widget.waypoints.map((waypoint) {
                                if (waypoint.buildingId == currentBuildingId &&
                                    waypoint.floor == currentFloorNum) {
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
                              if (widget.end.buildingId == currentBuildingId &&
                                  widget.end.floor == currentFloorNum)
                                _buildPoiMarker(
                                  poi: widget.end,
                                  type: 'destination',
                                  scaleX: scaleX,
                                  scaleY: scaleY,
                                  imageOffsetX: imageOffsetX,
                                  imageOffsetY: imageOffsetY,
                                ),
                              if (state.buildingId == currentBuildingId &&
                                  state.floor == currentFloorNum)
                                Builder(
                                  builder: (context) {
                                    double currentX = state.x;
                                    double currentY = state.y;

                                    if (state.x == 0 && state.y == 0) {
                                      currentX = widget.start.xCoord;
                                      currentY = widget.start.yCoord;

                                      if (result.path.isNotEmpty) {
                                        final startVertex = pathFinder
                                            .vertices[result.path.first];
                                        if (startVertex != null) {
                                          currentX = startVertex.x;
                                          currentY = startVertex.y;
                                        }
                                      }
                                    }

                                    final localX =
                                        currentX * scaleX + imageOffsetX;
                                    final localY =
                                        currentY * scaleY + imageOffsetY;
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
                                      left: screenX - 30,
                                      top: screenY - 42,
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
                                                  color: Colors.black
                                                      .withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.person,
                                              color: AppColors.primary,
                                              size: 24,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              Positioned(
                                top: 12,
                                left: 12,
                                right: 12,
                                child: CountSteps(
                                  navigationState: navigationState,
                                ),
                              ),
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
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children:
                                      MapUtilFunctions.getAvailableFloors(
                                        _currentBuilding,
                                      ).map((floor) {
                                        final bool
                                        hasPointOnThisFloor = allPois.any((
                                          poi,
                                        ) {
                                          final poiBuildingName =
                                              MapUtilFunctions.getBuildingName(
                                                poi.buildingId,
                                              );
                                          return poiBuildingName ==
                                                  _currentBuilding &&
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
                                                    decoration:
                                                        const BoxDecoration(
                                                          color:
                                                              AppColors.warning,
                                                          shape:
                                                              BoxShape.circle,
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
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text("Navigation State Error")),
          );
        },
      ),
    );
  }

  void _showIndoorConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.door_front_door_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  "실내 진입 확인",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "실내로 들어오셨나요?\n지도를 실내 모드로 전환합니다.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref
                              .read(navigationViewModelProvider.notifier)
                              .rejectIndoorEntry();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "아니요",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref
                              .read(navigationViewModelProvider.notifier)
                              .confirmIndoorEntry();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "예",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CountSteps extends StatelessWidget {
  const CountSteps({super.key, required this.navigationState});

  final AsyncValue<NavigationState> navigationState;

  @override
  Widget build(BuildContext context) {
    return navigationState.when(
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
    );
  }
}
