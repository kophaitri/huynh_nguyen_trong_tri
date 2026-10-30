import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/network/api_failure.dart';
import '../../models/attendance_model.dart';
import '../../services/qr_scanner_session.dart';
import '../../widgets/qr_scan_overlay.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with WidgetsBindingObserver {
  final _session = QrScannerSession();
  String? _qrError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_session.start());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Do not interrupt the first system permission dialog.
    if (state == AppLifecycleState.inactive &&
        _session.controller.value.isStarting &&
        !_session.controller.value.hasCameraPermission) {
      return;
    }
    _session.lifecycle(state == AppLifecycleState.resumed);
  }

  Future<void> _detected(BarcodeCapture capture) async {
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .firstOrNull;
    if (raw == null || !_session.claimCapture()) return;
    await _session.pauseCapture();
    if (!mounted || !_session.active || _session.error != null) return;
    try {
      final qr = ScannedAttendanceQr.parse(raw);
      Navigator.pop(context, qr);
    } on ApiFailure catch (e) {
      setState(
        () => _qrError =
            '${e.message} Bấm Quét lại và dùng mã QR điểm chấm công mới.',
      );
    } catch (_) {
      setState(() => _qrError = 'Không đọc được nội dung mã. Bấm Quét lại.');
    }
  }

  Future<void> _retry() async {
    setState(() => _qrError = null);
    await _session.retry();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quét QR điểm chấm công')),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: _session,
        builder: (context, _) => ValueListenableBuilder<MobileScannerState>(
          valueListenable: _session.controller,
          builder: (context, camera, _) {
            final error =
                _qrError ??
                _session.error ??
                (camera.error == null
                    ? null
                    : QrScannerSession.describeError(camera.error!));
            final disabled = _session.busy || camera.isStarting;
            return Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final side = min(
                        300.0,
                        min(size.width * .78, size.height * .75),
                      );
                      final window = Rect.fromCenter(
                        center: size.center(Offset.zero),
                        width: side,
                        height: side,
                      );
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: _session.controller,
                            useAppLifecycleState: false,
                            tapToFocus: true,
                            scanWindow: window,
                            onDetect: _detected,
                            onDetectError: (_, _) {
                              if (mounted) {
                                setState(
                                  () => _qrError = 'Không đọc được QR. Bấm Quét lại, giữ máy ổn định và tránh phản chiếu.',
                                );
                              }
                            },
                            errorBuilder: (context, error) => const ColoredBox(
                              color: Color(0xFF132D50),
                              child: Center(
                                child: Icon(
                                  Icons.no_photography_outlined,
                                  color: Colors.white,
                                  size: 54,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(child: QrScanOverlay(window: window)),
                          if (!camera.isRunning && !disabled)
                            const Center(
                              child: Icon(
                                Icons.qr_code_scanner,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          Positioned(
                            top: 12,
                            left: 12,
                            right: 12,
                            child: Text(
                              camera.isRunning
                                  ? 'Đưa mã QR vào giữa khung · Chạm để lấy nét'
                                  : disabled
                                  ? 'Đang chuẩn bị camera…'
                                  : 'Camera đang dừng',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                backgroundColor: Color(0x99132D50),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .44,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          error ??
                              'Camera ${camera.cameraDirection == CameraFacing.front ? 'trước' : 'sau'} · Quét mã mới trên điện thoại hoặc màn hình khác. Máy chủ vẫn xác minh chữ ký và thời hạn mã.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: error == null
                                ? const Color(0xFF132D50)
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            OutlinedButton.icon(
                              onPressed:
                                  disabled ||
                                      !camera.isRunning ||
                                      _session.locked ||
                                      camera.torchState ==
                                          TorchState.unavailable
                                  ? null
                                  : _session.toggleTorch,
                              icon: Icon(
                                camera.torchState == TorchState.on
                                    ? Icons.flash_on
                                    : Icons.flash_off,
                              ),
                              label: Text(
                                camera.torchState == TorchState.unavailable
                                    ? 'Không có flash'
                                    : camera.torchState == TorchState.on
                                    ? 'Tắt flash'
                                    : 'Bật flash',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  disabled ||
                                      !camera.isRunning ||
                                      _session.locked ||
                                      (camera.availableCameras != null &&
                                          camera.availableCameras! < 2)
                                  ? null
                                  : _session.switchCamera,
                              icon: const Icon(Icons.cameraswitch_outlined),
                              label: const Text('Đổi camera'),
                            ),
                            FilledButton.icon(
                              onPressed: disabled ? null : _retry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Quét lại'),
                            ),
                            TextButton(
                              onPressed: disabled
                                  ? null
                                  : () {
                                      setState(() => _qrError = null);
                                      unawaited(_session.start(reset: true));
                                    },
                              child: const Text('Bật lại camera'),
                            ),
                            if (camera.error?.errorCode ==
                                MobileScannerErrorCode.permissionDenied)
                              TextButton(
                                onPressed: Geolocator.openAppSettings,
                                child: const Text('Mở quyền camera'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Giữ QR cách camera khoảng 20–40 cm, hiển thị đủ viền trắng; tăng sáng màn hình chứa QR và tắt flash nếu bị lóa.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Android Emulator: nên đặt Back Camera = Webcam0 để quét điện thoại khác. Camera Emulated/VirtualScene chỉ hiển thị cảnh giả lập, không thấy điện thoại thật. Tránh gán cùng Webcam0 cho cả Front/Back rồi Cold Boot emulator.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF63738A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
