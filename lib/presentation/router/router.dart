import 'package:annyong/presentation/ui/home_page.dart';
import 'package:annyong/presentation/ui/menu_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static GoRouter router = GoRouter(
    initialLocation: "/home",
    navigatorKey: _rootNavigatorKey,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return Scaffold(body: child);
        },
        routes: [
          GoRoute(
            path: "/home",
            builder: (context, state) => HomePage(),
            routes: [
              GoRoute(path: "menu", builder: (context, state) => MenuPage()),
            ],
          ),
        ],
      ),
    ],
  );
}
