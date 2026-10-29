import '../core/network/json_reader.dart';

class EmployeeModel {
  const EmployeeModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.employeeCode,
    this.departmentId,
    this.department,
    required this.isActive,
    this.role,
    this.hasFace,
  });
  final String id;
  final String fullName;
  final String email;
  final String? employeeCode;
  final int? departmentId;
  final String? department;
  final bool isActive;
  // The list response has hasFace, but no role. Detail has role, but no hasFace.
  final String? role;
  final bool? hasFace;
  factory EmployeeModel.fromJson(Map<String, dynamic> j) => EmployeeModel(
    id: JsonReader.string(j['id']),
    fullName: JsonReader.string(j['fullName']),
    email: JsonReader.string(j['email']),
    employeeCode: JsonReader.optionalString(j['employeeCode']),
    departmentId: JsonReader.optionalInt(j['departmentId']),
    department: JsonReader.optionalString(j['department']),
    isActive: JsonReader.boolean(j['isActive']),
    role: JsonReader.optionalString(j['role']),
    hasFace: j['hasFace'] == null ? null : JsonReader.boolean(j['hasFace']),
  );
}

class EmployeeCreateInput {
  const EmployeeCreateInput({
    required this.email,
    required this.password,
    required this.fullName,
    this.employeeCode,
    this.departmentId,
    required this.role,
  });
  final String email;
  final String password;
  final String fullName;
  final String? employeeCode;
  final int? departmentId;
  final String role;
  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
    'fullName': fullName.trim(),
    'employeeCode': employeeCode,
    'departmentId': departmentId,
    'role': role,
  };
}

class EmployeeUpdateInput {
  const EmployeeUpdateInput({
    required this.fullName,
    this.employeeCode,
    this.departmentId,
    this.role,
    required this.isActive,
  });
  final String fullName;
  final String? employeeCode;
  final int? departmentId;
  final String? role;
  final bool isActive;
  Map<String, dynamic> toJson() => {
    'fullName': fullName.trim(),
    'employeeCode': employeeCode,
    'departmentId': departmentId,
    'role': role,
    'isActive': isActive,
  };
}
