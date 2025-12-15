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
import 'package:go_router/go_router.dart';
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

  /// '5호관'과 '60주년기념관' 사이를 전환하는 전용 토글 버튼용 헬퍼
  void _toggleBuilding() {
    setState(() {
      if (_currentBuilding == '5호관') {
        _currentBuilding = '60주년기념관';
      } else {
        _currentBuilding = '5호관';
      }
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

  /// 경로와 현재 네비게이션 상태를 기반으로 상단 안내 카드에 사용할
  /// 다음 동작(직진/좌/우회전/계단)을 계산한다.
  GuideInstruction _buildGuideInstruction(
    NavigationState state,
    PathFinder pathFinder,
    PathResult result,
  ) {
    final path = result.path;
    if (path.length < 2) {
      return GuideInstruction(
        type: GuideInstructionType.arrive,
        message: _guideMessage(GuideInstructionType.arrive),
        iconAssetPath: _guideIconAsset(GuideInstructionType.arrive),
      );
    }

    // 1. 현재 정점 ID 추정
    int? currId;
    if (state.currentVertex != null) {
      currId = state.currentVertex!.id;
    } else if (state.lastVertex != null) {
      currId = state.lastVertex!.id;
    } else {
      // 좌표 기반으로 경로 상 가장 가까운 정점을 찾는 fallback
      double bestDist = double.infinity;
      int? bestId;
      for (final id in path) {
        final v = pathFinder.vertices[id];
        if (v == null) continue;
        final dx = v.x - state.x;
        final dy = v.y - state.y;
        final d2 = dx * dx + dy * dy;
        if (d2 < bestDist) {
          bestDist = d2;
          bestId = id;
        }
      }
      currId = bestId;
    }

    if (currId == null) {
      return GuideInstruction(
        type: GuideInstructionType.recover,
        message: _guideMessage(GuideInstructionType.recover),
        iconAssetPath: _guideIconAsset(GuideInstructionType.recover),
      );
    }

    int currIndex = path.indexOf(currId);
    if (currIndex == -1) {
      // lastVertex 기준으로 한 번 더 시도
      if (state.lastVertex != null) {
        currIndex = path.indexOf(state.lastVertex!.id);
      }
      if (currIndex == -1) {
        return GuideInstruction(
          type: GuideInstructionType.recover,
          message: _guideMessage(GuideInstructionType.recover),
          iconAssetPath: _guideIconAsset(GuideInstructionType.recover),
        );
      }
    }

    // 도착 직전/직후 처리
    if (currIndex >= path.length - 1) {
      return GuideInstruction(
        type: GuideInstructionType.arrive,
        message: _guideMessage(GuideInstructionType.arrive),
        iconAssetPath: _guideIconAsset(GuideInstructionType.arrive),
      );
    }

    final fromIndex = currIndex == 0 ? currIndex : currIndex - 1;
    final fromId = path[fromIndex];
    final nextIndex = (currIndex + 1).clamp(0, path.length - 1);
    final nextId = path[nextIndex];

    final fromVertex = pathFinder.vertices[fromId];
    final currVertex = pathFinder.vertices[currId];
    final nextVertex = pathFinder.vertices[nextId];

    if (fromVertex == null || currVertex == null || nextVertex == null) {
      return GuideInstruction(
        type: GuideInstructionType.recover,
        message: _guideMessage(GuideInstructionType.recover),
        iconAssetPath: _guideIconAsset(GuideInstructionType.recover),
      );
    }

    // 2. 먼저 계단/층 이동 여부 확인 (WayType 기반)
    final edgesFromCurr = pathFinder.adjacencyList[currId] ?? const <Edge>[];
    Edge? nextEdge;
    for (final e in edgesFromCurr) {
      if (e.toVertexId == nextId) {
        nextEdge = e;
        break;
      }
    }

    if (nextEdge != null &&
        (nextEdge.way == WayType.up || nextEdge.way == WayType.down)) {
      final type = nextEdge.way == WayType.up
          ? GuideInstructionType.upstair
          : GuideInstructionType.downstair;
      return GuideInstruction(
        type: type,
        message: _guideMessage(type),
        iconAssetPath: _guideIconAsset(type),
      );
    }

    // 3. 방향(직진/좌/우/유턴) 판정
    final v1x = currVertex.x - fromVertex.x;
    final v1y = currVertex.y - fromVertex.y;
    final v2x = nextVertex.x - currVertex.x;
    final v2y = nextVertex.y - currVertex.y;

    // 기존 좌표계와 동일하게 atan2(dx, -dy) 사용
    final angle1 = math.atan2(v1x, -v1y);
    final angle2 = math.atan2(v2x, -v2y);

    double diff = angle2 - angle1;
    if (diff > math.pi) diff -= 2 * math.pi;
    if (diff < -math.pi) diff += 2 * math.pi;

    final absDiff = diff.abs();

    GuideInstructionType type;
    if (absDiff < 0.52) {
      // 약 30도 이내 → 직진
      type = GuideInstructionType.straight;
    } else if (absDiff > 2.62) {
      // 150도 이상 → 유턴
      type = GuideInstructionType.uturn;
    } else {
      // 좌/우 회전: 외적 부호 기준
      final cross = v1x * v2y - v1y * v2x;
      if (cross > 0) {
        type = GuideInstructionType.left;
      } else {
        type = GuideInstructionType.right;
      }
    }

    return GuideInstruction(
      type: type,
      message: _guideMessage(type),
      iconAssetPath: _guideIconAsset(type),
    );
  }

  String _guideMessage(GuideInstructionType type) {
    switch (type) {
      case GuideInstructionType.straight:
        return '직진하세요';
      case GuideInstructionType.left:
        return '좌회전하세요';
      case GuideInstructionType.right:
        return '우회전하세요';
      case GuideInstructionType.upstair:
        return '계단을 올라가세요';
      case GuideInstructionType.downstair:
        return '계단을 내려가세요';
      case GuideInstructionType.uturn:
        return '뒤로 돌아가세요';
      case GuideInstructionType.departure:
        return '출발 방향으로 이동하세요';
      case GuideInstructionType.arrive:
        return '목적지에 도착했습니다';
      case GuideInstructionType.recover:
        return '경로로 돌아가세요';
    }
  }

  String _guideIconAsset(GuideInstructionType type) {
    switch (type) {
      case GuideInstructionType.straight:
        return 'assets/icons/guide_tile/guide_straight.png';
      case GuideInstructionType.left:
        return 'assets/icons/guide_tile/guide_left.png';
      case GuideInstructionType.right:
        return 'assets/icons/guide_tile/guide_right.png';
      case GuideInstructionType.upstair:
        return 'assets/icons/guide_tile/guide_upstair.png';
      case GuideInstructionType.downstair:
        return 'assets/icons/guide_tile/guide_downstair.png';
      case GuideInstructionType.uturn:
        return 'assets/icons/guide_tile/guide_uturn.png';
      case GuideInstructionType.departure:
        return 'assets/icons/guide_tile/guide_departure.png';
      case GuideInstructionType.arrive:
        // 목적지 도착 시에도 출발 아이콘과 동일한 깃발 아이콘 사용
        return 'assets/icons/guide_tile/guide_departure.png';
      case GuideInstructionType.recover:
        return 'assets/icons/guide_tile/guide_uturn.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 네비게이션 상태 구독
    final navigationState = ref.watch(navigationViewModelProvider);

    // 상태 리스너: 'outdoorChecking' 상태가 되면 다이얼로그 띄우기
    // 그리고 사용자의 층/건물 변경 시 지도 이미지 자동 업데이트
    ref.listen(navigationViewModelProvider, (previous, next) {
      final prevState = previous?.value;
      final nextState = next.value;

      // outdoorChecking 상태 변경 감지 - 자동으로 실내 진입 확인
      final wasChecking =
          prevState?.handoverStatus == HandoverStatus.outdoorChecking;
      final isChecking =
          nextState?.handoverStatus == HandoverStatus.outdoorChecking;

      if (!wasChecking && isChecking) {
        // 다이얼로그 없이 자동으로 실내 진입 확인
        ref.read(navigationViewModelProvider.notifier).confirmIndoorEntry();
      }

      // 층/건물 변경 감지 및 자동 업데이트
      if (prevState != null && nextState != null) {
        final prevFloor = prevState.floor;
        final nextFloor = nextState.floor;
        final prevBuildingId = prevState.buildingId;
        final nextBuildingId = nextState.buildingId;

        final floorChanged = prevFloor != nextFloor;
        final buildingChanged = prevBuildingId != nextBuildingId;

        if (floorChanged || buildingChanged) {
          final newBuildingName = MapUtilFunctions.getBuildingName(
            nextBuildingId,
          );
          final newFloor = '${nextFloor}F';

          // 현재 표시 중인 건물/층과 다를 때만 업데이트
          if (_currentBuilding != newBuildingName ||
              _currentFloor != newFloor) {
            setState(() {
              _currentBuilding = newBuildingName;
              _currentFloor = newFloor;
              // 건물이 변경되면 지도 초기화
              if (buildingChanged) {
                _transformationController.value = Matrix4.identity();
                _isMapInitialized = false;
              }
            });
          }
        }
      }
    });

    final pathfinderAsync = ref.watch(pathFinderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('실시간 길안내')),
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

                  final startFloor = widget.start.floor;
                  final startBuildingId = widget.start.buildingId;

                  ref
                      .read(navigationViewModelProvider.notifier)
                      .startNavigation(
                        pathVertices,
                        startFloor: startFloor,
                        startBuildingId: startBuildingId,
                      );

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

                final guideInstruction = _buildGuideInstruction(
                  state,
                  pathFinder,
                  result,
                );

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                      child: GuideInstructionCard(
                        instruction: guideInstruction,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                      child: CostCard(
                        departure: widget.start.name,
                        destination: widget.end.name,
                        totalCost: totalCost / 10,
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
                                displayedImageSize.width /
                                calcOriginalSize.width;
                            final scaleY =
                                displayedImageSize.height /
                                calcOriginalSize.height;

                            final imageOffsetX =
                                (containerSize.width -
                                    displayedImageSize.width) /
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
                                  if (waypoint.buildingId ==
                                          currentBuildingId &&
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
                                if (widget.end.buildingId ==
                                        currentBuildingId &&
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
                                  UserMarker(
                                    state: state,
                                    currentMapBuildingId: currentBuildingId,
                                    currentMapFloorNum: currentFloorNum,
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
                                // Positioned(
                                //   top: 12,
                                //   left: 12,
                                //   right: 12,
                                //   child: CountSteps(
                                //     navigationState: navigationState,
                                //   ),
                                // ),
                                // 건물 전환 버튼 ('5호관' <-> '60주년기념관')
                                Positioned(
                                  bottom: 16,
                                  left: 16,
                                  child: GestureDetector(
                                    onTap: _toggleBuilding,
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
                                                            color: AppColors
                                                                .warning,
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
                    // 하단 안내 종료 버튼
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
                          onPressed: () async {
                            final shouldExit = await showDialog<bool>(
                              context: context,
                              barrierDismissible: true,
                              builder: (ctx) {
                                return AlertDialog(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Text(
                                    '안내 종료',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  content: const Text(
                                    '정말 안내를 종료할까요?\n길안내를 중단하고 홈 화면으로 이동합니다.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(ctx).pop(false);
                                      },
                                      child: const Text(
                                        '취소',
                                        style: TextStyle(color: AppColors.text),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(ctx).pop(true);
                                      },
                                      child: const Text(
                                        '확인',
                                        style: TextStyle(
                                          color: AppColors.text,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (shouldExit == true && context.mounted) {
                              // 네비게이션 상태 정리 후 홈으로 이동
                              ref
                                  .read(navigationViewModelProvider.notifier)
                                  .stopNavigation();
                              context.go('/home');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
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
                              color: AppColors.text,
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
      ),
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

/// 상단에 표시되는 다음 행동 안내 카드
class GuideInstructionCard extends StatelessWidget {
  final GuideInstruction instruction;

  const GuideInstructionCard({super.key, required this.instruction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '실시간 안내',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  instruction.message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFE6EDFF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                instruction.iconAssetPath,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum GuideInstructionType {
  straight,
  left,
  right,
  upstair,
  downstair,
  uturn,
  departure,
  arrive,
  recover,
}

class GuideInstruction {
  final GuideInstructionType type;
  final String message;
  final String iconAssetPath;

  const GuideInstruction({
    required this.type,
    required this.message,
    required this.iconAssetPath,
  });
}

/// 사용자 마커 위젯
/// NavigationState에 따라 마커 아이콘을 동적으로 결정하여 표시합니다.
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
    // 초기 상태 판단: 네비게이션 시작 후 아직 한 걸음도 이동하지 않은 상태(stepCount == 0)
    // (예전처럼 buildingId/floor만으로 판단하면 경로 전체에서 계속 초기 상태로 간주되는 문제가 있었음)
    final isInitialState = state.stepCount == 0;

    // 출발지의 건물/층 정보
    final startBuildingId = start.buildingId;
    final startFloor = start.floor;

    // 건물/층 매칭 체크
    final buildingMatches = state.buildingId == currentMapBuildingId;
    final floorMatches = state.floor == currentMapFloorNum;

    // 출발지와 현재 맵이 같은지 체크
    final startMatchesMap =
        startBuildingId == currentMapBuildingId &&
        startFloor == currentMapFloorNum;

    // 초기 상태이거나 출발지가 현재 맵과 일치하면 표시
    // 그 외에는 건물/층이 일치할 때만 표시
    if (!isInitialState && !startMatchesMap) {
      if (!buildingMatches || !floorMatches) {
        return const SizedBox.shrink();
      }
    }

    double currentX = state.x;
    double currentY = state.y;

    // 2. 초기 상태(0,0)일 때 출발지 좌표 사용
    if (isInitialState) {
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
        if (pathFinder.vertices.containsKey(endVId)) {
          currentEnd = pathFinder.vertices[endVId];
        }
      }
      // Case B: 정점 위 대기/회전 중 (onVertex)
      else if (state.matchingMode == MapMatchingMode.onVertex &&
          state.currentVertex != null) {
        currentStart = state.currentVertex;
        // 전체 경로(path)에서 현재 정점의 다음 정점을 찾음
        final currentIndex = path.indexOf(currentStart!.id);
        if (currentIndex != -1 && currentIndex + 1 < path.length) {
          final nextVId = path[currentIndex + 1];
          if (pathFinder.vertices.containsKey(nextVId)) {
            currentEnd = pathFinder.vertices[nextVId];
          }
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
        // [Fix] 판정 방향이 실제와 시계방향으로 90도 어긋나 있어 반시계 방향으로 90도 보정
        //double correctedHeading = state.heading - (math.pi / 2);
        //double diff = (correctedHeading - targetAngle).abs();
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
          // 지도가 시계 방향으로 30도 기울어져 있으므로 마커도 30도 추가 회전
          Transform.rotate(
            angle: state.heading + (30 * math.pi / 180),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SvgPicture.asset(
                'assets/icons/user_position/$markerIcon',
                width: 40,
                height: 40,
                placeholderBuilder: (context) => const Icon(
                  Icons.person,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
