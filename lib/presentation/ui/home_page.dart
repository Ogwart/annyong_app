import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/bookmark__button.dart';
import 'package:annyong/presentation/widgets/floor_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              alignment: AlignmentGeometry.center,
              children: [
                // 시설물 검색
                Positioned(
                  top: 10,
                  child: Row(
                    children: [
                      // ------------------메뉴 드로우어 버튼------------------
                      GestureDetector(
                        onTap: () {
                          context.go('/home/menu');
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: AppColors.grey200,
                          ),
                          child: Icon(Icons.menu, color: AppColors.text),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ------------------시설물 검색 버튼------------------
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 200,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: AppColors.grey200,
                          ),
                          child: Text(
                            "시설물 검색",
                            style: TextStyle(
                              fontFamily: "Pretendard",
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ------------------길찾기 버튼------------------
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 80,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: AppColors.primary,
                          ),
                          child: Text(
                            "길찾기",
                            style: TextStyle(
                              fontFamily: "Pretendard",
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 즐겨찾기
                Positioned(
                  top: 80,
                  left: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      BookmarkButton(bookmarkTitle: '5남102'),
                      BookmarkButton(bookmarkTitle: '5서 202'),
                      BookmarkButton(bookmarkTitle: '생명과학과 학생회실'),
                    ],
                  ),
                  // 데이터 생기면 즐겨찾기 부분 리스트뷰로 변경
                  // child: ListView.builder(
                  //   scrollDirection: Axis.horizontal,
                  //   itemCount: 2,
                  //   itemBuilder: (BuildContext context, int index) {
                  //     return BookmarkButton(bookmarkTitle: "5북102");
                  //   },
                  // ),
                ),
                // 건물 전환 버튼
                Positioned(
                  bottom: 20,
                  left: 0,
                  child: GestureDetector(
                    onTap: () {
                      // provider 활용해서 지도 현재 상태 바꿔주기
                    },
                    child: Container(
                      alignment: Alignment.center,
                      width: 70,
                      height: 47,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.grey200,
                      ),
                      child: Text(
                        '5호관',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
                // 층 전환 버튼
                Positioned(
                  bottom: 20,
                  right: 0,
                  child: Column(
                    children: [
                      FloorButton(isSelected: true, floorNumber: 2),
                      FloorButton(isSelected: false, floorNumber: 1),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
