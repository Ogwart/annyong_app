import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/util/icon_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PoiButton extends StatelessWidget {
  final Poi poi;
  final bool showTitle;
  final bool isFavorite;

  const PoiButton({
    super.key,
    required this.poi,
    this.showTitle = false,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    // 즐겨찾기이거나 제목을 표시하지 않는 경우 (축소 상태)
    if (isFavorite) {
      return Column(
        children: [
          Container(
            alignment: Alignment.center,
            height: 35,
            width: 35,
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
          ),
          Stack(
            children: [
              // 외곽선 텍스트 (Stroke)
              Text(
                poi.name,
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
                poi.name,
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

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 4),
            ],
          ),
          child: SvgPicture.asset(
            "assets/icons/svg/${iconPath(poi)}.svg",
            width: 35,
            height: 35,
          ),
        ),
        const SizedBox(width: 4),
        ?showTitle == true
            ? Stack(
                children: [
                  // 외곽선 텍스트 (Stroke)
                  Text(
                    poi.name,
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
                    poi.name,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            : null,
      ],
    );
  }
}
