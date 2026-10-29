import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/network/api_failure.dart';
import '../../models/attendance_model.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    returnImage: false,
  );
  bool _takingResult = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_stop());
    }
  }

  Future<void> _stop() async {
    try {
      await _controller.stop();
    } catch (_) {
      /* camera already stopped */
    }
  }

  Future<void> _start() async {
    try {
      await _controller.start();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Không mở được camera. Kiểm tra quyền camera trong cài đặt.',
        );
      }
    }
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_takingResult) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      try {
        final qr = ScannedAttendanceQr.parse(raw);
        _takingResult = true;
        await _stop();
        await _controller.dispose();
        if (mounted) Navigator.pop(context, qr);
        return;
      } on ApiFailure catch (error) {
        if (mounted) setState(() => _error = error.message);
      } catch (_) {
        _takingResult = false;
        if (mounted) {
          setState(
            () => _error =
                'Không thể đóng camera hoặc nhận QR. Hãy quay lại và quét lại.',
          );
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quét QR điểm chấm công')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _detected,
              onDetectError: (_, _) {
                if (mounted) {
                  setState(() => _error = 'Không đọc được QR. Hãy thử lại.');
                }
              },
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Không mở được camera. Cấp quyền camera trong cài đặt ứng dụng rồi thử lại.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: Geolocator.openAppSettings,
                        child: const Text('Mở cài đặt ứng dụng'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  _error ?? 'Quét mã đang hiển thị tại nơi làm việc. Máy chủ sẽ xác minh chữ ký và thời hạn QR.',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: _takingResult ? null : _start,
                  child: const Text('Bật lại camera'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
