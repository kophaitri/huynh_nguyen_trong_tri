import 'package:geolocator/geolocator.dart';

import '../core/config/api_config.dart';
import '../core/network/api_failure.dart';
import '../core/network/json_reader.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'device_identity_service.dart';
import 'face_liveness_service.dart';

class AttendanceService {
  AttendanceService(this.auth);
  final AuthService auth;
  void _signedIn() {
    if (auth.user == null) throw const ApiFailure('Vui lòng đăng nhập lại.');
  }

  Future<bool> hasEnrolledFace() async {
    _signedIn();
    return JsonReader.boolean(
      (await auth.client.get(ApiConfig.me, forceRefresh: true))['hasFace'],
    );
  }

  List<AttendanceRecord>? cachedHistory({int days = 30}) {
    final data = auth.client.cached(
      ApiConfig.myAttendance,
      queryParameters: {'days': days},
    );
    return data == null
        ? null
        : JsonReader.list(data, AttendanceRecord.fromJson);
  }

  Future<List<AttendanceRecord>> history({
    int days = 30,
    bool forceRefresh = false,
  }) async {
    _signedIn();
    return JsonReader.list(
      await auth.client.request(
        'GET',
        ApiConfig.myAttendance,
        queryParameters: {'days': days},
        forceRefresh: forceRefresh,
      ),
      AttendanceRecord.fromJson,
    );
  }

  Future<CurrentAttendanceQr> currentQr(int locationId) async {
    _signedIn();
    if (auth.user!.role == UserRole.employee) {
      throw const ApiFailure('Chỉ Admin/Manager được mở QR điểm chấm công.');
    }
    return CurrentAttendanceQr.fromJson(
      JsonReader.map(
        await auth.client.request(
          'GET',
          ApiConfig.currentQr,
          queryParameters: {'locationId': locationId},
        ),
      ),
    );
  }

  Future<AttendanceRecord> submit({
    required AttendanceAction action,
    required ScannedAttendanceQr qr,
    required Position position,
    required LivenessEvidence evidence,
    required bool consentToLocation,
  }) async {
    _signedIn();
    if (!consentToLocation) {
      throw const ApiFailure(
        'Bạn cần đồng ý chia sẻ vị trí cho lần chấm công này.',
      );
    }
    final userId = auth.user!.id;
    if (!evidence.fresh || evidence.userId != auth.user!.id) {
      throw const ApiFailure(
        'Hãy thực hiện lại kiểm tra chuyển động khuôn mặt.',
      );
    }
    if (DateTime.now().difference(position.timestamp).abs().inSeconds > 30 ||
        position.isMocked ||
        !position.accuracy.isFinite ||
        position.accuracy <= 0 ||
        position.accuracy > 100) {
      throw const ApiFailure(
        'GPS đã cũ hoặc không đủ chính xác. Hãy lấy lại vị trí.',
      );
    }
    // An enrolled account requires a genuine compatible embedding; never bypass
    // it with face detection, landmarks, random vectors or a constant true flag.
    if (await hasEnrolledFace()) {
      throw const ApiFailure(
        'Tài khoản đã có vector khuôn mặt. Chưa có bộ trích xuất MobileFaceNet tương thích để xác minh danh tính; không gửi chấm công.',
      );
    }
    if (!evidence.fresh) {
      throw const ApiFailure(
        'Kiểm tra khuôn mặt đã hết hạn. Hãy thực hiện lại.',
      );
    }
    final deviceId = await DeviceIdentityService().getId();
    if (auth.user?.id != userId ||
        !evidence.fresh ||
        DateTime.now().difference(position.timestamp).abs().inSeconds > 30) {
      throw const ApiFailure(
        'Phiên hoặc dữ liệu chuẩn bị đã thay đổi/hết hạn. Hãy chuẩn bị lại, không gửi chấm công.',
      );
    }
    final json = await auth.client.request(
      'POST',
      action == AttendanceAction.checkIn
          ? ApiConfig.checkIn
          : ApiConfig.checkOut,
      data: {
        'qrToken': qr.raw,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'isMocked': position.isMocked,
        'deviceId': deviceId,
        'faceVerified': true,
        'faceEmbedding': null,
      },
    );
    return AttendanceRecord.fromJson(JsonReader.map(json), receipt: true);
  }
}
