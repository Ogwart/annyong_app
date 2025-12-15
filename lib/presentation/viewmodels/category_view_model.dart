import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/entity/poi_category.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

class CategoryState {
  final List<Poi> favoritePois;
  final List<PoiCategory> categories;
  final int selectedCategoryId;
  final List<Poi> allPois;
  final List<Poi> displayedPois;

  const CategoryState({
    this.favoritePois = const [],
    this.categories = const [],
    this.selectedCategoryId = -1,
    this.allPois = const [],
    this.displayedPois = const [],
  });

  CategoryState copyWith({
    List<Poi>? favoritePois,
    List<PoiCategory>? categories,
    int? selectedCategoryId,
    List<Poi>? allPois,
    List<Poi>? displayedPois,
  }) {
    return CategoryState(
      favoritePois: favoritePois ?? this.favoritePois,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      allPois: allPois ?? this.allPois,
      displayedPois: displayedPois ?? this.displayedPois,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CategoryState &&
        listEquals(other.favoritePois, favoritePois) &&
        listEquals(other.categories, categories) &&
        other.selectedCategoryId == selectedCategoryId &&
        listEquals(other.allPois, allPois) &&
        listEquals(other.displayedPois, displayedPois);
  }

  @override
  int get hashCode {
    return favoritePois.hashCode ^
        categories.hashCode ^
        selectedCategoryId.hashCode ^
        allPois.hashCode ^
        displayedPois.hashCode;
  }
}

class CategoryViewModel extends StateNotifier<CategoryState> {
  CategoryViewModel() : super(const CategoryState()) {
    loadData();
  }

  Future<void> loadData() async {
    try {
      final favoritePois = await MapUtilFunctions.loadFavoritePois();
      final allPois = await PoiRepository().fetchPois();
      final categories = await PoiRepository().fetchCategories();

      // 초기 상태: 아무것도 선택하지 않음 (-2)
      // displayedPois는 전체 POI (allPois)로 설정
      state = state.copyWith(
        favoritePois: favoritePois,
        allPois: allPois,
        categories: categories,
        displayedPois: allPois,
        selectedCategoryId: -2,
      );
    } catch (e) {
      debugPrint('데이터 로드 중 오류 발생: $e');
    }
  }

  void setDefaultCategory() {
    state = state.copyWith(selectedCategoryId: 0, displayedPois: state.allPois);
  }

  void onCategorySelected(int categoryId) {
    // 이미 선택된 카테고리를 다시 선택하면 선택 해제 (-2: 아무것도 선택하지 않음)
    if (state.selectedCategoryId == categoryId) {
      state = state.copyWith(
        selectedCategoryId: -2,
        displayedPois: state.allPois,
      );
      return;
    }

    List<Poi> newDisplayedPois;
    if (categoryId == -1) {
      newDisplayedPois = state.favoritePois;
    } else {
      newDisplayedPois = state.allPois
          .where((poi) => poi.categoryId == categoryId)
          .toList();
    }

    state = state.copyWith(
      selectedCategoryId: categoryId,
      displayedPois: newDisplayedPois,
    );
  }

  // 빈 공간 클릭 시 호출할 메서드 (모든 마커 표시)
  void clearSelection() {
    state = state.copyWith(
      selectedCategoryId: -2,
      displayedPois: state.allPois,
    );
  }

  // 즐겨찾기가 업데이트되었을 때 호출할 메서드 (옵션)
  Future<void> refreshFavorites() async {
    final favoritePois = await MapUtilFunctions.loadFavoritePois();

    // 현재 즐겨찾기 카테고리가 선택되어 있다면 displayedPois도 업데이트
    List<Poi> newDisplayedPois = state.displayedPois;
    if (state.selectedCategoryId == -1) {
      newDisplayedPois = favoritePois;
    }

    state = state.copyWith(
      favoritePois: favoritePois,
      displayedPois: newDisplayedPois,
    );
  }
}

final categoryProvider =
    StateNotifierProvider<CategoryViewModel, CategoryState>((ref) {
      return CategoryViewModel();
    });
