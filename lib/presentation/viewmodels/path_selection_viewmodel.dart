import 'package:flutter_riverpod/legacy.dart';
import 'package:annyong/domain/entity/poi.dart';

class PathSelectionViewmodel extends StateNotifier<PathSelectionState> {
  PathSelectionViewmodel() : super(PathSelectionState());

  void setDeparture(Poi? departure) {
    state = state.copyWith(departure: departure);
  }

  void setDestination(Poi? destination) {
    state = state.copyWith(destination: destination);
  }

  void reset() {
    state = PathSelectionState();
  }

  void swapDepartureDestination() {
    state = state.copyWith(
      departure: state.destination,
      destination: state.departure,
    );
  }

  void resetPath() {
    state = PathSelectionState();
  }
}

class PathSelectionState {
  final Poi? departure;
  final Poi? destination;

  PathSelectionState({this.departure, this.destination});

  PathSelectionState copyWith({Poi? departure, Poi? destination}) {
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
