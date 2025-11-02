import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/search_rooms_page_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchRoomsPage extends StatefulWidget {
  final String searchType;

  const SearchRoomsPage({super.key, required this.searchType});

  @override
  State<SearchRoomsPage> createState() => _SearchRoomsPageState();
}

class _SearchRoomsPageState extends State<SearchRoomsPage> {
  String? selectedBuilding;
  String? selectedFloor;
  String? selectedClassroom;

  // 임시 데이터 - 나중에 실제 데이터로 교체
  final List<String> buildings = [
    '하이테크',
    '5호관(동)',
    '5호관(서)',
    '5호관(남)',
    '5호관(북)',
  ];

  // 층 목록은 건물 선택 후 표시
  List<String> floors = [];
  // 강의실 번호 목록은 층 선택 후 표시
  List<String> classrooms = [];

  @override
  void initState() {
    super.initState();
    // 기본값 설정 (UI 확인용)
    selectedBuilding = '하이테크';
    floors = []; // 하이테크에는 층 목록이 없음
    selectedFloor = null;
    classrooms = [];
    selectedClassroom = null;
  }

  void _onBuildingSelected(String building) {
    setState(() {
      selectedBuilding = building;
      selectedFloor = null;
      selectedClassroom = null;
      // 건물 선택 시 해당 건물의 층 목록 로드
      if (building == '5호관(남)') {
        floors = ['B1', '1F', '2F', '3F', '4F', '5F', '6F'];
      } else {
        floors = [];
      }
      classrooms = [];
    });
  }

  void _onFloorSelected(String floor) {
    setState(() {
      selectedFloor = floor;
      selectedClassroom = null;
      // 층 선택 시 해당 층의 강의실 목록 로드 (임시 데이터)
      if (selectedBuilding == '5호관(남)' && floor == '5F') {
        classrooms = [
          '5S501',
          '5S503',
          '5S505',
          '5S509',
          '5S517',
          '5S518',
          '5S521',
          '5S531',
          '5S532',
          '5S533',
          '5S534',
          '5S535',
        ];
      } else {
        classrooms = [];
      }
    });
  }

  void _onClassroomSelected(String classroom) {
    setState(() {
      selectedClassroom = classroom;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      itemCount: buildings.length,
                      itemBuilder: (context, index) {
                        final building = buildings[index];
                        final isSelected = selectedBuilding == building;
                        return CategoryItem(
                          name: building,
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
                              final isSelected = selectedFloor == floor;
                              return CategoryItem(
                                name: floor,
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
                            final isSelected = selectedClassroom == classroom;
                            return CategoryItemRooms(
                              name: classroom,
                              isSelected: isSelected,
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
