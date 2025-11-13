import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/entity/poi.dart';
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
import 'package:flutter/foundation.dart';

class SearchResultPage extends ConsumerStatefulWidget {
  final String? searchKeyword;
  final int? categoryId;
  final SearchMode? searchMode;
  final bool returnResult;

  const SearchResultPage({
    super.key,
    this.searchKeyword,
    this.categoryId,
    this.searchMode,
    this.returnResult = false,
  });

  @override
  ConsumerState<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends ConsumerState<SearchResultPage> {
  final PoiRepository _repository = PoiRepository();
  late final Future<List<Poi>> _poiFuture;
  late final String _displayKeyword;

  @override
  void initState() {
    super.initState();
    _displayKeyword = widget.searchKeyword ?? '';
    debugPrint('선택된 키워드: ${_displayKeyword}');
    _poiFuture = _loadPois();
    debugPrint('카테고리 ID: ${widget.categoryId}');

    // 페이지 진입 시 searchKeyword 설정 (한 번만 실행)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SearchResultProvider>();
      provider.setSearchKeyword(_displayKeyword);
    });
  }

  // 실제 POI 데이터를 불러오는 메서드
  Future<List<Poi>> _loadPois() async {
    final pois = await _repository.fetchPois();
    if (widget.categoryId != null) {
      return pois.where((poi) => poi.categoryId == widget.categoryId).toList();
    }
    return pois;
  }

  // POI 선택 처리 핸들러
  void _handlePoiSelect(Poi poi) {
    if (widget.returnResult) {
      context.pop(poi.name);
      return;
    }

    final pathProvider = ref.read(pathSelectionProvider.notifier);
    if (widget.searchMode == SearchMode.departure) {
      pathProvider.setDeparture(poi.name);
    } else if (widget.searchMode == SearchMode.destination) {
      pathProvider.setDestination(poi.name);
    } else {
      pathProvider.setDestination(poi.name);
      context.go('/home/pathSelection');
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SearchResultProvider>();

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
                    child: FutureBuilder<List<Poi>>(
                      future: _poiFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final results = snapshot.data ?? [];
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final poi = results[index];
                            return SearchResultItem(
                              title: poi.name,
                              categoryId: poi.categoryId,
                              description: poi.description ?? '설명 없음',
                              onSelect: () => _handlePoiSelect(poi),
                            );
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
