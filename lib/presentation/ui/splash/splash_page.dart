import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  void splashTimer() {
    Future.delayed(Duration(milliseconds: 2500)).then((_) {
      if (mounted) {
        context.go("/home");
      }
    });
  }

  @override
  void initState() {
    super.initState();
    splashTimer();
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
