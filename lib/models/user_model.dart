import '../core/network/api_failure.dart';

enum UserRole { admin, manager, employee }

class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;

  String get roleName => switch (role) {
    UserRole.admin => 'Admin',
    UserRole.manager => 'Manager',
    UserRole.employee => 'Employee',
  };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final role = switch (json['role']) {
      'Admin' => UserRole.admin,
      'Manager' => UserRole.manager,
      'Employee' => UserRole.employee,
      _ => throw const ApiFailure('Tài khoản chưa có quyền truy cập TriWork.'),
    };
    if (json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        json['fullName'] is! String ||
        json['email'] is! String) {
      throw const ApiFailure('Thông tin tài khoản từ máy chủ không hợp lệ.');
    }
    return UserModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      role: role,
    );
  }
}
