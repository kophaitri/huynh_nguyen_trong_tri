/// Routes verified against backend AuthController and DTOs.
abstract final class ApiConfig {
  static const String baseUrl = 'https://vupham309-001-site1.etempurl.com';
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String verifyOtp = '/api/auth/verify-otp';
  static const String resendOtp = '/api/auth/resend-otp';
  static const String me = '/api/auth/me';
  static const String employees = '/api/employees';
  static const String departments = '/api/departments';
  static const String shifts = '/api/shifts';
  static const String locations = '/api/locations';
  static const String leaves = '/api/leaves';
  static const String checkIn = '/api/attendance/check-in';
  static const String checkOut = '/api/attendance/check-out';
  static const String myAttendance = '/api/attendance/my';
  static const String currentQr = '/api/qr/current';
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration getReceiveTimeout = Duration(seconds: 12);
  static const Duration getDeadline = Duration(seconds: 15);
  static const Duration writeDeadline = Duration(seconds: 35);
  static const Duration cacheLifetime = Duration(seconds: 60);
  static const Duration storageDeadline = Duration(seconds: 8);
  static const Duration resendCooldown = Duration(seconds: 60);
}
