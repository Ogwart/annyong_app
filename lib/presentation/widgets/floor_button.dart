import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';

class FloorButton extends StatefulWidget {
  const FloorButton({
    super.key,
    required this.isSelected,
    required this.floorNumber,
  });

  final bool isSelected;
  final int floorNumber;

  @override
  State<FloorButton> createState() => _FloorButtonState();
}

class _FloorButtonState extends State<FloorButton> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 4),
      alignment: Alignment.center,
      width: 47,
      height: 47,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isSelected ? AppColors.primary : AppColors.grey200,
      ),
      child: Text(
        "${widget.floorNumber}F",
        style: TextStyle(
          color: widget.isSelected ? Colors.white : AppColors.text,
        ),
      ),
    );
  }
}
