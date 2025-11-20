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

  static const _textStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  @override
  State<SearchFacilitiesTile> createState() => _SearchFacilitiesTileState();
}

class _SearchFacilitiesTileState extends State<SearchFacilitiesTile> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await context.push<String>(
          "/home/search/searchResult",
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
        alignment: Alignment.center,
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.grey200,
        ),
        child: Text(
          widget.title,
          style: SearchFacilitiesTile._textStyle,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
