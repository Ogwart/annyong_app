import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';

class FloorButton extends StatelessWidget {
  final String floor;
  final bool isSelected;
  final VoidCallback onTap;

  const FloorButton({
    super.key,
    required this.floor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.grey200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              floor,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.text,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
