import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/util/guidance_info.dart';
import 'package:flutter/material.dart';

class NavigationGuideCard extends StatelessWidget {
  final GuidanceInfo info;

  const NavigationGuideCard({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "실시간 안내",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.message,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // [수정됨] imagePath가 있으면 이미지를, 없으면 아이콘을 표시
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: info.iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: info.imagePath != null
                  ? Image.asset(
                      info.imagePath!,
                      width: 28, // 아이콘 크기에 맞춰 조정
                      height: 28,
                      fit: BoxFit.contain,
                    )
                  : Icon(info.icon, color: info.iconColor, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
