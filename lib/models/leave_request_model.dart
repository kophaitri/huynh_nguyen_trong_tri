import '../core/network/json_reader.dart';

enum LeaveStatus {
  pending,
  approved,
  rejected;

  String get apiValue => switch (this) {
    pending => 'Pending',
    approved => 'Approved',
    rejected => 'Rejected',
  };
  String get label => switch (this) {
    pending => 'Chờ duyệt',
    approved => 'Đã duyệt',
    rejected => 'Từ chối',
  };
  static LeaveStatus parse(dynamic value) => switch (value) {
    'Pending' => pending,
    'Approved' => approved,
    'Rejected' => rejected,
    _ => JsonReader.invalid(),
  };
}

class LeaveRequestModel {
  const LeaveRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
    required this.createdAt,
  });
  final int id;
  final String userId;
  final String userName;
  final String fromDate;
  final String toDate;
  final String reason;
  final LeaveStatus status;
  final DateTime createdAt;
  factory LeaveRequestModel.fromJson(Map<String, dynamic> j) {
    final createdAt = DateTime.tryParse(JsonReader.string(j['createdAt']));
    if (createdAt == null) JsonReader.invalid();
    return LeaveRequestModel(
      id: JsonReader.integer(j['id']),
      userId: JsonReader.string(j['userId']),
      userName: JsonReader.string(j['userName']),
      fromDate: JsonReader.string(j['fromDate']),
      toDate: JsonReader.string(j['toDate']),
      reason: JsonReader.string(j['reason']),
      status: LeaveStatus.parse(j['status']),
      createdAt: createdAt,
    );
  }
}

class LeaveInput {
  const LeaveInput({
    required this.fromDate,
    required this.toDate,
    required this.reason,
  });
  final String fromDate;
  final String toDate;
  final String reason;
  Map<String, dynamic> toJson() => {
    'fromDate': fromDate,
    'toDate': toDate,
    'reason': reason.trim(),
  };
}
