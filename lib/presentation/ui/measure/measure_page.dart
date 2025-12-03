import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:annyong/domain/entity/calibration_route.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/usecases/calibration_service.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// 측정 진행 단계를 정의합니다.
/// ready: 경로 탐색 완료, 사용자가 시작 지점에 서 있는지 확인하는 단계
/// standby: 준비 완료 버튼 누름, 센서로부터 첫 걸음 신호를 기다리는 단계 (UI: 걸음 감지중...)
/// measuring: 첫 걸음 감지됨, 실제 측정 중 단계 (UI: 도착 버튼)
enum MeasureStep { ready, standby, measuring }

class MeasurePage extends StatefulWidget {
  final Poi? startPoi;

  const MeasurePage({super.key, this.startPoi});

  @override
  State<MeasurePage> createState() => _MeasurePageState();
}

class _MeasurePageState extends State<MeasurePage> {
  // 보폭 측정 서비스 (경로 탐색용)
  final CalibrationService _calibrationService = CalibrationService(
    PoiRepository(),
  );

  // widget.startPoi 대신 내부 상태로 관리하여 재선택 시 업데이트 가능하게 함
  Poi? _targetPoi;

  // 지도를 확대/이동하기 위한 컨트롤러
  final TransformationController _transformationController =
      TransformationController();

  // 탐색된 경로 정보 (목적지 Vertex, POI 포함)
  CalibrationRoute? _route;

  // 로딩 및 에러 상태 관리
  bool _isLoading = true;
  String? _errorMessage;

  // ---------------------------------------------------------------------------
  // [걸음수 측정 관련 변수]
  // ---------------------------------------------------------------------------
  int _currentPedometerSteps = 0; // 센서에서 들어오는 실시간 누적 걸음수
  int _startSteps = 0; // 측정이 시작된 시점(첫 걸음 감지 직전)의 기준 걸음수
  StreamSubscription<StepCount>? _stepCountSubscription;
  bool _isStepCountAvailable = false;

  // 현재 측정 단계 관리 (기본값: 준비 단계)
  MeasureStep _currentStep = MeasureStep.ready;

  // 지도 초기화 여부 확인
  bool _isMapInitialized = false;

  @override
  void initState() {
    super.initState();
    _targetPoi = widget.startPoi;

    // 권한 요청 및 만보기 센서 초기화
    _requestPermissionAndInit();

    // 시작 지점이 있으면 바로 경로 탐색 시작
    if (widget.startPoi != null) {
      _findRoute();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "출발 지점이 선택되지 않았습니다.";
      });
    }

    // 지도 움직임(줌/팬) 감지하여 화면 갱신 (경로 선 다시 그리기 위해 필요)
    _transformationController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stepCountSubscription?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  /// 지도 이미지와 경로가 화면 중앙에 잘 보이도록 초기 위치와 배율을 설정합니다.
  void _initializeMapPosition(Size containerSize) {
    if (_isMapInitialized ||
        _route == null ||
        containerSize.width <= 0 ||
        containerSize.height <= 0) {
      return;
    }

    // 건물 이름 및 층 정보 가져오기
    final buildingName = _getBuildingName(_route!.startPoi.buildingId);
    final floorString = '${_route!.startPoi.floor}F';

    // 지도 원본 이미지 사이즈 가져오기
    final originalSize = MapUtilFunctions.getImageOriginalSize(
      buildingName,
      floorString,
      '1x',
    );

    if (originalSize.width == 0 || originalSize.height == 0) return;

    // 화면에 표시된 이미지 사이즈 계산 (BoxFit.contain 기준)
    final displayedSize = MapUtilFunctions.getDisplayedImageSize(
      containerSize,
      originalSize,
    );

    final scale = displayedSize.width / originalSize.width;
    final offsetX = (containerSize.width - displayedSize.width) / 2;
    final offsetY = (containerSize.height - displayedSize.height) / 2;

    // 출발지 좌표 계산
    final startX = _route!.startPoi.xCoord * scale + offsetX;
    final startY = _route!.startPoi.yCoord * scale + offsetY;

    // 도착지 좌표 계산 (POI가 없으면 Vertex 좌표 사용)
    final destXVal =
        _route!.destinationPoi?.xCoord ?? _route!.destinationVertex.x;
    final destYVal =
        _route!.destinationPoi?.yCoord ?? _route!.destinationVertex.y;

    final endX = destXVal * scale + offsetX;
    final endY = destYVal * scale + offsetY;

    // 두 점 사이의 거리에 따라 줌 레벨 자동 조정
    final dist = math.sqrt(
      math.pow(startX - endX, 2) + math.pow(startY - endY, 2),
    );

    // 거리가 멀면 줌을 작게, 가까우면 줌을 크게 (화면의 40% 정도 차지하도록)
    double targetScale = (dist > 0) ? (containerSize.width * 0.4 / dist) : 3.0;
    targetScale = targetScale.clamp(2.5, 6.0); // 최소/최대 줌 제한

    // 두 점의 중간 지점이 화면 중앙에 오도록 이동
    final midX = (startX + endX) / 2;
    final midY = (startY + endY) / 2;

    final tx = (containerSize.width / 2) - (midX * targetScale);
    final ty = (containerSize.height / 2) - (midY * targetScale);

    final matrix = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(targetScale);

    _transformationController.value = matrix;
    _isMapInitialized = true;

    if (mounted) setState(() {});
  }

  /// 활동 인식 권한 요청 및 만보기 초기화
  Future<void> _requestPermissionAndInit() async {
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        // 권한 거부 시 처리가 필요하다면 여기에 추가
        return;
      }
    }
    _initPedometer();
  }

  /// 만보기 센서 스트림 구독
  /// [UX 수정] 대기 상태일 때 걸음 수 변화가 감지되면 자동으로 측정 상태로 전환
  void _initPedometer() {
    _stepCountSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        if (!mounted) return;

        setState(() {
          _currentPedometerSteps = event.steps;
          _isStepCountAvailable = true;

          // [핵심 로직 변경]
          // 대기(standby) 상태에서 센서 업데이트가 들어오면 즉시 측정(measuring)으로 전환
          if (_currentStep == MeasureStep.standby) {
            // 센서가 업데이트 되었다는 것은 걷기 시작했다는 의미 (혹은 누락된 데이터 수신)
            // 요청하신대로 (현재 값 - 1)을 시작점으로 잡아, 현재 1걸음부터 시작되도록 함
            _startSteps = event.steps - 1;
            _currentStep = MeasureStep.measuring;
          }
        });
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isStepCountAvailable = false;
          });
        }
      },
      cancelOnError: false,
    );
  }

  /// 보폭 측정 경로 탐색 (Hybrid Logic 적용)
  Future<void> _findRoute() async {
    if (_targetPoi == null) return;

    try {
      // CalibrationService를 통해 최적의 경로(POI 우선, 없으면 랜드마크) 탐색
      final route = await _calibrationService.findTargetRoute(_targetPoi!);

      setState(() {
        _route = route;
        _isLoading = false;

        if (route == null) {
          _errorMessage = null;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "경로 탐색 중 오류가 발생했습니다: $e";
      });
    }
  }

  // ---------------------------------------------------------------------------
  // [UI 이벤트 핸들러]
  // ---------------------------------------------------------------------------

  /// [준비됐어요] 버튼 클릭 시 -> 걸음 감지 대기(Standby) 상태로 전환
  void _onReadyPressed() {
    setState(() {
      _currentStep = MeasureStep.standby;
    });
  }

  // [_onStartPressed 제거됨]
  // standby 상태에서 센서가 반응하면 자동으로 measuring으로 넘어가므로 불필요

  /// [도착했습니다] 버튼 클릭 시 -> 결과 페이지로 이동
  // async로 선언하여 push 결과를 await로 받음 -> 재측정인 경우를 구분하여 처리하기 위함
  void _onArrivedPressed() async {
    if (_route == null) return;

    // 최종 걸음수 계산 (현재값 - 시작값)
    // _startSteps는 (첫 감지값 - 1)이므로, 첫 감지 시 (감지값 - (감지값-1)) = 1걸음이 됨
    final int walkedSteps = _currentPedometerSteps - _startSteps;

    // 만약 재측정이면 상태를 준비 단계로 초기화
    final bool? shouldRetry = await context.push<bool>(
      "/measure/measureResult",
      extra: {
        "walkedSteps": walkedSteps,
        "totalDistance": _route!.totalDistance,
      },
    );
    if (shouldRetry == true && mounted) {
      setState(() {
        _currentStep = MeasureStep.ready;
      });
    }
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
    String destinationName = "도착지";
    String guideText = "";

    if (_route != null) {
      if (_route!.destinationPoi != null) {
        destinationName = _route!.destinationPoi!.name;
        guideText = "(${_route!.totalDistance.toStringAsFixed(1)}m, 직진)";
      } else {
        destinationName = "복도 끝 (코너)";
        guideText = "(${_route!.totalDistance.toStringAsFixed(1)}m, 직진)";
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("보폭 측정"), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : _route == null
          ? _buildFailureView()
          : Column(
              children: [
                // -------------------- 상단 안내 영역 --------------------
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.grey200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "출발: ${_route!.startPoi.name}",
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.arrow_forward, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              "도착: $destinationName",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          guideText,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

                // -------------------- 지도 영역 --------------------
                Expanded(child: _buildMapArea()),

                // -------------------- 하단 버튼 액션 영역 --------------------
                _buildBottomActionArea(),
              ],
            ),
    );
  }

  /// 하단 버튼 영역 (단계별 UI 분기)
  Widget _buildBottomActionArea() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // [단계 1: 준비 확인]
          if (_currentStep == MeasureStep.ready) ...[
            const Text(
              "시작 위치에 정확히 서 계신가요?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _onReadyPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "준비됐어요",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ]
          // [단계 2: 걸음 감지 대기 (Standby)] - UX 개선 적용됨
          else if (_currentStep == MeasureStep.standby) ...[
            const Text(
              "이제 평소 걸음으로 걸어주세요!",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "걸음을 감지하고 있어요...",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),

            // [추가된 부분] 팁 텍스트 추가
            const SizedBox(height: 8),
            const Text(
              "[TIP] 감지되지 않는다면, 세게 3~5회 흔들어보세요!",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),

            // 공간 확보용 더미 컨테이너 (버튼 높이만큼)
            const SizedBox(height: 32),
          ]
          // [단계 3: 측정 중 (Measuring)]
          else if (_currentStep == MeasureStep.measuring) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("걷는 중... ", style: TextStyle(fontSize: 16)),
                Text(
                  // 현재 걸음수 - 시작값
                  "${_currentPedometerSteps - _startSteps}",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const Text(" 걸음", style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _onArrivedPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.text, // 도착 버튼은 검정색 계열
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "도착했습니다",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 지도 및 경로 오버레이 빌더
  Widget _buildMapArea() {
    final buildingName = _getBuildingName(_route!.startPoi.buildingId);
    final floorString = '${_route!.startPoi.floor}F';
    final mapImagePath = MapUtilFunctions.getImagePath(
      buildingName,
      floorString,
      '2x',
    );

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final containerSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          if (!_isMapInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initializeMapPosition(containerSize);
            });
          }

          final originalSize = MapUtilFunctions.getImageOriginalSize(
            buildingName,
            floorString,
            '1x',
          );
          final displayedSize = MapUtilFunctions.getDisplayedImageSize(
            containerSize,
            originalSize,
          );
          final scaleX = displayedSize.width / originalSize.width;
          final scaleY = displayedSize.height / originalSize.height;
          final offsetX = (containerSize.width - displayedSize.width) / 2;
          final offsetY = (containerSize.height - displayedSize.height) / 2;

          final destX =
              _route!.destinationPoi?.xCoord ?? _route!.destinationVertex.x;
          final destY =
              _route!.destinationPoi?.yCoord ?? _route!.destinationVertex.y;

          return Stack(
            children: [
              // 1. 지도 이미지 (줌/팬 가능)
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 10.0,
                  boundaryMargin: const EdgeInsets.all(500),
                  child: Image.asset(mapImagePath, fit: BoxFit.contain),
                ),
              ),

              // 2. 파란색 경로 선 (CustomPainter)
              Positioned.fill(
                child: CustomPaint(
                  painter: _PathPainter(
                    // 단순 시작/끝 점 대신, 전체 경로 Vertex 리스트를 전달
                    pathVertices: _route!.pathVertices,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    offsetX: offsetX,
                    offsetY: offsetY,
                    matrix: _transformationController.value,
                  ),
                ),
              ),
              // 3. 출발지 마커
              _buildMarker(
                x: _route!.startPoi.xCoord,
                y: _route!.startPoi.yCoord,
                scaleX: scaleX,
                scaleY: scaleY,
                offsetX: offsetX,
                offsetY: offsetY,
                icon: Icons.person_pin_circle,
                color: AppColors.primary,
              ),

              // 4. 도착지 마커
              _buildMarker(
                x: destX,
                y: destY,
                scaleX: scaleX,
                scaleY: scaleY,
                offsetX: offsetX,
                offsetY: offsetY,
                icon: Icons.flag,
                color: Colors.red,
              ),
            ],
          );
        },
      ),
    );
  }

  /// 지도 위 마커 위젯 생성 헬퍼
  Widget _buildMarker({
    required double x,
    required double y,
    required double scaleX,
    required double scaleY,
    required double offsetX,
    required double offsetY,
    required IconData icon,
    required Color color,
  }) {
    final initialX = x * scaleX + offsetX;
    final initialY = y * scaleY + offsetY;

    final matrix = _transformationController.value;
    final transformedX =
        matrix.storage[0] * initialX +
        matrix.storage[4] * initialY +
        matrix.storage[12];
    final transformedY =
        matrix.storage[1] * initialX +
        matrix.storage[5] * initialY +
        matrix.storage[13];

    return Positioned(
      left: transformedX - 16,
      top: transformedY - 32,
      child: Icon(icon, color: color, size: 32),
    );
  }

  // 에러 발생 시 뷰
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage ?? "알 수 없는 오류",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (context.canPop())
                  context.pop();
                else
                  context.go("/home");
              },
              child: const Text("돌아가기"),
            ),
          ],
        ),
      ),
    );
  }

  // 경로 탐색 실패 시 뷰
  Widget _buildFailureView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
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
            Column(
              children: [
                const Text(
                  "적당한 측정 경로가 없어요",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),

                // [수정된 부분] Text -> Wrap으로 변경하여 단어 단위 줄바꿈 구현
                Builder(
                  builder: (context) {
                    final String textContent =
                        "선택하신 '${_targetPoi?.name ?? '위치'}' 주변에는 보폭 측정에 적합한 경로(직선 혹은 POI)가 부족합니다. 조금 더 넓은 복도로 이동해보세요.";

                    return Wrap(
                      alignment: WrapAlignment.center,
                      runSpacing: 4.0, // 줄 간격 (== height: 1.5)
                      children: textContent.split(' ').map((word) {
                        return Text(
                          "$word ",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
            const Spacer(),

            // 기본값 설정 버튼
            GestureDetector(
              onTap: () {
                context.go("/home");
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "다음에 하기",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 다른 출발지 선택 버튼
            TextButton(
              onPressed: () async {
                if (mounted) {
                  final selectedPoi = await context.push<Poi>(
                    "/measureSelectPoi",
                    extra: {"returnResult": true},
                  );
                  if (selectedPoi != null && mounted) {
                    setState(() {
                      _targetPoi = selectedPoi;
                      _isLoading = true;
                      _errorMessage = null;
                      _route = null;
                      _currentStep = MeasureStep.ready;
                      _isMapInitialized = false;
                    });
                    _findRoute();
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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// [경로 그리기용 Painter 클래스]
// -----------------------------------------------------------------------------
class _PathPainter extends CustomPainter {
  // Vertex 리스트를 받아서 Polyline을 그립니다.
  final List<Vertex> pathVertices;
  final double scaleX;
  final double scaleY;
  final double offsetX;
  final double offsetY;
  final Matrix4 matrix;

  _PathPainter({
    required this.pathVertices,
    required this.scaleX,
    required this.scaleY,
    required this.offsetX,
    required this.offsetY,
    required this.matrix,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pathVertices.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round; // 꺾이는 부분 부드럽게

    final path = Path();

    // 1. 첫 번째 점으로 이동
    final firstV = pathVertices.first;
    final startPt = _getTransformedPoint(firstV.x, firstV.y);
    path.moveTo(startPt.dx, startPt.dy);

    // 2. 나머지 점들을 순서대로 연결 (lineTo)
    for (int i = 1; i < pathVertices.length; i++) {
      final v = pathVertices[i];
      final pt = _getTransformedPoint(v.x, v.y);
      path.lineTo(pt.dx, pt.dy);
    }

    canvas.drawPath(path, paint);
  }

  Offset _getTransformedPoint(double mapX, double mapY) {
    // 1. 이미지상 좌표로 변환
    final imgX = mapX * scaleX + offsetX;
    final imgY = mapY * scaleY + offsetY;

    // 2. 줌/팬 매트릭스 적용
    final tx =
        matrix.storage[0] * imgX +
        matrix.storage[4] * imgY +
        matrix.storage[12];
    final ty =
        matrix.storage[1] * imgX +
        matrix.storage[5] * imgY +
        matrix.storage[13];

    return Offset(tx, ty);
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    return oldDelegate.matrix != matrix ||
        oldDelegate.pathVertices != pathVertices;
  }
}
