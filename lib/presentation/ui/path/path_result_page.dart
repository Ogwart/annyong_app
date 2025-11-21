import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/providers/path_finder_provider.dart';
import 'package:annyong/domain/usecases/path_description_builder.dart';

class PathResultPage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
            start.vertexId ?? -1,
            ...waypoints.map((e) => e.vertexId ?? -1),
            end.vertexId ?? -1,
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
                      '출발지: ${start.name}\n도착지: ${end.name}',
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

          const JsonEncoder encoder = JsonEncoder.withIndent('  ');
          final String prettyJson = encoder.convert(jsonResult);
          debugPrint('----------- [Path Result JSON Start] -----------');
          debugPrint(prettyJson);
          debugPrint('----------- [Path Result JSON End] -----------');

          // 유효한 경로 찾았을 때 UI 렌더링
          final double totalCost = jsonResult['total_cost'] ?? 0.0;
          final List<dynamic> routes = jsonResult['routes'] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                                '출발: ${start.name}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),

                        // 2. 경유지 (리스트가 비어있으면 렌더링되지 않음)
                        // Collection for를 사용하여 경유지 목록만큼 Row 생성
                        for (int i = 0; i < waypoints.length; i++) ...[
                          const SizedBox(height: 8), // 위 요소와의 간격ㄱ
                          Row(
                            children: [
                              // 경유지 아이콘 (파란색 깃발 추천)
                              const Icon(Icons.flag, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '경유${i + 1}: ${waypoints[i].name}',
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
                                '도착: ${end.name}',
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

                    // 단순 아이콘 매핑
                    // TODO: 실제 요구사항에 맞게 아이콘 및 색상 매핑 로직 수정 필요
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
