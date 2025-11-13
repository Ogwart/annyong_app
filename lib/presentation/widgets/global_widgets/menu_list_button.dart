import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MenuListButton extends StatelessWidget {
  const MenuListButton({
    super.key,
    required this.title,
    required this.routePath,
  });

  final String title;
  final String routePath;

  @override
  Widget build(BuildContext context) {
    // 1. GestureDetector가 Container 전체를 감싸도록 변경
    return GestureDetector(
      onTap: () {
        // 2. 절대 경로로 이동하도록 context.go를 호출
        context.go(routePath);
      },
      behavior: HitTestBehavior.opaque, // 빈 공간도 탭이 되도록 설정
      child: InkWell(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 30),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.grey300, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              // 3. 내부 GestureDetector는 제거하고 아이콘만 남김
              SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.grey400,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
