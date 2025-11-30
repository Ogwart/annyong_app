import 'dart:async';
import 'dart:io';

import 'package:annyong/domain/entity/calibration_route.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/calibration_service.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // widget.startPoi 대신 내부 상태로 관리하여 재선택 시 업데이트 가능하게 함
  Poi? _targetPoi;

  CalibrationRoute? _route;
  bool _isLoading = true;
  String? _errorMessage;
  int _stepCount = 0; // 측정 중 이동한 걸음수
  int _initialStepCount = 0; // 측정 시작 시점의 걸음수
  StreamSubscription<StepCount>? _stepCountSubscription;
  bool _isStepCountAvailable = false;
  String? _stepCountError;

  @override
  void initState() {
    super.initState();
    // 초기 타겟 설정
    _targetPoi = widget.startPoi;

    _requestPermissionAndInit();
    if (widget.startPoi != null) {
      _findRoute();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "출발 지점이 선택되지 않았습니다.";
      });
    }
  }

  @override
  void dispose() {
    _stepCountSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissionAndInit() async {
    // Android에서 활동 인식 권한 요청
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();

      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) {
          setState(() {
            _isStepCountAvailable = false;
            _stepCountError = "걸음수 측정을 위해 활동 인식 권한이 필요합니다.\n설정에서 권한을 허용해주세요.";
          });
        }
        return;
      }
    }

    // 권한이 허용되었거나 iOS인 경우 pedometer 초기화
    await _initPedometer();
  }

  Future<void> _initPedometer() async {
    try {
      // 현재 걸음수 가져오기 (첫 번째 이벤트로 초기값 설정)
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          if (mounted) {
            setState(() {
              // 첫 번째 이벤트면 초기값으로 설정
              if (_initialStepCount == 0) {
                _initialStepCount = event.steps;
                _isStepCountAvailable = true;
              }

              // 측정 시작 후 이동한 걸음수 = 현재 걸음수 - 시작 시점 걸음수
              _stepCount = event.steps - _initialStepCount;
              if (_stepCount < 0) {
                _stepCount = 0; // 음수 방지
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isStepCountAvailable = false;
              _stepCountError =
                  "걸음수 측정 중 오류: $error\n권한을 확인하거나 실제 기기에서 실행해주세요.";
            });
          }
        },
        cancelOnError: false,
      );

      // 스트림이 이벤트를 발생시키지 않는 경우를 대비해 타임아웃 설정
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_isStepCountAvailable && _stepCountError == null) {
          setState(() {
            _stepCountError =
                "걸음수 측정이 시작되지 않았습니다.\n권한을 확인하거나 기기를 움직여보세요.\n(시뮬레이터에서는 작동하지 않습니다)";
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStepCountAvailable = false;
          _stepCountError = "걸음수 측정 초기화 실패: $e\n실제 기기에서 실행해주세요.";
        });
      }
    }
  }

  Future<void> _findRoute() async {
    // _targetPoi가 없으면 실행하지 않음
    if (_targetPoi == null) return;

    try {
      debugPrint("----------- [_findRoute Start] ----------- ");
      debugPrint(
        "경로 탐색 시작: Start POI = ${widget.startPoi?.name} (ID: ${widget.startPoi?.id})",
      );

      // widget.startPoi 대신 _targetPoi 사용
      final route = await _calibrationService.findTargetRoute(_targetPoi!);
      setState(() {
        _route = route;
        _isLoading = false;
        if (route == null) {
          // 측정 불가용 UX 화면을 보여주기 위해 _errorMessage를 명시적으로 비워둠
          // _errorMessage = "측정 가능한 경로를 찾을 수 없습니다.\n콘솔 로그를 확인해주세요.";
          _errorMessage = null;
        }
      });
    } catch (e, stackTrace) {
      debugPrint("[Error] 경로 탐색 중 치명적 에러 발생: $e");
      debugPrint(" -- 스택 트레이스: $stackTrace"); // 에러 파일 위치 디버깅용

      setState(() {
        _isLoading = false;
        _errorMessage = "경로 탐색 중 오류가 발생했습니다: $e";
      });
    }
    debugPrint("----------- [_findRoute End] ----------- ");
  }

  Future<void> _goToResultPage(double strideLength) async {
    // 결과 페이지로 이동하고, 사용자가 '확인'을 눌러서 pop될 때까지 대기
    await context.push("/measure/measureResult", extra: strideLength);

    // 결과 페이지가 닫히면(측정 완료), 홈으로 이동
    if (mounted) {
      context.go("/home");
    }
  }

  void _onArrived() {
    if (_route == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("경로 정보가 없습니다.")));
      return;
    }

    if (_stepCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("걸음수가 0입니다. 이동 후 다시 시도해주세요.")),
      );
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
      appBar: AppBar(title: const Text("보폭 측정"), centerTitle: true),
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
                      onPressed: () {
                        if (mounted) {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go("/home");
                          }
                        }
                      },
                      child: const Text("돌아가기"),
                    ),
                  ],
                ),
              ),
            )
          : _route == null
          // -------------------- [예외처리용 화면] --------------------
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 상단 실패 아이콘 (정상 화면과 위치 통일)
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.grey200,
                        ),
                        child: Icon(
                          Icons.straighten_outlined,
                          size: 48,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),

                  // 설명 문구 (정상 화면의 경로 정보와 비슷한 위치)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        const Text(
                          "직선 경로를 찾기 어려워요",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "선택하신 '${widget.startPoi?.name ?? '위치'}' 주변에는\n도착지로 삼을만한 시설물이 부족합니다.\n다른 장소를 선택하거나 기본값을 사용해주세요.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 버튼을 아래로 밀어내기 위해 하단 여백 채우기
                  const Spacer(),

                  // 선택지 제공 버튼: 기본값(0.7m) 설정
                  GestureDetector(
                    onTap: () {
                      _goToResultPage(0.7);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(40), // 둥근 모서리 통일
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "기본 보폭(70cm)으로 설정",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 재시도 옵션 (다른 출발지 선택)
                  TextButton(
                    onPressed: () async {
                      if (mounted) {
                        // POI 선택 페이지로 이동하여 결과를 기다림
                        final selectedPoi = await context.push<Poi>(
                          "/measureSelectPoi",
                          extra: {"returnResult": true},
                        );

                        // 선택된 POI가 있으면 상태 업데이트 및 재탐색
                        if (selectedPoi != null && mounted) {
                          setState(() {
                            _targetPoi = selectedPoi;
                            _isLoading = true; // 로딩 표시
                            _errorMessage = null; // 에러 초기화
                            _route = null; // 기존 경로 초기화
                          });
                          _findRoute(); // 재탐색 실행
                        }
                      }
                    },
                    child: Text(
                      "다른 출발지 선택하기",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40), // 하단 여백
                ],
              ),
            )
          // -------------------- [정상 보폭 측정용 화면] --------------------
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
                          _route!.destinationPoi.description == null
                              ? "설명 없음"
                              : "${_route!.destinationPoi.description}",
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
                  // --------------------걸음수 표시--------------------
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (_stepCountError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _stepCountError!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.red,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Row(
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.grey200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _stepCount.toString(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!_isStepCountAvailable)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              "걸음수 측정을 사용할 수 없습니다.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
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
                      if (context.mounted) {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go("/home");
                        }
                      }
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
