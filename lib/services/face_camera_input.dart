import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/network/api_failure.dart';

/// Converts transient camera buffers only. No photo files or uploads.
abstract final class FaceCameraInput {
  static const emulatorHelp =
      'Nếu dùng Android Emulator: tắt emulator, mở Device Manager → Edit AVD → '
      'Show Advanced Settings → Camera → Front, chọn Emulated hoặc Webcam0 '
      '(không chọn None), rồi Cold Boot. Không gán cùng Webcam0 cho cả Front và '
      'Back; có thể đặt Back là Emulated. Webcam0 cần quyền webcam trên máy tính. '
      'Ảnh Emulated chỉ thử camera, không chứng minh liveness.';

  /// Select by the lens reported by Android/iOS, never by camera index/name.
  /// Emulated/Webcam0 configured as Front are also reported as front-facing.
  static CameraDescription frontCamera(List<CameraDescription> cameras) {
    if (cameras.isEmpty) {
      throw const ApiFailure(
        'Hệ điều hành không liệt kê camera nào. Chưa thể kết luận thiết bị thiếu '
        'camera hay camera đang bị vô hiệu hóa. Kiểm tra quyền truy cập camera '
        'của hệ thống và cấu hình thiết bị. $emulatorHelp',
      );
    }
    final front = cameras.where(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (front.isNotEmpty) return front.first;
    final directions = cameras.map((c) => c.lensDirection.name).join(', ');
    throw ApiFailure(
      'Không có camera trước trong danh sách hệ điều hành trả về '
      '(${cameras.length} camera; hướng: $directions). Camera trước có thể chưa '
      'được cấu hình hoặc đã bị tắt. Không dùng camera sau để thay thế. $emulatorHelp',
    );
  }

  static bool needsPermissionSettings(String code) => const {
    'CameraAccessDenied',
    'CameraAccessDeniedWithoutPrompt',
    'CameraAccessRestricted',
  }.contains(code);

  static String cameraError(String code, String? description) {
    if (code == 'CameraAccessDeniedWithoutPrompt') {
      return 'Quyền camera đã bị từ chối và hệ thống không hỏi lại. '
          'Mở cài đặt ứng dụng → Quyền → Camera, cho phép rồi bấm Thử lại.';
    }
    if (code == 'CameraAccessDenied') {
      return 'Chưa được cấp quyền camera. Cho phép Camera trong cài đặt ứng dụng '
          'rồi bấm Thử lại.';
    }
    if (code == 'CameraAccessRestricted') {
      return 'Hệ thống đang hạn chế quyền camera. Kiểm tra giới hạn thiết bị '
          'hoặc liên hệ người quản lý thiết bị.';
    }
    final detail = '$code ${description ?? ''}'.toLowerCase();
    if (detail.contains('disabled') || detail.contains('device policy')) {
      return 'Camera bị vô hiệu hóa bởi hệ thống hoặc chính sách thiết bị. '
          'Bật Quyền truy cập camera trong cài đặt nhanh Android; kiểm tra '
          'chính sách quản lý thiết bị rồi bấm Thử lại.';
    }
    if (detail.contains('in use') || detail.contains('max cameras')) {
      return 'Camera đang được ứng dụng khác sử dụng. Đóng ứng dụng đó rồi bấm Thử lại.';
    }
    return 'Lỗi khởi tạo hoặc luồng camera (mã: $code). Đóng ứng dụng đang dùng '
        'camera, kiểm tra camera hệ thống rồi bấm Thử lại. $emulatorHelp';
  }

  static InputImage convert(CameraImage image, CameraController controller) {
    final camera = controller.description;
    var degrees = camera.sensorOrientation;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final device = switch (controller.value.deviceOrientation) {
        DeviceOrientation.portraitUp => 0,
        DeviceOrientation.landscapeLeft => 90,
        DeviceOrientation.portraitDown => 180,
        DeviceOrientation.landscapeRight => 270,
      };
      degrees = camera.lensDirection == CameraLensDirection.front
          ? (degrees + device) % 360
          : (degrees - device + 360) % 360;
    }
    final rotation = InputImageRotationValue.fromRawValue(degrees);
    if (rotation == null) {
      throw const ApiFailure(
        'Không đọc được hướng camera. Hãy giữ máy thẳng và thử lại.',
      );
    }
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (ios &&
        (image.format.group != ImageFormatGroup.bgra8888 ||
            image.planes.length != 1)) {
      throw const ApiFailure(
        'Camera không cung cấp định dạng ảnh được hỗ trợ.',
      );
    }
    final bytes = ios ? image.planes.single.bytes : _nv21(image);
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: ios ? InputImageFormat.bgra8888 : InputImageFormat.nv21,
        bytesPerRow: ios ? image.planes.single.bytesPerRow : image.width,
      ),
    );
  }

  static Uint8List _nv21(CameraImage image) {
    final w = image.width;
    final h = image.height;
    if (image.planes.length == 1 &&
        image.planes.single.bytes.length == w * h * 3 ~/ 2) {
      return image.planes.single.bytes;
    }
    if (image.planes.length != 3 || w.isOdd || h.isOdd) {
      throw const ApiFailure(
        'Camera không cung cấp luồng NV21/YUV420 phù hợp. Hãy thử thiết bị Android/iOS khác.',
      );
    }
    final bytes = Uint8List(w * h * 3 ~/ 2);
    final y = image.planes[0];
    final u = image.planes[1];
    final v = image.planes[2];
    for (var row = 0; row < h; row++) {
      for (var col = 0; col < w; col++) {
        bytes[row * w + col] =
            y.bytes[row * y.bytesPerRow + col * (y.bytesPerPixel ?? 1)];
      }
    }
    var offset = w * h;
    for (var row = 0; row < h ~/ 2; row++) {
      for (var col = 0; col < w ~/ 2; col++) {
        bytes[offset++] =
            v.bytes[row * v.bytesPerRow + col * (v.bytesPerPixel ?? 1)];
        bytes[offset++] =
            u.bytes[row * u.bytesPerRow + col * (u.bytesPerPixel ?? 1)];
      }
    }
    return bytes;
  }
}
