import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';

class ResetButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;

  const ResetButton({super.key, required this.onTap, this.label = '초기화'});

  @override
  State<ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends State<ResetButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      // 눌림 상태 관리
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100), // 부드러운 효과
        opacity: _isPressed ? 0.6 : 1.0, // 눌렸을 때 투명도 적용 (흐리게)
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary, // 배경색 파란색으로 변경
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white, // 배경이 파란색이므로 글씨는 흰색
            ),
          ),
        ),
      ),
    );
  }
}
