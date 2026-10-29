import '../core/network/json_reader.dart';

class ShiftModel {
  const ShiftModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.lateToleranceMinutes,
  });
  final int id;
  final String name;
  final String startTime;
  final String endTime;
  final int lateToleranceMinutes;
  factory ShiftModel.fromJson(Map<String, dynamic> j) => ShiftModel(
    id: JsonReader.integer(j['id']),
    name: JsonReader.string(j['name']),
    startTime: JsonReader.string(j['startTime']),
    endTime: JsonReader.string(j['endTime']),
    lateToleranceMinutes: JsonReader.integer(j['lateToleranceMinutes']),
  );
}

class ShiftInput {
  const ShiftInput({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.lateToleranceMinutes,
  });
  final String name;
  final String startTime;
  final String endTime;
  final int lateToleranceMinutes;
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'startTime': startTime,
    'endTime': endTime,
    'lateToleranceMinutes': lateToleranceMinutes,
  };
}
