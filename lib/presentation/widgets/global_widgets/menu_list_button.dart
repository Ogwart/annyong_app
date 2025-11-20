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
    return GestureDetector(
      onTap: () {
        context.go(routePath);
      },
      behavior: HitTestBehavior.opaque,
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
