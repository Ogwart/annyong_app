//import 'dart:convert';
import 'dart:math' as math;
import 'package:annyong/presentation/widgets/path_page/cost_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/providers/path_finder_provider.dart';
import 'package:annyong/domain/usecases/path_description_builder.dart';
import 'package:annyong/presentation/viewmodels/navigation_view_model.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
import 'package:annyong/presentation/theme/app_colors.dart';

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
  // [현위치 추정용] 중복 실행 방지 플래그
  bool _isNavigationStarted = false;
  
  @override
  void initState() {
    super.initState();
    // 페이지 진입 시 길 안내 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigationNotifier = ref.read(navigationViewModelProvider.notifier);
    });
  }

  @override
  void dispose() {
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
          // 방문해야 할 모든 지점의 Vertex ID를 순서대로 리스트화
          // 유효하지 않은 것은 -1로 대체
          final List<int> visitOrder = [
            widget.start.vertexId ?? -1,
            ...widget.waypoints.map((e) => e.vertexId ?? -1),
            widget.end.vertexId ?? -1,
          ];

          // 유효하지 않은 정점이 있을 때 예외 처리
          if (visitOrder.contains(-1)) {
            return const Center(child: Text("유효하지 않은 위치 정보가 있습니다."));
          }

          // 경유지 포함하여 경로 탐색
          final result = pathFinder.findPathWithWaypoints(visitOrder);

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

          // 경로가 산출되었으므로 현위치 추정 시작
          // ===============================================================
          if (!_isNavigationStarted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(navigationViewModelProvider.notifier)
                   .startNavigation(result.path);
                
                setState(() {
                  _isNavigationStarted = true;
                });
              }
            });
          }

          // JSON 결과 생성 및 출력
          final jsonResult = PathDescriptionBuilder().build(
            pathFinder,
            result.path,
            result.totalCost,
          );

          //const JsonEncoder encoder = JsonEncoder.withIndent('  ');
          //final String prettyJson = encoder.convert(jsonResult);
          //debugPrint('----------- [Path Result JSON Start] -----------');
          //debugPrint(prettyJson);
          //debugPrint('----------- [Path Result JSON End] -----------');

          // 유효한 경로 찾았을 때 UI 렌더링
          final double totalCost = jsonResult['total_cost'] ?? 0.0;

          // 사용자의 현재 건물과 층 정보 가져오기
          final navigationState = ref.watch(navigationViewModelProvider);
          final buildingName = _getBuildingName(widget.start.buildingId);
          final floorString = '${widget.start.floor}F';

          // 지도 이미지 경로 (2x 해상도 사용)
          final mapImagePath = MapUtilFunctions.getImagePath(
            buildingName,
            floorString,
            '2x',
          );

          // 네비게이션 상태에 따라 화면 분기 (실외 vs 실내)
          return navigationState.when(
            data: (state) {
              // A. 실외 상태면 OutdoorPage 반환
              if (state.handoverStatus == HandoverStatus.outdoor) {
                return const OutdoorPage();
              }
              
              // B. 실내 상태 (지도 + 걸음수 패널)
              return Stack(
                children: [
                  // 1. 스크롤 가능한 지도 영역
                  _buildIndoorMapView(
                    context, 
                    state, 
                    totalCost, 
                    mapImagePath
                  ),

                  // 2. 상단 고정 걸음수 패널 (여기 추가!)
                  // 주의: CountSteps는 AsyncValue를 받도록 설계되어 있으니, 
                  // 그냥 AsyncValue.data(state)로 다시 감싸서 넘기거나,
                  // CountSteps를 수정해서 state만 받게 하는 게 깔끔함.
        
                  // 여기서는 간단하게 CountSteps를 수정하는 걸 추천합니다.
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: CountSteps(state: state), // AsyncValue가 아닌 state 직접 전달
                  ),              
                ]
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text("Navigation State Error")),
          );
        },
      ),
    );
  }

  // [이동 & 수정] 기존 build 메서드 내의 거대한 위젯 트리를 여기로 옮김
  Widget _buildIndoorMapView(
    BuildContext context,
    NavigationState state, // AsyncValue가 아닌 실제 데이터 받음
    double totalCost,
    String mapImagePath,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------출발, 경유, 도착, 총 비용------------------
          CostCard(
            departure: widget.start.name,
            destination: widget.end.name,
            totalCost: totalCost,
            waypoints: widget.waypoints,
          ),
          const SizedBox(height: 20),
          // ------------------지도 및 사용자 위치------------------
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
                  // 지도 이미지
                  Positioned.fill(
                    child: Image.asset(mapImagePath, fit: BoxFit.contain),
                  ),
                  
                  // [수정] 사용자 위치 마커 (state를 바로 사용)
                  if (state.floor == widget.start.floor)
                    Builder(builder: (context) {
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
                    }),
                  
                  
                  // 도착지 마커
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

  // 실내 진입 확인 다이얼로그
  void _showIndoorConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // 바깥 터치로 닫기 금지
      builder: (ctx) {
        return AlertDialog(
          title: const Text("실내 진입 확인"),
          content: const Text("실내로 들어오셨나요?\n지도를 실내 모드로 전환합니다."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // 다이얼로그 닫기
                ref.read(navigationViewModelProvider.notifier).rejectIndoorEntry();
              },
              child: const Text("아니요"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx); // 다이얼로그 닫기
                ref.read(navigationViewModelProvider.notifier).confirmIndoorEntry();
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
