import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';

class BookmarkMarker extends StatelessWidget {
  final String bookmarkTitle;
  const BookmarkMarker({super.key, required this.bookmarkTitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
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
      child: Row(
        children: [
          Icon(Icons.star_rounded, color: AppColors.point),
          const SizedBox(width: 4),
          Text(
            bookmarkTitle,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
