import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:annyong/presentation/util/icon_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CategoryButton extends StatelessWidget {
  final String bookmarkTitle;
  final VoidCallback? onTap;
  final bool isSelected;

  const CategoryButton({
    super.key,
    required this.bookmarkTitle,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: 6, left: 6),
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        alignment: Alignment.center,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(48),
          border: BoxBorder.all(
            width: 2,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
          boxShadow: [
            BoxShadow(color: AppColors.shadow.withAlpha(25), blurRadius: 15),
          ],
        ),
        child: Row(
          children: [
            bookmarkTitle == "즐겨찾기"
                ? Icon(
                    Icons.star_rounded,
                    color: isSelected ? Colors.white : AppColors.point,
                    size: 20,
                  )
                : SvgPicture.asset(
                    "assets/icons/svg/${categoryIconPath(bookmarkTitle)}_outlined.svg",
                    width: 16,
                    height: 16,
                    colorFilter: isSelected
                        ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                        : const ColorFilter.mode(
                            AppColors.path,
                            BlendMode.srcIn,
                          ),
                  ),
            const SizedBox(width: 6),
            Text(
              bookmarkTitle,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: isSelected ? Colors.white : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
