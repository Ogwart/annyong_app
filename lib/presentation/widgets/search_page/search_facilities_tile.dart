import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/ui/search/search_page.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchFacilitiesTile extends StatefulWidget {
  const SearchFacilitiesTile({
    super.key,
    required this.title,
    this.searchMode,
    this.returnResult = false,
    required this.categoryId,
  });

  final String title;
  final SearchMode? searchMode;
  final bool returnResult;
  final int categoryId;

  @override
  State<SearchFacilitiesTile> createState() => _SearchFacilitiesTileState();
}

class _SearchFacilitiesTileState extends State<SearchFacilitiesTile> {
  bool _isPressed = false; // 눌림 상태 변수

  String _getBasePath() {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/measureSelectPoi')) {
      return '/measureSelectPoi';
    }
    return '/home/search';
  }

  @override
  Widget build(BuildContext context) {
    // 아이콘 경로 (ex. assets/icons/search_tile/poi_1_icon.png)
    final iconPath =
        'assets/icons/search_tile/poi_${widget.categoryId}_icon.png';

    return GestureDetector(
      // 눌림 효과를 주기 위해 터치 상황에 따라 _isPressed 관리
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),

      // 클릭 시 해당 POI 검색 결과로 이동
      onTap: () async {
        final basePath = _getBasePath();
        final result = await context.push<Poi>(
          '$basePath/searchResult',
          extra: {
            'title': widget.title,
            'searchMode': widget.searchMode,
            'returnResult': widget.returnResult,
            'categoryId': widget.categoryId,
          },
        );
        if (widget.returnResult && result != null && context.mounted) {
          context.pop(result);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isPressed ? AppColors.secondary : AppColors.grey200,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isPressed
                  ? AppColors.primary.withOpacity(0.25)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(2, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                iconPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // 아이콘 이미지 못불러올 경우를 대비한 대체 이미지
                  return const Icon(Icons.place, color: AppColors.primary);
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                widget.title.replaceAll(' ', '\n'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
