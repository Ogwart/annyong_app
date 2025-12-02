//import 'dart:convert';
import 'dart:math' as math;
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

  @override
  Widget build(BuildContext context) {
    // 네비게이션 상태 구독
    final navigationState = ref.watch(navigationViewModelProvider);

    // 상태 리스너: 'outdoorChecking' 상태가 되면 다이얼로그 띄우기
    ref.listen(navigationViewModelProvider, (previous, next) {
      if (next.value?.handoverStatus == HandoverStatus.outdoorChecking) {
        _showIndoorConfirmationDialog(context);
      }
    });

    final pathfinderAsync = ref.watch(pathFinderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('길찾기 결과')),
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
            debugPrint("✅ [PathResultPage] 경로 계산 완료 (1회)");
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

              return Stack(
                children: [
                  _buildIndoorMapView(context, state, totalCost, mapImagePath),
                  // Positioned(
                  //   top: 12,
                  //   left: 12,
                  //   right: 12,
                  //   child: CountSteps(state: state), // [Fix] state 이름 수정
                  // ),
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
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
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                if (context.mounted) {
                  context.go('/home');
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                width: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: AppColors.primary,
                ),
                child: Text(
                  '길안내 종료하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
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
  // [Fix] 파라미터 이름을 state로 변경하고 타입 수정 (AsyncValue 제거)
  const CountSteps({super.key, required this.state});

  final NavigationState state;

  @override
  Widget build(BuildContext context) {
    // state는 이미 데이터이므로 when 등을 쓸 필요 없이 바로 사용
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
