import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';

class SearchResultItem extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onSelect;
  final int categoryId;

  const SearchResultItem({
    super.key,
    required this.title,
    required this.description,
    required this.onSelect,
    required this.categoryId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // 간격 조정
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 위쪽 정렬
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 장소 이름
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 6),
                // 설명부분은 단어 단위로 줄바꿈
                Wrap(
                  spacing: 3.0, // 단어 사이 간격
                  runSpacing: 2.0, // 줄 사이 간격
                  children: description.split(' ').map((word) {
                    return Text(
                      word,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                        fontFamily: 'Pretendard',
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 선택 버튼
          GestureDetector(
            onTap: onSelect,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20), // 둥근 버튼
              ),
              child: const Text(
                '선택',
                style: TextStyle(
                  fontSize: 14,
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
