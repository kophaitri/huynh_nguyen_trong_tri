import '../core/network/api_failure.dart';
import '../core/network/json_reader.dart';

enum AttendanceAction {
  checkIn,
  checkOut;

  String get label => this == checkIn ? 'Chấm công vào' : 'Chấm công ra';
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.type,
    required this.time,
    required this.isLate,
    required this.isEarlyLeave,
    required this.distance,
    this.location,
    this.flags = const [],
  });
  final int id;
  final String type;
  final DateTime time;
  final bool isLate;
  final bool isEarlyLeave;
  final double distance;
  final String? location;
  final List<String> flags;
  factory AttendanceRecord.fromJson(
    Map<String, dynamic> json, {
    bool receipt = false,
  }) {
    final type = JsonReader.string(json['type']);
    if (type != 'CheckIn' && type != 'CheckOut') JsonReader.invalid();
    final time = DateTime.tryParse(
      JsonReader.string(json[receipt ? 'timeLocal' : 'timestamp']),
    );
    if (time == null) JsonReader.invalid();
    final flags = receipt ? json['flags'] : <dynamic>[];
    if (flags is! List || flags.any((f) => f is! String)) JsonReader.invalid();
    return AttendanceRecord(
      id: JsonReader.integer(json['id']),
      type: type,
      time: time,
      isLate: JsonReader.boolean(json['isLate']),
      isEarlyLeave: JsonReader.boolean(json['isEarlyLeave']),
      distance: JsonReader.number(
        json[receipt ? 'distance' : 'distanceMeters'],
      ),
      location: receipt ? null : JsonReader.string(json['location']),
      flags: List<String>.from(flags),
    );
  }
  String get label =>
      type == 'CheckIn' ? 'Đã chấm công vào' : 'Đã chấm công ra';
}

class ScannedAttendanceQr {
  const ScannedAttendanceQr._(this.raw, this.locationId);
  final String raw;
  final int locationId;
  // Parse routing metadata only. Signature and expiry are verified by the server.
  factory ScannedAttendanceQr.parse(String raw) {
    final parts = raw.split('.');
    final id = parts.length == 4 ? int.tryParse(parts[1]) : null;
    if (parts.length != 4 ||
        parts.first != 'SC1' ||
        id == null ||
        id <= 0 ||
        id > 2147483647) {
      throw const ApiFailure('Đây không phải mã QR chấm công được hỗ trợ.');
    }
    return ScannedAttendanceQr._(raw, id);
  }
}

class CurrentAttendanceQr {
  CurrentAttendanceQr({
    required this.token,
    required this.location,
    required this.ttlSeconds,
  });
  final String token;
  final String location;
  final int ttlSeconds;
  factory CurrentAttendanceQr.fromJson(Map<String, dynamic> json) =>
      CurrentAttendanceQr(
        token: JsonReader.string(json['token']),
        location: JsonReader.string(json['location']),
        ttlSeconds: JsonReader.integer(json['ttlSeconds']),
      );
}
