import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';

class LocationInputTile extends StatefulWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  final Widget? trailing;

  const LocationInputTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  @override
  State<LocationInputTile> createState() => _LocationInputTileState();
}

class _LocationInputTileState extends State<LocationInputTile> {
  bool _isPressed = false; // 눌림 상태 변수

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      // 눌림 효과를 주기 위해 터치 상황에 따라 _isPressed 관리
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          // 눌림 상태에 따라 테두리 색상 변경
          border: Border.all(
            color: _isPressed ? AppColors.secondary : AppColors.grey200,
            width: 1.0,
          ),
          // 눌림 상태에 따라 그림자 효과 변경
          boxShadow: [
            BoxShadow(
              color: _isPressed
                  ? AppColors.primary.withOpacity(0.25)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(2, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.grey400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.value ?? '선택해주세요',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: widget.value == null
                          ? AppColors.grey400
                          : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}
