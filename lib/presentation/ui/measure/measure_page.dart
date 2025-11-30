import 'dart:async';
import 'dart:io';
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
    if (_isMapInitialized || _route == null) return;

    // 1. 출발지와 목적지 좌표 (원본 이미지 기준)
    // 2x 이미지 기준 좌표라고 가정 (POI 좌표계와 일치하는지 확인 필요)
    // MapUtilFunctions.getImagePath에서 '2x'를 호출하므로 2x 이미지 사용
    // HomePage 로직에 따르면 1x 이미지 기준으로 POI 좌표가 설정되어 있을 수 있음
    // 하지만 path_result_page에서는 0.19 곱해서 쓰고 있음.
    // 여기서는 InteractiveViewer 내부의 Image가 BoxFit.contain으로 들어감.

    // 2x 이미지 원본 크기
    final originalSize = MapUtilFunctions.getImageOriginalSize(
      _getBuildingName(_route!.startPoi.buildingId),
      '${_route!.startPoi.floor}F',
      '2x',
    );

    // 2x 이미지 기준으로 POI 좌표 변환 (필요하다면)
    // 여기서는 POI 좌표(xCoord, yCoord)가 어떤 해상도 기준인지 불명확하지만
    // HomePage에서는 1x 기준으로 계산하여 사용.
    // path_result_page에서는 xCoord * 0.19로 사용.

    // 안전하게 가기 위해:
    // InteractiveViewer의 child인 Image가 BoxFit.contain으로 렌더링될 때의 실제 크기 구하기
    final displayedSize = MapUtilFunctions.getDisplayedImageSize(
      containerSize,
      originalSize,
    );

    // 축소 비율 (원본 대비 화면 표시 비율)
    final scaleX = displayedSize.width / originalSize.width;
    final scaleY = displayedSize.height / originalSize.height;

    // 화면상에서의 출발/도착 좌표 (Zoom 1.0일 때)
    final p1 = Offset(
      _route!.startPoi.xCoord * scaleX,
      _route!.startPoi.yCoord * scaleY,
    );
    final p2 = Offset(
      _route!.destinationPoi.xCoord * scaleX,
      _route!.destinationPoi.yCoord * scaleY,
    );

    // 중점 (여기서는 시작 지점을 중심으로 설정)
    // 기존: final center = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final center = p1; // 시작 지점을 중심으로 설정

    // 두 점 사이 거리
    double dist = (p1 - p2).distance;

    // 목표 스케일: 두 점 사이 거리가 화면 너비의 약 60% 정도 되도록
    // (너무 꽉 차면 마커가 잘릴 수 있으므로 여유 있게)
    // 만약 거리가 너무 가깝다면 최대 스케일 제한
    double targetScale = containerSize.width * 0.6 / dist;

    // 최소/최대 스케일 보정
    if (targetScale < 2.0) targetScale = 2.0;
    if (targetScale > 5.0) targetScale = 5.0;

    // 중앙 정렬을 위한 이동(Translation)
    // 화면 중앙 - (중점 * 스케일)
    // 오프셋 보정값 추가 (사용자가 직접 조정 가능)
    const double offsetXCorrection = -50.0; // x축 보정 (왼쪽으로 이동)
    const double offsetYCorrection = -50.0; // y축 보정 (위로 이동)

    // tx, ty 계산 시 스케일을 고려하여 center에 곱하는 것이 맞음.
    // (containerWidth/2) - (centerX * scale) => 중심점을 화면 중앙으로.
    // 여기에 보정값을 더함.
    // 하지만 InteractiveViewer에 alignment: Alignment.topLeft를 주었으므로,
    // (0,0) 기준으로 이동해야 함.

    final tx =
        containerSize.width / 2 - center.dx * targetScale + offsetXCorrection;
    final ty =
        containerSize.height / 2 - center.dy * targetScale + offsetYCorrection;

    // 만약 tx, ty가 양수라면(화면 중앙보다 왼쪽/위쪽 여백이 생김), 0으로 제한하여 빈 공간 최소화 (선택 사항)
    // 하지만 여기서는 특정 지점을 중앙에 놓는 것이 목표이므로 제한하지 않음.

    // 매트릭스 설정 (scale -> translate 순서 주의)
    final matrix = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(targetScale);

    _transformationController.value = matrix;
    _isMapInitialized = true;

    // 상태 업데이트하여 마커 위치 재계산 유도
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
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
    try {
      final route = await _calibrationService.findTargetRoute(widget.startPoi!);
      setState(() {
        _route = route;
        _isLoading = false;
        if (route == null) {
          _errorMessage = "측정 가능한 경로를 찾을 수 없습니다.\n콘솔 로그를 확인해주세요.";
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
          ? const Center(child: Text("경로를 찾을 수 없습니다."))
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
