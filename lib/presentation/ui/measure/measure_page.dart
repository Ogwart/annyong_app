import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MeasurePage extends StatelessWidget {
  const MeasurePage({super.key});

  final int distanceRemain = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --------------------상단 신발 이미지--------------------
            Expanded(
              child: Container(
                padding: EdgeInsets.all(40),
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.grey200,
                ),
                child: Image.asset(
                  'assets/icons/steps.png',
                  color: AppColors.primary,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // --------------------안내 텍스트--------------------
            Text(
              '보폭을 측정하고 있습니다\n목표 거리까지 $distanceRemain미터',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 40),
            // --------------------다음에 측정하기 버튼--------------------
            GestureDetector(
              onTap: () {
                context.pop();
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '다음에 측정하기',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Expanded(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
