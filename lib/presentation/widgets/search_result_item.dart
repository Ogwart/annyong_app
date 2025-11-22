import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class SearchResultItem extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onSelect;
  final int categoryId;
  final bool isCanNavigation; // 길찾기 지원 여부

  const SearchResultItem({
    super.key,
    required this.title,
    required this.description,
    required this.onSelect,
    required this.categoryId,
    this.isCanNavigation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 장소 이름
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 4),
                // 장소 설명
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.text,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            // isAvailable이 false면 onTap에 null을 주어 클릭 자체가 안 되게 함 (무응답)
            onTap: () {
              if (isCanNavigation) {
                onSelect();
              } else {
                Fluttertoast.showToast(msg: "죄송합니다. 길찾기가 지원되지 않는 장소입니다.");
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                // isAvailable 여부에 따라 색상 변경: 활성화 시 primary, 비활성화 시 grey400
                color: isCanNavigation
                    ? AppColors.primary
                    : AppColors.secondary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '선택',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Pretendard',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
