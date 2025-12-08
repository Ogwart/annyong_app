import 'package:annyong/domain/entity/poi.dart';

String iconPath(Poi poi) {
  switch (poi.categoryId) {
    case 1:
      {
        if (poi.description == "강의실") {
          return "study_room";
        } else {
          return "help";
        }
      }
    case 2:
      return "rounge";
    case 3:
      return "professor_room";
    case 4:
      {
        if (poi.name == "엘리베이터") {
          return "elevator";
        } else {
          return "upstair";
        }
      }
    case 5:
      return "toilet";
    case 6:
      return "door";
    case 7:
      return "vending_machine";
    case 8:
      return "purifier";
    case 9:
      {
        if (poi.name == "ATM") {
          return "ATM";
        } else {
          return "AED";
        }
      }
    case 10:
      return "outlet";
    case 11:
      {
        if (poi.name == "소화전") {
          return "fire_hydrant";
        } else {
          return "fire_extinguisher";
        }
      }
    case 12:
      return "trash_can";
    default:
      return "study_room";
  }
}
