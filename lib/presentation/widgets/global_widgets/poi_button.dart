import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PoiButton extends StatelessWidget {
  final String bookmarkTitle;
  final bool showTitle;
  final bool isFavorite;

  const PoiButton({
    super.key,
    required this.bookmarkTitle,
    this.showTitle = false,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    // 즐겨찾기이거나 제목을 표시하지 않는 경우 (축소 상태)
    if (isFavorite) {
      return Container(
        alignment: Alignment.center,
        height: 30,
        width: 30,
        decoration: BoxDecoration(
          color: isFavorite ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(48),
          border: Border.all(
            color: isFavorite ? Colors.white : AppColors.primary,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isFavorite ? Icons.star_rounded : Icons.location_on,
          color: isFavorite ? Colors.white : AppColors.primary,
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: BoxBorder.all(color: AppColors.primary, width: 2),
          ),
          child: const Icon(
            Icons.location_on,
            color: AppColors.primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 4),
        Stack(
          children: [
            // 외곽선 텍스트 (Stroke)
            Text(
              bookmarkTitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = Colors.white,
              ),
            ),
            // 실제 텍스트 (Fill)
            Text(
              bookmarkTitle,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
