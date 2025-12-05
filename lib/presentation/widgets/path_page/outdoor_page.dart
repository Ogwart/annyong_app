import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';

class OutdoorPage extends StatelessWidget {
  final String destinationBuildingName;
  final VoidCallback onForceIndoor; // [추가] 강제 실내 전환 콜백

  const OutdoorPage({
    super.key,
    required this.destinationBuildingName,
    required this.onForceIndoor, // [추가]
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_walk_rounded,
              size: 80,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            "현재 실외 이동 중입니다",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              fontFamily: 'Pretendard',
            ),
          ),
          const SizedBox(height: 16),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF555555),
                height: 1.5,
                fontFamily: 'Pretendard',
              ),
              children: [
                TextSpan(
                  text: destinationBuildingName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const TextSpan(text: " 입구에 도착하면\n자동으로 실내 지도로 전환됩니다."),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // [추가] GPS 상태 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gps_fixed, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  "GPS 신호 수신 중",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // [핵심 추가] 강제 실내 전환 버튼
          // 인식 오류 시 사용자가 직접 탈출할 수 있는 수단 제공
          TextButton.icon(
            onPressed: onForceIndoor,
            icon: const Icon(
              Icons.map_outlined,
              size: 18,
              color: AppColors.grey400,
            ),
            label: const Text(
              "실내 지도로 보기",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.grey400,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
