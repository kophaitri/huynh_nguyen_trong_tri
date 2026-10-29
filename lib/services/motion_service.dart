import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/motion_sample.dart';

enum MotionPhase { idle, starting, measuring, stopped, unavailable }

class MotionService extends ChangeNotifier {
  static const samplingPeriod = Duration(milliseconds: 100);
  static const _silenceLimit = Duration(seconds: 5);
  static const _capacity = 100;
  final _watch = Stopwatch();
  final List<MotionSample> _samples = [];
  StreamSubscription<AccelerometerEvent>? _subscription;
  Future<void>? _canceling;
  Timer? _watchdog;
  Duration _lastEventAt = Duration.zero;
  bool _starting = false;
  bool _running = false;
  bool _disposed = false;
  int _generation = 0;
  double? _smoothedChange;
  MotionPhase _phase = MotionPhase.idle;
  String? _message;

  MotionPhase get phase => _phase;
  bool get running => _running;
  bool get starting => _starting;
  String? get message => _message;
  MotionSample? get latest => _samples.lastOrNull;
  List<MotionSample> get samples => List.unmodifiable(_samples);
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_disposed || _starting || _running) return;
    _starting = true;
    final generation = ++_generation;
    _phase = MotionPhase.starting;
    _message = null;
    _changed();
    try {
      await _cancelSubscription();
      if (_disposed || generation != _generation) return;
      if (kIsWeb ||
          (defaultTargetPlatform != TargetPlatform.android &&
              defaultTargetPlatform != TargetPlatform.iOS)) {
        await _fail(
          'Kiểm tra gia tốc hiện hỗ trợ ứng dụng Android/iOS. Hãy dùng điện thoại có cảm biến.',
        );
        return;
      }
      _samples.clear();
      _smoothedChange = null;
      _lastEventAt = Duration.zero;
      _watch
        ..reset()
        ..start();
      _running = true;
      _subscription = accelerometerEventStream(samplingPeriod: samplingPeriod)
          .listen(
            (event) {
              if (generation == _generation) _onEvent(event);
            },
            onError: (Object error, StackTrace stack) {
              if (generation != _generation || _disposed) return;
              unawaited(
                _fail(
                  error is PlatformException && error.code == 'NO_SENSOR'
                      ? 'Thiết bị không có gia tốc kế. Không thể đo chuyển động.'
                      : 'Không truy cập được gia tốc kế. Kiểm tra quyền chuyển động hoặc thử lại trên thiết bị hỗ trợ.',
                ),
              );
            },
            onDone: () {
              if (_running && generation == _generation && !_disposed) {
                unawaited(
                  _fail('Luồng cảm biến đã kết thúc. Bấm Bắt đầu để thử lại.'),
                );
              }
            },
            cancelOnError: true,
          );
      _watchdog?.cancel();
      _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_running &&
            generation == _generation &&
            _watch.elapsed - _lastEventAt > _silenceLimit) {
          unawaited(
            _fail(
              'Không nhận được mẫu trong 5 giây. Thiết bị có thể thiếu cảm biến hoặc đang chặn dữ liệu chuyển động.',
            ),
          );
        }
      });
    } catch (_) {
      if (!_disposed && generation == _generation) {
        await _fail(
          'Không khởi động được gia tốc kế. Hãy thử lại trên điện thoại có cảm biến.',
        );
      }
    } finally {
      _starting = false;
      _changed();
    }
  }

  void _onEvent(AccelerometerEvent event) {
    if (_disposed || !_running) return;
    if (!event.x.isFinite || !event.y.isFinite || !event.z.isFinite) {
      unawaited(_fail('Cảm biến trả dữ liệu không hợp lệ. Đã dừng đo.'));
      return;
    }
    final elapsed = _watch.elapsed;
    _lastEventAt = elapsed;
    final previous = latest;
    // Some platforms ignore the requested frequency. Bound UI work to ~10 Hz.
    if (previous != null && elapsed - previous.elapsed < samplingPeriod) return;
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (!magnitude.isFinite) {
      unawaited(_fail('Độ lớn gia tốc không hợp lệ. Đã dừng đo.'));
      return;
    }
    if (previous != null) {
      final dx = event.x - previous.x;
      final dy = event.y - previous.y;
      final dz = event.z - previous.z;
      final change = sqrt(dx * dx + dy * dy + dz * dz);
      _smoothedChange = _smoothedChange == null
          ? change
          : .7 * _smoothedChange! + .3 * change;
    }
    // Qualitative estimate from smoothed vector changes, not absolute |a|:
    // a stationary accelerometer still reports gravity (~9.81 m/s²).
    final level = _samples.length < 5 || _smoothedChange == null
        ? MotionLevel.warmingUp
        : _smoothedChange! < .35
        ? MotionLevel.steady
        : _smoothedChange! < 1.8
        ? MotionLevel.moving
        : MotionLevel.strong;
    _samples.add(
      MotionSample(
        x: event.x,
        y: event.y,
        z: event.z,
        magnitude: magnitude,
        variation: _smoothedChange,
        elapsed: elapsed,
        level: level,
      ),
    );
    if (_samples.length > _capacity) _samples.removeAt(0);
    _phase = MotionPhase.measuring;
    _changed();
  }

  Future<void> _cancelSubscription() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription == null) return _canceling ?? Future.value();
    final operation = () async {
      try {
        await subscription.cancel();
      } catch (_) {
        /* Dart listener is already detached. */
      }
    }();
    _canceling = operation;
    return operation.whenComplete(() {
      if (identical(_canceling, operation)) _canceling = null;
    });
  }

  Future<void> _halt(MotionPhase phase, String? message) async {
    _generation++;
    _running = false;
    _watch.stop();
    _watchdog?.cancel();
    _watchdog = null;
    _phase = phase;
    _message = message;
    _changed();
    await _cancelSubscription();
  }

  Future<void> _fail(String message) => _halt(MotionPhase.unavailable, message);
  Future<void> stop() => _halt(MotionPhase.stopped, null);

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _running = false;
    _watch.stop();
    _watchdog?.cancel();
    unawaited(_cancelSubscription());
    super.dispose();
  }
}
