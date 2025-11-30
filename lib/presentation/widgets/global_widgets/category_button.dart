import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';

class CategoryButton extends StatelessWidget {
  final String bookmarkTitle;
  final VoidCallback? onTap;
  final bool isSelected;

  const CategoryButton({
    super.key,
    required this.bookmarkTitle,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: 12),
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 20),
        alignment: Alignment.center,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(48),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          bookmarkTitle,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: isSelected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}
