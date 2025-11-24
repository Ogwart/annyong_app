import 'package:annyong/domain/entity/poi.dart';
import 'package:annyong/domain/repository/beacon_repository.dart';
import 'package:annyong/domain/repository/poi_repository.dart';
import 'package:annyong/domain/usecases/beacon_scan_service.dart';
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
  final BeaconRepository _beaconRepository = BeaconRepository();
  final PoiRepository _poiRepository = PoiRepository();
  final BeaconScanService _beaconScanService = BeaconScanService(BeaconRepository());
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
                    //const SizedBox(width: 40),
                    // 측정 시작 버튼
                    GestureDetector(
                      onTap: _isLoading ? null : () async {
                        setState(() {
                          _isLoading = true;
                        });

                        try {
                          // 1. 주변 비콘을 검색하여 인접 비콘들의 인접 POI ID 리스트를 얻는다
                          // RSSI가 -40~-70 사이인 비콘들을 찾고, 각 비콘의 인접 POI를 합쳐서 중복 제거
                          final nearPoiIds = await _beaconScanService.scanNearbyBeaconsAndGetPoiIds();

                          List<Poi>? nearPois;

                          // 2. 인접 POI ID 리스트가 있다면 POI 객체 리스트로 변환
                          if (nearPoiIds.isNotEmpty) {
                            nearPois = await _poiRepository.getPoisByIds(nearPoiIds);
                          }

                          if (!mounted) return;

                          // 3-1. 만약 인접 poi 리스트가 존재한다면 위치 기반 인접 POI 추천 탭과 /measureSelectPoi 부분을 함께 보여준다
                          // 3-2. 만약 인접 poi 리스트가 존재하지 않는다면 /measureSelectPoi 부분만 보여준다
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
                          // 에러 발생 시 기존 방식대로 진행
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
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
