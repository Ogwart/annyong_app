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

String categoryIconPath(String title) {
  switch (title) {
    case "강의실/과사무실":
      return "study_room";
    case "라운지/카페":
      return "lounge";
    case "교수연구실":
      return "professor_room";
    case "엘리베이터/계단":
      return "elevator";
    case "화장실":
      return "toilet";
    case "출입문":
      return "door";
    case "자판기":
      return "vending_machine";
    case "정수기":
      return "purifier";
    case "ATM/제세동기":
      return "ATM";
    case "콘센트":
      return "outlet";
    case "소화기/소화전":
      return "fire_extinguisher";
    case "쓰레기통":
      return "trash_can";
    default:
      return "study_room";
  }
}
