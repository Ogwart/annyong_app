import 'package:flutter/foundation.dart';

class HomePageMapProvider extends ChangeNotifier {
  String _selectedFloor = '1F';
  String _selectedBuilding = '5호관';

  String get selectedFloor => _selectedFloor;
  String get selectedBuilding => _selectedBuilding;

  void setSelectedFloor(String floor) {
    if (_selectedFloor != floor) {
      _selectedFloor = floor;
      notifyListeners();
    }
  }

  void setSelectedBuilding(String building) {
    if (_selectedBuilding != building) {
      _selectedBuilding = building;
      notifyListeners();
    }
  }

  void toggleBuilding() {
    if (_selectedBuilding == '5호관') {
      _selectedBuilding = '하이테크관';
    } else {
      _selectedBuilding = '5호관';
    }
    // 건물 전환 시 층을 1F로 고정
    _selectedFloor = '1F';
    notifyListeners();
  }
}
