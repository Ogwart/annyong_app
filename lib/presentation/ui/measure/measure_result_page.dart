import 'package:annyong/domain/usecases/stride_service.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MeasureResultPage extends StatefulWidget {
  // 이전 페이지에서 전달받은 측정 데이터 (Map형태로 전달받음)
  // extra: {"walkedSteps": int, "totalDistance": double}
  final int walkedSteps;
  final double totalDistance;

  const MeasureResultPage({
    super.key,
    required this.walkedSteps,
    required this.totalDistance,
  });

  @override
  State<MeasureResultPage> createState() => _MeasureResultPageState();
}

class _MeasureResultPageState extends State<MeasureResultPage> {
  late double _calculatedStride; // 계산된 보폭 (미터)
  bool _isValid = false; // 측정값 유효성 여부
  double? _prevStride; // 이전에 저장된 보폭 값

  @override
  void initState() {
    super.initState();
    // 1. 보폭 계산 및 유효성 검사 실행
    _calculateAndValidate();
    // 2. 기존 저장값 불러오기 (비교 표시용)
    _loadPrevStride();
  }

  /// 보폭 계산 로직
  void _calculateAndValidate() {
    // 걸음수가 0이면 계산 불가
    if (widget.walkedSteps == 0) {
      _calculatedStride = 0.0;
      _isValid = false;
      return;
    }

    // 보폭 = 총 이동 거리 / 걸음 수
    _calculatedStride = widget.totalDistance / widget.walkedSteps;

    // [유효성 검사 조건]
    // 1. 보폭이 0.45m ~ 0.95m 사이여야 함
    // 2. 최소 7걸음 이상 걸었어야 함 (너무 짧으면 오차 큼)
    if (_calculatedStride >= 0.45 &&
        _calculatedStride <= 0.95 &&
        widget.walkedSteps >= 7) {
      _isValid = true;
    } else {
      _isValid = false;
    }
  }

  /// 이전에 저장된 보폭 불러오기
  Future<void> _loadPrevStride() async {
    final prev = await StrideService.getStrideLength();
    setState(() {
      _prevStride = prev;
    });
  }

  /// 보폭 저장 후 종료 처리
  Future<void> _saveStrideAndExit() async {
    // SharedPreferences에 저장
    await StrideService.saveStrideLength(_calculatedStride);

    if (!mounted) return;

    // 2. 홈 화면으로 이동
    // (GoRouter를 사용 중이므로 go("/home")을 호출)
    context.go("/home");
  }

  @override
  Widget build(BuildContext context) {
    // cm 단위 변환 (소수점 없이 표시)
    final strideCm = (_calculatedStride * 100).toStringAsFixed(0);
    final prevCm = _prevStride != null
        ? (_prevStride! * 100).toStringAsFixed(0)
        : "?";

    return Scaffold(
      appBar: AppBar(title: const Text("측정 결과"), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // -------------------- 결과 아이콘 --------------------
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _isValid
                      ? Colors.green.withAlpha(10)
                      : Colors.red.withAlpha(10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isValid
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  size: 60,
                  color: _isValid ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 24),

              // -------------------- 결과 텍스트 분기 --------------------
              if (_isValid) ...[
                // [정상 범위일 때]
                const Text(
                  "측정 완료!",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  "당신의 보폭은 ${strideCm}cm예요",
                  style: const TextStyle(
                    fontSize: 20,
                    color: AppColors.primary,
                  ),
                ),
                if (_prevStride != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "이전 값 ${prevCm}cm → 이번 ${strideCm}cm",
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
              ] else ...[
                // [비정상 범위일 때]
                const Text(
                  "측정값이 비정상적이에요",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "보폭: ${strideCm}cm (${widget.walkedSteps}보)",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "걸음 수가 너무 적거나(7보 미만),\n보폭이 너무 크거나 작습니다.\n다시 한 번 걸어보시는 걸 추천드려요!\n일반적인 보폭은 0.45m ~ 0.95m예요.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],

              const Spacer(),

              // -------------------- 하단 버튼 영역 --------------------
              if (_isValid)
                // 정상 -> 바로 저장 가능
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveStrideAndExit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "저장하기",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                )
              else
                // 비정상 -> 다시 측정(권장) or 강제 저장
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        // pop 할 때 true 값을 전달하여 재측정임을 알림
                        // 그냥 뒤로 가버리면 이전 걸음 수가 그대로 남아있어 재측정의 의미가 없음
                        onPressed: () => context.pop(true),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "다시 측정하기",
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _saveStrideAndExit, // 그래도 저장 로직 수행
                      child: const Text(
                        "그래도 저장할래요",
                        style: TextStyle(
                          color: Colors.grey,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
