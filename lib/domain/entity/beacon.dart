class Beacon {
  final int beaconId;
  final String macId;
  final int buildingId;
  final int floor;
  final int xCoord;
  final int yCoord;
  final List<int> nearPoiIds;
  final String type;

  Beacon({
    required this.beaconId,
    required this.macId,
    required this.buildingId,
    required this.floor,
    required this.xCoord,
    required this.yCoord,
    required this.nearPoiIds,
    required this.type,
  });

  // JSON -> 객체 변환
  factory Beacon.fromJson(Map<String, dynamic> json) {
    return Beacon(
      beaconId: json['beacon_id'] as int,
      macId: json['mac_id'] as String,
      buildingId: json['building_id'] as int,
      floor: json['floor'] as int,
      xCoord: json['x_coord'] as int,
      yCoord: json['y_coord'] as int,
      nearPoiIds: List<int>.from(json['near_poi_ids'] ?? []),
      type: json['type'] as String,
    );
  }

  // 객체 -> JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'beacon_id': beaconId,
      'mac_id': macId,
      'building_id': buildingId,
      'floor': floor,
      'x_coord': xCoord,
      'y_coord': yCoord,
      'near_poi_ids': nearPoiIds,
      'type': type,
    };
  }

  @override
  String toString() {
    return 'Beacon(id: $beaconId, mac: $macId, loc: ($xCoord, $yCoord), near: $nearPoiIds)';
  }
}
