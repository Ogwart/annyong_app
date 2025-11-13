import 'package:annyong/presentation/ui/search/search_page.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchRoomsTile extends StatelessWidget {
  const SearchRoomsTile({
    super.key,
    required this.title,
    this.searchMode,
    this.returnResult = false,
  });

  final String title;
  final SearchMode? searchMode;
  final bool returnResult;

  static const _textStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await context.push<String>(
          '/home/search/searchRooms',
          extra: {
            'title': title,
            'searchMode': searchMode,
            'returnResult': returnResult,
          },
        );
        if (returnResult && result != null) {
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
        child: Text(title, style: _textStyle, textAlign: TextAlign.center),
      ),
    );
  }
}
