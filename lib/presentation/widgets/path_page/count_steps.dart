import 'dart:math' as math;
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/viewmodels/navigation_state.dart';
import 'package:flutter/material.dart';

class CountSteps extends StatelessWidget {
  const CountSteps({super.key, required this.state});

  final NavigationState state;

  @override
  Widget build(BuildContext context) {
    final headingDegrees = (state.heading * 180 / math.pi) % 360;
    String directionText;
    if (headingDegrees >= 337.5 || headingDegrees < 22.5) {
      directionText = '북';
    } else if (headingDegrees >= 22.5 && headingDegrees < 67.5) {
      directionText = '북동';
    } else if (headingDegrees >= 67.5 && headingDegrees < 112.5) {
      directionText = '동';
    } else if (headingDegrees >= 112.5 && headingDegrees < 157.5) {
      directionText = '남동';
    } else if (headingDegrees >= 157.5 && headingDegrees < 202.5) {
      directionText = '남';
    } else if (headingDegrees >= 202.5 && headingDegrees < 247.5) {
      directionText = '남서';
    } else if (headingDegrees >= 247.5 && headingDegrees < 292.5) {
      directionText = '서';
    } else {
      directionText = '북서';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.grey200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_walk,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${state.stepCount}걸음',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.navigation, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '$directionText (${headingDegrees.toStringAsFixed(0)}°)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
