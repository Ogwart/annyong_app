import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PoiButton extends StatelessWidget {
  final String bookmarkTitle;
  const PoiButton({super.key, required this.bookmarkTitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      height: 30,
      width: 30,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(Icons.star_rounded, color: Colors.white),
    );
  }
}
