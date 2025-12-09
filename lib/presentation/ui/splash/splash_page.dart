import 'dart:io';
import 'package:flutter/services.dart'; // 앱 종료를 위해 추가
import 'package:annyong/domain/usecases/beacon_scan_service.dart';
import 'package:annyong/domain/usecases/favorite_service.dart';
import 'package:annyong/domain/usecases/stride_service.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. 기본 데이터 초기화
    await StrideService.initializeDefaultStride();
    await FavoriteService.initializeDefaultFavorites();

    // 2. 첫 실행 여부 확인
    final isFirst = await StrideService.isFirstLaunch();

    // 스플래시 화면 지연 (UX)
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    if (isFirst) {
      // 5-1. 최초 사용자라면 비콘 스캐닝을 하지 않음 (권한 없음)
      // 바로 측정 안내 페이지로 이동
      context.go("/measureNotice");
      await StrideService.setFirstLaunchCompleted();
    } else {
      // 5-2. 기존 사용자: 권한 체크 및 비콘 스캐닝 시작
      await _checkPermissionAndStartScan();
    }
  }

  Future<void> _checkPermissionAndStartScan() async {
    // 필요한 권한 목록 정의
    List<Permission> permissions = [];

    // [수정] 플랫폼별 필수 권한 추가 (활동 감지 포함)
    if (Platform.isAndroid) {
      // Android 12 이상 (API 31+)
      permissions.add(Permission.bluetoothScan);
      permissions.add(Permission.bluetoothConnect);
      permissions.add(Permission.location);
      permissions.add(Permission.activityRecognition); // [추가] 걸음 수 측정 권한
    } else if (Platform.isIOS) {
      permissions.add(Permission.bluetooth);
      permissions.add(Permission.location);
      permissions.add(
        Permission.activityRecognition,
      ); // [추가] iOS Motion Usage 권한
      // 참고: iOS의 경우 Info.plist에 NSMotionUsageDescription이 있어야 함
    }

    // 권한 상태 확인
    bool allGranted = true;
    for (var permission in permissions) {
      // 활동 감지 권한 등은 OS 버전에 따라 status가 다를 수 있으므로 체크
      if (await permission.status.isDenied) {
        allGranted = false;
        break;
      }
    }

    if (allGranted) {
      // 권한이 이미 허용된 경우 -> 백그라운드 스캔 시작 후 홈 이동
      await BeaconScanService().startBackgroundScan();
      if (mounted) context.go("/home");
    } else {
      // 권한이 없는 경우 -> 권한 요청
      await _requestPermissions(permissions);
    }
  }

  Future<void> _requestPermissions(List<Permission> permissions) async {
    Map<Permission, PermissionStatus> statuses = await permissions.request();

    bool isAllGranted = true;
    statuses.forEach((key, value) {
      // activityRecognition은 일부 기기에서 제한적일 수 있으나 필수 권한으로 처리
      if (!value.isGranted) {
        isAllGranted = false;
      }
    });

    if (isAllGranted) {
      // 권한 허가됨 -> 스캔 시작 후 홈 이동
      await BeaconScanService().startBackgroundScan();
      if (mounted) context.go("/home");
    } else {
      // 5-3. 권한 거절 시 앱 종료
      _showExitDialog();
    }
  }

  void _showExitDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("권한 필요"),
        content: const Text(
          "비콘 스캔 및 걸음 수 측정을 위해\n블루투스, 위치, 신체 활동 감지 권한이 필수입니다.\n권한을 허용하지 않으면 앱을 사용할 수 없습니다.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              // 앱 종료
              if (Platform.isAndroid) {
                SystemNavigator.pop();
              } else {
                exit(0);
              }
            },
            child: const Text("종료"),
          ),
          TextButton(
            onPressed: () {
              // 설정으로 이동 (사용자가 다시 시도할 기회 제공)
              openAppSettings();
            },
            child: const Text("설정으로 이동"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFA2DDFF),
      body: Center(
        child: Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              child: Image.asset("assets/image/mascot.png"),
            ),
            Positioned(
              top: 180,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    "인하대학교 실내 길찾기",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 24,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    "안뇽앱",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 88,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
