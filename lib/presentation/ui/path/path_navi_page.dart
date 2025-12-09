import 'dart:math' as math;
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/presentation/viewmodels/navigation_view_model.dart';
import 'package:annyong/presentation/widgets/path_page/cost_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:annyong/presentation/util/get_building_name.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/providers/path_finder_provider.dart';
import 'package:annyong/domain/usecases/path_description_builder.dart';
import 'package:annyong/presentation/viewmodels/navigation_state.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/path_page/outdoor_page.dart';
import 'package:annyong/domain/usecases/path_finder.dart';
import 'package:flutter_svg/svg.dart';
import 'package:vector_math/vector_math_64.dart' as math64;
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'package:go_router/go_router.dart';

class PathNaviPage extends ConsumerStatefulWidget {
  final Poi start;
  final Poi end;
  final List<Poi> waypoints;
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
    _currentBuilding = getBuildingName(widget.start.buildingId);
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
        // ignore
      }
    });
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final navigationState = ref.watch(navigationViewModelProvider);

    ref.listen(navigationViewModelProvider, (previous, next) {
      if (next.value?.handoverStatus == HandoverStatus.outdoorChecking) {
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
          if (_cachedPathResult == null) {
            if (widget.preCalculatedPath != null &&
                widget.preCalculatedCost != null) {
              _cachedPathResult = PathResult(
                path: widget.preCalculatedPath!,
                totalCost: widget.preCalculatedCost!,
              );
            } else {
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
          }

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

          if (!_isNavigationStarted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
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

          return navigationState.when(
            data: (state) {
              if (state.handoverStatus == HandoverStatus.outdoor) {
                return OutdoorPage(
                  destinationBuildingName: getBuildingName(
                    widget.end.buildingId,
                  ),
                  onForceIndoor: () {
                    ref
                        .read(navigationViewModelProvider.notifier)
                        .confirmIndoorEntry();
                  },
                );
              }

              final allPois = [widget.start, ...widget.waypoints, widget.end];
              final involvedBuildings = allPois
                  .map((p) => getBuildingName(p.buildingId))
                  .toSet();

              final mapImagePath = MapUtilFunctions.getImagePath(
                _currentBuilding,
                _currentFloor,
                '2x',
              );

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

                          final int currentMapBuildingId =
                              MapUtilFunctions.getBuildingId(_currentBuilding);
                          final int currentMapFloorNum =
                              MapUtilFunctions.getFloorNumber(_currentFloor);

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
                              ...widget.waypoints.map((waypoint) {
                                if (waypoint.buildingId ==
                                        currentMapBuildingId &&
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
                              if (widget.end.buildingId ==
                                      currentMapBuildingId &&
                                  widget.end.floor == currentMapFloorNum)
                                _buildPoiMarker(
                                  poi: widget.end,
                                  type: 'destination',
                                  scaleX: scaleX,
                                  scaleY: scaleY,
                                  imageOffsetX: imageOffsetX,
                                  imageOffsetY: imageOffsetY,
                                ),

                              // 사용자 마커
                              UserMarker(
                                state: state,
                                currentMapBuildingId: currentMapBuildingId,
                                currentMapFloorNum: currentMapFloorNum,
                                start: widget.start,
                                pathFinder: pathFinder,
                                path: result.path,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                imageOffsetX: imageOffsetX,
                                imageOffsetY: imageOffsetY,
                                transformationController:
                                    _transformationController,
                              ),
                              CountSteps(state: state),
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
                                        final bool hasPointOnThisFloor = allPois
                                            .any((poi) {
                                              final poiBuildingName =
                                                  getBuildingName(
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
        return AlertDialog(
          title: const Text("실내 진입 확인"),
          content: const Text("실내로 들어오셨나요?\n지도를 실내 모드로 전환합니다."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref
                    .read(navigationViewModelProvider.notifier)
                    .rejectIndoorEntry();
              },
              child: const Text("아니요"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref
                    .read(navigationViewModelProvider.notifier)
                    .confirmIndoorEntry();
              },
              child: const Text("네, 들어왔습니다"),
            ),
          ],
        );
      },
    );
  }
}

class CountSteps extends StatelessWidget {
  const CountSteps({super.key, required this.state});

  final NavigationState state;

  @override
  Widget build(BuildContext context) {
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
  }
}

class PathPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  PathPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        if (i % 2 == 0) {
          if (points[i] != points[i - 1]) {
            path.moveTo(points[i].dx, points[i].dy);
          }
        } else {
          path.lineTo(points[i].dx, points[i].dy);
        }
      }
    }

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, borderPaint);

    final pathPaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, pathPaint);

    final arrowPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.fill;

    for (final metric in path.computeMetrics()) {
      const double dashWidth = 20.0;
      const double arrowSize = 1.5;

      double distance = dashWidth;
      while (distance < metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          final position = tangent.position;
          final angle = -tangent.angle;

          canvas.save();
          canvas.translate(position.dx, position.dy);
          canvas.rotate(angle);

          final arrowPath = Path()
            ..moveTo(-arrowSize, -arrowSize)
            ..lineTo(arrowSize, 0)
            ..lineTo(-arrowSize, arrowSize)
            ..close();

          canvas.drawPath(arrowPath, arrowPaint);
          canvas.restore();
        }
        distance += 40.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant PathPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

class UserMarker extends StatelessWidget {
  final NavigationState state;
  final int currentMapBuildingId;
  final int currentMapFloorNum;
  final Poi start;
  final PathFinder pathFinder;
  final List<int> path;
  final double scaleX;
  final double scaleY;
  final double imageOffsetX;
  final double imageOffsetY;
  final TransformationController transformationController;

  const UserMarker({
    super.key,
    required this.state,
    required this.currentMapBuildingId,
    required this.currentMapFloorNum,
    required this.start,
    required this.pathFinder,
    required this.path,
    required this.scaleX,
    required this.scaleY,
    required this.imageOffsetX,
    required this.imageOffsetY,
    required this.transformationController,
  });

  @override
  Widget build(BuildContext context) {
    // 1. 현재 보고 있는 건물/층과 내 위치가 일치하는지 확인
    if (state.buildingId != currentMapBuildingId ||
        state.floor != currentMapFloorNum) {
      return const SizedBox.shrink();
    }

    double currentX = state.x;
    double currentY = state.y;

    // 2. 초기 상태(0,0)일 때 출발지 좌표 사용
    if (state.x == 0 && state.y == 0) {
      currentX = start.xCoord;
      currentY = start.yCoord;

      if (path.isNotEmpty) {
        final startVertex = pathFinder.vertices[path.first];
        if (startVertex != null) {
          currentX = startVertex.x;
          currentY = startVertex.y;
        }
      }
    }

    // 3. 화면 좌표 변환
    final localX = currentX * scaleX + imageOffsetX;
    final localY = currentY * scaleY + imageOffsetY;

    final currentMatrix = transformationController.value;
    final screenX =
        currentMatrix.storage[0] * localX +
        currentMatrix.storage[4] * localY +
        currentMatrix.storage[12];
    final screenY =
        currentMatrix.storage[1] * localX +
        currentMatrix.storage[5] * localY +
        currentMatrix.storage[13];

    // 4. 마커 아이콘 결정 로직
    // 기본값은 normal
    String markerIcon = 'user_position_normal.svg';

    if (state.matchingMode == MapMatchingMode.outOfEdge) {
      // (1) 경로 이탈 (픽셀 기반) -> unknown
      markerIcon = 'user_position_unknown.svg';
    } else {
      // (2) 방향 체크: 엣지 또는 정점 위에 있을 때
      // '가야 할 방향' 벡터를 계산하기 위한 시작점과 끝점
      Vertex? currentStart;
      Vertex? currentEnd;

      // Case A: 엣지 위 이동 중 (onEdge)
      if (state.matchingMode == MapMatchingMode.onEdge &&
          state.currentEdge != null &&
          state.lastVertex != null) {
        currentStart = state.lastVertex;
        // 엣지의 반대편 정점이 가야 할 목표
        final endVId = state.currentEdge!.getOtherVertexId(currentStart!.id);
        currentEnd = pathFinder.vertices[endVId];
      }
      // Case B: 정점 위 대기/회전 중 (onVertex) - 이 부분이 누락되어 있었음
      else if (state.matchingMode == MapMatchingMode.onVertex &&
          state.currentVertex != null) {
        currentStart = state.currentVertex;
        // 전체 경로(path)에서 현재 정점의 다음 정점을 찾음
        final currentIndex = path.indexOf(currentStart!.id);
        if (currentIndex != -1 && currentIndex + 1 < path.length) {
          final nextVId = path[currentIndex + 1];
          currentEnd = pathFinder.vertices[nextVId];
        }
      }

      // 시작점과 목표점이 모두 유효할 때만 각도 계산 수행
      if (currentStart != null && currentEnd != null) {
        // 벡터: Start -> End
        final dx = currentEnd.x - currentStart.x;
        // 화면 좌표계는 Y가 아래로 증가하므로, 수학적 각도(반시계 방향) 계산 시 -dy 사용
        final dy = currentEnd.y - currentStart.y;
        final targetAngle = math.atan2(dx, -dy);

        // 현재 헤딩과 목표 각도의 차이 계산 (최단 거리 보정)
        double diff = (state.heading - targetAngle).abs();
        if (diff > math.pi) {
          diff = 2 * math.pi - diff;
        }

        // 진행 방향과 목표 방향이 90도(PI/2) 이상 차이나면 역방향(warning)으로 간주
        if (diff > math.pi / 2) {
          markerIcon = 'user_position_warning.svg';
        }
      }
    }

    // 5. 최종 위젯 반환
    return Positioned(
      left: screenX - 30,
      top: screenY - 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 동심원 이펙트
          const RippleMarker(),
          // 회전하는 사용자 아이콘
          Transform.rotate(
            angle: state.heading,
            child: SvgPicture.asset(
              'assets/icons/user_position/$markerIcon',
              width: 40,
              height: 40,
            ),
          ),
        ],
      ),
    );
  }
}
