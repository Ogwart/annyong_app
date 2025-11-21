import 'package:shared_preferences/shared_preferences.dart';

class StrideService {
  static const String _strideLengthKey = 'stride_length';
  static const String _isFirstLaunchKey = 'is_first_launch';
  static const double _defaultStrideLength = 0.7; // 70cm 기본값

  /// 보폭 데이터 가져오기 (기본값: 70cm)
  static Future<double> getStrideLength() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_strideLengthKey) ?? _defaultStrideLength;
  }

  /// 보폭 데이터 저장하기
  static Future<void> saveStrideLength(double strideLength) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_strideLengthKey, strideLength);
  }

  /// 첫 실행 여부 확인
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstLaunchKey) ?? true;
  }

  /// 첫 실행 완료 표시
  static Future<void> setFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLaunchKey, false);
  }

  /// 초기값 설정 (앱 최초 실행 시)
  static Future<void> initializeDefaultStride() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_strideLengthKey)) {
      await prefs.setDouble(_strideLengthKey, _defaultStrideLength);
    }
  }
}

