import '../core/network/json_reader.dart';

class WorkLocationModel {
  const WorkLocationModel({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.shiftId,
  });
  final int id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final int shiftId;
  factory WorkLocationModel.fromJson(Map<String, dynamic> j) =>
      WorkLocationModel(
        id: JsonReader.integer(j['id']),
        name: JsonReader.string(j['name']),
        address: JsonReader.optionalString(j['address']),
        latitude: JsonReader.number(j['latitude']),
        longitude: JsonReader.number(j['longitude']),
        radiusMeters: JsonReader.integer(j['radiusMeters']),
        shiftId: JsonReader.integer(j['shiftId']),
      );
}

class WorkLocationInput {
  const WorkLocationInput({
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.shiftId,
  });
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final int shiftId;
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'address': address?.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'shiftId': shiftId,
  };
}
