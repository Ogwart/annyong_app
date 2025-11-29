import 'package:annyong/domain/usecases/stride_service.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/global_widgets/menu_list_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: StrideService.getStrideLength(),
      builder: (context, snapshot) {
        final strideLength = snapshot.data ?? 0.7; // 기본값 70cm

        return Scaffold(
          body: Column(
            children: [
              // 상단 보폭 메뉴
              Container(
                padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                width: double.infinity,
                height: 264,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 16,
                      offset: Offset(0, 4),
                      color: Colors.black.withAlpha(25),
                    ),
                  ],
                  color: AppColors.primary,
                ),
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
                            child: Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                            ),
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              '${(strideLength * 100).toStringAsFixed(0)}cm',
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
                            context.push('/measureNotice');
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
              // 설정 메뉴
              MenuListButton(title: '즐겨찾기', routePath: '/home/menu/bookmark'),
              MenuListButton(title: '설정', routePath: '/home/menu/settings'),
              //MenuListButton(title: '설정', route: "menu/settings"),
            ],
          ),
        );
      },
    );
  }
}
