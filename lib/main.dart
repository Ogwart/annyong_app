import 'package:annyong/presentation/router/router.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Pretendard',
      ),
      title: 'Annyong App',
      routerConfig: AppRouter.router,
    );
  }
}
