import 'package:flutter_riverpod/legacy.dart';

class PathSelectionViewmodel extends StateNotifier<PathSelectionState> {
  PathSelectionViewmodel() : super(PathSelectionState());

  void setDeparture(String? departure) {
    state = state.copyWith(departure: departure);
  }

  void setDestination(String? destination) {
    state = state.copyWith(destination: destination);
  }

  void reset() {
    state = PathSelectionState();
  }
}

class PathSelectionState {
  final String? departure;
  final String? destination;

  PathSelectionState({this.departure, this.destination});

  PathSelectionState copyWith({String? departure, String? destination}) {
    return PathSelectionState(
      departure: departure ?? this.departure,
      destination: destination ?? this.destination,
    );
  }
}

final pathSelectionProvider =
    StateNotifierProvider<PathSelectionViewmodel, PathSelectionState>((ref) {
      return PathSelectionViewmodel();
    });
