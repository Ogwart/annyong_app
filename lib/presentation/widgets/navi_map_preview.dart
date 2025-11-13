import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'package:flutter/material.dart';

class NaviFloorButtonData {
  final String floor;
  final bool isSelected;
  final VoidCallback? onTap;

  const NaviFloorButtonData({
    required this.floor,
    required this.isSelected,
    this.onTap,
  });
}

class NaviMapPreview extends StatelessWidget {
  final List<NaviFloorButtonData> floorButtons;

  const NaviMapPreview({super.key, required this.floorButtons});

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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.navigation,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }
}

