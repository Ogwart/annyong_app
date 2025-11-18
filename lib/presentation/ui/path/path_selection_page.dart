import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/ui/search/search_page.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:annyong/domain/entity/poi.dart';

class PathSelectionPage extends ConsumerStatefulWidget {
  const PathSelectionPage({super.key});

  @override
  ConsumerState<PathSelectionPage> createState() => _PathSelectionPageState();
}

class _PathSelectionPageState extends ConsumerState<PathSelectionPage> {
  final TextEditingController _departureController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  String? _selectedFloor = '1F';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateControllers();
    });
  }

  void _updateControllers() {
    final pathState = ref.read(pathSelectionProvider);
    _departureController.text = pathState.departure?.name ?? '';
    _destinationController.text = pathState.destination?.name ?? '';
  }

  @override
  void dispose() {
    _departureController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _swapDepartureDestination() {
    // final temp = _departureController.text;
    // _departureController.text = _destinationController.text;
    // _destinationController.text = temp;
    // setState(() {});
    ref.read(pathSelectionProvider.notifier).swapDepartureDestination();
  }

  void _reset() {
    // _departureController.clear();
    // _destinationController.clear();
    // setState(() {});
    ref.read(pathSelectionProvider.notifier).resetPath();
  }

  bool get _isFindPathEnabled {
    return _departureController.text.isNotEmpty &&
        _destinationController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pathSelectionProvider, (previous, next) {
      _updateControllers();
    });

    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.grey200),
      body: SafeArea(
        child: Stack(
          children: [
            // 메인 컨텐츠
            Positioned(
              child: Container(
                width: double.infinity,
                height: 200,
                color: AppColors.grey200,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 출발지와 목적지 입력 필드
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 출발지 필드
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.grey300,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _departureController,
                                readOnly: true,
                                onTap: () {
                                  context.push(
                                    '/home/search',
                                    extra: SearchMode.departure,
                                  );
                                },
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: '출발지',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 16,
                                    color: AppColors.grey400,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 16,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 목적지 필드
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppColors.grey300,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TextField(
                                      controller: _destinationController,
                                      readOnly: true,
                                      onTap: () {
                                        context.push(
                                          '/home/search',
                                          extra: SearchMode.destination,
                                        );
                                      },
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        hintText: '목적지',
                                        hintStyle: TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 16,
                                          color: AppColors.grey400,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 16,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ------------------Swap 버튼-----------------------
                      GestureDetector(
                        onTap: _swapDepartureDestination,
                        child: SizedBox(
                          width: 48,
                          height: 112,
                          child: Image.asset('assets/icons/arrow_swap.png'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 초기화 버튼
                  GestureDetector(
                    onTap: _reset,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.grey300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '초기화',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // --------------------경유지 추가 버튼-------------------------
            Positioned(
              top: 36,
              right: 80,
              child: GestureDetector(
                onTap: () {
                  // 추가 목적지 기능 구현
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ),
            // 층 선택 버튼 (오른쪽)
            Positioned(
              right: 24,
              bottom: 100,
              child: Column(
                children: [
                  _buildFloorButton('1F'),
                  const SizedBox(height: 8),
                  _buildFloorButton('B1'),
                ],
              ),
            ),
            // 길찾기 버튼 (하단)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: _isFindPathEnabled
                    ? () {
                        // 길찾기 기능 구현
                        final pathState = ref.read(pathSelectionProvider);
                        final Poi? startPoi = pathState.departure;
                        final Poi? endPoi = pathState.destination;

                        debugPrint('출발지 POI: ${pathState.departure!.vertexId}');
                        debugPrint(
                          '목적지 POI: ${pathState.destination!.vertexId}',
                        );

                        if (startPoi != null && endPoi != null) {
                          // 길찾기 결과 페이지로 이동하면서 출발지/목적지 Poi 객체를 전달
                          context.push(
                            '/home/pathSelection/pathResult',
                            extra: {'start': startPoi, 'end': endPoi},
                          );
                        }
                      }
                    : null,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isFindPathEnabled
                        ? AppColors.primary
                        : AppColors.grey300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '길찾기',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _isFindPathEnabled
                            ? Colors.white
                            : AppColors.grey400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorButton(String floor) {
    final isSelected = _selectedFloor == floor;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFloor = floor;
        });
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.grey200,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            floor,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
