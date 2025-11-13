import 'package:annyong/presentation/ui/measure/measure_notice_page.dart';
import 'package:annyong/presentation/ui/measure/measure_page.dart';
import 'package:annyong/presentation/ui/measure/measure_result_page.dart';
import 'package:annyong/presentation/ui/menu/bookmark_page.dart';
import 'package:annyong/presentation/ui/home/home_page.dart';
import 'package:annyong/presentation/ui/menu/menu_page.dart';
import 'package:annyong/presentation/ui/navi/navi_page.dart';
import 'package:annyong/presentation/ui/path/path_selection_page.dart';
import 'package:annyong/presentation/ui/search/search_page.dart';
import 'package:annyong/presentation/ui/search/search_result_page.dart';
import 'package:annyong/presentation/ui/search/search_rooms_page.dart';
import 'package:annyong/presentation/ui/menu/settings_page.dart';
import 'package:annyong/presentation/ui/splash/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static GoRouter router = GoRouter(
    initialLocation: "/",
    navigatorKey: _rootNavigatorKey,
    routes: [
      GoRoute(path: "/", builder: (context, state) => const SplashPage()),
      GoRoute(
        path: "/measureNotice",
        builder: (context, state) => MeasureNoticePage(),
        routes: [
          GoRoute(path: "measure", builder: (context, state) => MeasurePage()),
          GoRoute(
            path: "measureResult",
            builder: (context, state) => MeasureResultPage(),
          ),
        ],
      ),
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
                builder: (context, state) {
                  SearchMode? searchMode;
                  bool returnResult = false;
                  final extra = state.extra;
                  if (extra is SearchMode) {
                    searchMode = extra;
                  } else if (extra is Map) {
                    final searchModeValue = extra['searchMode'];
                    if (searchModeValue is SearchMode) {
                      searchMode = searchModeValue;
                    }
                    final returnResultValue = extra['returnResult'];
                    if (returnResultValue is bool) {
                      returnResult = returnResultValue;
                    }
                  }
                  return SearchPage(
                    searchMode: searchMode,
                    returnResult: returnResult,
                  );
                },
                routes: [
                  GoRoute(
                    path: "searchRooms",
                    builder: (context, state) {
                      final extra = state.extra;
                      String searchType = '';
                      final int categoryId =
                          extra is Map<String, dynamic> &&
                              extra['categoryId'] is int
                          ? extra['categoryId'] as int
                          : 0;
                      SearchMode? searchMode;
                      bool returnResult = false;
                      if (extra is Map<String, dynamic>) {
                        searchType = extra['title'] as String? ?? '';
                        final searchModeValue = extra['searchMode'];
                        if (searchModeValue is SearchMode) {
                          searchMode = searchModeValue;
                        }
                        final returnResultValue = extra['returnResult'];
                        if (returnResultValue is bool) {
                          returnResult = returnResultValue;
                        }
                      } else if (extra is String) {
                        searchType = extra;
                      }
                      return SearchRoomsPage(
                        searchType: searchType,
                        categoryId: categoryId,
                        searchMode: searchMode,
                        returnResult: returnResult,
                      );
                    },
                  ),
                  GoRoute(
                    path: "searchResult",
                    builder: (context, state) {
                      final extra = state.extra;
                      String searchKeyword = '';
                      final int categoryId =
                          extra is Map<String, dynamic> &&
                              extra['categoryId'] is int
                          ? extra['categoryId'] as int
                          : 0;
                      SearchMode? searchMode;
                      bool returnResult = false;
                      if (extra is Map<String, dynamic>) {
                        searchKeyword = extra['title'] as String? ?? '';
                        final searchModeValue = extra['searchMode'];
                        if (searchModeValue is SearchMode) {
                          searchMode = searchModeValue;
                        }
                        final returnResultValue = extra['returnResult'];
                        if (returnResultValue is bool) {
                          returnResult = returnResultValue;
                        }
                      } else if (extra is String) {
                        searchKeyword = extra;
                      }
                      return SearchResultPage(
                        searchKeyword: searchKeyword,
                        categoryId: categoryId,
                        searchMode: searchMode,
                        returnResult: returnResult,
                      );
                    },
                  ),
                ],
              ),
              // 경로 선택 페이지 (길찾기)
              GoRoute(
                path: "pathSelection",
                builder: (context, state) => PathSelectionPage(),
              ),
              GoRoute(
                path: "navi",
                builder: (context, state) => const NaviPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
