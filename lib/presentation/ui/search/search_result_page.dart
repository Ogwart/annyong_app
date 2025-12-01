import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/providers/search_result_provider.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/ui/search/search_page.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'package:annyong/presentation/widgets/search_result_item.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:annyong/presentation/util/search_result_page_util.dart';

class SearchResultPage extends ConsumerStatefulWidget {
  final String? searchKeyword;
  final int? categoryId;
  final SearchMode? searchMode;
  final bool returnResult;

  const SearchResultPage({
    super.key,
    this.searchKeyword,
    this.categoryId,
    this.searchMode,
    this.returnResult = false,
  });

  @override
  ConsumerState<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends ConsumerState<SearchResultPage> {
  final PoiRepository _repository = PoiRepository();
  final TransformationController _transformationController =
      TransformationController();
  late final Future<List<Poi>> _poiFuture;
  late final String _displayKeyword;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 초기 줌 레벨 3.0 설정
    _transformationController.value = Matrix4.identity()
      ..scaleByDouble(1, 1, 1, 1);
    _transformationController.addListener(() {
      setState(() {});
    });
    _displayKeyword = widget.searchKeyword ?? '';
    debugPrint('선택된 키워드: $_displayKeyword');
    _poiFuture = SearchResultPageUtil.loadPois(
      _repository,
      categoryId: widget.categoryId,
    );
    debugPrint('카테고리 ID: ${widget.categoryId}');

    // 페이지 진입 시 searchKeyword 설정 및 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(searchResultProvider.notifier);
      notifier.setSearchKeyword(_displayKeyword);
      // 초기값 설정 (5호관 1층) - 다음 프레임에 실행
      Future.microtask(() {
        notifier.reset();
      });
    });
  }

  // POI 선택 처리 핸들러
  void _handlePoiSelect(Poi poi) {
    // 결과 반환 모드인 경우 선택한 POI 객체 반환
    if (widget.returnResult) {
      context.pop(poi);
      return;
    }

    // 선택한 강의실을 출발지/목적지로 설정
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
      // 기본 모드: 목적지로 설정하고 pathSelection으로 이동
      pathProvider.setDestination(poi);
    }
    context.go("/home/pathSelection");
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchResultProvider);
    final notifier = ref.read(searchResultProvider.notifier);

    // 화면을 벗어날 때 초기화
    ref.listen(searchResultProvider, (previous, next) {});
    final imagePath = notifier.getImagePath();

    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // 화면을 벗어날 때 초기화 (다음 프레임에 실행)
          Future.microtask(() {
            notifier.reset();
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // 지도 영역 (상단 60%)
              Expanded(
                flex: 6,
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: FutureBuilder<List<Poi>>(
                    future: _poiFuture,
                    builder: (context, snapshot) {
                      final allPois = snapshot.data ?? [];
                      final filteredPois =
                          SearchResultPageUtil.getFilteredPoisForCurrentBuildingAndFloor(
                            allPois,
                            state.selectedBuilding,
                            state.selectedFloor,
                          );

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final containerSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );

                          // 1x 기준 원본 크기
                          final baseOriginalSize =
                              MapUtilFunctions.getImageOriginalSize(
                                state.selectedBuilding,
                                state.selectedFloor,
                                '1x',
                              );

                          // 표시 크기 계산
                          final displayedImageSize =
                              MapUtilFunctions.getDisplayedImageSize(
                                containerSize,
                                baseOriginalSize,
                              );

                          // 오프셋 및 스케일
                          final imageOffsetX =
                              (containerSize.width - displayedImageSize.width) /
                              2;
                          final imageOffsetY =
                              (containerSize.height -
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
                                child: InteractiveViewer(
                                  transformationController:
                                      _transformationController,
                                  boundaryMargin: EdgeInsets.all(20),
                                  panEnabled: true,
                                  scaleEnabled: false,
                                  minScale: 3.0,
                                  maxScale: 3.0,
                                  child: Image.asset(
                                    imagePath,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              // POI 위치 마커
                              ...filteredPois.map((poi) {
                                final transformation =
                                    _transformationController.value;

                                // POI 좌표 -> 1배 줌 상태의 화면 좌표
                                final initialScreenX =
                                    poi.xCoord * scaleX + imageOffsetX;
                                final initialScreenY =
                                    poi.yCoord * scaleY + imageOffsetY;

                                // InteractiveViewer 변환 적용
                                final transformedX =
                                    transformation.storage[0] * initialScreenX +
                                    transformation.storage[4] * initialScreenY +
                                    transformation.storage[12];
                                final transformedY =
                                    transformation.storage[1] * initialScreenX +
                                    transformation.storage[5] * initialScreenY +
                                    transformation.storage[13];

                                // 마커 위치 오프셋 적용
                                final markerOffset =
                                    MapUtilFunctions.markerOffset;

                                return Positioned(
                                  left: transformedX - 12 + markerOffset.dx,
                                  top: transformedY - 24 + markerOffset.dy,
                                  child: IgnorePointer(
                                    child: Container(
                                      color: AppColors.secondary,
                                      child: Row(
                                        children: [
                                          // TODO: 마커 UI 변경
                                          Icon(
                                            Icons.location_on,
                                            color: AppColors.primary,
                                            size: 24,
                                          ),
                                          Text("${poi.id}"),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              // 뒤로가기 버튼
                              SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: IconButton(
                                    onPressed: () {
                                      Future.microtask(() {
                                        notifier.reset();
                                      });
                                      context.pop();
                                    },
                                    icon: const Icon(
                                      Icons.arrow_back_ios,
                                      color: AppColors.text,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                              // 건물 선택 버튼
                              Positioned(
                                bottom: 20,
                                left: 20,
                                child: GestureDetector(
                                  onTap: () {
                                    final newBuilding =
                                        state.selectedBuilding == '5호관'
                                        ? '60주년기념관'
                                        : '5호관';
                                    notifier.setSelectedBuilding(newBuilding);
                                    notifier.setSelectedFloor('1F');
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
                                      state.selectedBuilding,
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
                                        state.selectedBuilding,
                                      ).map((floor) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: FloorButton(
                                            floor: floor,
                                            isSelected:
                                                state.selectedFloor == floor,
                                            onTap: () {
                                              notifier.setSelectedFloor(floor);
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
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final poi = results[index];
                              return SearchResultItem(
                                title: poi.name,
                                categoryId: poi.categoryId,
                                description: poi.description ?? '설명 없음',
                                // 디버깅용
                                // description:
                                //     "POI ${poi.id}: ${buildingList[poi.buildingId - 1]}에 위치, ${poi.description}",
                                onSelect: () => _handlePoiSelect(poi),
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
