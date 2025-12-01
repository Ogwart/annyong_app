import 'package:annyong/domain/entity/poi.dart';

String iconPath(Poi poi) {
  switch (poi.categoryId) {
    case 1:
      return "study_room";
    case 2:
      return "rounge";
    case 3:
      return "study_room";
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
      return "fire_extinguisher";
    case 12:
      return "trash_can";
    default:
      return "study_room";
  }
}
