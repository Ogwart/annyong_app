import 'package:annyong/domain/entity/poi_category.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/search_page/search_facilities_tile.dart';
import 'package:annyong/presentation/widgets/search_page/search_rooms_tile.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum SearchMode { normal, departure, destination }

class SearchPage extends StatefulWidget {
  final SearchMode? searchMode;
  final bool returnResult;

  const SearchPage({super.key, this.searchMode, this.returnResult = false});

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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('공간', style: _sectionTitleStyle),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: GridView.builder(
                shrinkWrap: true,
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
            ),
            const SizedBox(height: 20),
            const Text('시설물', style: _sectionTitleStyle),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
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
            ),
          ],
        ),
      ),
    );
  }
}
