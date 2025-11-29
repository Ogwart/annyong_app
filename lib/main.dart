import 'package:annyong/domain/usecases/beacon_scan_service.dart';
import 'package:annyong/presentation/providers/home_page_map_provider.dart';
import 'package:annyong/presentation/router/router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 앱 생명주기 감지 등록
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // 앱 생명주기 감지 해제
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 요구사항 5: 앱이 종료되면(Detached) 백그라운드 스캐닝 종료
    // Paused 상태에서도 끌 것인지는 기획에 따르지만,
    // "앱이 종료되면"이라는 멘트에 집중하여 Detached에서 처리하거나
    // 백그라운드 배터리 소모를 줄이려면 Paused에서 Stop, Resumed에서 Start를 할 수도 있음.
    // 여기서는 확실한 종료(Detached) 시에 멈추도록 구현.
    if (state == AppLifecycleState.detached) {
      BeaconScanService().stopBackgroundScan();
    }

    // 만약 앱이 백그라운드로 내려갔을 때도 스캔을 멈추고 싶다면 아래 주석 해제
    /*
    if (state == AppLifecycleState.paused) {
      BeaconScanService().stopBackgroundScan();
    } else if (state == AppLifecycleState.resumed) {
      // 권한 체크 후 다시 시작 필요할 수 있음
      BeaconScanService().startBackgroundScan(); 
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => HomePageMapProvider())],
      child: MaterialApp.router(
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: AppBarTheme(backgroundColor: Colors.white),
          fontFamily: 'Pretendard',
        ),
        title: 'Annyong App',
        routerConfig: AppRouter.router,
      ),
    );
  }
}
