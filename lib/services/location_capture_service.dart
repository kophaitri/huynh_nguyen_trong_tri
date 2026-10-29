import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/network/api_failure.dart';

class LocationCaptureFailure extends ApiFailure {
  const LocationCaptureFailure(
    super.message, {
    this.serviceDisabled = false,
    this.permissionBlocked = false,
  });
  final bool serviceDisabled;
  final bool permissionBlocked;
}

class LocationCaptureService {
  Future<Position> capture() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationCaptureFailure(
        'Định vị đang tắt. Hãy bật dịch vụ vị trí rồi lấy lại GPS.',
        serviceDisabled: true,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationCaptureFailure(
        'Quyền vị trí đã bị chặn. Mở cài đặt ứng dụng để cấp quyền.',
        permissionBlocked: true,
      );
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw const LocationCaptureFailure(
        'Cần quyền vị trí khi sử dụng để chấm công.',
      );
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (position.isMocked) {
        throw const LocationCaptureFailure(
          'Thiết bị báo vị trí giả lập. Không thể dùng để chấm công.',
        );
      }
      if (!position.accuracy.isFinite ||
          position.accuracy <= 0 ||
          position.accuracy > 100) {
        throw const LocationCaptureFailure(
          'GPS chưa đủ chính xác (cần sai số trên 0 và không quá 100 m). Hãy ra nơi thoáng và thử lại.',
        );
      }
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude.abs() > 90 ||
          position.longitude.abs() > 180) {
        throw const LocationCaptureFailure(
          'Tọa độ GPS không hợp lệ. Vui lòng thử lại.',
        );
      }
      return position;
    } on TimeoutException {
      throw const LocationCaptureFailure(
        'Lấy GPS quá thời gian chờ. Kiểm tra tín hiệu và thử lại.',
      );
    } on PermissionDeniedException {
      throw const LocationCaptureFailure(
        'Chưa được cấp quyền vị trí. Vui lòng kiểm tra cài đặt.',
        permissionBlocked: true,
      );
    } on LocationServiceDisabledException {
      throw const LocationCaptureFailure(
        'Định vị đã bị tắt. Vui lòng bật lại.',
        serviceDisabled: true,
      );
    }
  }
}
