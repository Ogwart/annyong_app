import 'package:annyong/presentation/providers/search_result_provider.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/ui/search/search_page.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'package:annyong/presentation/widgets/search_result_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class SearchResultPage extends ConsumerStatefulWidget {
  final String searchKeyword;
  final SearchMode? searchMode;
  final bool returnResult;

  const SearchResultPage({
    super.key,
    required this.searchKeyword,
    this.searchMode,
    this.returnResult = false,
  });

  @override
  ConsumerState<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends ConsumerState<SearchResultPage> {
  @override
  void initState() {
    super.initState();
    // 페이지 진입 시 searchKeyword 설정 (한 번만 실행)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SearchResultProvider>();
      provider.setSearchKeyword(widget.searchKeyword);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SearchResultProvider>();

    // 임시 데이터 - 나중에 실제 데이터로 교체
    final List<Map<String, String>> searchResults = [
      {'title': '장소 이름 1', 'description': '장소와 관련된 설명 등'},
      {'title': '장소 이름 2', 'description': '장소와 관련된 설명 등'},
      {'title': '장소 이름 3', 'description': '장소와 관련된 설명 등'},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 지도 영역 (상단 60%)
          Column(
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  color: Colors.white,
                  child: Stack(
                    children: [
                      // 지도 플레이스홀더 (실제 지도는 나중에 추가)
                      Container(color: Colors.white),
                      // 뒤로가기 버튼
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(
                              Icons.arrow_back_ios,
                              color: AppColors.text,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      // 사용자 위치 표시 아이콘
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(right: 120, bottom: 80),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.navigation,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      // 층 선택 버튼 (오른쪽 하단, 하단 패널 위에 배치)
                      Positioned(
                        bottom: MediaQuery.of(context).size.height * 0.4 + 20,
                        right: 20,
                        child: Column(
                          children: [
                            FloorButton(
                              floor: '2F',
                              isSelected: provider.selectedFloor == '2F',
                              onTap: () {
                                provider.setSelectedFloor('2F');
                              },
                            ),
                            const SizedBox(height: 8),
                            FloorButton(
                              floor: '1F',
                              isSelected: provider.selectedFloor == '1F',
                              onTap: () {
                                provider.setSelectedFloor('1F');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 검색 결과 패널 (하단 40%)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.4,
              decoration: BoxDecoration(
                color: AppColors.grey200,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // 패널 드래그 핸들
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grey400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 검색 결과 리스트
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final result = searchResults[index];
                        return SearchResultItem(
                          title: result['title']!,
                          description: result['description']!,
                          onSelect: () {
                            if (widget.returnResult) {
                              context.pop(result['title']!);
                              return;
                            }

                            final pathProvider =
                                ref.read(pathSelectionProvider.notifier);
                            if (widget.searchMode == SearchMode.departure) {
                              pathProvider.setDeparture(result['title']);
                            } else if (widget.searchMode ==
                                SearchMode.destination) {
                              pathProvider.setDestination(result['title']);
                            } else {
                              // 기본 모드: 목적지로 설정하고 path_selection으로 이동
                              pathProvider.setDestination(result['title']);
                              context.go('/home/pathSelection');
                              return;
                            }
                            // 출발지/목적지 모드: path_selection으로 돌아가기
                            context.pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
