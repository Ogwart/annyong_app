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

  void setWaypoint1(Poi? waypoint1) {
    state = state.copyWith(waypoint1: waypoint1);
  }

  void setWaypoint2(Poi? waypoint2) {
    state = state.copyWith(waypoint2: waypoint2);
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
  final Poi? waypoint1;
  final Poi? waypoint2;

  PathSelectionState({
    this.departure,
    this.destination,
    this.waypoint1,
    this.waypoint2,
  });

  PathSelectionState copyWith({
    Poi? departure,
    Poi? destination,
    Poi? waypoint1,
    Poi? waypoint2,
  }) {
    return PathSelectionState(
      departure: departure ?? this.departure,
      destination: destination ?? this.destination,
      waypoint1: waypoint1 ?? this.waypoint1,
      waypoint2: waypoint2 ?? this.waypoint2,
    );
  }
}

final pathSelectionProvider =
    StateNotifierProvider<PathSelectionViewmodel, PathSelectionState>((ref) {
      return PathSelectionViewmodel();
    });
