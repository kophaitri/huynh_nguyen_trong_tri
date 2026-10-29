import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/network/api_failure.dart';
import '../../services/face_camera_input.dart';
import '../../services/face_liveness_service.dart';
import '../../widgets/crud_widgets.dart';

class FaceLivenessScreen extends StatefulWidget {
  const FaceLivenessScreen({super.key, required this.userId});
  final String userId;
  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

class _FaceLivenessScreenState extends State<FaceLivenessScreen>
    with WidgetsBindingObserver {
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: .2,
    ),
  );
  late final _challenge = FaceLivenessService(
    userId: widget.userId,
    turnRight: Random.secure().nextBool(),
  );
  CameraController? _camera;
  bool _initializing = false;
  bool _processing = false;
  bool _finished = false;
  bool _closed = false;
  bool _permissionSettings = false;
  int _generation = 0;
  String? _error;
  String _hint = 'Đặt một khuôn mặt trong khung, nơi đủ sáng.';
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _processingFrame;
  Future<void>? _stopping;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // A system permission dialog can make the app inactive during initialize.
      if (state == AppLifecycleState.inactive && _initializing) return;
      _challenge.reset();
      unawaited(_stop());
    }
  }

  Future<void> _stop() {
    _generation++;
    return _stopping ??= _releaseCamera().whenComplete(() => _stopping = null);
  }

  Future<void> _releaseCamera() async {
    final camera = _camera;
    _camera = null;
    camera?.removeListener(_onCameraChanged);
    if (mounted && !_closed) setState(() {});
    try {
      if (camera?.value.isStreamingImages == true) {
        await camera!.stopImageStream();
      }
    } catch (_) {
      /* already closed */
    }
    await _processingFrame;
    try {
      await camera?.dispose();
    } catch (_) {
      /* already closed */
    }
  }

  void _onCameraChanged() {
    final camera = _camera;
    if (camera == null || _closed || !mounted || !camera.value.hasError) return;
    setState(() {
      _permissionSettings = false;
      _error = FaceCameraInput.cameraError(
        'CameraRuntimeError',
        camera.value.errorDescription,
      );
    });
    _challenge.reset();
    unawaited(_stop());
  }

  Future<void> _start() async {
    if (_initializing || _finished || _closed) return;
    setState(() {
      _initializing = true;
      _error = null;
      _permissionSettings = false;
    });
    final stopping = _stop();
    final generation = _generation;
    await stopping;
    if (_closed || !mounted || generation != _generation) {
      if (mounted && !_closed) setState(() => _initializing = false);
      return;
    }
    _challenge.reset();
    try {
      final cameras = await availableCameras();
      if (_closed || !mounted || generation != _generation) return;
      if (kDebugMode) {
        debugPrint(
          'Face camera discovery: count=${cameras.length}; lenses=${cameras.map((c) => c.lensDirection.name).join(',')}',
        );
      }
      final front = FaceCameraInput.frontCamera(cameras);
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );
      _camera = controller;
      controller.addListener(_onCameraChanged);
      await controller.initialize();
      if (_closed ||
          _camera != controller ||
          !mounted ||
          generation != _generation) {
        return;
      }
      await controller.startImageStream((image) {
        if (_error != null ||
            _processing ||
            _closed ||
            _finished ||
            _camera != controller ||
            DateTime.now().difference(_lastFrame).inMilliseconds < 120) {
          return;
        }
        _lastFrame = DateTime.now();
        _processingFrame = _process(image, controller);
      });
    } on CameraException catch (error) {
      if (mounted && !_closed && generation == _generation) {
        setState(() {
          _permissionSettings = FaceCameraInput.needsPermissionSettings(
            error.code,
          );
          _error = FaceCameraInput.cameraError(error.code, error.description);
        });
      }
      await _stop();
    } on ApiFailure catch (error) {
      if (mounted && !_closed && generation == _generation) {
        setState(() => _error = error.message);
      }
      await _stop();
    } catch (_) {
      if (mounted && !_closed && generation == _generation) {
        setState(
          () => _error =
              'Không thể khởi động kiểm tra khuôn mặt trên thiết bị này.',
        );
      }
      await _stop();
    } finally {
      if (mounted && !_closed) setState(() => _initializing = false);
    }
  }

  Future<void> _process(CameraImage image, CameraController controller) async {
    _processing = true;
    LivenessEvidence? evidence;
    try {
      final faces = await _detector.processImage(
        FaceCameraInput.convert(image, controller),
      );
      if (_closed || _camera != controller || !mounted) return;
      evidence = _challenge.process(faces);
      if (mounted) {
        setState(
          () => _hint = faces.length != 1
              ? 'Cần đúng một khuôn mặt trong khung.'
              : _challenge.instruction,
        );
      }
      if (evidence != null) _finished = true;
    } catch (error) {
      if (mounted && !_closed && _camera == controller) {
        setState(
          () => _error = error is ApiFailure ? error.message : 'Không xử lý được luồng ảnh. Hãy thử lại trên thiết bị hỗ trợ camera và ML Kit.',
        );
      }
      _challenge.reset();
      // Release after this frame completes, so release never awaits itself.
      unawaited(
        Future<void>(() async {
          if (_camera == controller) await _stop();
        }),
      );
    } finally {
      _processing = false;
    }
    if (evidence != null && mounted && !_closed) {
      // Run after this frame finishes so camera release never awaits itself.
      final result = evidence;
      unawaited(
        Future<void>(() async {
          await _stop();
          if (mounted) Navigator.pop(context, result);
        }),
      );
    }
  }

  Future<void> _close() async {
    _closed = true;
    await _stop();
    await _detector.close();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kiểm tra chuyển động khuôn mặt')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Chớp mắt và quay đầu theo hướng dẫn. Đây là kiểm tra chuyển động tại máy, không xác minh danh tính và không đảm bảo chống giả mạo bằng video.',
            ),
            const SizedBox(height: 16),
            if (_camera?.value.isInitialized == true)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(height: 330, child: CameraPreview(_camera!)),
              )
            else
              const SizedBox(
                height: 180,
                child: Center(
                  child: Icon(Icons.face_retouching_natural, size: 80),
                ),
              ),
            const SizedBox(height: 20),
            if (_initializing) const LinearProgressIndicator(),
            if (_error != null)
              CrudErrorState(message: _error!, onRetry: _start)
            else
              Text(
                _hint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 20),
            if (_error != null && _permissionSettings)
              TextButton(
                onPressed: Geolocator.openAppSettings,
                child: const Text('Mở quyền camera trong cài đặt'),
              ),
            if (_camera == null && !_initializing && _error == null)
              FilledButton(
                onPressed: _start,
                child: const Text('Bật lại camera'),
              ),
            const Text('Không lưu ảnh, không tải khung hình lên máy chủ.'),
          ],
        ),
      ),
    ),
  );
}
