import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/search_page/search_facilities_tile.dart';
import 'package:annyong/presentation/widgets/search_page/search_rooms_tile.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum SearchMode { normal, departure, destination }

class SearchPage extends StatelessWidget {
  final SearchMode? searchMode;
  final bool returnResult;

  const SearchPage({super.key, this.searchMode, this.returnResult = false});

  static const _sectionTitleStyle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 16,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("시설물 검색", style: TextStyle(fontSize: 24)),
        leading: Padding(
          padding: const EdgeInsetsGeometry.symmetric(horizontal: 12),
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
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                children: [
                  SearchRoomsTile(
                    title: '강의실',
                    searchMode: searchMode,
                    returnResult: returnResult,
                  ),
                  SearchRoomsTile(
                    title: '라운지\n교내 카페',
                    searchMode: searchMode,
                    returnResult: returnResult,
                  ),
                  SearchRoomsTile(
                    title: '사무실',
                    searchMode: searchMode,
                    returnResult: returnResult,
                  ),
                ],
              ),
            ),
            const Text('시설물', style: _sectionTitleStyle),
            const SizedBox(height: 12),
            Flexible(
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                children: [
                  SearchFacilitiesTile(
                    title: '엘리베이터\n계단',
                    searchMode: searchMode,
                    returnResult: returnResult,
                  ),
                  SearchFacilitiesTile(
                    title: '화장실',
                    searchMode: searchMode,
                    returnResult: returnResult,
                  ),
                  SearchFacilitiesTile(
                    title: '출입문',
                    searchMode: searchMode,
                    returnResult: returnResult,
                  ),
                  SearchFacilitiesTile(
                    title: '자판기',
                    searchMode: searchMode,
                    returnResult: returnResult,
                  ),
                  SearchFacilitiesTile(
                    title: '정수기',
                    searchMode: searchMode,
                    returnResult: returnResult,
                  ),
                  SearchFacilitiesTile(
                    title: 'ATM\n제세동기',
                    searchMode: searchMode,
                    returnResult: returnResult,
                  ),
                  SearchFacilitiesTile(
                    title: '콘센트',
                    searchMode: searchMode,
                    returnResult: returnResult,
                  ),
                  SearchFacilitiesTile(
                    title: '소화기',
                    searchMode: searchMode,
                    returnResult: returnResult,
                  ),
                  SearchFacilitiesTile(
                    title: '쓰레기통',
                    searchMode: searchMode,
                    returnResult: returnResult,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
