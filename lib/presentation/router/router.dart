import 'package:annyong/presentation/ui/measure/measure_notice_page.dart';
import 'package:annyong/presentation/ui/measure/measure_page.dart';
import 'package:annyong/presentation/ui/measure/measure_result_page.dart';
import 'package:annyong/presentation/ui/menu/bookmark_page.dart';
import 'package:annyong/presentation/ui/home/home_page.dart';
import 'package:annyong/presentation/ui/menu/menu_page.dart';
import 'package:annyong/presentation/ui/path/path_selection_page.dart';
import 'package:annyong/presentation/ui/path/path_result_page.dart';
import 'package:annyong/presentation/ui/path/path_navi_page.dart';
import 'package:annyong/presentation/ui/search/search_page.dart';
import 'package:annyong/presentation/ui/search/search_result_page.dart';
import 'package:annyong/presentation/ui/search/search_rooms_page.dart';
import 'package:annyong/presentation/ui/menu/settings_page.dart';
import 'package:annyong/presentation/ui/splash/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:annyong/domain/entity/poi.dart';

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
      ),
      // 측정용 POI 선택 페이지 (ShellRoute 밖에서 접근 가능)
      GoRoute(
        path: "/measureSelectPoi",
        builder: (context, state) {
          SearchMode? searchMode;
          bool returnResult = false;
          List<Poi>? nearPois;
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
            final nearPoisValue = extra['nearPois'];
            if (nearPoisValue is List<Poi>) {
              nearPois = nearPoisValue;
            }
          }
          return SearchPage(
            searchMode: searchMode,
            returnResult: returnResult,
            nearPois: nearPois,
          );
        },
        routes: [
          GoRoute(
            path: "searchRooms",
            builder: (context, state) {
              final extra = state.extra;
              String searchType = '';
              final int categoryId =
                  extra is Map<String, dynamic> && extra['categoryId'] is int
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
                  extra is Map<String, dynamic> && extra['categoryId'] is int
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
      // 측정 페이지
      GoRoute(
        path: "/measure",
        builder: (context, state) {
          final extra = state.extra;
          final Poi? startPoi = extra is Poi ? extra : null;
          return MeasurePage(startPoi: startPoi);
        },
        routes: [
          GoRoute(
            path: "measureResult",
            builder: (context, state) {
              final extra = state.extra;
              final double? strideLength = extra is double ? extra : null;
              return MeasureResultPage(strideLength: strideLength);
            },
          ),
        ],
      ),
      // 홈 페이지, 메뉴 페이지, 검색 페이지
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
              // 길찾기 관련 페이지
              GoRoute(
                path: "pathSelection",
                builder: (context, state) => PathSelectionPage(),
                routes: [
                  GoRoute(
                    path: "pathResult",
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>;
                      final Poi start = extra['start'] as Poi;
                      final Poi end = extra['end'] as Poi;

                      return PathResultPage(
                        start: start,
                        end: end,
                        waypoints:
                            (extra['waypoints'] as List<dynamic>?)
                                ?.cast<Poi>() ??
                            [],
                      );
                    },
                  ),
                  GoRoute(
                    path: "pathNavi",
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>;
                      final Poi start = extra['start'] as Poi;
                      final Poi end = extra['end'] as Poi;

                      final List<int>? preCalculatedPath =
                          extra['preCalculatedPath'] as List<int>?;
                      final double? preCalculatedCost =
                          extra['preCalculatedCost'] as double?;

                      return PathNaviPage(
                        start: start,
                        end: end,
                        waypoints:
                            (extra['waypoints'] as List<dynamic>?)
                                ?.cast<Poi>() ??
                            [],
                        preCalculatedPath: preCalculatedPath,
                        preCalculatedCost: preCalculatedCost,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
