import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:annyong/domain/entity/calibration_route.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/calibration_service.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
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

  // 지도를 확대/이동하기 위한 컨트롤러
  final TransformationController _transformationController =
      TransformationController();

  CalibrationRoute? _route;
  bool _isLoading = true;
  String? _errorMessage;
  int _stepCount = 0; // 측정 중 이동한 걸음수
  int _initialStepCount = 0; // 측정 시작 시점의 걸음수
  StreamSubscription<StepCount>? _stepCountSubscription;
  bool _isStepCountAvailable = false;
  String? _stepCountError;

  // 지도 위치 초기화 여부 확인
  bool _isMapInitialized = false;

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

    _transformationController.addListener(() {
      // 화면 갱신이 필요할 경우 (마커 위치 동기화 등)
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stepCountSubscription?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  // 지도 초기 위치 설정 (출발지와 목적지 중점이 화면 중앙에 오도록)
  void _initializeMapPosition(Size containerSize) {
    if (_isMapInitialized ||
        _route == null ||
        containerSize.width <= 0 ||
        containerSize.height <= 0)
      return;

    final buildingName = _getBuildingName(_route!.startPoi.buildingId);
    final floorString = '${_route!.startPoi.floor}F';

    // 기존에 '2x'로 되어 있어서 좌표 계산 배율이 틀어졌던 것이기 때문에
    // 마커 로직과 동일하게 '1x' 기준으로 원본 크기를 가져오도록 변경
    final originalSize = MapUtilFunctions.getImageOriginalSize(
      buildingName,
      floorString,
      '1x',
    );

    if (originalSize.width == 0 || originalSize.height == 0) return;

    final displayedSize = MapUtilFunctions.getDisplayedImageSize(
      containerSize,
      originalSize,
    );

    // 2. 스케일 계산 (BoxFit.contain이므로 가로/세로 비율 중 맞는 것 하나만 쓰면 됨)
    // displayedSize는 이미 비율이 맞춰진 크기이므로 width 기준으로 계산
    final scale = displayedSize.width / originalSize.width;

    // 3. 여백(Offset) 계산
    final offsetX = (containerSize.width - displayedSize.width) / 2;
    final offsetY = (containerSize.height - displayedSize.height) / 2;

    // 4. 출발지 좌표를 화면상 절대 좌표로 변환
    final startX = _route!.startPoi.xCoord * scale + offsetX;
    final startY = _route!.startPoi.yCoord * scale + offsetY;

    // 5. 목적지 좌표 계산 (줌 레벨 결정을 위해)
    final endX = _route!.destinationPoi.xCoord * scale + offsetX;
    final endY = _route!.destinationPoi.yCoord * scale + offsetY;

    // 6. 줌 레벨 계산 (화면 너비의 40% 정도가 되도록)
    final dist = math.sqrt(
      math.pow(startX - endX, 2) + math.pow(startY - endY, 2),
    );
    double targetScale = (dist > 0) ? (containerSize.width * 0.4 / dist) : 3.0;
    targetScale = targetScale.clamp(2.5, 6.0);

    // 7. 중앙 정렬을 위한 이동량(Translation) 계산
    // 화면 중앙 - (출발지 * 줌배율)
    final tx = (containerSize.width / 2) - (startX * targetScale);
    final ty = (containerSize.height / 2) - (startY * targetScale);

    // 8. 매트릭스 적용
    final matrix = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(targetScale);

    _transformationController.value = matrix;
    _isMapInitialized = true;

    if (mounted) setState(() {});
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

  String _getBuildingName(int buildingId) {
    switch (buildingId) {
      case 1:
      case 2:
        return '5호관';
      case 3:
        return '하이테크관';
      default:
        return '5호관';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("보폭 측정"), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? SafeArea(
              child: Center(
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
              ),
            )
          : _route == null
          // -------------------- [예외처리용 화면] --------------------
          ? SafeArea(
              child: Padding(
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
                              color: AppColors.primary.withAlpha(30),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                        TextButton(
                          onPressed: () async {
                            if (mounted) {
                              context.go('/home');
                            }
                          },
                          child: Text(
                            "홈 화면으로 돌아가기",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40), // 하단 여백
                  ],
                ),
              ),
            )
          // -------------------- [정상 보폭 측정용 화면] --------------------
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --------------------경로 정보--------------------
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
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
                      ],
                    ),
                  ),

                  // --------------------지도 영역--------------------
                  Builder(
                    builder: (context) {
                      final buildingName = _getBuildingName(
                        _route!.startPoi.buildingId,
                      );
                      final floorString = '${_route!.startPoi.floor}F';

                      // 2x 이미지 경로
                      final mapImagePath = MapUtilFunctions.getImagePath(
                        buildingName,
                        floorString,
                        '2x',
                      );

                      return Container(
                        height: 300,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.grey200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final containerSize = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );

                              // 초기 위치 계산 (최초 1회)
                              if (!_isMapInitialized) {
                                // LayoutBuilder 내부에서 setState 직접 호출 불가하므로 postFrameCallback
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _initializeMapPosition(containerSize);
                                });
                              }

                              // 마커 위치 계산을 위한 변수들
                              final originalSize =
                                  MapUtilFunctions.getImageOriginalSize(
                                    buildingName,
                                    floorString,
                                    '1x',
                                  );

                              final displayedSize =
                                  MapUtilFunctions.getDisplayedImageSize(
                                    containerSize,
                                    originalSize,
                                  );

                              final scaleX =
                                  displayedSize.width / originalSize.width;
                              final scaleY =
                                  displayedSize.height / originalSize.height;

                              // 이미지가 중앙 정렬되면서 생기는 오프셋 (BoxFit.contain 특성)
                              final offsetX =
                                  (containerSize.width - displayedSize.width) /
                                  2;
                              final offsetY =
                                  (containerSize.height -
                                      displayedSize.height) /
                                  2;

                              return Stack(
                                children: [
                                  // InteractiveViewer
                                  Positioned.fill(
                                    child: InteractiveViewer(
                                      transformationController:
                                          _transformationController,
                                      panEnabled: true, // 사용자가 지도 이동 가능
                                      scaleEnabled: true, // 사용자가 지도 확대/축소 가능
                                      minScale: 1.0,
                                      maxScale: 10.0,
                                      alignment:
                                          Alignment.topLeft, // 좌표계 기준을 왼쪽 위로 설정
                                      boundaryMargin: const EdgeInsets.all(
                                        500,
                                      ), // 여유 공간 넉넉히
                                      child: Image.asset(
                                        mapImagePath,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),

                                  // 출발지 마커
                                  Builder(
                                    builder: (context) {
                                      // 1. 기본 화면 좌표 (Zoom 1.0)
                                      final initialX =
                                          _route!.startPoi.xCoord * scaleX +
                                          offsetX;
                                      final initialY =
                                          _route!.startPoi.yCoord * scaleY +
                                          offsetY;

                                      // 2. 현재 변환 행렬 적용
                                      final matrix =
                                          _transformationController.value;
                                      final transformedX =
                                          matrix.storage[0] * initialX +
                                          matrix.storage[4] * initialY +
                                          matrix.storage[12];
                                      final transformedY =
                                          matrix.storage[1] * initialX +
                                          matrix.storage[5] * initialY +
                                          matrix.storage[13];

                                      return Positioned(
                                        left: transformedX - 12, // 마커 크기 절반 보정
                                        top: transformedY - 24, // 마커 크기 절반 보정
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.3,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.person_pin_circle,
                                            color: AppColors.primary,
                                            size: 24,
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  // 도착지 마커
                                  Builder(
                                    builder: (context) {
                                      final initialX =
                                          _route!.destinationPoi.xCoord *
                                              scaleX +
                                          offsetX;
                                      final initialY =
                                          _route!.destinationPoi.yCoord *
                                              scaleY +
                                          offsetY;

                                      final matrix =
                                          _transformationController.value;
                                      final transformedX =
                                          matrix.storage[0] * initialX +
                                          matrix.storage[4] * initialY +
                                          matrix.storage[12];
                                      final transformedY =
                                          matrix.storage[1] * initialX +
                                          matrix.storage[5] * initialY +
                                          matrix.storage[13];

                                      return Positioned(
                                        left: transformedX - 12,
                                        top: transformedY - 24,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.3,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.location_on,
                                            color: Colors.red,
                                            size: 24,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
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
                  // --------------------도착, 다음에 측정하기 버튼--------------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _onArrived,
                        child: Container(
                          alignment: Alignment.center,
                          width: 100,
                          height: 50,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Text(
                            "도착",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
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
                          alignment: Alignment.center,
                          height: 50,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.grey200,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Text(
                            "다음에 측정하기",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
    );
  }
}
