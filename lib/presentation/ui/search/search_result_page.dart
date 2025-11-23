import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/providers/search_result_provider.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/ui/search/search_page.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'package:annyong/presentation/widgets/search_result_item.dart';
import 'package:annyong/presentation/util/home_page_util_funtions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  late final Future<List<Poi>> _poiFuture;
  late final String _displayKeyword;

  @override
  void initState() {
    super.initState();
    _displayKeyword = widget.searchKeyword ?? '';
    debugPrint('선택된 키워드: $_displayKeyword');
    _poiFuture = _loadPois();
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

  // 실제 POI 데이터를 불러오는 메서드
  Future<List<Poi>> _loadPois() async {
    final pois = await _repository.fetchPois();
    if (widget.categoryId != null) {
      return pois.where((poi) => poi.categoryId == widget.categoryId).toList();
    }
    return pois;
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

  List<Poi> _getFilteredPoisForCurrentBuildingAndFloor(
    List<Poi> allPois,
    String building,
    String floor,
  ) {
    final buildingId = HomePageUtilFunctions.getBuildingId(building);
    final floorNumber = HomePageUtilFunctions.getFloorNumber(floor);
    return allPois
        .where(
          (poi) => poi.buildingId == buildingId && poi.floor == floorNumber,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchResultProvider);
    final notifier = ref.read(searchResultProvider.notifier);

    // 화면을 벗어날 때 초기화
    ref.listen(searchResultProvider, (previous, next) {});
    final imagePath = notifier.getImagePath();

    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop) {
          // 화면을 벗어날 때 초기화 (다음 프레임에 실행)
          Future.microtask(() {
            notifier.reset();
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
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
                        _getFilteredPoisForCurrentBuildingAndFloor(
                          allPois,
                          state.selectedBuilding,
                          state.selectedFloor,
                        );

                    // 디버깅: 필터링된 POI 정보 로그 출력
                    debugPrint('=== 검색 결과 POI 마커 정보 ===');
                    debugPrint('전체 POI 개수: ${allPois.length}');
                    debugPrint('필터링된 POI 개수: ${filteredPois.length}');
                    debugPrint(
                      '현재 건물: ${state.selectedBuilding}, 층: ${state.selectedFloor}',
                    );
                    debugPrint('---');
                    for (var poi in filteredPois) {
                      final scaledX = poi.xCoord * 0.3;
                      final scaledY = poi.yCoord * 0.5;
                      final adjustedX = scaledX - 20;
                      final adjustedY = scaledY + 285;
                      final buildingName = poi.buildingId == 1
                          ? '5호관'
                          : poi.buildingId == 2
                          ? '하이테크관'
                          : '알 수 없음';
                      debugPrint(
                        'POI 이름: ${poi.name} | 건물: $buildingName | 층: ${poi.floor}F | '
                        '원본 좌표: (${poi.xCoord}, ${poi.yCoord}) | '
                        '변환된 좌표: ($adjustedX, $adjustedY)',
                      );
                    }
                    debugPrint('============================');

                    return Stack(
                      children: [
                        // 지도와 마커
                        InteractiveViewer(
                          boundaryMargin: EdgeInsets.all(20),
                          panEnabled: true,
                          scaleEnabled: false, // 확대축소 불가
                          minScale: 3.0,
                          maxScale: 3.0,
                          child: Stack(
                            children: [
                              // 지도
                              Positioned.fill(
                                child: Image.asset(
                                  imagePath,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              // POI 위치 마커
                              ...filteredPois.map((poi) {
                                // POI 좌표에 스케일 및 오프셋 적용 (home_page와 동일한 로직)
                                final scaledX = poi.xCoord * 0.23;
                                final scaledY = poi.yCoord * 0.27;
                                final adjustedX = scaledX - 0;
                                final adjustedY = scaledY + 130;

                                return Positioned(
                                  left: adjustedX - 12,
                                  top: adjustedY - 24,
                                  child: IgnorePointer(
                                    child: Container(
                                      color: AppColors.secondary,
                                      child: Row(
                                        children: [
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
                            ],
                          ),
                        ),
                        // 뒤로가기 버튼
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: IconButton(
                              onPressed: () {
                                // 다음 프레임에 초기화 (위젯 빌드 중 상태 변경 방지)
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
                        // 건물 선택 버튼 (왼쪽 하단)
                        Positioned(
                          bottom: 20,
                          left: 20,
                          child: GestureDetector(
                            onTap: () {
                              // 5호관과 하이테크관 토글
                              final newBuilding =
                                  state.selectedBuilding == '5호관'
                                  ? '하이테크관'
                                  : '5호관';
                              notifier.setSelectedBuilding(newBuilding);
                              // 건물 변경 시 층을 1F로 초기화
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
                        // 층 선택 버튼 (오른쪽 하단, 하단 패널 위에 배치)
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: Column(
                            children:
                                HomePageUtilFunctions.getAvailableFloors(
                                  state.selectedBuilding,
                                ).map((floor) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: FloorButton(
                                      floor: floor,
                                      isSelected: state.selectedFloor == floor,
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
                            final buildingList = ["5서", "5남", "하"];
                            return SearchResultItem(
                              title: poi.name,
                              categoryId: poi.categoryId,
                              // 디버깅을 위해 시연 전까진 POI 속성을 덧붙여 설명
                              // description: poi.description ?? '설명 없음',
                              description:
                                  "POI ${poi.id}: ${buildingList[poi.buildingId - 1]}에 위치, ${poi.description}",
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
    );
  }
}
