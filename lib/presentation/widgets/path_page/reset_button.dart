import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';

class ResetButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const ResetButton({super.key, required this.onTap, this.label = '초기화'});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.grey200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}
