import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/global_widgets/menu_list_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            width: double.infinity,
            height: 264,
            decoration: BoxDecoration(color: AppColors.primary),
            child: Column(
              children: [
                // 상단 화살표, 페이지 제목
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        context.pop();
                      },
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.arrow_back_ios, color: Colors.white),
                      ),
                    ),
                    Text(
                      '메뉴',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 50),
                // 보폭 관련 메뉴
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '나의 보폭',
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                        Text(
                          '70cm',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 40,
                          ),
                        ),
                      ],
                    ),
                    // ------------보폭 재측정 버튼------------
                    GestureDetector(
                      onTap: () {
                        // 재측정 화면으로 라우팅
                      },
                      child: Container(
                        alignment: Alignment.center,
                        width: 80,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(48),
                        ),
                        child: Text(
                          '다시 측정',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 즐겨찾기 메뉴
          Padding(
            padding: EdgeInsets.symmetric(vertical: 30, horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "즐겨찾기",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // 즐겨찾기 수정 페이지로 라우팅
                  },
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.settings_outlined),
                  ),
                ),
              ],
            ),
          ),
          // 설정 메뉴
          MenuListButton(title: '즐겨찾기', routePath: '/home/menu/bookmark'),
          MenuListButton(title: '설정', routePath: '/home/menu/settings'),
          //MenuListButton(title: '설정', route: "menu/settings"),
        ],
      ),
    );
  }
}
