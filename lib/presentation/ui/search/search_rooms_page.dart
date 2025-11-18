import 'package:annyong/domain/entity/building.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/building_repository.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/ui/search/search_page.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:annyong/presentation/widgets/search_rooms_page_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

class SearchRoomsPage extends ConsumerStatefulWidget {
  final String searchType;
  final int categoryId;
  final SearchMode? searchMode;
  final bool returnResult;

  const SearchRoomsPage({
    super.key,
    required this.searchType,
    required this.categoryId,
    this.searchMode,
    this.returnResult = false,
  });

  @override
  ConsumerState<SearchRoomsPage> createState() => _SearchRoomsPageState();
}

class _SearchRoomsPageState extends ConsumerState<SearchRoomsPage> {
  final BuildingRepository _buildingRepository = BuildingRepository();
  final PoiRepository _poiRepository = PoiRepository();

  List<Building> _buildings = [];
  List<Poi> _filteredPois = [];
  bool _isLoading = true;

  String? selectedBuilding;
  int? selectedBuildingId;
  String? selectedFloor;
  String? selectedClassroom;

  // 층 목록은 건물 선택 후 표시
  List<int> floors = [];
  // 강의실 번호 목록은 층 선택 후 표시
  List<Poi> classrooms = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final buildings = await _buildingRepository.fetchBuildings();
      final pois = await _poiRepository.fetchPois();

      // 선택된 카테고리에 맞는 POI만 필터링
      debugPrint('선택된 카테고리 ID: ${widget.categoryId}');
      final filteredPois = pois
          .where((poi) => poi.categoryId == widget.categoryId)
          .toList();

      // 필터링된 POI가 있는 건물만 표시
      setState(() {
        _buildings = buildings;
        _filteredPois = filteredPois;
        _isLoading = false;

        // 기본값 설정
        if (_buildings.isNotEmpty) {
          selectedBuilding = _buildings.first.name;
          selectedBuildingId = _buildings.first.id;
        }
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onBuildingSelected(Building building) {
    setState(() {
      debugPrint('선택된 건물: ${building.name}');
      selectedBuilding = building.name;
      selectedBuildingId = building.id;
      selectedFloor = null;
      selectedClassroom = null;
      // 건물 선택 시 해당 건물의 층 목록 로드
      if (selectedBuilding!.contains('5호관')) {
        floors = [1, 2];
      } else if (selectedBuilding!.contains('하이테크')) {
        floors = [1];
      } else {
        floors = [];
      }
      classrooms = [];
    });
  }

  void _onFloorSelected(int floor) {
    setState(() {
      debugPrint('선택된 층: $floor');
      selectedFloor = '${floor}F';
      selectedClassroom = null;

      // 선택된 카테고리 + 선택된 건물 + 선택된 층에 있는 POI 목록 필터링
      classrooms = _filteredPois
          .where(
            (poi) => poi.buildingId == selectedBuildingId && poi.floor == floor,
          )
          .toList();
    });
  }

  Future<void> _onClassroomSelected(Poi classroom) async {
    debugPrint('선택된 강의실: ${classroom.name}');
    setState(() {
      selectedClassroom = classroom.name;
    });

    // 결과 반환 모드인 경우 선택한 강의실 이름 반환
    if (widget.returnResult) {
      context.pop(classroom.name);
      return;
    }

    // 선택한 강의실을 출발지/목적지로 설정
    final pathProvider = ref.read(pathSelectionProvider.notifier);
    if (widget.searchMode == SearchMode.departure) {
      pathProvider.setDeparture(classroom.name);
    } else if (widget.searchMode == SearchMode.destination) {
      pathProvider.setDestination(classroom.name);
    } else {
      // 기본 모드: 목적지로 설정하고 pathSelection으로 이동
      pathProvider.setDestination(classroom.name);
    }
    context.go("/home/pathSelection");
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios, color: AppColors.text),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.grey200,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '강의실 번호를 입력하세요!',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.grey400,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    Icon(Icons.search_rounded, color: AppColors.text, size: 24),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // -------------------선택 요소 표시용 헤더-------------------
          Container(
            decoration: BoxDecoration(
              color: AppColors.grey200,
              border: Border(
                bottom: BorderSide(color: AppColors.grey300, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      CategoryBox(categoryName: '건물'),
                      if (selectedBuilding != null && selectedFloor == null)
                        SelectedCategoryFlag(),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      CategoryBox(categoryName: '층'),
                      if (selectedFloor != null && selectedClassroom == null)
                        SelectedCategoryFlag(),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      CategoryBox(categoryName: '강의실 번호'),
                      if (selectedClassroom != null) SelectedCategoryFlag(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // -------------------세부 정보 선택 창-------------------
          Expanded(
            child: Row(
              children: [
                // -------------------건물 컬럼-------------------
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: AppColors.grey300, width: 1),
                      ),
                    ),
                    child: ListView.builder(
                      itemCount: _buildings.length,
                      itemBuilder: (context, index) {
                        final building = _buildings[index];
                        final isSelected = selectedBuilding == building.name;
                        return CategoryItem(
                          name: building.name,
                          isSelected: isSelected,
                          onTap: () => _onBuildingSelected(building),
                        );
                      },
                    ),
                  ),
                ),
                // -------------------층 컬럼-------------------
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: AppColors.grey300, width: 1),
                      ),
                    ),
                    child: selectedBuilding == null
                        ? const SizedBox()
                        : ListView.builder(
                            itemCount: floors.length,
                            itemBuilder: (context, index) {
                              final floor = floors[index];
                              final floorLabel = '${floor}F';
                              final isSelected = selectedFloor == floorLabel;
                              return CategoryItem(
                                name: floorLabel,
                                isSelected: isSelected,
                                onTap: () => _onFloorSelected(floor),
                              );
                            },
                          ),
                  ),
                ),
                // -------------------강의실 번호 컬럼-------------------
                Expanded(
                  child: selectedFloor == null
                      ? const SizedBox()
                      : ListView.builder(
                          itemCount: classrooms.length,
                          itemBuilder: (context, index) {
                            final classroom = classrooms[index];
                            final isSelected =
                                selectedClassroom == classroom.name;
                            return CategoryItemRooms(
                              name: classroom.name,
                              isSelected: isSelected,
                              onTap: () => _onClassroomSelected(classroom),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
