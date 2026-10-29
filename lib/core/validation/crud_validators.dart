import '../network/api_failure.dart';

abstract final class CrudValidators {
  static String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Vui lòng nhập thông tin.' : null;
  static String? nonNegativeInt(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number != null && number > 2147483647) {
      return 'Số nguyên vượt quá giới hạn của máy chủ.';
    }
    return number == null || number < 0 ? 'Nhập số nguyên từ 0 trở lên.' : null;
  }

  static String? positiveInt(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number != null && number > 2147483647) {
      return 'Số nguyên vượt quá giới hạn của máy chủ.';
    }
    return number == null || number <= 0 ? 'Nhập số nguyên lớn hơn 0.' : null;
  }

  static String? coordinate(String? value, {required bool latitude}) {
    final number = double.tryParse(value?.trim() ?? '');
    final bound = latitude ? 90 : 180;
    return number == null ||
            !number.isFinite ||
            number < -bound ||
            number > bound
        ? 'Nhập tọa độ từ -$bound đến $bound.'
        : null;
  }

  static String? time(String? value) =>
      RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d$').hasMatch(value ?? '')
      ? null
      : 'Giờ cần đúng HH:mm:ss (ví dụ 08:00:00).';
  static DateTime? parseDate(String? value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value ?? '')) return null;
    final date = DateTime.tryParse(value!);
    return date != null &&
            date.year >= 1 &&
            date.year <= 9999 &&
            formatDate(date) == value
        ? date
        : null;
  }

  static String formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String? date(String? value) =>
      parseDate(value) == null ? 'Ngày cần đúng yyyy-MM-dd.' : null;
  static void check(Iterable<String?> errors) {
    for (final error in errors) {
      if (error != null) throw ApiFailure(error);
    }
  }
}
