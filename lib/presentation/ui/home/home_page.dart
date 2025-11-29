import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/favorite_service.dart';
import 'package:annyong/presentation/viewmodels/home_map_viewmodel.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:annyong/presentation/providers/home_page_map_provider.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/global_widgets/bookmark__button.dart';
import 'package:annyong/presentation/widgets/global_widgets/bookmark__marker.dart';
import 'package:annyong/presentation/widgets/home_page/floor_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

/// 선형 투영을 사용하는 커스텀 CRS
/// Mercator 투영의 비선형성을 제거하여 POI 간격이 일정하게 유지되도록 함
/// Epsg3857을 기반으로 하되, 좌표 변환을 선형으로 처리
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
  // LatLngBounds는 실제 지리 좌표계를 사용하므로 위도는 -90~90 범위여야 함
  // 가상 좌표계는 POI 좌표 변환 시에만 사용
  final LatLngBounds mapBounds = LatLngBounds(
    const LatLng(-90, -180),
    const LatLng(90, 180),
  );
  final PoiRepository _poiRepository = PoiRepository();
  List<Poi> _favoritePois = [];

  // 지도 화면 밖으로 넘어가는 현상 방지용 함수
  // visibleBounds가 mapBounds를 넘어서지 않도록 center를 조정
  void checkAndConstrainBounds(LatLng? currentCenter) {
    if (currentCenter == null) return;

    final LatLngBounds visibleBounds = mapController.camera.visibleBounds;
    double newLat = currentCenter.latitude;
    double newLng = currentCenter.longitude;
    bool needsUpdate = false;

    // 위도 경계 체크: visibleBounds가 mapBounds를 넘어서지 않도록
    if (visibleBounds.south < mapBounds.south) {
      // 남쪽으로 넘어갔으면 위로 이동
      newLat += mapBounds.south - visibleBounds.south;
      needsUpdate = true;
    } else if (visibleBounds.north > mapBounds.north) {
      // 북쪽으로 넘어갔으면 아래로 이동
      newLat -= visibleBounds.north - mapBounds.north;
      needsUpdate = true;
    }

    // 경도 경계 체크: visibleBounds가 mapBounds를 넘어서지 않도록
    if (visibleBounds.west < mapBounds.west) {
      // 서쪽으로 넘어갔으면 동으로 이동
      newLng += mapBounds.west - visibleBounds.west;
      needsUpdate = true;
    } else if (visibleBounds.east > mapBounds.east) {
      // 동쪽으로 넘어갔으면 서로 이동
      newLng -= visibleBounds.east - mapBounds.east;
      needsUpdate = true;
    }

    if (needsUpdate) {
      mapController.move(LatLng(newLat, newLng), mapController.camera.zoom);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeMapProvider.notifier).resetMapReady();
      // 홈 페이지로 돌아올 때 출발지/목적지 초기화
      ref.read(pathSelectionProvider.notifier).reset();
      // 즐겨찾기 POI 로드
      _loadFavoritePois();
    });
  }

  Future<void> _loadFavoritePois() async {
    final favoriteIds = await FavoriteService.getFavoritePoiIds();
    final allPois = await _poiRepository.fetchPois();

    // 즐겨찾기 POI 필터링 (5호관 1층만)
    final favorites = allPois.where((poi) {
      return favoriteIds.contains(poi.id) &&
          poi.buildingId == 1 &&
          poi.floor == 1;
    }).toList();

    // 디버깅: 로드된 즐겨찾기 POI 확인
    print('Loaded favorite POIs: ${favorites.length}');
    for (var poi in favorites) {
      print(
        '  - ${poi.name} (id: ${poi.id}, x: ${poi.xCoord}, y: ${poi.yCoord})',
      );
    }

    if (mounted) {
      setState(() {
        _favoritePois = favorites;
      });
    }
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

  /// POI 좌표는 1792×1024px 이미지를 기준으로 함 (왼쪽 위가 0, 0)
  /// [xCoord] POI의 x 좌표 (0~1792)
  /// [yCoord] POI의 y 좌표 (0~1024)
  /// [zoom] 현재 줌 레벨 (2 또는 3)
  LatLng poiPixelToLatLng(double xCoord, double yCoord, double zoom) {
    const double coordinateRange = 1024.0;

    // 실제 LatLng 좌표계 범위 (FlutterMap이 사용하는 범위)
    const double actualLatRange = 180.0; // 실제 위도 범위 (-90 ~ 90)
    const double actualLngRange = 360.0; // 실제 경도 범위 (-180 ~ 180)

    double virtualLat = coordinateRange - yCoord; // Y축 반전
    double virtualLng = xCoord;
    double lat =
        (virtualLat / coordinateRange) * actualLatRange - 90.0; // -90 ~ 90

    // if (lat < 0) {
    //   lat *= 0.75; // 음수인 경우 0.75를 곱함
    // } else {
    //   lat *= 1.25; // 양수인 경우 1.25를 곱함
    // }

    // 위도 범위 제한 (-90 ~ 90)
    if (lat > 90.0) lat = 90.0;
    if (lat < -90.0) lat = -90.0;

    double lng = (virtualLng / 1792) * actualLngRange - 180.0; // -180 ~ 180

    // 디버깅: 변환 과정 상세 출력
    print('  변환 과정:');
    print('    POI 좌표: ($xCoord, $yCoord)');
    print('    가상 좌표: ($virtualLat, $virtualLng)');
    print('    최종 좌표: ($lat, $lng)');

    return LatLng(lat, lng);
  }

  /// 즐겨찾기 마커 생성
  List<Marker> _buildFavoriteMarkers(HomePageMapProvider mapProvider) {
    final currentBuilding = mapProvider.selectedBuilding;
    final currentFloor = mapProvider.selectedFloor;

    // 5호관 1층일 때만 표시
    if (currentBuilding != '5호관' || currentFloor != '1F') {
      return [];
    }

    // MapController가 준비되지 않았으면 초기 줌 레벨 사용
    double currentZoom = 2.0; // 기본값 (initialZoom과 동일)
    try {
      currentZoom = mapController.camera.zoom;
    } catch (e) {
      // MapController가 아직 준비되지 않음, 기본값 사용
      currentZoom = 2.0;
    }

    print('Building favorite markers: ${_favoritePois.length} POIs');

    return _favoritePois.map((poi) {
      final latLng = poiPixelToLatLng(poi.xCoord, poi.yCoord, currentZoom);

      // 디버깅: 변환된 좌표 출력
      print(
        'POI: ${poi.name} (${poi.xCoord}, ${poi.yCoord}) -> LatLng(${latLng.latitude.toStringAsFixed(3)}, ${latLng.longitude.toStringAsFixed(3)})',
      );

      return Marker(
        point: latLng,
        width: 80,
        alignment: Alignment.center,
        child: BookmarkMarker(bookmarkTitle: poi.name),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    //final isMapReady = ref.watch(homeMapProvider);
    final mapProvider = context.watch<HomePageMapProvider>();
    final tileUrlTemplate = _getTileUrlTemplate(
      mapProvider.selectedBuilding,
      mapProvider.selectedFloor,
    );

    return Scaffold(
      body: SafeArea(
        child: Container(
          alignment: Alignment.center,
          width: double.infinity,
          child: Stack(
            //alignment: AlignmentGeometry.center,
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  crs: MapNoRepeat(),
                  backgroundColor: Colors.white,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
                  ),
                  initialCenter: LatLng(
                    (512 / 1024) * 180 - 90, // 가상 좌표 512(이미지 중심)를 실제 위도로 변환
                    (896 / 1792) * 360 - 180, // 가상 좌표 896(이미지 중심)을 실제 경도로 변환
                  ), // 가상 좌표계 중심 (512, 896)을 실제 좌표로 매핑
                  initialZoom: 2,
                  maxZoom: 3,
                  minZoom: 2,
                  onPositionChanged: (position, hasGesture) {
                    // 지도 이동 시 경계 체크하여 무한 스크롤 방지
                    if (hasGesture) {
                      checkAndConstrainBounds(position.center);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    tileProvider: AssetTileProvider(),
                    urlTemplate: tileUrlTemplate,
                    tileDimension: 128,
                    //tms: true,
                  ),
                  // 즐겨찾기 마커 레이어
                  MarkerLayer(markers: _buildFavoriteMarkers(mapProvider)),
                ],
              ),
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
              // -----------------------즐겨찾기-------------------------
              Positioned(
                top: 70,
                left: 24,
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
    );
  }
}
