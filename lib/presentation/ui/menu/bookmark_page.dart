import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/usecases/favorite_service.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';
import 'package:annyong/presentation/viewmodels/category_view_model.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:annyong/presentation/widgets/search_result_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BookmarkPage extends ConsumerStatefulWidget {
  const BookmarkPage({super.key});

  @override
  ConsumerState<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends ConsumerState<BookmarkPage> {
  List<Poi> _favoritePois = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await MapUtilFunctions.loadFavoritePois();
    if (mounted) {
      setState(() {
        _favoritePois = favorites;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(Poi poi) async {
    await FavoriteService.removeFavorite(poi.id);

    // 상태 갱신
    await _loadFavorites();

    // 홈 화면의 즐겨찾기 상태도 갱신
    ref.read(categoryProvider.notifier).refreshFavorites();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${poi.name}이(가) 즐겨찾기에서 삭제되었습니다.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '즐겨찾기',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios),
          color: AppColors.text,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoritePois.isEmpty
          ? SafeArea(
              child: const Center(
                child: Text(
                  '즐겨찾는 장소가 없습니다.',
                  style: TextStyle(color: AppColors.grey400, fontSize: 16),
                ),
              ),
            )
          : SafeArea(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                itemCount: _favoritePois.length,
                itemBuilder: (context, index) {
                  final poi = _favoritePois[index];
                  final buildingName = MapUtilFunctions.getBuildingName(
                    poi.buildingId,
                  );

                  // Dismissible을 사용하여 스와이프로 삭제 기능 구현
                  return Dismissible(
                    key: Key(poi.id.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: AppColors.warning,
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    onDismissed: (direction) {
                      _removeFavorite(poi);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SearchResultItem(
                        title: poi.name,
                        categoryId: poi.categoryId,
                        description:
                            "$buildingName ${poi.floor}층, ${poi.description ?? ''}",
                        // 아이템 선택 시 해당 POI로 이동하거나 상세 정보 표시 (현재는 동작 없음)
                        onSelect: () {
                          ref
                              .read(pathSelectionProvider.notifier)
                              .setDestination(poi);
                          context.go('/home/pathSelection');
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
