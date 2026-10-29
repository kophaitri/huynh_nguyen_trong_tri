import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/network/api_failure.dart';
import '../../models/attendance_model.dart';
import '../../models/work_location_model.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/face_liveness_service.dart';
import '../../services/location_capture_service.dart';
import '../../services/location_service.dart';
import '../../widgets/attendance_widgets.dart';
import '../../widgets/auth_frame.dart';
import '../../widgets/crud_widgets.dart';
import '../shared/crud_route.dart';
import 'attendance_history_screen.dart';
import 'face_liveness_screen.dart';
import 'qr_scan_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.auth, this.initialAction});
  final AuthService auth;
  final AttendanceAction? initialAction;
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with WidgetsBindingObserver {
  bool get _mobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  ScannedAttendanceQr? _qr;
  Position? _position;
  WorkLocationModel? _location;
  LivenessEvidence? _evidence;
  AttendanceRecord? _receipt;
  String? _receiptLocation;
  String? _error;
  bool _busy = false;
  bool _consent = false;
  LocationCaptureFailure? _locationError;
  bool _uncertain = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && mounted) {
      setState(() {
        _qr = null;
        _position = null;
        _evidence = null;
        _location = null;
        _consent = false;
      });
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể hoàn tất thao tác trên thiết bị này. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _face() => _perform(() async {
    _evidence = null;
    if (await AttendanceService(widget.auth).hasEnrolledFace()) {
      throw const ApiFailure(
        'Tài khoản đã đăng ký vector khuôn mặt. TriWork chưa có bộ trích xuất MobileFaceNet tương thích, nên chưa thể xác minh danh tính để chấm công. Không thay thế bằng phát hiện khuôn mặt.',
      );
    }
    if (!mounted) return;
    final agreed = await confirmCrudAction(
      context,
      title: 'Cho phép kiểm tra khuôn mặt?',
      message: 'Camera trước xử lý khung hình ngay trên máy để kiểm tra chớp mắt và quay đầu. Không lưu hoặc gửi ảnh. Đây không phải xác minh danh tính. Bạn đồng ý thực hiện?',
      confirmLabel: 'Đồng ý mở camera',
    );
    if (!agreed || !mounted || widget.auth.user == null) return;
    final result = await openCrudPage<LivenessEvidence>(
      context,
      widget.auth,
      (_) => FaceLivenessScreen(userId: widget.auth.user!.id),
    );
    if (mounted) setState(() => _evidence = result);
  });
  Future<void> _gps() => _perform(() async {
    setState(() {
      _position = null;
      _locationError = null;
      _consent = false;
    });
    try {
      final position = await LocationCaptureService().capture();
      if (mounted) setState(() => _position = position);
    } on LocationCaptureFailure catch (error) {
      if (mounted) setState(() => _locationError = error);
      rethrow;
    }
  });
  Future<void> _scan() => _perform(() async {
    setState(() {
      _qr = null;
      _location = null;
    });
    final qr = await openCrudPage<ScannedAttendanceQr>(
      context,
      widget.auth,
      (_) => const QrScanScreen(),
    );
    if (qr == null || !mounted) return;
    final location = await LocationService(widget.auth).get(qr.locationId);
    if (mounted) {
      setState(() {
        _qr = qr;
        _location = location;
      });
    }
  });
  double? get _distance => _position == null || _location == null
      ? null
      : Geolocator.distanceBetween(
          _position!.latitude,
          _position!.longitude,
          _location!.latitude,
          _location!.longitude,
        );
  Future<void> _submit(AttendanceAction action) => _perform(() async {
    if (_qr == null || _position == null || _evidence == null || !_consent) {
      throw const ApiFailure(
        'Cần đủ kiểm tra chuyển động, GPS, QR và đồng ý chia sẻ vị trí.',
      );
    }
    if (_distance != null && _distance! > _location!.radiusMeters) {
      throw const ApiFailure(
        'Bạn đang ngoài vùng chấm công theo GPS hiện tại. Hãy đến đúng địa điểm rồi lấy lại vị trí.',
      );
    }
    if (!mounted) return;
    final confirmed = await confirmCrudAction(
      context,
      title: action.label,
      message:
          'Gửi vị trí hiện tại, sai số GPS và kết quả kiểm tra chuyển động đến máy chủ để ${action.label.toLowerCase()} tại ${_location!.name}? Máy chủ là nơi quyết định kết quả.',
      confirmLabel: 'Gửi chấm công',
    );
    if (!confirmed || !mounted) return;
    final qr = _qr;
    final position = _position;
    final evidence = _evidence;
    if (qr == null || position == null || evidence == null) {
      throw const ApiFailure('Thông tin đã hết hiệu lực. Hãy chuẩn bị lại.');
    }
    try {
      final receipt = await AttendanceService(widget.auth).submit(
        action: action,
        qr: qr,
        position: position,
        evidence: evidence,
        consentToLocation: _consent,
      );
      if (mounted) {
        setState(() {
          _receipt = receipt;
          _receiptLocation = _location?.name;
          _qr = null;
          _evidence = null;
          _consent = false;
          _uncertain = false;
        });
      }
    } on ApiFailure {
      if (mounted) {
        setState(() {
          _qr = null;
          _evidence = null;
          _uncertain = true;
        });
      }
      rethrow;
    }
  });
  Future<void> _history() async {
    await openCrudPage<void>(
      context,
      widget.auth,
      (_) => AttendanceHistoryScreen(auth: widget.auth),
    );
    // Viewing history alone does not establish whether an uncertain POST committed.
  }

  @override
  Widget build(BuildContext context) {
    final distance = _distance;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initialAction?.label ?? 'Chấm công TriWork'),
          automaticallyImplyLeading: !_busy,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Thực hiện kiểm tra chuyển động trước, lấy GPS rồi quét QR sau cùng để hạn chế mã hết hạn.',
                    ),
                    if (!_mobile)
                      const AuthMessage(
                        'Camera kiểm tra chuyển động chỉ hỗ trợ Android/iOS. Bạn vẫn có thể xem lịch sử.',
                        isError: false,
                      ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      ),
                    if (_error != null) AuthMessage(_error!),
                    if (_locationError?.serviceDisabled == true)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : Geolocator.openLocationSettings,
                        child: const Text('Mở cài đặt định vị'),
                      ),
                    if (_locationError?.permissionBlocked == true)
                      TextButton(
                        onPressed: _busy ? null : Geolocator.openAppSettings,
                        child: const Text('Mở quyền vị trí trong cài đặt'),
                      ),
                    if (_receipt != null)
                      AttendanceReceiptCard(
                        record: _receipt!,
                        location: _receiptLocation,
                      ),
                    AttendanceStepCard(
                      title: '1. Chuyển động khuôn mặt',
                      icon: Icons.face_retouching_natural,
                      description: _evidence?.fresh == true
                          ? 'Đã hoàn thành thử thách tại máy. Chưa xác minh danh tính.'
                          : 'Chớp mắt và quay đầu. Không lưu/gửi ảnh.',
                      buttonLabel: 'Kiểm tra bằng camera trước',
                      onPressed: _busy || !_mobile ? null : _face,
                    ),
                    AttendanceStepCard(
                      title: '2. GPS hiện tại',
                      icon: Icons.my_location,
                      description: _position == null
                          ? 'Chỉ lấy vị trí khi bạn bấm nút. Không theo dõi nền.'
                          : '${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)}\nSai số ±${_position!.accuracy.toStringAsFixed(0)} m. GPS chỉ dùng khi còn mới trong 30 giây.',
                      buttonLabel: 'Lấy lại vị trí GPS',
                      onPressed: _busy || !_mobile ? null : _gps,
                    ),
                    AttendanceStepCard(
                      title: '3. QR tại nơi làm việc',
                      icon: Icons.qr_code_scanner,
                      description: _qr == null
                          ? 'Dùng mã mới đang hiển thị tại điểm chấm công.'
                          : '${_location!.name}\n${distance == null ? 'Cần lấy GPS để tính khoảng cách.' : 'Ước tính ${distance.toStringAsFixed(0)} m / bán kính ${_location!.radiusMeters} m.'}\nChữ ký và thời hạn QR chưa được máy chủ xác minh.',
                      buttonLabel: 'Quét QR mới',
                      onPressed: _busy || !_mobile ? null : _scan,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _consent,
                      onChanged: _busy || _position == null
                          ? null
                          : (value) =>
                                setState(() => _consent = value ?? false),
                      title: const Text(
                        'Tôi đồng ý gửi vị trí cho lần chấm công này.',
                      ),
                    ),
                    if (_uncertain)
                      const AuthMessage(
                        'Yêu cầu chưa được xác nhận. Hãy kiểm tra lịch sử trước khi chuẩn bị lại và gửi tiếp; không tự động gửi lại.',
                        isError: false,
                      ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: AttendanceAction.values
                          .where(
                            (action) =>
                                widget.initialAction == null ||
                                action == widget.initialAction,
                          )
                          .map(
                            (action) => FilledButton.icon(
                              onPressed:
                                  _busy ||
                                      !_mobile ||
                                      !_consent ||
                                      _qr == null ||
                                      _position == null ||
                                      _evidence == null
                                  ? null
                                  : () => _submit(action),
                              icon: Icon(
                                action == AttendanceAction.checkIn
                                    ? Icons.login
                                    : Icons.logout,
                              ),
                              label: Text(action.label),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _history,
                      icon: const Icon(Icons.history),
                      label: const Text('Xem lịch sử từ máy chủ'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
