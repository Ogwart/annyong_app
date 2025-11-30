import 'package:annyong/presentation/viewmodels/home_map_viewmodel.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:annyong/presentation/viewmodels/category_view_model.dart';
import 'package:annyong/presentation/providers/home_page_map_provider.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/global_widgets/category_button.dart';
import 'package:annyong/presentation/widgets/global_widgets/poi_button.dart';
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
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

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final resolution = MapUtilFunctions.getResolutionFromScale(scale);

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
      body: SafeArea(
        child: LayoutBuilder(
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

            return Container(
              alignment: Alignment.center,
              width: double.infinity,
              child: Stack(
                children: [
                  // -------------------지도-------------------
                  Positioned.fill(
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
                  // 마커 빌더 (선택된 카테고리 또는 즐겨찾기)
                  ...MapUtilFunctions.getFilteredFavoritePois(
                    categoryState.displayedPois,
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
                          ref
                              .read(pathSelectionProvider.notifier)
                              .setDestination(poi);
                          context.go('/home/pathSelection');
                        },
                        child: PoiButton(bookmarkTitle: poi.name),
                      ),
                    );
                  }),
                  // 시설물 검색
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ------------------메뉴 드로우어 버튼------------------
                          Flexible(
                            flex: 1,
                            child: GestureDetector(
                              onTap: () {
                                context.go('/home/menu');
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: AppColors.grey200,
                                ),
                                child: const Icon(
                                  Icons.menu,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // ------------------시설물 검색 버튼------------------
                          Flexible(
                            flex: 2,
                            child: GestureDetector(
                              onTap: () {
                                context.go('/home/search');
                              },
                              child: Container(
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: AppColors.grey200,
                                ),
                                child: const Text(
                                  "시설물 검색",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // ------------------길찾기 버튼------------------
                          Flexible(
                            flex: 1,
                            child: GestureDetector(
                              onTap: () {
                                context.go('/home/pathSelection');
                              },
                              child: Container(
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: AppColors.primary,
                                ),
                                child: const Text(
                                  "길찾기",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // -----------------------카테고리-------------------------
                  Positioned(
                    top: 60,
                    left: 24,
                    right: 24,
                    height: 50,
                    child: SizedBox(
                      child: Padding(
                        padding: EdgeInsetsGeometry.all(4),
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
                            final category =
                                categoryState.categories[index - 1];
                            return Center(
                              child: CategoryButton(
                                bookmarkTitle: category.name.replaceAll(
                                  '\n',
                                  '/',
                                ),
                                isSelected:
                                    categoryState.selectedCategoryId ==
                                    category.id,
                                onTap: () => ref
                                    .read(categoryProvider.notifier)
                                    .onCategorySelected(category.id),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  // --------------------건물 전환 버튼----------------------
                  Positioned(
                    bottom: 20,
                    left: 24,
                    child: GestureDetector(
                      onTap: () {
                        mapProvider.toggleBuilding();
                      },
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 70,
                          minHeight: 47,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.grey200,
                        ),
                        child: Text(
                          mapProvider.selectedBuilding,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // --------------------층 전환 버튼------------------------
                  Positioned(
                    bottom: 20,
                    right: 24,
                    child: Column(
                      children:
                          MapUtilFunctions.getAvailableFloors(
                                mapProvider.selectedBuilding,
                              )
                              .map(
                                (floor) => FloorButton(
                                  floor: floor,
                                  onTap: () =>
                                      mapProvider.setSelectedFloor(floor),
                                  isSelected:
                                      mapProvider.selectedFloor == floor,
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
