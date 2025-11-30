import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/entity/poi_category.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/search_page/search_facilities_tile.dart';
import 'package:annyong/presentation/widgets/search_page/search_rooms_tile.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum SearchMode { normal, departure, destination, waypoint1, waypoint2 }

class SearchPage extends StatefulWidget {
  final SearchMode? searchMode;
  final bool returnResult;
  final List<Poi>? nearPois;

  const SearchPage({
    super.key,
    this.searchMode,
    this.returnResult = false,
    this.nearPois,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _sectionTitleStyle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 16,
  );

  final PoiRepository _poiRepository = PoiRepository();
  List<PoiCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _poiRepository.fetchCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 공간 카테고리만 필터링 (id가 1, 2, 3인 카테고리)
  List<PoiCategory> _getRoomCategories() {
    return _categories.where((c) => c.id <= 3).toList();
  }

  // 시설물 카테고리만 필터링 (id가 4 이상인 카테고리)
  List<PoiCategory> _getFacilityCategories() {
    return _categories.where((c) => c.id > 3).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final roomCategories = _getRoomCategories();
    final facilityCategories = _getFacilityCategories();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("시설물 검색", style: TextStyle(fontSize: 24)),
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios),
            color: AppColors.text,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 위치 기반 인접 POI 추천 섹션
              if (widget.nearPois != null && widget.nearPois!.isNotEmpty) ...[
                const Text('위치 기반 인접 POI 추천', style: _sectionTitleStyle),
                const SizedBox(height: 12),
                ...widget.nearPois!.asMap().entries.map((entry) {
                  final poi = entry.value;
                  final buildingList = ["5서", "5남", "하"];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "POI ${poi.id}: ${buildingList[poi.buildingId - 1]}에 위치, ${poi.description ?? ""}",
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (widget.returnResult) {
                              context.pop(poi);
                            } else {
                              context.pop(); // 일반 검색 모드에서는 다른 동작 수행
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('선택'),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
              ],
              const Text('공간', style: _sectionTitleStyle),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true, // 내용물 크기만큼만 높이 차지
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: roomCategories.length,
                itemBuilder: (context, index) {
                  final category = roomCategories[index];
                  return SearchRoomsTile(
                    title: category.name,
                    categoryId: category.id,
                    searchMode: widget.searchMode,
                    returnResult: widget.returnResult,
                  );
                },
              ),

              const SizedBox(height: 20),

              // 시설물 섹션
              const Text('시설물', style: _sectionTitleStyle),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true, // 내용물 크기만큼만 높이 차지
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: facilityCategories.length,
                itemBuilder: (context, index) {
                  final category = facilityCategories[index];
                    return SearchFacilitiesTile(
                    title: category.name,
                    categoryId: category.id,
                    searchMode: widget.searchMode,
                    returnResult: widget.returnResult,
                  );
                },
              ),
              // 하단 여백 추가 (스크롤 끝부분 여유)
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }
}
