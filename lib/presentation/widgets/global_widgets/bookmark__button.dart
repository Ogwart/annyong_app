import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';

class BookmarkButton extends StatelessWidget {
  final String bookmarkTitle;
  final VoidCallback? onTap;
  const BookmarkButton({super.key, required this.bookmarkTitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: 12),
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 20),
        alignment: Alignment.center,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(48),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          bookmarkTitle,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}
