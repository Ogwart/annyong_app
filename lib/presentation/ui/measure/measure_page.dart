import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:annyong/domain/entity/calibration_route.dart';
import 'package:annyong/domain/entity/graph_models.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/calibration_service.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// 측정 진행 단계를 정의합니다.
/// ready: 경로 탐색 완료, 사용자가 시작 지점에 서 있는지 확인하는 단계
/// standby: 준비 완료 버튼 누름, '출발' 버튼을 누르기 대기하는 단계
/// measuring: 걷는 중, '도착' 버튼을 누르기 대기하는 단계
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
  int _startSteps = 0; // '출발' 버튼을 누른 시점의 걸음수 저장
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
  void _initPedometer() {
    _stepCountSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        if (mounted) {
          setState(() {
            _currentPedometerSteps = event.steps;
            _isStepCountAvailable = true;
          });
        }
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

        // 탐색 실패 시 null 반환됨 -> _errorMessage를 null로 유지하여 실패 UI(_buildFailureView) 표시
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

  /// [준비됐어요] 버튼 클릭 시 -> 대기 상태로 전환
  void _onReadyPressed() {
    setState(() {
      _currentStep = MeasureStep.standby;
    });
  }

  /// [출발!] 버튼 클릭 시 -> 측정 시작 (시작 걸음수 기록)
  void _onStartPressed() {
    setState(() {
      // 현재 누적 걸음수를 시작점으로 기록 (0부터 시작하는 효과)
      _startSteps = _currentPedometerSteps;
      _currentStep = MeasureStep.measuring;
    });
  }

  /// [도착했습니다] 버튼 클릭 시 -> 결과 페이지로 이동
  void _onArrivedPressed() {
    if (_route == null) return;

    // 최종 걸음수 계산 (현재값 - 시작값)
    final int walkedSteps = _currentPedometerSteps - _startSteps;

    // 결과 페이지로 이동 (걸음수와 총 거리 전달)
    context.push(
      "/measure/measureResult",
      extra: {
        "walkedSteps": walkedSteps, // int
        "totalDistance": _route!.totalDistance, // double
      },
    );
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
    // 도착지 이름 및 안내 텍스트 설정
    String destinationName = "도착지";
    String guideText = "";

    if (_route != null) {
      if (_route!.destinationPoi != null) {
        // POI가 있는 경우
        destinationName = _route!.destinationPoi!.name;
        guideText = "(${_route!.totalDistance.toStringAsFixed(1)}m, 직진)";
      } else {
        // 랜드마크(코너, 막다른 길)인 경우
        destinationName = "복도 끝 (코너)";
        guideText = "(${_route!.totalDistance.toStringAsFixed(1)}m, 직진)";
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("보폭 측정"), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          // 에러 발생 시 화면
          ? _buildErrorView()
          : _route == null
          // -------------------- [경로 탐색 실패 시 UI] --------------------
          ? _buildFailureView()
          // -------------------- [측정 화면 (지도 표시)] --------------------
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
          // 단계 1: 준비 확인
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
          // 단계 2: 출발 대기
          else if (_currentStep == MeasureStep.standby) ...[
            const Text(
              "아래 버튼을 누르고 걸어주세요!",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 120,
              height: 120,
              child: ElevatedButton(
                onPressed: _onStartPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const CircleBorder(),
                  elevation: 5,
                ),
                child: const Text(
                  "출발!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ]
          // 단계 3: 측정 중 (도착 대기)
          else if (_currentStep == MeasureStep.measuring) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("걷는 중... ", style: TextStyle(fontSize: 16)),
                Text(
                  // 현재 걸음수 표시
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

          // 지도 초기화 (최초 1회)
          if (!_isMapInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initializeMapPosition(containerSize);
            });
          }

          // 좌표 계산용 변수 준비
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

          // 도착지 좌표 (POI가 없으면 Vertex 좌표 사용)
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
              // InteractiveViewer 위에 그리기 위해 Matrix 변환 적용
              Positioned.fill(
                child: CustomPaint(
                  painter: _PathPainter(
                    startX: _route!.startPoi.xCoord,
                    startY: _route!.startPoi.yCoord,
                    endX: destX,
                    endY: destY,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    offsetX: offsetX,
                    offsetY: offsetY,
                    matrix: _transformationController.value,
                    pathVertices: _route!.pathVertices,
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
    // InteractiveViewer의 매트릭스를 직접 적용하여 절대 위치 계산
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
      left: transformedX - 16, // 아이콘 크기/2 보정 (중앙 정렬)
      top: transformedY - 32, // 아이콘 바닥이 좌표에 오도록 보정
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
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go("/home");
                }
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
                Text(
                  "선택하신 '${widget.startPoi?.name ?? '위치'}' 주변에는\n보폭 측정에 적합한 경로(직선 혹은 POI)가 부족합니다.\n조금 더 넓은 복도로 이동해보세요.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const Spacer(),

            // 기본값 설정 버튼 (사용자 편의)
            GestureDetector(
              onTap: () {
                // 기본값 저장 후 결과 페이지 등 이동 처리 필요할 수 있음
                // 여기서는 생략하거나 홈으로 이동
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
                      _currentStep = MeasureStep.ready; // 상태 초기화
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
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double scaleX;
  final double scaleY;
  final double offsetX;
  final double offsetY;
  final Matrix4 matrix;
  final List<Vertex>? pathVertices;

  _PathPainter({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.scaleX,
    required this.scaleY,
    required this.offsetX,
    required this.offsetY,
    required this.matrix,
    this.pathVertices,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 파란색 선 스타일 정의
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    print("PathPainter: pathVertices count: ${pathVertices?.length}");

    // 경로 데이터가 있으면 꺾인 선 그리기
    if (pathVertices != null && pathVertices!.isNotEmpty) {
      final path = Path();

      // 1. 출발지점 (POI)
      final sX = startX * scaleX + offsetX;
      final sY = startY * scaleY + offsetY;
      final pStart = _transformPoint(sX, sY);
      path.moveTo(pStart.dx, pStart.dy);

      // 2. 경유지점 (Vertices)
      for (int i = 0; i < pathVertices!.length; i++) {
        final v = pathVertices![i];
        final vx = v.x * scaleX + offsetX;
        final vy = v.y * scaleY + offsetY;
        final p = _transformPoint(vx, vy);
        path.lineTo(p.dx, p.dy);
      }

      // 3. 도착지점 (POI 혹은 Vertex)
      // 도착지 좌표가 마지막 Vertex와 다를 수 있으므로 연결
      final eX = endX * scaleX + offsetX;
      final eY = endY * scaleY + offsetY;
      final pEnd = _transformPoint(eX, eY);
      path.lineTo(pEnd.dx, pEnd.dy);

      canvas.drawPath(path, paint);
    } else {
      // 기존 로직: 출발-도착 직선 그리기
      // 1. 이미지 기준 좌표로 변환
      final sX = startX * scaleX + offsetX;
      final sY = startY * scaleY + offsetY;
      final eX = endX * scaleX + offsetX;
      final eY = endY * scaleY + offsetY;

      // 2. InteractiveViewer 매트릭스 변환 적용 (줌/팬 반영)
      final p1 = _transformPoint(sX, sY);
      final p2 = _transformPoint(eX, eY);

      // 선 그리기
      canvas.drawLine(p1, p2, paint);
    }
  }

  Offset _transformPoint(double x, double y) {
    // 행렬 연산을 통해 현재 화면상의 절대 좌표 계산
    final tx =
        matrix.storage[0] * x + matrix.storage[4] * y + matrix.storage[12];
    final ty =
        matrix.storage[1] * x + matrix.storage[5] * y + matrix.storage[13];
    return Offset(tx, ty);
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    // 매트릭스가 변경되면(줌/이동 시) 다시 그려야 함
    return oldDelegate.matrix != matrix;
  }
}
