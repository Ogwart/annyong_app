import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/ui/path/path_result_page.dart';
import 'package:flutter/material.dart';

class CostCard extends StatelessWidget {
  const CostCard({
    super.key,
    required this.totalCost,
    required this.departure,
    required this.destination,
    required this.waypoints,
  });

  final double totalCost;
  final String departure;
  final String destination;
  final List<Poi> waypoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.grey200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. 출발지 (항상 랜더링)
          Row(
            children: [
              const Icon(Icons.place, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '출발: $departure',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),

          // 2. 경유지 (리스트가 비어있으면 렌더링되지 않음)
          for (int i = 0; i < waypoints.length; i++) ...[
            const SizedBox(height: 8), // 위 요소와의 간격
            Row(
              children: [
                // 경유지 아이콘 (파란색 깃발 추천)
                const Icon(Icons.flag, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '경유${i + 1}: ${waypoints[i].name}',
                    style: Theme.of(context).textTheme.titleMedium,
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
                  '도착: $destination',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          // 4. 총 비용 정보
          const Divider(height: 24),
          Text(
            '총 비용: 약 ${totalCost.toStringAsFixed(0)}m',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
