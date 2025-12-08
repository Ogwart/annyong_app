import 'dart:math' as math;
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/presentation/viewmodels/navigation_view_model.dart';
import 'package:annyong/presentation/widgets/path_page/cost_card.dart';
import 'package:annyong/presentation/widgets/path_page/count_steps.dart';
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

// [수정] 클래스 이름 변경: PathResultPage -> PathNaviPage
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

class _PathNaviPageState extends ConsumerState<PathNaviPage> {
  bool _isNavigationStarted = false; // [현위치 추정용] 중복 실행 방지 플래그
  PathResult? _cachedPathResult; // 계산된 경로 결과를 저장할 변수

  @override
  void initState() {
    super.initState();
    // 페이지 진입 시 길 안내 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationViewModelProvider.notifier);
    });
  }

  @override
  void dispose() {
    // 페이지 종료 시 길 안내 종료 및 초기화
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

  String _getBuildingName(int buildingId) {
    return MapUtilFunctions.getBuildingName(buildingId);
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
          final buildingName = _getBuildingName(widget.start.buildingId);
          final floorString = '${widget.start.floor}F';

          final mapImagePath = MapUtilFunctions.getImagePath(
            buildingName,
            floorString,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CountSteps(state: state),
                  ),
                  _buildIndoorMapView(context, state, totalCost, mapImagePath),
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

  Widget _buildIndoorMapView(
    BuildContext context,
    NavigationState state,
    double totalCost,
    String mapImagePath,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CostCard(
            departure: widget.start.name,
            destination: widget.end.name,
            totalCost: totalCost,
            waypoints: widget.waypoints,
          ),
          const SizedBox(height: 20),
          Container(
            height: 300,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.grey200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(mapImagePath, fit: BoxFit.contain),
                  ),

                  if (state.floor == widget.start.floor)
                    Builder(
                      builder: (context) {
                        final scaledX = state.x * 0.19;
                        final scaledY = state.y * 0.19;
                        final adjustedX = scaledX - 10;
                        final adjustedY = scaledY + 50;

                        return Positioned(
                          left: adjustedX - 12,
                          top: adjustedY - 24,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),

                  if (widget.end.floor == widget.start.floor)
                    Builder(
                      builder: (context) {
                        final scaledX = widget.end.xCoord * 0.19;
                        final scaledY = widget.end.yCoord * 0.19;
                        final adjustedX = scaledX - 10;
                        final adjustedY = scaledY + 50;

                        return Positioned(
                          left: adjustedX - 12,
                          top: adjustedY - 24,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
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
