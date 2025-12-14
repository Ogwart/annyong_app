import 'package:annyong/presentation/viewmodels/home_map_viewmodel.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:annyong/presentation/viewmodels/category_view_model.dart';
import 'package:annyong/presentation/providers/home_page_map_provider.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/global_widgets/category_button.dart';
import 'package:annyong/presentation/widgets/global_widgets/poi_button.dart';
import 'package:annyong/presentation/widgets/home_page/poi_bottom_sheet.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final TransformationController _transformationController =
      TransformationController();
  String _currentImagePath = 'assets/map/5_1F/5_1F_1x.jpg';
  String _currentBuilding = '5호관';
  String _currentFloor = '1F';
  bool _isInitialized = false; // 초기 위치 설정 플래그

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeMapProvider.notifier).resetMapReady();
      // 홈 페이지로 돌아올 때 출발지/목적지 초기화
      ref.read(pathSelectionProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  // 줌 레벨을 추적하기 위한 변수
  double _currentScale = 1.0;

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final resolution = MapUtilFunctions.getResolutionFromScale(scale);

    // 줌 레벨 업데이트
    if (_currentScale != scale) {
      _currentScale = scale;
    }

    // 현재 건물/층에 맞는 이미지 경로 생성
    final newImagePath = MapUtilFunctions.getImagePath(
      _currentBuilding,
      _currentFloor,
      resolution,
    );

    // 이미지 경로가 변경된 경우에만 업데이트
    if (newImagePath != _currentImagePath) {
      setState(() {
        _currentImagePath = newImagePath;
      });
    } else {
      // 변환이 변경되면 마커 위치도 업데이트하기 위해 setState 호출
      setState(() {});
    }
  }

  void _updateImagePath(String building, String floor) {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final resolution = MapUtilFunctions.getResolutionFromScale(scale);
    final newImagePath = MapUtilFunctions.getImagePath(
      building,
      floor,
      resolution,
    );

    if (newImagePath != _currentImagePath) {
      setState(() {
        _currentBuilding = building;
        _currentFloor = floor;
        _currentImagePath = newImagePath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<HomePageMapProvider>();
    final categoryState = ref.watch(categoryProvider);

    // 건물/층이 변경되면 이미지 경로 업데이트
    if (mapProvider.selectedBuilding != _currentBuilding ||
        mapProvider.selectedFloor != _currentFloor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateImagePath(
          mapProvider.selectedBuilding,
          mapProvider.selectedFloor,
        );
      });
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final containerSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          // 좌표 계산용 기준 크기
          final baseOriginalSize = MapUtilFunctions.getImageOriginalSize(
            mapProvider.selectedBuilding,
            mapProvider.selectedFloor,
            '1x',
          );
          // BoxFit.contain일 때 실제 표시되는 이미지 크기
          final displayedImageSize = MapUtilFunctions.getDisplayedImageSize(
            containerSize,
            baseOriginalSize,
          );
          // 이미지가 컨테이너 중앙 오도록 하는 오프셋
          final imageOffsetX =
              (containerSize.width - displayedImageSize.width) / 2;
          final imageOffsetY =
              (containerSize.height - displayedImageSize.height) / 2;

          // POI 좌표->화면 좌표
          final scaleX = displayedImageSize.width / baseOriginalSize.width;
          final scaleY = displayedImageSize.height / baseOriginalSize.height;

          // 초기 위치 설정 (한 번만 실행)
          if (!_isInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isInitialized) {
                const double initialZoom = 4.5;
                // 목표 지도 좌표 (896, 512)
                const double targetMapX = 1200.0;
                const double targetMapY = 800.0;

                // 지도 좌표를 화면 좌표로 변환
                final targetScreenX = targetMapX * scaleX + imageOffsetX;
                final targetScreenY = targetMapY * scaleY + imageOffsetY;

                // 화면 중앙 좌표
                final screenCenterX = containerSize.width / 2;
                final screenCenterY = containerSize.height / 2;

                // 목표 좌표가 화면 중앙에 오도록 translate 계산
                // 줌이 적용되므로 좌표도 스케일링됨
                final translateX =
                    (screenCenterX - targetScreenX * initialZoom) / initialZoom;
                final translateY =
                    (screenCenterY - targetScreenY * initialZoom) / initialZoom;

                _transformationController.value = Matrix4.identity()
                  ..scale(initialZoom)
                  ..translate(translateX, translateY);

                setState(() {
                  _isInitialized = true;
                });
              }
            });
          }

          return Container(
            alignment: Alignment.center,
            width: double.infinity,
            child: Stack(
              children: [
                //Positioned.fill(child: Container(color: Color(0xffCEDBEF))),
                // -------------------지도-------------------
                Positioned.fill(
                  child: GestureDetector(
                    // 빈 공간 클릭 시 선택 초기화
                    onTap: () {
                      ref.read(categoryProvider.notifier).clearSelection();
                    },
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      boundaryMargin: EdgeInsets.all(20),
                      panEnabled: true,
                      scaleEnabled: true,
                      minScale: 0.5,
                      maxScale: 9.0,
                      child: Image.asset(
                        _currentImagePath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                // 마커 빌더 (선택된 카테고리 또는 즐겨찾기)
                ...MapUtilFunctions.getFilteredFavoritePois(
                  (categoryState.selectedCategoryId == -2 &&
                          _currentScale < 3.0)
                      ? categoryState.favoritePois
                      : categoryState.displayedPois,
                  mapProvider.selectedBuilding,
                  mapProvider.selectedFloor,
                ).map((poi) {
                  final transformation = _transformationController.value;

                  // POI 좌표 -> 1배 줌 상태의 화면 좌표
                  final initialScreenX = poi.xCoord * scaleX + imageOffsetX;
                  final initialScreenY = poi.yCoord * scaleY + imageOffsetY;

                  // interactive viewer 참조, 확대율에 따라 좌표 변환
                  final transformedX =
                      transformation.storage[0] * initialScreenX +
                      transformation.storage[4] * initialScreenY +
                      transformation.storage[12];
                  final transformedY =
                      transformation.storage[1] * initialScreenX +
                      transformation.storage[5] * initialScreenY +
                      transformation.storage[13];

                  // 마커 크기의 절반만큼 오프셋 + 추가 조정 오프셋(나중에 바꾸려면 여기 수정)
                  const markerSize = 40.0;
                  final markerOffset = MapUtilFunctions.markerOffset;
                  return Positioned(
                    left: transformedX - markerSize / 2 + markerOffset.dx,
                    top: transformedY - markerSize / 2 + markerOffset.dy,
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => PoiBottomSheet(poi: poi),
                        );
                      },
                      // zoom level 3부터 글씨 표시
                      child: PoiButton(
                        poi: poi,
                        showTitle: _currentScale >= 4,
                        isFavorite: categoryState.favoritePois.any(
                          (p) => p.id == poi.id,
                        ),
                      ),
                    ),
                  );
                }),
                // --------------------------상단 헤더 및 검색창--------------------------
                Positioned(
                  top: 40, // 상태바 아래로 위치 조정
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      // 1. 헤더 영역 (메뉴, 위치 정보, 길찾기)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // 1. 메뉴 버튼
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: GestureDetector(
                              onTap: () => context.go('/home/menu'),
                              child: Container(
                                height: 50,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: BoxBorder.all(
                                    color: AppColors.primary,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.shadow.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 15,
                                    ),
                                  ],
                                  color: Colors.white,
                                ),
                                child: const Icon(
                                  Icons.menu,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          // 2. 검색창 (시설물 검색)
                          Expanded(
                            flex: 3,
                            child: GestureDetector(
                              onTap: () => context.go('/home/search'),
                              child: Container(
                                height: 50,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: BoxBorder.all(
                                    color: AppColors.primary,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.shadow.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 15,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.apps,
                                      color: AppColors.primary,
                                      size: 26,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      "시설물 선택",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // 3. 길찾기 버튼
                          Expanded(
                            flex: 1,
                            child: GestureDetector(
                              onTap: () {
                                ref
                                    .read(pathSelectionProvider.notifier)
                                    .reset();
                                context.go('/home/pathSelection');
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.shadow.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 15,
                                    ),
                                  ],
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.directions,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                // -----------------------카테고리-------------------------
                Positioned(
                  top: 104,
                  left: 16,
                  right: 16,
                  height: 50,
                  child: SizedBox(
                    child: ListView.builder(
                      // key를 추가하여 상태가 변경되어도 스크롤 위치가 유지되도록 함
                      key: const PageStorageKey('category_list'),
                      scrollDirection: Axis.horizontal,
                      itemCount: categoryState.categories.length + 1,
                      itemBuilder: (BuildContext context, int index) {
                        if (index == 0) {
                          return Center(
                            child: CategoryButton(
                              bookmarkTitle: '즐겨찾기',
                              isSelected:
                                  categoryState.selectedCategoryId == -1,
                              onTap: () => ref
                                  .read(categoryProvider.notifier)
                                  .onCategorySelected(-1),
                            ),
                          );
                        }
                        final category = categoryState.categories[index - 1];
                        return Center(
                          child: CategoryButton(
                            bookmarkTitle: category.name.replaceAll('\n', '/'),
                            isSelected:
                                categoryState.selectedCategoryId == category.id,
                            onTap: () => ref
                                .read(categoryProvider.notifier)
                                .onCategorySelected(category.id),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // --------------------통합 하단 컨트롤러----------------------
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: BoxBorder.all(
                          color: AppColors.primary,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow.withAlpha(25),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. 건물 목록 (선택된 건물은 파란색 버튼, 선택 안된 건물은 회색 텍스트)
                          ...['5호관', '60주년기념관'].map((building) {
                            final isSelected =
                                mapProvider.selectedBuilding == building;
                            return GestureDetector(
                              onTap: () {
                                mapProvider.setSelectedBuilding(building);
                              },
                              child: isSelected
                                  ? Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Text(
                                        building,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      height: 36,
                                      margin: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      color: Colors.transparent,
                                      alignment: Alignment.center,
                                      child: Text(
                                        building,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.grey400,
                                        ),
                                      ),
                                    ),
                            );
                          }),
                          // 구분선
                          Container(
                            width: 2,
                            height: 24,
                            color: AppColors.grey300,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          // 2. 층 선택 리스트 (선택된 층은 파란색 원형 버튼, 선택 안된 층은 회색 텍스트)
                          ...(MapUtilFunctions.getAvailableFloors(
                                mapProvider.selectedBuilding,
                              )..sort()) // 오름차순 정렬
                              .map((floor) {
                                final isSelected =
                                    mapProvider.selectedFloor == floor;
                                return GestureDetector(
                                  onTap: () =>
                                      mapProvider.setSelectedFloor(floor),
                                  child: isSelected
                                      ? Container(
                                          width: 36,
                                          height: 36,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            floor.replaceAll('F', ''),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 36,
                                          height: 36,
                                          color: Colors.transparent,
                                          alignment: Alignment.center,
                                          child: Text(
                                            floor.replaceAll('F', ''),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.normal,
                                              color: AppColors.grey400,
                                            ),
                                          ),
                                        ),
                                );
                              }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
