import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/beacon_scan_service.dart';
import 'package:annyong/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MeasureNoticePage extends StatefulWidget {
  const MeasureNoticePage({super.key});

  @override
  State<MeasureNoticePage> createState() => _MeasureNoticePageState();
}

class _MeasureNoticePageState extends State<MeasureNoticePage> {
  final PoiRepository _poiRepository = PoiRepository();
  final BeaconScanService _beaconScanService = BeaconScanService();

  bool _isLoading = false;

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

              const SizedBox(height: 24), // 아이콘과 타이틀 사이 간격
              // --------------------메인 타이틀 (추가됨)--------------------
              const Text(
                "보폭 측정 가이드",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const Text(
                "정확한 길 안내를 위해 3가지만 기억해주세요!",
                style: TextStyle(fontSize: 16, color: Colors.grey),
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
                      crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽 정렬
                      children: [
                        _buildNoticeItem(
                          number: "1",
                          title: "평평한 직선 구간 선택",
                          content: "계단이나 코너가 없는 곧은 복도에서 측정해야 정확합니다.",
                        ),
                        const SizedBox(height: 24),
                        _buildNoticeItem(
                          number: "2",
                          title: "평소 걸음걸이 유지",
                          content: "일부러 크게 걷지 말고, 평소처럼 편안하게 걸어주세요.",
                        ),
                        const SizedBox(height: 24),
                        _buildNoticeItem(
                          number: "3",
                          title: "휴대폰 파지 방법",
                          content: "정확한 센서 인식을 위해 휴대폰을 손에 들고 이동해주세요.",
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
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go("/home");
                        }
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
                    // 측정 시작 버튼
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () async {
                              setState(() {
                                _isLoading = true;
                              });

                              try {
                                // 1. 주변 비콘을 검색하여 인접 비콘들의 인접 POI ID 리스트를 얻는다
                                // (싱글톤 서비스 내부에서 현재 스캔된 값을 가져옴)
                                final nearPoiIds = await _beaconScanService
                                    .scanNearbyBeaconsAndGetPoiIds();

                                List<Poi>? nearPois;

                                // 2. 인접 POI ID 리스트가 있다면 POI 객체 리스트로 변환
                                if (nearPoiIds.isNotEmpty) {
                                  nearPois = await _poiRepository.getPoisByIds(
                                    nearPoiIds,
                                  );
                                }

                                if (!mounted) return;
                                // 3. 페이지 이동
                                final selectedPoi = await context.push<Poi>(
                                  "/measureSelectPoi",
                                  extra: {
                                    "returnResult": true,
                                    "searchMode": null,
                                    "nearPois": nearPois,
                                  },
                                );

                                if (selectedPoi != null && context.mounted) {
                                  // POI 선택 후 측정 페이지로 이동
                                  context.go("/measure", extra: selectedPoi);
                                }
                              } catch (e) {
                                // 에러 발생 시 기존 방식대로 진행 (인접 POI 없음)
                                if (mounted) {
                                  final selectedPoi = await context.push<Poi>(
                                    "/measureSelectPoi",
                                    extra: {
                                      "returnResult": true,
                                      "searchMode": null,
                                      "nearPois": null,
                                    },
                                  );

                                  if (selectedPoi != null && context.mounted) {
                                    context.go("/measure", extra: selectedPoi);
                                  }
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
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
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
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

Widget _buildNoticeItem({
  required String number,
  required String title,
  required String content,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "$number.",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              content,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700], // AppColors.grey400 보다 조금 진한 색 추천
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
