import 'package:dio/dio.dart';

/// Contains only a safe user-facing message, never raw request/response data.
class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.statusCode, this.retryAfter, this.code});

  final String message;
  final int? statusCode;
  final Duration? retryAfter;
  final String? code;
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  factory ApiFailure.fromDio(DioException error) {
    final status = error.response?.statusCode;
    final retrySeconds = int.tryParse(
      error.response?.headers.value('retry-after') ?? '',
    );
    if (status == 429) {
      return ApiFailure(
        'Bạn thao tác quá nhanh. Vui lòng chờ rồi thử lại.',
        statusCode: status,
        retryAfter: retrySeconds == null
            ? null
            : Duration(seconds: retrySeconds),
      );
    }
    if (status != null && status >= 500) {
      return ApiFailure(
        'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
        statusCode: status,
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const ApiFailure(
        'Kết nối quá thời gian chờ. Kiểm tra mạng rồi thử lại.',
      );
    }
    if (error.type == DioExceptionType.connectionError) {
      return const ApiFailure(
        'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
      );
    }
    if (error.type == DioExceptionType.badCertificate) {
      return const ApiFailure('Không thể xác minh kết nối HTTPS tới máy chủ.');
    }

    // Only display known validation messages. Never expose arbitrary server text
    // (which may contain a submitted email, a stack trace or other sensitive data).
    final data = error.response?.data;
    if (data is Map) {
      final code = data['code'];
      const attendanceMessages = <String, String>{
        'QR_INVALID': 'QR không hợp lệ hoặc đã hết hạn. Hãy quét mã mới tại nơi làm việc.',
        'LOCATION_NOT_FOUND':
            'Địa điểm trong QR không còn tồn tại. Hãy liên hệ quản lý.',
        'OUT_OF_RANGE': 'Máy chủ xác định bạn ở ngoài vùng chấm công. Hãy đến đúng địa điểm và lấy lại GPS.',
        'FRAUD_SUSPECTED': 'Máy chủ từ chối vị trí hoặc thiết bị. Không dùng GPS giả; nếu đổi máy, liên hệ Admin kiểm tra thiết bị đã gắn.',
        'FACE_REQUIRED': 'Máy chủ yêu cầu kiểm tra khuôn mặt. Với tài khoản đã có vector, cần bộ trích xuất MobileFaceNet tương thích.',
        'FACE_MISMATCH':
            'Máy chủ báo khuôn mặt không khớp. Chấm công chưa được chấp nhận.',
        'ALREADY_DONE':
            'Hôm nay đã có lần chấm công này. Hãy kiểm tra lịch sử từ máy chủ.',
        'NO_CHECKIN': 'Máy chủ chưa ghi nhận chấm công vào hôm nay. Chưa thể chấm công ra.',
      };
      if (code is String && attendanceMessages.containsKey(code)) {
        return ApiFailure(
          attendanceMessages[code]!,
          statusCode: status,
          code: code,
        );
      }
      final message = data['message'];
      const messages = <String, String>{
        'Sai tài khoản hoặc mật khẩu': 'Email hoặc mật khẩu không đúng.',
        'Tài khoản đã bị khoá':
            'Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.',
        'OTP sai hoặc hết hạn':
            'Mã OTP sai hoặc đã hết hạn. Vui lòng kiểm tra hoặc gửi lại mã.',
        'Đang được sử dụng, không thể xoá':
            'Dữ liệu đang được sử dụng, không thể xóa.',
        'Đơn đã được duyệt/từ chối':
            'Đơn đã được xử lý. Vui lòng làm mới danh sách.',
        'Đơn đã xử lý': 'Đơn đã được xử lý, không thể hủy.',
        'Ngày kết thúc phải sau ngày bắt đầu':
            'Ngày kết thúc không được trước ngày bắt đầu.',
        'Role không hợp lệ': 'Vai trò nhân viên không hợp lệ.',
      };
      if (messages.containsKey(message)) {
        return ApiFailure(messages[message]!, statusCode: status);
      }
      final errors = data['errors'];
      if (errors is List &&
          errors.any((e) => e is String && e.contains('already taken'))) {
        return ApiFailure('Email này đã được đăng ký.', statusCode: status);
      }
      if (errors != null && status == 400) {
        return const ApiFailure(
          'Dữ liệu không hợp lệ. Kiểm tra email, họ tên và mật khẩu (ít nhất 6 ký tự, có chữ thường và số).',
          statusCode: 400,
        );
      }
    }
    return ApiFailure(switch (status) {
      401 => 'Phiên xác thực không hợp lệ hoặc đã hết hạn.',
      403 => 'Máy chủ từ chối quyền truy cập.',
      400 => 'Dữ liệu không hợp lệ. Vui lòng kiểm tra lại.',
      404 =>
        'Không tìm thấy dữ liệu hoặc bạn không có quyền truy cập dữ liệu này.',
      409 => 'Dữ liệu đang được sử dụng hoặc đã thay đổi. Vui lòng làm mới.',
      422 => 'Dữ liệu chưa hợp lệ. Vui lòng kiểm tra các trường đã nhập.',
      _ => 'Không thể hoàn tất yêu cầu. Vui lòng thử lại.',
    }, statusCode: status);
  }

  @override
  String toString() => message;
}
