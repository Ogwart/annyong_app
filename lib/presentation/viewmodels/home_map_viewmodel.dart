import 'package:flutter_riverpod/legacy.dart';

class HomeMapViewmodel extends StateNotifier<bool> {
  HomeMapViewmodel() : super(false);

  void setMapReady() {
    state = true;
  }

  void resetMapReady() {
    state = false;
  }
}

final homeMapProvider = StateNotifierProvider<HomeMapViewmodel, bool>((ref) {
  return HomeMapViewmodel();
});
