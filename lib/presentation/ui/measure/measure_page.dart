import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as math64;
import 'package:annyong/presentation/util/get_building_name.dart';
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

enum MeasureStep { ready, standby, measuring }

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

  Poi? _targetPoi;
  final TransformationController _transformationController =
      TransformationController();
  CalibrationRoute? _route;

  bool _isLoading = true;
  String? _errorMessage;

  int _currentPedometerSteps = 0;
  int _startSteps = 0;
  StreamSubscription<StepCount>? _stepCountSubscription;
  bool _isStepCountAvailable = false;

  MeasureStep _currentStep = MeasureStep.ready;
  bool _isMapInitialized = false;

  @override
  void initState() {
    super.initState();
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
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stepCountSubscription?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  void _initializeMapPosition(Size containerSize) {
    if (_isMapInitialized ||
        _route == null ||
        containerSize.width <= 0 ||
        containerSize.height <= 0) {
      return;
    }

    final buildingName = getBuildingName(_route!.startPoi.buildingId);
    final floorString = '${_route!.startPoi.floor}F';

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

    final scale = displayedSize.width / originalSize.width;
    final offsetX = (containerSize.width - displayedSize.width) / 2;
    final offsetY = (containerSize.height - displayedSize.height) / 2;

    final startX = _route!.startPoi.xCoord * scale + offsetX;
    final startY = _route!.startPoi.yCoord * scale + offsetY;

    final destXVal =
        _route!.destinationPoi?.xCoord ?? _route!.destinationVertex.x;
    final destYVal =
        _route!.destinationPoi?.yCoord ?? _route!.destinationVertex.y;

    final endX = destXVal * scale + offsetX;
    final endY = destYVal * scale + offsetY;

    final dist = math.sqrt(
      math.pow(startX - endX, 2) + math.pow(startY - endY, 2),
    );

    double targetScale = (dist > 0) ? (containerSize.width * 0.4 / dist) : 3.0;
    targetScale = targetScale.clamp(2.5, 6.0);

    final midX = (startX + endX) / 2;
    final midY = (startY + endY) / 2;

    final tx = (containerSize.width / 2) - (midX * targetScale);
    final ty = (containerSize.height / 2) - (midY * targetScale);

    final matrix = Matrix4.identity()
      ..translateByVector3(math64.Vector3(tx, ty, 0))
      ..scale(targetScale);

    _transformationController.value = matrix;
    _isMapInitialized = true;

    if (mounted) setState(() {});
  }

  Future<void> _requestPermissionAndInit() async {
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        return;
      }
    }
    _initPedometer();
  }

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

  Future<void> _findRoute() async {
    if (_targetPoi == null) return;

    try {
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

  void _onReadyPressed() {
    setState(() {
      _currentStep = MeasureStep.standby;
    });
  }

  void _onStartPressed() {
    setState(() {
      _startSteps = _currentPedometerSteps;
      _currentStep = MeasureStep.measuring;
    });
  }

  void _onArrivedPressed() {
    if (_route == null) return;
    final int walkedSteps = _currentPedometerSteps - _startSteps;
    context.push(
      "/measure/measureResult",
      extra: {
        "walkedSteps": walkedSteps,
        "totalDistance": _route!.totalDistance,
      },
    );
  }

  void _goToResultPage(double defaultStride) {
    context.push(
      "/measure/measureResult",
      extra: {"walkedSteps": 10, "totalDistance": defaultStride * 10},
    );
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
                Expanded(child: _buildMapArea()),
                _buildBottomActionArea(),
              ],
            ),
    );
  }

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
          ] else if (_currentStep == MeasureStep.standby) ...[
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
          ] else if (_currentStep == MeasureStep.measuring) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("걷는 중... ", style: TextStyle(fontSize: 16)),
                Text(
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
                  backgroundColor: AppColors.text,
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

  Widget _buildMapArea() {
    final buildingName = getBuildingName(_route!.startPoi.buildingId);
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
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 10.0,
                  boundaryMargin: const EdgeInsets.all(500),
                  child: Image.asset(mapImagePath, fit: BoxFit.contain),
                ),
              ),
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
                  ),
                ),
              ),
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
            GestureDetector(
              onTap: () {
                _goToResultPage(0.7);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(40),
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
                    Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

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
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sX = startX * scaleX + offsetX;
    final sY = startY * scaleY + offsetY;
    final eX = endX * scaleX + offsetX;
    final eY = endY * scaleY + offsetY;

    final p1 = _transformPoint(sX, sY);
    final p2 = _transformPoint(eX, eY);

    canvas.drawLine(p1, p2, paint);
  }

  Offset _transformPoint(double x, double y) {
    final tx =
        matrix.storage[0] * x + matrix.storage[4] * y + matrix.storage[12];
    final ty =
        matrix.storage[1] * x + matrix.storage[5] * y + matrix.storage[13];
    return Offset(tx, ty);
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    return oldDelegate.matrix != matrix;
  }
}
