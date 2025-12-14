import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/presentation/providers/search_result_provider.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/ui/search/search_page.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
import 'package:annyong/presentation/util/search_result_page_util.dart';
import 'package:annyong/presentation/viewmodels/category_view_model.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:annyong/presentation/widgets/global_widgets/category_button.dart';
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'package:annyong/presentation/widgets/search_result_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vector_math/vector_math_64.dart' as math64;

class MapSearchPage extends ConsumerStatefulWidget {
  final SearchMode? searchMode;
  final bool returnResult;

  const MapSearchPage({super.key, this.searchMode, this.returnResult = false});

  @override
  ConsumerState<MapSearchPage> createState() => _MapSearchPageState();
}

class _MapSearchPageState extends ConsumerState<MapSearchPage>
    with SingleTickerProviderStateMixin {
  final PoiRepository _repository = PoiRepository();
  final TransformationController _transformationController =
      TransformationController();
  final ScrollController _scrollController = ScrollController();
  Size? _mapContainerSize;

  late final Future<List<Poi>> _poiFuture;
  late final AnimationController _mapAnimationController;
  Animation<Matrix4>? _mapAnimation;

  @override
  void initState() {
    super.initState();
    _transformationController.value = Matrix4.identity();
    _transformationController.addListener(() {
      setState(() {});
    });

    _mapAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _mapAnimationController.addListener(() {
      if (_mapAnimation != null) {
        _transformationController.value = _mapAnimation!.value;
      }
    });

    _poiFuture = _repository.fetchPois();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchResultProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _scrollController.dispose();
    _mapAnimationController.dispose();
    super.dispose();
  }

  void _animateMapToPoi(Poi poi) {
    if (_mapContainerSize == null) return;

    final state = ref.read(searchResultProvider);
    final baseOriginalSize = MapUtilFunctions.getImageOriginalSize(
      state.selectedBuilding,
      state.selectedFloor,
      '1x',
    );

    final displayedImageSize = MapUtilFunctions.getDisplayedImageSize(
      _mapContainerSize!,
      baseOriginalSize,
    );

    final scaleX = displayedImageSize.width / baseOriginalSize.width;
    final scaleY = displayedImageSize.height / baseOriginalSize.height;

    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final targetZoom = currentScale < 2.0 ? 4.0 : currentScale;

    final imageOffsetX =
        (_mapContainerSize!.width - displayedImageSize.width) / 2;
    final imageOffsetY =
        (_mapContainerSize!.height - displayedImageSize.height) / 2;

    final targetX =
        -((poi.xCoord * scaleX + imageOffsetX) * targetZoom -
            _mapContainerSize!.width / 2);
    final targetY =
        -((poi.yCoord * scaleY + imageOffsetY) * targetZoom -
            _mapContainerSize!.height / 2);

    final targetMatrix = Matrix4.identity()
      ..translateByVector3(math64.Vector3(targetX, targetY, 0))
      ..scale(targetZoom);

    _mapAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: targetMatrix,
        ).animate(
          CurvedAnimation(
            parent: _mapAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    _mapAnimationController.forward(from: 0);
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;

    const double estimatedItemHeight = 100.0;
    final double targetOffset = index * estimatedItemHeight;
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double offset = targetOffset > maxScroll ? maxScroll : targetOffset;

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handlePoiSelect(Poi poi) {
    if (widget.returnResult) {
      context.pop(poi);
      return;
    }

    final pathProvider = ref.read(pathSelectionProvider.notifier);
    if (widget.searchMode == SearchMode.departure) {
      pathProvider.setDeparture(poi);
    } else if (widget.searchMode == SearchMode.destination) {
      pathProvider.setDestination(poi);
    } else if (widget.searchMode == SearchMode.waypoint1) {
      pathProvider.setWaypoint1(poi);
    } else if (widget.searchMode == SearchMode.waypoint2) {
      pathProvider.setWaypoint2(poi);
    } else {
      pathProvider.reset();
      pathProvider.setDestination(poi);
    }
    context.go("/home/pathSelection");
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchResultProvider);
    final searchNotifier = ref.read(searchResultProvider.notifier);
    final categoryState = ref.watch(categoryProvider);
    final imagePath = searchNotifier.getImagePath();

    // 포커스된 POI가 변경되면 지도와 리스트를 이동시킴
    ref.listen<SearchResultState>(searchResultProvider, (previous, next) async {
      if (next.focusedPoiId != null &&
          next.focusedPoiId != previous?.focusedPoiId) {
        final allPois = await _poiFuture;
        final currentCategoryState = ref.read(categoryProvider);

        // 카테고리 필터 적용 (리스트와 동일한 로직)
        List<Poi> filteredByCategory;
        if (currentCategoryState.selectedCategoryId == -1) {
          filteredByCategory = currentCategoryState.favoritePois;
        } else if (currentCategoryState.selectedCategoryId == -2) {
          filteredByCategory = allPois;
        } else {
          filteredByCategory = allPois
              .where(
                (poi) =>
                    poi.categoryId == currentCategoryState.selectedCategoryId,
              )
              .toList();
        }

        // 건물/층 필터 적용
        final filteredList =
            SearchResultPageUtil.getFilteredPoisForCurrentBuildingAndFloor(
              filteredByCategory,
              next.selectedBuilding,
              next.selectedFloor,
            );

        final index = filteredList.indexWhere((p) => p.id == next.focusedPoiId);
        if (index != -1) {
          final targetPoi = filteredList[index];
          _animateMapToPoi(targetPoi);
          _scrollToIndex(index);
        }
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          Future.microtask(() {
            searchNotifier.reset();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("출발지 선택")),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              // 카테고리 필터 (상단)
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categoryState.categories.length + 1,
                  itemBuilder: (BuildContext context, int index) {
                    if (index == 0) {
                      return Center(
                        child: CategoryButton(
                          bookmarkTitle: '즐겨찾기',
                          isSelected: categoryState.selectedCategoryId == -1,
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
              // 지도 영역 (중앙 60%)
              Expanded(
                flex: 6,
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: FutureBuilder<List<Poi>>(
                    future: _poiFuture,
                    builder: (context, snapshot) {
                      final allPois = snapshot.data ?? [];

                      // 카테고리 필터 적용
                      List<Poi> filteredByCategory;
                      if (categoryState.selectedCategoryId == -1) {
                        filteredByCategory = categoryState.favoritePois;
                      } else if (categoryState.selectedCategoryId == -2) {
                        filteredByCategory = allPois;
                      } else {
                        filteredByCategory = allPois
                            .where(
                              (poi) =>
                                  poi.categoryId ==
                                  categoryState.selectedCategoryId,
                            )
                            .toList();
                      }

                      // 건물/층 필터 적용
                      final filteredPois =
                          SearchResultPageUtil.getFilteredPoisForCurrentBuildingAndFloor(
                            filteredByCategory,
                            searchState.selectedBuilding,
                            searchState.selectedFloor,
                          );

                      // 선택된 POI는 가장 앞에 위치하도록 리스트 맨 뒤로 옮김
                      if (searchState.focusedPoiId != null) {
                        final focusedIndex = filteredPois.indexWhere(
                          (p) => p.id == searchState.focusedPoiId,
                        );
                        if (focusedIndex != -1) {
                          final focusedPoi = filteredPois.removeAt(
                            focusedIndex,
                          );
                          filteredPois.add(focusedPoi);
                        }
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          _mapContainerSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );

                          final baseOriginalSize =
                              MapUtilFunctions.getImageOriginalSize(
                                searchState.selectedBuilding,
                                searchState.selectedFloor,
                                '1x',
                              );

                          final displayedImageSize =
                              MapUtilFunctions.getDisplayedImageSize(
                                _mapContainerSize!,
                                baseOriginalSize,
                              );

                          final imageOffsetX =
                              (_mapContainerSize!.width -
                                  displayedImageSize.width) /
                              2;
                          final imageOffsetY =
                              (_mapContainerSize!.height -
                                  displayedImageSize.height) /
                              2;
                          final scaleX =
                              displayedImageSize.width / baseOriginalSize.width;
                          final scaleY =
                              displayedImageSize.height /
                              baseOriginalSize.height;

                          return Stack(
                            children: [
                              // 지도 (InteractiveViewer)
                              Positioned.fill(
                                child: GestureDetector(
                                  onTap: () =>
                                      searchNotifier.setFocusedPoi(null),
                                  child: InteractiveViewer(
                                    transformationController:
                                        _transformationController,
                                    boundaryMargin: EdgeInsets.all(20),
                                    panEnabled: true,
                                    scaleEnabled: true,
                                    minScale: 1.0,
                                    maxScale: 6.0,
                                    child: Image.asset(
                                      imagePath,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),

                              // POI 마커 렌더링
                              ...filteredPois.map((poi) {
                                final transformation =
                                    _transformationController.value;
                                final initialScreenX =
                                    poi.xCoord * scaleX + imageOffsetX;
                                final initialScreenY =
                                    poi.yCoord * scaleY + imageOffsetY;

                                final transformedX =
                                    transformation.storage[0] * initialScreenX +
                                    transformation.storage[4] * initialScreenY +
                                    transformation.storage[12];
                                final transformedY =
                                    transformation.storage[1] * initialScreenX +
                                    transformation.storage[5] * initialScreenY +
                                    transformation.storage[13];

                                final isSelected =
                                    (poi.id == searchState.focusedPoiId);

                                const double iconSize = 35.0;
                                final double scale = isSelected ? 1.1 : 1.0;

                                return Positioned(
                                  left: transformedX - (iconSize / 2),
                                  top: transformedY - (iconSize / 2),
                                  child: GestureDetector(
                                    onTap: () {
                                      searchNotifier.setFocusedPoi(poi.id);
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // 마커 아이콘
                                        AnimatedScale(
                                          scale: scale,
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          curve: Curves.easeOutBack,
                                          child: Container(
                                            width: iconSize,
                                            height: iconSize,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: isSelected
                                                      ? AppColors.primary
                                                            .withAlpha(50)
                                                      : Colors.black.withAlpha(
                                                          20,
                                                        ),
                                                  blurRadius: isSelected
                                                      ? 12
                                                      : 6,
                                                  offset: const Offset(0, 4),
                                                  spreadRadius: isSelected
                                                      ? 2
                                                      : 0,
                                                ),
                                              ],
                                            ),
                                            child: SvgPicture.asset(
                                              'assets/icons/svg/general_marker.svg',
                                            ),
                                          ),
                                        ),
                                        // 항상 텍스트 표시
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4.0,
                                          ),
                                          child: Stack(
                                            children: [
                                              Text(
                                                poi.name,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  foreground: Paint()
                                                    ..style =
                                                        PaintingStyle.stroke
                                                    ..strokeWidth = 3.0
                                                    ..color = Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                poi.name,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.text,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              // 건물 선택 버튼
                              Positioned(
                                bottom: 20,
                                left: 20,
                                child: GestureDetector(
                                  onTap: () {
                                    final newBuilding =
                                        searchState.selectedBuilding == '5호관'
                                        ? '60주년기념관'
                                        : '5호관';
                                    searchNotifier.setSelectedBuilding(
                                      newBuilding,
                                    );
                                    searchNotifier.setSelectedFloor('1F');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.grey200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      searchState.selectedBuilding,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // 층 선택 버튼
                              Positioned(
                                bottom: 20,
                                right: 20,
                                child: Column(
                                  children:
                                      MapUtilFunctions.getAvailableFloors(
                                        searchState.selectedBuilding,
                                      ).map((floor) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: FloorButton(
                                            floor: floor,
                                            isSelected:
                                                searchState.selectedFloor ==
                                                floor,
                                            onTap: () {
                                              searchNotifier.setSelectedFloor(
                                                floor,
                                              );
                                            },
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              // 검색 결과 패널 (하단 40%)
              Container(
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: BoxDecoration(
                  color: AppColors.grey200,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // 패널 드래그 핸들
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.grey400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // 검색 결과 리스트
                    Expanded(
                      child: FutureBuilder<List<Poi>>(
                        future: _poiFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final results = snapshot.data ?? [];

                          // 카테고리 필터 적용
                          List<Poi> filteredByCategory;
                          if (categoryState.selectedCategoryId == -1) {
                            filteredByCategory = categoryState.favoritePois;
                          } else if (categoryState.selectedCategoryId == -2) {
                            filteredByCategory = results;
                          } else {
                            filteredByCategory = results
                                .where(
                                  (poi) =>
                                      poi.categoryId ==
                                      categoryState.selectedCategoryId,
                                )
                                .toList();
                          }

                          // 건물/층 필터 적용
                          final displayList =
                              SearchResultPageUtil.getFilteredPoisForCurrentBuildingAndFloor(
                                filteredByCategory,
                                searchState.selectedBuilding,
                                searchState.selectedFloor,
                              );

                          if (displayList.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 48,
                                    color: AppColors.grey400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "해당 층에는 시설물이 없습니다.",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.grey400,
                                      fontFamily: 'Pretendard',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final bool isAnyFocused =
                              searchState.focusedPoiId != null;

                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            itemCount: displayList.length,
                            itemBuilder: (context, index) {
                              final poi = displayList[index];

                              final bool isMeFocused =
                                  poi.id == searchState.focusedPoiId;
                              final double opacity =
                                  (isAnyFocused && !isMeFocused) ? 0.5 : 1.0;

                              return AnimatedOpacity(
                                duration: const Duration(milliseconds: 50),
                                opacity: opacity,
                                child: InkWell(
                                  onTap: () {
                                    if (isMeFocused) {
                                      searchNotifier.setFocusedPoi(null);
                                    } else {
                                      searchNotifier.setFocusedPoi(poi.id);
                                    }
                                  },
                                  child: SearchResultItem(
                                    title: poi.name,
                                    categoryId: poi.categoryId,
                                    description: poi.description ?? '설명 없음',
                                    onSelect: () => _handlePoiSelect(poi),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
