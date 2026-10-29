import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/api_failure.dart';
import '../../models/attendance_model.dart';
import '../../models/work_location_model.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../widgets/crud_widgets.dart';

class QrDisplayScreen extends StatefulWidget {
  const QrDisplayScreen({super.key, required this.auth});
  final AuthService auth;
  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen>
    with WidgetsBindingObserver {
  late Future<List<WorkLocationModel>> _locations = LocationService(widget.auth)
      .all();
  int? _locationId;
  CurrentAttendanceQr? _qr;
  DateTime? _validUntil;
  Timer? _timer;
  int _ticks = 0;
  int _generation = 0;
  bool _loading = false;
  bool _running = false;
  String? _error;
  int get _seconds =>
      max(0, _validUntil?.difference(DateTime.now()).inSeconds ?? 0);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stop();
    }
  }

  void _stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    if (mounted) {
      setState(() {
        _qr = null;
        _running = false;
        _loading = false;
      });
    }
  }

  Future<void> _loadQr() async {
    if (_loading || _locationId == null) return;
    final generation = _generation;
    final started = DateTime.now();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qr = await AttendanceService(widget.auth).currentQr(_locationId!);
      if (mounted && generation == _generation) {
        setState(() {
          _qr = qr;
          // Count from request start so network delay never extends advertised TTL.
          _validUntil = started.add(Duration(seconds: qr.ttlSeconds));
        });
      }
    } on ApiFailure catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = error.message;
          _qr = null;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _start() async {
    if (_locationId == null || _loading) return;
    _timer?.cancel();
    _generation++;
    final generation = _generation;
    _ticks = 0;
    setState(() => _running = true);
    await _loadQr();
    if (!mounted || !_running || generation != _generation) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _ticks++);
      if (_ticks % 30 == 0 && !_loading) unawaited(_loadQr());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QR điểm chấm công')),
    body: SafeArea(
      child: FutureBuilder<List<WorkLocationModel>>(
        future: _locations,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: CrudErrorState(
                message: snapshot.error is ApiFailure
                    ? (snapshot.error as ApiFailure).message
                    : 'Không đọc được địa điểm.',
                onRetry: () => setState(
                  () =>
                      _locations = LocationService(widget.auth)
                          .all(forceRefresh: true),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return const CrudEmptyState(
              message: 'Chưa có địa điểm để hiển thị QR.',
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _locationId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Điểm chấm công',
                      ),
                      items: snapshot.data!
                          .map(
                            (l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(
                                l.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        _stop();
                        setState(() => _locationId = id);
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _locationId == null || _loading
                          ? null
                          : _start,
                      child: const Text('Lấy QR từ máy chủ'),
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator(),
                      ),
                    if (_error != null)
                      CrudErrorState(message: _error!, onRetry: _loadQr),
                    const SizedBox(height: 20),
                    if (_qr != null && _seconds > 0) ...[
                      Text(
                        _qr!.location,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) => Center(
                          child: QrImageView(
                            data: _qr!.token,
                            size: min(280.0, constraints.maxWidth),
                            backgroundColor: Colors.white,
                            semanticsLabel: 'QR chấm công hiện tại',
                          ),
                        ),
                      ),
                      Text(
                        'Còn tối đa $_seconds giây · tự lấy mã mới mỗi 30 giây',
                        textAlign: TextAlign.center,
                      ),
                    ] else if (_running)
                      const Text(
                        'Mã chưa sẵn sàng hoặc đã hết hạn. Hãy lấy QR mới.',
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 20),
                    const Text(
                      'Chỉ hiển thị QR do backend phát hành. Máy chủ xác minh thời hạn/chữ ký khi nhân viên gửi chấm công.',
                    ),
                    if (_running)
                      TextButton(
                        onPressed: _stop,
                        child: const Text('Dừng hiển thị QR'),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
