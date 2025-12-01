import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'package:flutter/material.dart';

class FloorButtonData {
  final String floor;
  final bool isSelected;
  final VoidCallback? onTap;

  const FloorButtonData({
    required this.floor,
    required this.isSelected,
    this.onTap,
  });
}

class MapPreview extends StatelessWidget {
  final List<FloorButtonData> floorButtons;

  const MapPreview({super.key, required this.floorButtons});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.grey200,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        Positioned(
          top: 40,
          right: 32,
          child: Column(
            children: [
              for (var i = 0; i < floorButtons.length; i++) ...[
                FloorButton(
                  floor: floorButtons[i].floor,
                  isSelected: floorButtons[i].isSelected,
                  onTap: floorButtons[i].onTap ?? () {},
                ),
                if (i != floorButtons.length - 1) const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
