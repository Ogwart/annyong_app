import 'package:annyong/presentation/providers/search_result_provider.dart';
import 'package:annyong/presentation/router/router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SearchResultProvider()),
      ],
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
