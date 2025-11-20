import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/ui/search/search_page.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/widgets/path_page/location_input_tile.dart';
import 'package:annyong/presentation/widgets/path_page/add_waypoint_button.dart';
import 'package:annyong/presentation/widgets/path_page/reset_button.dart';
import 'package:annyong/presentation/widgets/path_page/map_preview.dart';

class PathSelectionPage extends ConsumerStatefulWidget {
  const PathSelectionPage({super.key});

  @override
  ConsumerState<PathSelectionPage> createState() => _PathSelectionPageState();
}

class _PathSelectionPageState extends ConsumerState<PathSelectionPage> {
  String? _selectedFloor = '1F';
  String? _departure;
  String? _destination;
  final List<String?> _waypoints = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFromState();
    });
  }

  void _updateFromState() {
    final pathState = ref.read(pathSelectionProvider);
    setState(() {
      _departure = pathState.departure?.name;
      _destination = pathState.destination?.name;
      _waypoints.clear();
      if (pathState.waypoint1 != null) {
        _waypoints.add(pathState.waypoint1!.name);
      }
      if (pathState.waypoint2 != null) {
        _waypoints.add(pathState.waypoint2!.name);
      }
    });
  }

  Future<void> _selectLocation(
    SearchMode searchMode, {
    int? waypointIndex,
  }) async {
    final result = await context.push<Poi>('/home/search', extra: searchMode);

    if (result == null) return;

    // Provider의 Notifier만 호출하고, 실제 상태 변경은
    // ref.listen이 감지하여 _updateFromState()를 실행하고 화면을 갱신하도록 함
    final notifier = ref.read(pathSelectionProvider.notifier);

    switch (searchMode) {
      case SearchMode.departure:
        notifier.setDeparture(result);
      case SearchMode.destination:
        notifier.setDestination(result);
      case SearchMode.waypoint1:
        notifier.setWaypoint1(result);
      case SearchMode.waypoint2:
        notifier.setWaypoint2(result);
      case SearchMode.normal:
        debugPrint('Normal mode selected, no action taken.');
        break;
    }
  }

  // 경유지 추가 로직
  void _addWaypoint() {
    if (_waypoints.length >= 2) return; // 경유지는 최대 2개까지만 허용
    setState(() {
      _waypoints.add(null);
    });
  }

  // 경유지 삭제 로직
  void _removeWaypoint(int index) {
    setState(() {
      _waypoints.removeAt(index);
      if (index == 0) {
        ref.read(pathSelectionProvider.notifier).setWaypoint1(null);
      } else if (index == 1) {
        ref.read(pathSelectionProvider.notifier).setWaypoint2(null);
      }
    });
  }

  // 스왑 로직은 오류가 많아서 보류
  // void _swapDepartureDestination() {
  //   // final temp = _departureController.text;
  //   // _departureController.text = _destinationController.text;
  //   // _destinationController.text = temp;
  //   // setState(() {});
  //   ref.read(pathSelectionProvider.notifier).swapDepartureDestination();
  // }

  // 길찾기 버튼 클릭 시 실행 로직
  void _handleFindPath() {
    debugPrint('----------- [_handleFindPath Start] -----------');
    final pathState = ref.read(pathSelectionProvider);
    final Poi? startPoi = pathState.departure;
    final Poi? endPoi = pathState.destination;

    // null이 아닌 경유지만 필터링하여 경유지 리스트 생성
    final List<Poi> activeWaypoints = [];
    if (pathState.waypoint1 != null) {
      activeWaypoints.add(pathState.waypoint1!);
    }
    if (pathState.waypoint2 != null) {
      activeWaypoints.add(pathState.waypoint2!);
    }

    debugPrint('출발지 POI: ${startPoi!.vertexId}');
    debugPrint('경유지 POI: ${activeWaypoints.map((e) => e.vertexId).toList()}');
    debugPrint('목적지 POI: ${endPoi!.vertexId}');
    debugPrint('----------- [_handleFindPath End] -----------');

    context.go(
      '/home/pathSelection/pathResult',
      extra: {'start': startPoi, 'end': endPoi, 'waypoints': activeWaypoints},
    );
  }

  void _reset() {
    setState(() {
      _departure = null;
      _destination = null;
      _waypoints.clear();
    });
    ref.read(pathSelectionProvider.notifier).resetPath();
  }

  bool get _isFindPathEnabled {
    // 목적지와 출발지가 모두 설정되어야 경로 검색 버튼이 활성화되도록
    return _departure != null && _destination != null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pathSelectionProvider, (previous, next) {
      _updateFromState();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('길찾기 검색')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // 출발지 입력 버튼
                  LocationInputTile(
                    label: '출발지',
                    value: _departure,
                    onTap: () => _selectLocation(SearchMode.departure),
                  ),
                  const SizedBox(height: 12),
                  // 경유지 입력 버튼들
                  for (var i = 0; i < _waypoints.length; i++) ...[
                    LocationInputTile(
                      label: '경유지 ${i + 1}',
                      value: _waypoints[i],
                      onTap: () => _selectLocation(
                        i == 0 ? SearchMode.waypoint1 : SearchMode.waypoint2,
                        waypointIndex: i,
                      ),
                      trailing: IconButton(
                        onPressed: () => _removeWaypoint(i),
                        icon: Icon(Icons.delete_outline, color: AppColors.text),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // 경유지 추가 버튼
                  if (_waypoints.length < 2) ...[
                    Center(child: AddWaypointButton(onTap: _addWaypoint)),
                    const SizedBox(height: 12),
                  ],
                  // 목적지 입력 버튼
                  LocationInputTile(
                    label: '목적지',
                    value: _destination,
                    onTap: () => _selectLocation(SearchMode.destination),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 초기화 버튼
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ResetButton(onTap: _reset),
              ),
            ),
            // 지도 미리보기
            Expanded(
              child: MapPreview(
                floorButtons: [
                  FloorButtonData(
                    floor: '1F',
                    isSelected: _selectedFloor == '1F',
                    onTap: () {
                      setState(() {
                        _selectedFloor = '1F';
                      });
                    },
                  ),
                  FloorButtonData(
                    floor: '2F',
                    isSelected: _selectedFloor == '2F',
                    onTap: () {
                      setState(() {
                        _selectedFloor = '2F';
                      });
                    },
                  ),
                ],
              ),
            ),
            // 길찾기 실행 버튼
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isFindPathEnabled ? _handleFindPath : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFindPathEnabled
                        ? AppColors.primary
                        : AppColors.grey300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: AppColors.grey300,
                  ),
                  child: Text(
                    '길찾기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _isFindPathEnabled
                          ? Colors.white
                          : AppColors.grey400,
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
}
