import 'package:flutter/foundation.dart';

class SearchResultProvider extends ChangeNotifier {
  String _searchKeyword = '';
  String _selectedFloor = '2F';

  String get searchKeyword => _searchKeyword;
  String get selectedFloor => _selectedFloor;

  void setSearchKeyword(String keyword) {
    _searchKeyword = keyword;
    notifyListeners();
  }

  void setSelectedFloor(String floor) {
    _selectedFloor = floor;
    notifyListeners();
  }
}

