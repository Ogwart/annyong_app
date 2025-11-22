import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart'; // Toast 메시지 사용을 위해 추가

class SelectedCategoryFlag extends StatelessWidget {
  const SelectedCategoryFlag({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          height: 3,
          width: 30,
          decoration: BoxDecoration(
            color: AppColors.text,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryBox extends StatelessWidget {
  const CategoryBox({super.key, required this.categoryName});

  final String categoryName;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      height: 50,
      child: Text(
        categoryName,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
          fontFamily: 'Pretendard',
        ),
      ),
    );
  }
}

class CategoryItem extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryItem({
    super.key,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: isSelected ? AppColors.primary : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: isSelected ? Colors.white : AppColors.text,
            fontFamily: 'Pretendard',
          ),
        ),
      ),
    );
  }
}

class CategoryItemRooms extends StatelessWidget {
  final String name;
  final bool isSelected;
  final bool isCanNavigation; // 길찾기 지원 여부
  final VoidCallback onTap;

  const CategoryItemRooms({
    super.key,
    required this.name,
    required this.isSelected,
    required this.isCanNavigation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isCanNavigation) {
          onTap();
        } else {
          // 미지원 장소 클릭 시 토스트 메시지 출력
          Fluttertoast.showToast(msg: "죄송합니다. 길찾기가 지원되지 않는 장소입니다.");
        }
      },
      child: Container(
        // 선택됨: Primary, 미지원: Grey300, 기본: White
        color: isSelected
            ? AppColors.primary
            : (isCanNavigation ? Colors.white : AppColors.grey200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            // 선택됨: White, 나머지: Text Color
            color: isSelected ? Colors.white : AppColors.text,
            fontFamily: 'Pretendard',
          ),
        ),
      ),
    );
  }
}
