import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("시설물 검색", style: TextStyle(fontSize: 24)),
        leading: Padding(
          padding: EdgeInsetsGeometry.symmetric(horizontal: 12),
          child: IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '공간',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: GridView(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                children: [
                  SearchRoomsTile(title: '강의실'),
                  SearchRoomsTile(title: '라운지\n교내 카페'),
                  SearchRoomsTile(title: '동아리방\n사무실'),
                ],
              ),
            ),
            Text(
              '시설물',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: GridView(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                children: [
                  SearchFacilitiesTile(title: '엘리베이터\n계단'),
                  SearchFacilitiesTile(title: '화장실'),
                  SearchFacilitiesTile(title: '자판기'),
                  SearchFacilitiesTile(title: '정수기'),
                  SearchFacilitiesTile(title: '프린트'),
                  SearchFacilitiesTile(title: 'ATM'),
                  SearchFacilitiesTile(title: '콘센트'),
                  SearchFacilitiesTile(title: '소화기'),
                  SearchFacilitiesTile(title: '제세동기'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchRoomsTile extends StatelessWidget {
  const SearchRoomsTile({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        alignment: Alignment.center,
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.grey200,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class SearchFacilitiesTile extends StatelessWidget {
  const SearchFacilitiesTile({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        alignment: Alignment.center,
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.grey200,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
