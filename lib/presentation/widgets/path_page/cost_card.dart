import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CostCard extends StatefulWidget {
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
  State<CostCard> createState() => _CostCardState();
}

class _CostCardState extends State<CostCard> {
  bool _isExpanded = false; // 토글 상태 관리 (기본: 닫힘)

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.grey200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 10,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: _isExpanded ? _buildExpandedView() : _buildCollapsedView(),
      ),
    );
  }

  // 1. 닫힘 상태 (Collapsed): 간결한 요약 정보
  Widget _buildCollapsedView() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 출발지 -> 목적지 (심플한 화살표 연결)
              Row(
                children: [
                  Text(
                    widget.departure,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.grey400,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.destination,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 간결한 총 거리 표시
        Container(
          margin: const EdgeInsets.only(left: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${widget.totalCost.toStringAsFixed(0)}m',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.grey400),
      ],
    );
  }

  // 2. 열림 상태 (Expanded): 상세 타임라인 정보 (기존 디자인)
  Widget _buildExpandedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 헤더 (접기 버튼 포함)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "경로 상세",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.grey400,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.grey400,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 출발지
        _buildTimelineItem(
          title: widget.departure,
          label: '출발지',
          iconPath: 'assets/icons/svg/departure_icon.svg',
          isLast: false,
        ),

        // 경유지 리스트
        for (int i = 0; i < widget.waypoints.length; i++)
          _buildTimelineItem(
            title: widget.waypoints[i].name,
            label: '경유지${i + 1}',
            iconPath: 'assets/icons/svg/stopover_icon.svg',
            isLast: false,
          ),

        // 목적지
        _buildTimelineItem(
          title: widget.destination,
          label: '목적지',
          iconPath: 'assets/icons/svg/destination_icon.svg',
          isLast: true,
        ),

        const SizedBox(height: 20),
        const Divider(height: 1, color: AppColors.grey200),
        const SizedBox(height: 16),

        // 총 비용 정보
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '약 ${widget.totalCost.toStringAsFixed(0)}m',
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
    );
  }

  Widget _buildTimelineItem({
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
              Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: SvgPicture.asset(iconPath, width: 25, height: 25),
              ),
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.grey400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
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
