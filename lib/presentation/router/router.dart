import 'package:annyong/presentation/ui/bookmark_page.dart';
import 'package:annyong/presentation/ui/home_page.dart';
import 'package:annyong/presentation/ui/menu_page.dart';
import 'package:annyong/presentation/ui/search_page.dart';
import 'package:annyong/presentation/ui/search_result_page.dart';
import 'package:annyong/presentation/ui/search_rooms_page.dart';
import 'package:annyong/presentation/ui/settings_page.dart';
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
              // 메뉴 관련 페이지
              GoRoute(
                path: "menu",
                builder: (context, state) => MenuPage(),
                routes: [
                  GoRoute(
                    path: "bookmark",
                    builder: (context, state) => BookmarkPage(),
                  ),
                  GoRoute(
                    path: "settings",
                    builder: (context, state) => SettingsPage(),
                  ),
                ],
              ),
              // 검색 관련 페이지
              GoRoute(
                path: "search",
                builder: (context, state) => SearchPage(),
                routes: [
                  GoRoute(
                    path: "searchRooms",
                    builder: (context, state) {
                      final searchType = state.extra as String? ?? '';
                      return SearchRoomsPage(searchType: searchType);
                    },
                  ),
                  GoRoute(
                    path: "searchResult",
                    builder: (context, state) {
                      final searchKeyword = state.extra as String? ?? '';
                      return SearchResultPage(searchKeyword: searchKeyword);
                    },
                  ),
                ],
              ),
              // 검색 결과 페이지
            ],
          ),
        ],
      ),
    ],
  );
}
