abstract final class AuthValidators {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Email không hợp lệ.';
    }
    return null;
  }

  static String? password(String? value) =>
      value == null || value.isEmpty ? 'Vui lòng nhập mật khẩu.' : null;

  static String? newPassword(String? value) {
    if (value == null ||
        value.length < 6 ||
        !RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value)) {
      return 'Mật khẩu cần ít nhất 6 ký tự, có chữ thường và số.';
    }
    return null;
  }

  static String? fullName(String? value) =>
      value == null || value.trim().isEmpty ? 'Vui lòng nhập họ tên.' : null;

  static String? otp(String? value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
      ? null
      : 'Vui lòng nhập đủ 6 chữ số.';
}
