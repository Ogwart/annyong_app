import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.grey200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimelineItem(
            context,
            title: departure,
            label: '출발지',
            iconPath: 'assets/icons/svg/departure_icon.svg',
            isLast: false,
          ),

          for (int i = 0; i < waypoints.length; i++)
            _buildTimelineItem(
              context,
              title: waypoints[i].name,
              label: '경유지${i + 1}',
              iconPath: 'assets/icons/svg/stopover_icon.svg',
              isLast: false,
            ),

          _buildTimelineItem(
            context,
            title: destination,
            label: '목적지',
            iconPath: 'assets/icons/svg/destination_icon.svg',
            isLast: true,
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.grey200),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "총 이동 거리",
                style: TextStyle(
                  color: AppColors.grey400,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '약 ${totalCost.toStringAsFixed(0)}m',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 타임라인 아이템을 만드는 위젯
  Widget _buildTimelineItem(
    BuildContext context, {
    required String title,
    required String label,
    required String iconPath,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              // 아이콘
              Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: SvgPicture.asset(iconPath, width: 25, height: 25),
              ),
              // 요소간 중간 연결선 (마지막 아이템은 표시하지 않음)
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.grey300,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // 텍스트 영역
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 라벨 (작은 글씨)
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.grey400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 장소 이름 (큰 글씨)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
