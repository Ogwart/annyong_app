import 'package:flutter_riverpod/legacy.dart';

class SearchResultState {
  final String searchKeyword;
  final String selectedBuilding;
  final String selectedFloor;
  final int? focusedPoiId; // 현재 선택된 POI Id

  SearchResultState({
    String? searchKeyword,
    String? selectedBuilding,
    String? selectedFloor,
    this.focusedPoiId,
  }) : searchKeyword = searchKeyword ?? '',
       selectedBuilding = selectedBuilding ?? '5호관',
       selectedFloor = selectedFloor ?? '1F';

  SearchResultState copyWith({
    String? searchKeyword,
    String? selectedBuilding,
    String? selectedFloor,
    int? focusedPoiId,
  }) {
    return SearchResultState(
      searchKeyword: searchKeyword ?? this.searchKeyword,
      selectedBuilding: selectedBuilding ?? this.selectedBuilding,
      selectedFloor: selectedFloor ?? this.selectedFloor,
      focusedPoiId: focusedPoiId ?? this.focusedPoiId,
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

  // 리스트 아이템 클릭 시 POI 포커싱
  void setFocusedPoi(int? poiId) {
    // copyWith의 '??' 연산자 특성상 null을 전달하면 기존 값이 유지되므로,
    // 해제(null) 요청이 들어오면 copyWith 대신 직접 생성자를 호출하여 상태를 갱신
    if (poiId == null) {
      state = SearchResultState(
        searchKeyword: state.searchKeyword,
        selectedBuilding: state.selectedBuilding,
        selectedFloor: state.selectedFloor,
        focusedPoiId: null, // 명시적으로 null 할당
      );
    } else {
      state = state.copyWith(focusedPoiId: poiId);
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
    } else if (state.selectedBuilding == '60주년기념관') {
      buildingPrefix = '3';
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
