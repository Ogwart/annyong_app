import 'package:flutter_riverpod/legacy.dart';
import 'package:annyong/domain/entity/poi.dart';

class PathSelectionViewmodel extends StateNotifier<PathSelectionState> {
  PathSelectionViewmodel() : super(PathSelectionState());

  // 기존 선택정보를 삭제하기 위해 null을 넣으면, copyWith의 자체 ?? 연산으로 인해 무시됨
  // 그럴 경우 경유지 삭제가 제대로 동작하지 않고 waypoint 객체에 여전히 남아있어 경유지 삭제 시 문제가 됨
  // 따라서 null이 들어오면 명시적으로 그대로 null이 저장되도록 copyWith 대신 상태 객체를 직접 호출해 제거
  void setDeparture(Poi? departure) {
    state = PathSelectionState(
      departure: departure,
      destination: state.destination,
      waypoint1: state.waypoint1,
      waypoint2: state.waypoint2,
    );
  }

  void setDestination(Poi? destination) {
    state = PathSelectionState(
      departure: state.departure,
      destination: destination,
      waypoint1: state.waypoint1,
      waypoint2: state.waypoint2,
    );
  }

  void setWaypoint1(Poi? waypoint1) {
    state = PathSelectionState(
      departure: state.departure,
      destination: state.destination,
      waypoint1: waypoint1,
      waypoint2: state.waypoint2,
    );
  }

  void setWaypoint2(Poi? waypoint2) {
    state = PathSelectionState(
      departure: state.departure,
      destination: state.destination,
      waypoint1: state.waypoint1,
      waypoint2: waypoint2,
    );
  }

  void reset() {
    state = PathSelectionState();
  }

  // void swapDepartureDestination() {
  //   state = state.copyWith(
  //     departure: state.destination,
  //     destination: state.departure,
  //   );
  // }

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
