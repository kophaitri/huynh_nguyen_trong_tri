import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Serial camera operations; no QR storage, logging or API calls.
class QrScannerSession extends ChangeNotifier {
  final controller = MobileScannerController(
    autoStart: false,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 300,
    cameraResolution: const Size(1280, 720),
    returnImage: false,
  );
  Future<void> _tail = Future.value();
  bool _closed = false, _active = true, _locked = false, _busy = false;
  String? _error;
  bool get busy => _busy;
  bool get active => _active;
  bool get locked => _locked;
  String? get error => _error;
  static String describeError(MobileScannerException error) {
    if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
      return 'Chưa được cấp quyền camera. Mở cài đặt ứng dụng, cho phép Camera rồi bấm Bật lại camera.';
    }
    if (error.errorCode == MobileScannerErrorCode.unsupported) {
      return 'Không tìm thấy camera phù hợp. Kiểm tra camera thiết bị hoặc cấu hình camera emulator.';
    }
    return 'Lỗi camera (${error.errorCode.name}). Đóng ứng dụng khác đang dùng camera, kiểm tra quyền truy cập camera của hệ thống rồi thử lại.';
  }

  void _changed() {
    if (!_closed) notifyListeners();
  }

  Future<void> _run(Future<void> Function() operation) {
    final next = _tail.then((_) async {
      if (_closed) return;
      _busy = true;
      _changed();
      try {
        await operation();
      } on MobileScannerException catch (e) {
        _error = describeError(e);
      } catch (_) {
        _error = 'Camera chưa sẵn sàng. Bấm Bật lại camera để thử lại.';
      } finally {
        _busy = false;
        _changed();
      }
    });
    _tail = next;
    return next;
  }

  Future<void> start({bool reset = false}) => _run(() async {
    if (!_active) return;
    if (reset) {
      _locked = false;
      _error = null;
    }
    if (!_locked && !controller.value.isRunning) await controller.start();
  });
  void lifecycle(bool active) {
    _active = active;
    if (active) {
      unawaited(start());
    } else {
      unawaited(_run(controller.stop));
    }
  }

  bool claimCapture() {
    if (_closed || !_active || _locked || _busy || !controller.value.isRunning) {
      return false;
    }
    _locked = true;
    _error = null;
    _changed();
    return true;
  }

  Future<void> pauseCapture() => _run(controller.pause);
  Future<void> retry() => _run(() async {
    if (!_active) return;
    _error = null;
    _locked = false;
    await controller.stop();
    if (_active && !_closed) await controller.start();
  });
  Future<void> switchCamera() => _run(() async {
    if (!_active || _locked) return;
    _error = null;
    await controller.switchCamera();
  });
  Future<void> toggleTorch() => _run(() async {
    if (_active &&
        !_locked &&
        controller.value.isRunning &&
        controller.value.torchState != TorchState.unavailable) {
      await controller.toggleTorch();
    }
  });
  @override
  void dispose() {
    _closed = true;
    _active = false;
    unawaited(
      _tail.then((_) async {
        try {
          await controller.dispose();
        } catch (_) {
          /* Already released. */
        }
      }),
    );
    super.dispose();
  }
}
