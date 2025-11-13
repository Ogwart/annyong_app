import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';

class NaviAddWaypointButton extends StatelessWidget {
  final VoidCallback onTap;

  const NaviAddWaypointButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(Icons.add_circle, color: AppColors.primary, size: 28),
    );
  }
}

