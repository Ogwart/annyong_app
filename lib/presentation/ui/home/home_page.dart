import 'package:annyong/presentation/viewmodels/home_map_viewmodel.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:annyong/presentation/providers/home_page_map_provider.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/global_widgets/bookmark__button.dart';
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class MapNoRepeat extends Epsg3857 {
  const MapNoRepeat();

  @override
  bool get replicatesWorldLongitude => false;
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final MapController mapController = MapController();
  final LatLngBounds mapBounds = LatLngBounds(
    const LatLng(0, 0),
    const LatLng(13, 7),
  );

  // 지도 화면 밖으로 넘어가는 현상 방지용 함수
  // center 값이 지도 범위를 넘어서면 화면을 강제로 안쪽으로 끌어옴
  void checkAndConstrainBounds(LatLng? currentCenter) {
    if (currentCenter == null) return;

    final LatLngBounds visibleBounds = mapController.camera.visibleBounds;
    final double correctionlng = visibleBounds.east - currentCenter.longitude;
    final double correctionLat = currentCenter.latitude - visibleBounds.south;

    double newLat = currentCenter.latitude;
    double newlng = currentCenter.longitude;

    if (newLat < mapBounds.south + correctionLat) {
      newLat = mapBounds.south + correctionLat;
    } else if (newLat > mapBounds.north - correctionLat) {
      newLat = mapBounds.north - correctionLat;
    }

    if (newlng < mapBounds.west + correctionlng) {
      newlng = mapBounds.west + correctionlng;
    } else if (newlng > mapBounds.east - correctionlng) {
      newlng = mapBounds.east - correctionlng;
    }
    if (newLat != currentCenter.latitude || newlng != currentCenter.longitude) {
      mapController.move(LatLng(newLat, newlng), mapController.camera.zoom);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeMapProvider.notifier).resetMapReady();
      // 홈 페이지로 돌아올 때 출발지/목적지 초기화
      ref.read(pathSelectionProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  String _getTileUrlTemplate(String building, String floor) {
    // 5호관인 경우에만 층에 따라 타일 경로 반환
    if (building == '5호관') {
      switch (floor) {
        case '1F':
          return 'assets/map/5_1F/{z}/{x}/{y}.jpg';
        case '2F':
          return 'assets/map/5_2F/{z}/{x}/{y}.jpg';
        default:
          return 'assets/map/5_1F/{z}/{x}/{y}.jpg';
      }
    }
    if (building == '하이테크관') {
      switch (floor) {
        case '1F':
          return 'assets/map/8_1F/{z}/{x}/{y}.jpg';
        default:
          return 'assets/map/8_1F/{z}/{x}/{y}.jpg';
      }
    }
    // 다른 건물은 기본값 반환
    return 'assets/map/5_1F/{z}/{x}/{y}.jpg';
  }

  List<String> _getAvailableFloors(String building) {
    // 건물에 따라 사용 가능한 층 리스트 반환
    switch (building) {
      case '5호관':
        return ['2F', '1F'];
      case '하이테크관':
        return ['1F'];
      default:
        return ['1F'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMapReady = ref.watch(homeMapProvider);
    final mapProvider = context.watch<HomePageMapProvider>();
    final tileUrlTemplate = _getTileUrlTemplate(
      mapProvider.selectedBuilding,
      mapProvider.selectedFloor,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              alignment: AlignmentGeometry.center,
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    crs: MapNoRepeat(),
                    backgroundColor: Colors.white,
                    interactionOptions: InteractionOptions(
                      flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
                    ),
                    initialCenter: LatLng(6.5, 3.5),
                    initialZoom: 1,
                    maxZoom: 3,
                    minZoom: 1,
                    // onMapReady: () {
                    //   ref.read(homeMapProvider.notifier).setMapReady();
                    // },
                    // cameraConstraint: CameraConstraint.contain(
                    //   bounds: mapBounds,
                    // ),
                    // onPositionChanged: (camera, hasGesture) {
                    //   if (hasGesture && isMapReady) {
                    //     checkAndConstrainBounds(camera.center);
                    //   }
                    // },
                  ),
                  children: [
                    TileLayer(
                      tileProvider: AssetTileProvider(),
                      urlTemplate: tileUrlTemplate,
                      tileDimension: 256,
                      //tms: true,
                    ),
                  ],
                ),
                // 시설물 검색
                Positioned(
                  top: 10,
                  child: Row(
                    children: [
                      // ------------------메뉴 드로우어 버튼------------------
                      GestureDetector(
                        onTap: () {
                          context.go('/home/menu');
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: AppColors.grey200,
                          ),
                          child: const Icon(Icons.menu, color: AppColors.text),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ------------------시설물 검색 버튼------------------
                      GestureDetector(
                        onTap: () {
                          context.go('/home/search');
                        },
                        child: Container(
                          width: 200,
                          height: 50,
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
                      const SizedBox(width: 12),
                      // ------------------길찾기 버튼------------------
                      GestureDetector(
                        onTap: () {
                          context.go('/home/pathSelection');
                        },
                        child: Container(
                          width: 80,
                          height: 50,
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
                    ],
                  ),
                ),
                // -----------------------즐겨찾기-------------------------
                Positioned(
                  top: 80,
                  left: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: const [
                      BookmarkButton(bookmarkTitle: '5남102'),
                      BookmarkButton(bookmarkTitle: '5서 202'),
                      BookmarkButton(bookmarkTitle: '생명과학과 학생회실'),
                    ],
                  ),
                  // 데이터 생기면 즐겨찾기 부분 리스트뷰로 변경
                  // child: ListView.builder(
                  //   scrollDirection: Axis.horizontal,
                  //   itemCount: 2,
                  //   itemBuilder: (BuildContext context, int index) {
                  //     return BookmarkButton(bookmarkTitle: "5북102");
                  //   },
                  // ),
                ),
                // --------------------건물 전환 버튼----------------------
                Positioned(
                  bottom: 20,
                  left: 0,
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
                  right: 0,
                  child: Column(
                    children: _getAvailableFloors(mapProvider.selectedBuilding)
                        .map(
                          (floor) => FloorButton(
                            floor: floor,
                            onTap: () => mapProvider.setSelectedFloor(floor),
                            isSelected: mapProvider.selectedFloor == floor,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
