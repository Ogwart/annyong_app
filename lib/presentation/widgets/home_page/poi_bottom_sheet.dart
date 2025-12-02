import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/usecases/favorite_service.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/viewmodels/category_view_model.dart';
import 'package:annyong/presentation/viewmodels/path_selection_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:annyong/presentation/util/map_util_funtions.dart';

class PoiBottomSheet extends ConsumerStatefulWidget {
  final Poi poi;

  const PoiBottomSheet({super.key, required this.poi});

  @override
  ConsumerState<PoiBottomSheet> createState() => _PoiBottomSheetState();
}

class _PoiBottomSheetState extends ConsumerState<PoiBottomSheet> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final isFav = await FavoriteService.isFavorite(widget.poi.id);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    bool success;
    if (_isFavorite) {
      success = await FavoriteService.removeFavorite(widget.poi.id);
    } else {
      success = await FavoriteService.addFavorite(widget.poi.id);
    }

    if (success && mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
      });
      // 즐겨찾기 목록 갱신 요청
      ref.read(categoryProvider.notifier).refreshFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    final buildingName = MapUtilFunctions.getBuildingName(
      widget.poi.buildingId,
    );

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 핸들 바 (선택 사항)
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.grey200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // POI 이름 및 즐겨찾기 버튼
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.poi.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 위치 정보
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$buildingName ${widget.poi.floor}층",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _toggleFavorite,
                icon: Icon(
                  _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: _isFavorite ? AppColors.point : AppColors.grey400,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 설명 (Description)
          if (widget.poi.description != null &&
              widget.poi.description!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.grey200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.poi.description!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.text,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          // 출발/도착 버튼
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final pathProvider = ref.read(
                      pathSelectionProvider.notifier,
                    );
                    pathProvider.reset(); // 기존에 남아있을지 모를 길찾기 정보 제거
                    pathProvider.setDeparture(widget.poi);
                    context.pop(); // 바텀 시트 닫기
                    context.go('/home/pathSelection');
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    "출발",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final pathProvider = ref.read(
                      pathSelectionProvider.notifier,
                    );
                    pathProvider.reset(); // 기존에 남아있을지 모를 길찾기 정보 제거
                    pathProvider.setDestination(widget.poi);
                    context.pop(); // 바텀 시트 닫기
                    context.go('/home/pathSelection');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "도착",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
