Map<String, dynamic> departmentJson({
  int id = 11,
  String name = 'Test Department',
}) => {
  'id': id,
  'name': name,
  'description': 'Test description',
  'employees': [],
};
Map<String, dynamic> shiftJson() => {
  'id': 21,
  'name': 'Test Shift',
  'startTime': '08:00:00',
  'endTime': '17:00:00',
  'lateToleranceMinutes': 10,
};
Map<String, dynamic> locationJson() => {
  'id': 31,
  'name': 'Test Location',
  'address': 'Test address',
  'latitude': 10.8,
  'longitude': 106.7,
  'radiusMeters': 100,
  'shiftId': 21,
  'shift': null,
};
Map<String, dynamic> employeeJson({
  String id = 'other-user',
  String name = 'Test Employee',
  bool detail = false,
}) => {
  'id': id,
  'fullName': name,
  'email': 'employee@example.test',
  'employeeCode': 'TEST-01',
  'departmentId': 11,
  'isActive': true,
  if (detail)
    'role': 'Manager'
  else ...{
    'department': 'Test Department',
    'hasFace': false,
  },
};
Map<String, dynamic> leaveJson({
  int id = 41,
  String userId = 'test-user-id',
  String status = 'Pending',
}) => {
  'id': id,
  'userId': userId,
  'userName': 'Test User',
  'fromDate': '2026-11-02',
  'toDate': '2026-11-03',
  'reason': 'Test reason',
  'status': status,
  'createdAt': '2026-10-29T01:00:00Z',
};
Map<String, dynamic> pageJson(
  List<Map<String, dynamic>> items, {
  int? total,
  int page = 1,
  int pageSize = 20,
}) => {
  'total': total ?? items.length,
  'page': page,
  'pageSize': pageSize,
  'items': items,
};
