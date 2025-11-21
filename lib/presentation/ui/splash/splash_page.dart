import 'package:annyong/domain/usecases/stride_service.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    // 기본 보폭 초기화
    await StrideService.initializeDefaultStride();
    
    // 첫 실행 여부 확인
    final isFirst = await StrideService.isFirstLaunch();
    
    // 스플래시 화면 표시 후 이동
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (mounted) {
      if (isFirst) {
        // 첫 실행이면 MeasureNoticePage로 이동
        context.go("/measureNotice");
        // 첫 실행 완료 표시
        await StrideService.setFirstLaunchCompleted();
      } else {
        // 이미 실행한 적이 있으면 홈으로 이동
        context.go("/home");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "인하대학교 실내 길찾기",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 24,
                color: Colors.white,
              ),
            ),
            Text(
              "안뇽앱",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 88,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
