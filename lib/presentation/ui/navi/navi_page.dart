import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/widgets/navi_add_waypoint_button.dart';
import 'package:annyong/presentation/widgets/navi_location_input_tile.dart';
import 'package:annyong/presentation/widgets/navi_map_preview.dart';
import 'package:annyong/presentation/widgets/navi_reset_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum _LocationFieldType { departure, destination, waypoint }

class NaviPage extends StatefulWidget {
  const NaviPage({super.key});

  @override
  State<NaviPage> createState() => _NaviPageState();
}

class _NaviPageState extends State<NaviPage> {
  String? _departure;
  String? _destination;
  final List<String?> _waypoints = [];

  void _resetSelections() {
    setState(() {
      _departure = null;
      _destination = null;
      _waypoints.clear();
    });
  }

  Future<void> _selectLocation(
    _LocationFieldType field, {
    int? waypointIndex,
  }) async {
    final result = await context.push<String>(
      '/home/search',
      extra: {'returnResult': true},
    );

    if (result == null || result.isEmpty) {
      return;
    }

    setState(() {
      switch (field) {
        case _LocationFieldType.departure:
          _departure = result;
        case _LocationFieldType.destination:
          _destination = result;
        case _LocationFieldType.waypoint:
          if (waypointIndex != null && waypointIndex < _waypoints.length) {
            _waypoints[waypointIndex] = result;
          }
      }
    });
  }

  void _addWaypoint() {
    if (_waypoints.length >= 2) {
      return;
    }
    setState(() {
      _waypoints.add(null);
    });
  }

  void _removeWaypoint(int index) {
    setState(() {
      _waypoints.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // ------------------출발지 입력 버튼------------------
                  NaviLocationInputTile(
                    label: '출발지',
                    value: _departure,
                    onTap: () => _selectLocation(_LocationFieldType.departure),
                  ),
                  const SizedBox(height: 12),
                  // ------------------경유지 입력 버튼------------------
                  for (var i = 0; i < _waypoints.length; i++) ...[
                    NaviLocationInputTile(
                      label: '경유지 ${i + 1}',
                      value: _waypoints[i],
                      onTap: () => _selectLocation(
                        _LocationFieldType.waypoint,
                        waypointIndex: i,
                      ),
                      trailing: IconButton(
                        onPressed: () => _removeWaypoint(i),
                        icon: Icon(Icons.delete_outline, color: AppColors.text),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // ------------------경유지 추가 버튼------------------
                  if (_waypoints.length < 2) ...[
                    Center(child: NaviAddWaypointButton(onTap: _addWaypoint)),
                    const SizedBox(height: 12),
                  ],
                  // ------------------목적지 입력 버튼------------------
                  NaviLocationInputTile(
                    label: '목적지',
                    value: _destination,
                    onTap: () =>
                        _selectLocation(_LocationFieldType.destination),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ------------------초기화 버튼------------------
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: NaviResetButton(onTap: _resetSelections),
              ),
            ),
            // ------------------지도 미리보기------------------
            Expanded(
              child: NaviMapPreview(
                floorButtons: [
                  NaviFloorButtonData(
                    floor: '1F',
                    isSelected: false,
                    onTap: () {
                      // TODO: 층 전환 로직 연동
                    },
                  ),
                  NaviFloorButtonData(
                    floor: '1F',
                    isSelected: true,
                    onTap: () {
                      // TODO: 층 전환 로직 연동
                    },
                  ),
                  NaviFloorButtonData(
                    floor: 'B1',
                    isSelected: false,
                    onTap: () {
                      // TODO: 층 전환 로직 연동
                    },
                  ),
                ],
              ),
            ),
            // ------------------길찾기 실행 버튼------------------
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '길찾기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
