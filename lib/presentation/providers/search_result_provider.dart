import 'package:flutter_riverpod/legacy.dart';

class SearchResultState {
  final String searchKeyword;
  final String selectedBuilding;
  final String selectedFloor;

  SearchResultState({
    String? searchKeyword,
    String? selectedBuilding,
    String? selectedFloor,
  }) : searchKeyword = searchKeyword ?? '',
       selectedBuilding = selectedBuilding ?? '5호관',
       selectedFloor = selectedFloor ?? '1F';

  SearchResultState copyWith({
    String? searchKeyword,
    String? selectedBuilding,
    String? selectedFloor,
  }) {
    return SearchResultState(
      searchKeyword: searchKeyword ?? this.searchKeyword,
      selectedBuilding: selectedBuilding ?? this.selectedBuilding,
      selectedFloor: selectedFloor ?? this.selectedFloor,
    );
  }
}

class SearchResultNotifier extends StateNotifier<SearchResultState> {
  SearchResultNotifier() : super(SearchResultState());

  void setSearchKeyword(String keyword) {
    state = state.copyWith(searchKeyword: keyword);
  }

  void setSelectedBuilding(String building) {
    if (state.selectedBuilding != building) {
      state = state.copyWith(selectedBuilding: building);
    }
  }

  void setSelectedFloor(String floor) {
    if (state.selectedFloor != floor) {
      state = state.copyWith(selectedFloor: floor);
    }
  }

  void reset() {
    // 초기값으로 리셋 (5호관 1층)
    state = SearchResultState(
      searchKeyword: state.searchKeyword, // 검색 키워드는 유지
      selectedBuilding: '5호관',
      selectedFloor: '1F',
    );
  }

  /// 현재 건물/층에 맞는 지도 이미지 경로 반환 (2x만 사용)
  String getImagePath() {
    // 건물에 따라 폴더명 결정
    String buildingPrefix;
    if (state.selectedBuilding == '5호관') {
      buildingPrefix = '5';
    } else if (state.selectedBuilding == '하이테크관') {
      buildingPrefix = '8';
    } else {
      buildingPrefix = '5';
    }

    // 층수에서 숫자만 추출
    final floorNumber = state.selectedFloor.replaceAll('F', '');

    return 'assets/map/${buildingPrefix}_${floorNumber}F/${buildingPrefix}_${floorNumber}F_2x.jpg';
  }
}

final searchResultProvider =
    StateNotifierProvider<SearchResultNotifier, SearchResultState>((ref) {
      return SearchResultNotifier();
    });
