import 'package:annyong/domain/usecases/stride_service.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MeasureResultPage extends StatefulWidget {
  final double? strideLength;

  const MeasureResultPage({super.key, this.strideLength});

  @override
  State<MeasureResultPage> createState() => _MeasureResultPageState();
}

class _MeasureResultPageState extends State<MeasureResultPage> {
  @override
  void initState() {
    super.initState();
    _saveStrideLengthIfValid();
  }

  Future<void> _saveStrideLengthIfValid() async {
    final double stride = widget.strideLength ?? 0.0;
    if (stride > 0) {
      // 유효한 보폭이면 저장
      await StrideService.saveStrideLength(stride);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double stride = widget.strideLength ?? 0.0;
    final bool isValid = stride > 0; // 0보다 큰 값만 유효

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text("측정 결과")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --------------------결과 아이콘--------------------
            Container(
              padding: const EdgeInsets.all(40),
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isValid
                    ? AppColors.primary.withAlpha(10)
                    : Colors.red.withAlpha(10),
              ),
              child: Icon(
                isValid ? Icons.check_circle : Icons.error,
                size: 60,
                color: isValid ? AppColors.primary : Colors.red,
              ),
            ),
            const SizedBox(height: 32),
            // --------------------결과 텍스트--------------------
            Text(
              isValid ? "측정 완료!" : "측정 오류",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 24,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            if (isValid)
              Column(
                children: [
                  Text(
                    "당신의 보폭은",
                    style: TextStyle(fontSize: 18, color: AppColors.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${stride.toStringAsFixed(2)}m",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 48,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Text(
                    "측정 결과가 올바르지 않습니다.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "다시 측정해주세요.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            const Spacer(),
            // --------------------확인 버튼--------------------
            GestureDetector(
              onTap: () {
                context.pop();
              },
              child: Container(
                alignment: Alignment.center,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Text(
                  "확인",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
