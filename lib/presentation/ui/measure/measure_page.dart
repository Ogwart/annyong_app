import 'package:annyong/domain/entity/calibration_route.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/calibration_service.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MeasurePage extends StatefulWidget {
  final Poi? startPoi;

  const MeasurePage({super.key, this.startPoi});

  @override
  State<MeasurePage> createState() => _MeasurePageState();
}

class _MeasurePageState extends State<MeasurePage> {
  final CalibrationService _calibrationService = CalibrationService(
    PoiRepository(),
  );

  CalibrationRoute? _route;
  bool _isLoading = true;
  String? _errorMessage;
  int _stepCount = 0; // 걸음수 (임시로 수동 입력, 나중에 pedometer로 대체)

  @override
  void initState() {
    super.initState();
    if (widget.startPoi != null) {
      _findRoute();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "출발 지점이 선택되지 않았습니다.";
      });
    }
  }

  Future<void> _findRoute() async {
    try {
      final route = await _calibrationService.findTargetRoute(widget.startPoi!);
      setState(() {
        _route = route;
        _isLoading = false;
        if (route == null) {
          _errorMessage = "측정 가능한 경로를 찾을 수 없습니다.";
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "경로 탐색 중 오류가 발생했습니다: $e";
      });
    }
  }

  void _onArrived() {
    if (_route == null || _stepCount == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("걸음수를 입력해주세요.")));
      return;
    }

    // 보폭 계산: 총 거리 / 걸음수
    final double strideLength = _route!.totalDistance / _stepCount;

    // 결과 페이지로 이동
    context.push("/measure/measureResult", extra: strideLength);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text("보폭 측정")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text("돌아가기"),
                    ),
                  ],
                ),
              ),
            )
          : _route == null
          ? const Center(child: Text("경로를 찾을 수 없습니다."))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --------------------상단 신발 이미지--------------------
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.grey200,
                      ),
                      child: Image.asset(
                        'assets/icons/steps.png',
                        color: AppColors.primary,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // --------------------경로 정보--------------------
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.grey200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "출발: ${_route!.startPoi.name}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "목적지: ${_route!.destinationPoi.name}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "총 거리: ${_route!.totalDistance.toStringAsFixed(1)}m (${_route!.mode == "one-way" ? "편도" : "왕복"})",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // --------------------안내 텍스트--------------------
                  Text(
                    '목적지까지 이동한 후\n도착 버튼을 눌러주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // --------------------걸음수 입력--------------------
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "걸음수: ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _stepCount = int.tryParse(value) ?? 0;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // --------------------도착 버튼--------------------
                  GestureDetector(
                    onTap: _onArrived,
                    child: Container(
                      alignment: Alignment.center,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Text(
                        "도착",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // --------------------다음에 측정하기 버튼--------------------
                  GestureDetector(
                    onTap: () {
                      context.pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.grey200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '다음에 측정하기',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
    );
  }
}
