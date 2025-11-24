//import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/providers/path_finder_provider.dart';
import 'package:annyong/domain/usecases/path_description_builder.dart';
import 'package:annyong/presentation/viewmodels/navigation_view_model.dart';
import 'package:annyong/presentation/util/home_page_util_funtions.dart';
import 'package:annyong/presentation/theme/app_colors.dart';

class PathResultPage extends ConsumerStatefulWidget {
  final Poi start;
  final Poi end;
  final List<Poi> waypoints;

  const PathResultPage({
    super.key,
    required this.start,
    required this.end,
    this.waypoints = const [], // 경유지 기본값: 빈 리스트
  });

  @override
  ConsumerState<PathResultPage> createState() => _PathResultPageState();
}

class _PathResultPageState extends ConsumerState<PathResultPage> {
  @override
  void initState() {
    super.initState();
    // 페이지 진입 시 길 안내 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigationNotifier = ref.read(navigationViewModelProvider.notifier);
      // 출발 POI로 초기 위치 설정
      navigationNotifier.setInitialPositionFromPoi(widget.start);
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
        return '5호관';
      case 2:
        return '하이테크관';
      default:
        return '5호관';
    }
  }

  @override
  Widget build(BuildContext context) {
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
          final List<dynamic> routes = jsonResult['routes'] ?? [];

          // 사용자의 현재 건물과 층 정보 가져오기
          final navigationState = ref.watch(navigationViewModelProvider);
          final buildingName = _getBuildingName(widget.start.buildingId);
          final floorString = '${widget.start.floor}F';

          // 지도 이미지 경로 (2x 해상도 사용)
          final mapImagePath = HomePageUtilFunctions.getImagePath(
            buildingName,
            floorString,
            '2x',
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        // 실시간 걸음수 및 방향 정보 (상단 오버레이)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: navigationState.when(
                            data: (state) {
                              final headingDegrees =
                                  (state.heading * 180 / math.pi) % 360;
                              String directionText;
                              if (headingDegrees >= 337.5 ||
                                  headingDegrees < 22.5) {
                                directionText = '북';
                              } else if (headingDegrees >= 22.5 &&
                                  headingDegrees < 67.5) {
                                directionText = '북동';
                              } else if (headingDegrees >= 67.5 &&
                                  headingDegrees < 112.5) {
                                directionText = '동';
                              } else if (headingDegrees >= 112.5 &&
                                  headingDegrees < 157.5) {
                                directionText = '남동';
                              } else if (headingDegrees >= 157.5 &&
                                  headingDegrees < 202.5) {
                                directionText = '남';
                              } else if (headingDegrees >= 202.5 &&
                                  headingDegrees < 247.5) {
                                directionText = '남서';
                              } else if (headingDegrees >= 247.5 &&
                                  headingDegrees < 292.5) {
                                directionText = '서';
                              } else {
                                directionText = '북서';
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                        Icon(
                                          Icons.navigation,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
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
                        ),
                        // 사용자 위치 마커 (현재 층일 때만 표시)
                        navigationState.when(
                          data: (state) {
                            // 현재 지도 층과 사용자 층이 일치할 때만 마커 표시
                            if (state.floor != widget.start.floor) {
                              return const SizedBox.shrink();
                            }

                            // 사용자 좌표를 화면 좌표로 변환
                            // (search_result_page와 동일한 변환 로직 사용)
                            final scaledX = state.x * 0.19;
                            final scaledY = state.y * 0.19;
                            final adjustedX = scaledX - 10;
                            final adjustedY = scaledY + 50;

                            // 변환된 좌표 로그 출력
                            print(
                              '[PathResult] 변환된 좌표: 실제=(${state.x.toStringAsFixed(2)}, ${state.y.toStringAsFixed(2)}) → 화면=(${adjustedX.toStringAsFixed(2)}, ${adjustedY.toStringAsFixed(2)}), 층=${state.floor}F',
                            );

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
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.person_pin_circle,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        // 도착지 마커 (현재 층일 때만 표시)
                        if (widget.end.floor == widget.start.floor)
                          Builder(
                            builder: (context) {
                              // 도착지 POI 좌표를 화면 좌표로 변환
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
                                        color: Colors.black.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
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
                // ------------------출발, 경유, 도착, 총 비용 카드------------------
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. 출발지 (항상 랜더링)
                        Row(
                          children: [
                            const Icon(Icons.place, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '출발: ${widget.start.name}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),

                        // 2. 경유지 (리스트가 비어있으면 렌더링되지 않음)
                        // Collection for를 사용하여 경유지 목록만큼 Row 생성
                        for (int i = 0; i < widget.waypoints.length; i++) ...[
                          const SizedBox(height: 8), // 위 요소와의 간격ㄱ
                          Row(
                            children: [
                              // 경유지 아이콘 (파란색 깃발 추천)
                              const Icon(Icons.flag, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '경유${i + 1}: ${widget.waypoints[i].name}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // 3. 도착지 (항상 랜더링)
                        const SizedBox(height: 8), // 위 요소(출발지 혹은 마지막 경유지)와의 간격
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '도착: ${widget.end.name}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),

                        // 4. 총 비용 정보 (항상 랜더링)
                        const Divider(height: 24),
                        Text(
                          '총 비용: 약 ${totalCost.toStringAsFixed(0)}m',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ------------------상세 경로 리스트------------------
                const SizedBox(height: 16),
                Text('상세 경로', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: routes.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final step = routes[index] as Map<String, dynamic>;
                    final way = step['way'] as String;
                    final from = step['vertex1_id'];
                    final to = step['vertex2_id'];
                    final seq = step['sequence'];

                    IconData iconData;
                    Color iconColor = Colors.grey;

                    if (way.contains("계단")) {
                      iconData = Icons.stairs;
                      iconColor = Colors.orange;
                    } else if (way.contains("좌회전")) {
                      iconData = Icons.turn_left;
                      iconColor = Colors.blue;
                    } else if (way.contains("우회전")) {
                      iconData = Icons.turn_right;
                      iconColor = Colors.blue;
                    } else if (way == "직진") {
                      iconData = Icons.arrow_upward;
                      iconColor = Colors.green;
                    } else {
                      iconData = Icons.navigation;
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        child: Text('$seq'),
                      ),
                      title: Text(
                        way,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('노드 $from → 노드 $to'),
                      trailing: Icon(iconData, color: iconColor),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
