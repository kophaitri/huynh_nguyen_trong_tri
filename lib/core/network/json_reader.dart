import 'api_failure.dart';

abstract final class JsonReader {
  static Never invalid() => throw const ApiFailure(
    'Dữ liệu máy chủ không đúng định dạng. Vui lòng thử lại.',
  );
  static Map<String, dynamic> map(dynamic value) =>
      value is Map<String, dynamic> ? value : invalid();
  static String string(dynamic value) => value is String ? value : invalid();
  static String? optionalString(dynamic value) =>
      value == null ? null : string(value);
  static int integer(dynamic value) => value is int ? value : invalid();
  static int? optionalInt(dynamic value) =>
      value == null ? null : integer(value);
  static double number(dynamic value) =>
      value is num && value.isFinite ? value.toDouble() : invalid();
  static bool boolean(dynamic value) => value is bool ? value : invalid();
  static List<T> list<T>(
    dynamic value,
    T Function(Map<String, dynamic>) decode,
  ) {
    if (value is! List) invalid();
    return (value).map((item) => decode(map(item))).toList();
  }
}
