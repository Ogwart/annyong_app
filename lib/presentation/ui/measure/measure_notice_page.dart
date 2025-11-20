import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/presentation/static.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MeasureNoticePage extends StatefulWidget {
  const MeasureNoticePage({super.key});

  @override
  State<MeasureNoticePage> createState() => _MeasureNoticePageState();
}

class _MeasureNoticePageState extends State<MeasureNoticePage> {
  final StaticExample example = StaticExample();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.all(16),
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.grey200,
                  ),
                  child: Image.asset(
                    'assets/icons/steps.png',
                    color: AppColors.primary,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // -----------------------보폭 측정 안내사항 텍스트-----------------------
              Flexible(
                flex: 4,
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  width: double.infinity,
                  height: 400,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      children: [
                        Text(
                          example.exampleText,
                          style: TextStyle(fontSize: 16, color: AppColors.text),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          example.exampleText,
                          style: TextStyle(fontSize: 16, color: AppColors.text),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          example.exampleText,
                          style: TextStyle(fontSize: 16, color: AppColors.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Flexible(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // 건너뛰기 버튼
                    GestureDetector(
                      onTap: () {
                        context.pop();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        width: 144,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          color: AppColors.grey200,
                        ),
                        child: Text(
                          "건너뛰기",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                    //const SizedBox(width: 40),
                    // 측정 시작 버튼
                    GestureDetector(
                      onTap: () async {
                        // POI 선택 화면으로 이동
                        final selectedPoi = await context.push<Poi>(
                          "/home/search",
                          extra: {"returnResult": true, "searchMode": null},
                        );

                        if (selectedPoi != null && context.mounted) {
                          // POI 선택 후 측정 페이지로 이동
                          context.pop();
                          context.push("/measure", extra: selectedPoi);
                        }
                      },
                      child: Container(
                        alignment: Alignment.center,
                        width: 144,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          color: AppColors.primary,
                        ),
                        child: Text(
                          "측정 시작",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
