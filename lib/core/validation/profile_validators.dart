abstract final class ProfileValidators {
  static String? fullName(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2 || text.length > 100) {
      return 'Họ tên cần từ 2 đến 100 ký tự.';
    }
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(text)) {
      return 'Họ tên chứa ký tự không hợp lệ.';
    }
    return null;
  }

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\+?[0-9 ().-]+$').hasMatch(text) ||
        digits.length < 8 ||
        digits.length > 15) {
      return 'Số điện thoại cần 8–15 chữ số, có thể bắt đầu bằng +.';
    }
    return null;
  }

  static String? address(String? value) =>
      (value?.trim().length ?? 0) > 300 ? 'Địa chỉ tối đa 300 ký tự.' : null;
}
