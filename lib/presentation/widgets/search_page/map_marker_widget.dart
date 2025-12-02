import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MapMarkerWidget extends StatelessWidget {
  final bool isSelected;
  final String poiName;
  final String markerSvgPath = 'assets/icons/svg/general_marker.svg';

  const MapMarkerWidget({
    super.key,
    required this.isSelected,
    required this.poiName,
  });

  @override
  Widget build(BuildContext context) {
    final double scale = isSelected ? 1.1 : 1.0; // 선택 시 10% 더 커지게끔 비율 설정
    const double size = 35.0; // 마커 기본 크기

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 마커 아이콘 부분
        AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.5) // 선택: 파란색 그림자
                      : Colors.black.withOpacity(0.2), // 미선택: 연회색 그림자
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 4),
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            child: SvgPicture.asset(markerSvgPath),
          ),
        ),

        // 선택되었을 때만 하단에 이름 표시 (검은 글씨에 흰색 테두리)
        if (isSelected)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Stack(
              children: [
                Text(
                  poiName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth =
                          3.0 // 테두리 두께
                      ..color = Colors.white, // 테두리 색상
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  poiName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text, // 글자 색상
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
