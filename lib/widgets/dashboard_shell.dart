import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_failure.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import '../screens/attendance/attendance_history_screen.dart';
import '../screens/attendance/attendance_screen.dart';
import '../screens/attendance/qr_display_screen.dart';
import '../screens/departments/department_screen.dart';
import '../screens/employee/smart_insights_screen.dart';
import '../screens/employee/motion_screen.dart';
import '../screens/employee/text_scan_screen.dart';
import '../screens/employees/employee_screen.dart';
import '../screens/leaves/leave_screen.dart';
import '../screens/locations/location_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/shared/crud_route.dart';
import '../screens/shifts/shift_screen.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import 'crud_widgets.dart';
import 'insight_widgets.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({
    super.key,
    required this.title,
    required this.icon,
    required this.user,
    required this.auth,
  });
  final String title;
  final IconData icon;
  final UserModel user;
  final AuthService auth;
  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell>
    with WidgetsBindingObserver {
  int _index = 0;
  late Future<DashboardData> _future;
  DashboardData? _lastData;
  final _visitedTabs = <int>{0};
  bool _loading = false;
  bool _refreshAfterLoad = false;
  int _request = 0;
  int _seenRevision = -1;
  String _day = DashboardService.dayKey(DateTime.now());
  Timer? _dateTimer;
  bool get _employee => widget.user.role == UserRole.employee;
  @override
  void initState() {
    super.initState();
    _future = _loadDashboard(false);
    WidgetsBinding.instance.addObserver(this);
    _dateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_day != DashboardService.dayKey(DateTime.now())) _reload();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        _index == 0 &&
        ModalRoute.of(context)?.isCurrent == true) {
      _ensureFresh();
    }
  }

  @override
  void dispose() {
    _dateTimer?.cancel();
    _request++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<DashboardData> _loadDashboard(bool force) {
    final request = ++_request;
    final revision = widget.auth.client.cacheRevision;
    _seenRevision = revision;
    _loading = true;
    final previous = _lastData;
    if (previous != null) {
      _lastData = DashboardData(
        todayRecords: previous.todayRecords,
        counts: previous.counts,
        errors: previous.errors,
        loadedAt: previous.loadedAt,
        pending: {
          'attendance',
          if (!_employee) ...[
            'Nhân viên',
            'Phòng ban',
            'Ca làm',
            'Địa điểm',
            'Đơn chờ duyệt',
          ],
        },
      );
    }
    return DashboardService(widget.auth)
        .load(
          forceRefresh: force,
          previous: previous,
          onUpdate: (partial) {
            if (mounted && request == _request) {
              setState(() => _lastData = partial);
            }
          },
        )
        .then((data) {
          if (mounted && request == _request) {
            setState(() {
              _lastData = data;
              _seenRevision = revision;
            });
          }
          return data;
        })
        .whenComplete(() {
          if (!mounted || request != _request) return;
          setState(() => _loading = false);
          if (_refreshAfterLoad) {
            _refreshAfterLoad = false;
            scheduleMicrotask(() {
              if (mounted) _reload();
            });
          }
        });
  }

  void _ensureFresh() {
    final changed = _seenRevision != widget.auth.client.cacheRevision;
    if (_loading) {
      if (changed) _refreshAfterLoad = true;
      return;
    }
    if (changed ||
        _lastData == null ||
        DateTime.now().difference(_lastData!.loadedAt) >=
            const Duration(seconds: 60)) {
      _reload(forceRefresh: false);
    }
  }

  void _reload({bool forceRefresh = true}) {
    if (!mounted) return;
    if (_loading && !forceRefresh) return;
    setState(() {
      _refreshAfterLoad = false;
      _day = DashboardService.dayKey(DateTime.now());
      _future = _loadDashboard(forceRefresh);
    });
  }

  Future<void> _open(
    Widget Function() page, {
    bool refreshOnReturn = true,
  }) async {
    await openCrudPage<void>(context, widget.auth, (_) => page());
    if (refreshOnReturn && mounted && widget.auth.user != null) _ensureFresh();
  }

  String _clock(DateTime time) {
    final vn = DashboardService.vietnamTime(time);
    return '${vn.hour.toString().padLeft(2, '0')}:${vn.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Trang chủ',
      ),
      const NavigationDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history_rounded),
        label: 'Lịch sử',
      ),
      if (_employee)
        const NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights_rounded),
          label: 'Insights',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Hồ sơ',
      ),
    ];
    final index = _index < destinations.length ? _index : 0;
    final body = IndexedStack(
      index: index,
      children: [
        _home(),
        if (_visitedTabs.contains(1))
          AttendanceHistoryScreen(auth: widget.auth, active: index == 1)
        else
          const SizedBox.shrink(),
        if (_employee)
          (_visitedTabs.contains(2)
              ? SmartInsightsScreen(auth: widget.auth, active: index == 2)
              : const SizedBox.shrink()),
        if (_visitedTabs.contains(destinations.length - 1))
          ProfileScreen(
            auth: widget.auth,
            active: index == destinations.length - 1,
          )
        else
          const SizedBox.shrink(),
      ],
    );
    return Scaffold(
      appBar: index == 0
          ? AppBar(
              title: const Text(
                'TriWork',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              actions: [
                IconButton(
                  onPressed: _loading ? null : _reload,
                  tooltip: 'Làm mới',
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _index = destinations.length - 1;
                    _visitedTabs.add(_index);
                  }),
                  tooltip: 'Hồ sơ',
                  icon: const Icon(Icons.account_circle_outlined),
                ),
              ],
            )
          : null,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD9F4E9),
        destinations: destinations,
        onDestinationSelected: (value) {
          if (value == _index) return;
          setState(() {
            _index = value;
            _visitedTabs.add(value);
          });
          if (value == 0) _ensureFresh();
        },
      ),
    );
  }

  Widget _home() => SafeArea(
    child: FutureBuilder<DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        final loading = _loading;
        final data = _lastData ?? snapshot.data;
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            try {
              await _future;
            } catch (_) {
              /* Rendered below. */
            }
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _greeting(),
                      const SizedBox(height: 22),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 18),
                          child: LinearProgressIndicator(),
                        ),
                      if (snapshot.hasError)
                        CrudErrorState(
                          message: snapshot.error is ApiFailure
                              ? (snapshot.error as ApiFailure).message
                              : 'Không đọc được tổng quan.',
                          onRetry: _reload,
                        ),
                      if (data?.cachedParts.isNotEmpty == true)
                        const Text(
                          'Có dữ liệu từ bộ nhớ (tối đa 60 giây).',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF63738A),
                          ),
                        ),
                      _today(
                        data,
                        data?.pending.contains('attendance') ?? loading,
                      ),
                      if (!_employee) ...[
                        const SizedBox(height: 24),
                        _heading(
                          'Tổng quan quản lý',
                          'Số liệu trực tiếp từ các API bạn có quyền đọc',
                        ),
                        const SizedBox(height: 14),
                        InsightCardGrid(
                          children: [
                            for (final key in [
                              'Nhân viên',
                              'Phòng ban',
                              'Ca làm',
                              'Địa điểm',
                              'Đơn chờ duyệt',
                            ])
                              InsightStatCard(
                                label: 'Tổng ${key.toLowerCase()}',
                                value:
                                    data?.counts[key]?.toString() ??
                                    ((data?.pending.contains(key) ?? loading)
                                        ? '…'
                                        : 'Chưa đủ dữ liệu'),
                                icon: key == 'Đơn chờ duyệt'
                                    ? Icons.pending_actions_outlined
                                    : Icons.bar_chart_rounded,
                                note:
                                    data?.errors[key] ??
                                    (data?.pending.contains(key) == true
                                        ? 'Đang cập nhật · giữ số liệu lần trước.'
                                        : 'Tổng tại lần tải dữ liệu gần nhất.'),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 26),
                      _heading(
                        'Lối tắt công việc',
                        _employee
                            ? 'Dành cho ngày làm việc của bạn'
                            : 'Thao tác theo quyền ${widget.user.roleName}',
                      ),
                      const SizedBox(height: 14),
                      InsightCardGrid(
                        children: [
                          _shortcut(
                            'Quét QR chấm công',
                            Icons.qr_code_scanner,
                            'Chuẩn bị camera, GPS rồi quét mã tại nơi làm việc',
                            () => AttendanceScreen(auth: widget.auth),
                          ),
                          _shortcut(
                            'Lịch sử chấm công',
                            Icons.history,
                            'Xem những lần vào và ra đã được ghi nhận',
                            () => AttendanceHistoryScreen(auth: widget.auth),
                          ),
                          if (_employee)
                            _shortcut(
                              'Smart Insights',
                              Icons.insights_rounded,
                              'Hiểu nhịp làm việc từ lịch sử thật',
                              () => SmartInsightsScreen(auth: widget.auth),
                            ),
                          if (!_employee)
                            _shortcut(
                              'QR điểm chấm công',
                              Icons.qr_code_rounded,
                              'Hiển thị mã động do máy chủ cấp',
                              () => QrDisplayScreen(auth: widget.auth),
                            ),
                          if (_employee)
                            _shortcut(
                              'Đo chuyển động',
                              Icons.vibration_rounded,
                              'Kiểm tra gia tốc kế của thiết bị',
                              () => const MotionScreen(),
                              refreshOnReturn: false,
                            ),
                          if (_employee)
                            _shortcut(
                              'Quét và dịch văn bản',
                              Icons.translate_rounded,
                              'Nhận dạng chữ từ ảnh · dịch Anh / Việt offline',
                              () => const TextScanScreen(),
                              refreshOnReturn: false,
                            ),
                          if (!_employee)
                            _shortcut(
                              'Nhân viên',
                              Icons.badge_outlined,
                              widget.user.role == UserRole.admin
                                  ? 'Quản lý thông tin nhân sự'
                                  : 'Xem danh sách và chi tiết',
                              () => EmployeeScreen(auth: widget.auth),
                            ),
                          _shortcut(
                            'Đơn nghỉ phép',
                            Icons.event_note_outlined,
                            _employee
                                ? 'Tạo và theo dõi đơn của bạn'
                                : 'Xem, duyệt và từ chối đơn',
                            () => LeaveScreen(auth: widget.auth),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _heading(
                        _employee ? 'Thông tin công việc' : 'Danh mục làm việc',
                        widget.user.role == UserRole.admin
                            ? 'Quản lý phòng ban, ca và địa điểm'
                            : 'Tra cứu thông tin từ máy chủ',
                      ),
                      const SizedBox(height: 14),
                      InsightCardGrid(
                        children: [
                          _shortcut(
                            'Phòng ban',
                            Icons.business_outlined,
                            'Cơ cấu phòng ban',
                            () => DepartmentScreen(auth: widget.auth),
                          ),
                          _shortcut(
                            'Ca làm',
                            Icons.schedule_outlined,
                            'Giờ bắt đầu và kết thúc ca',
                            () => ShiftScreen(auth: widget.auth),
                          ),
                          _shortcut(
                            'Địa điểm',
                            Icons.location_on_outlined,
                            'Địa điểm làm việc',
                            () => LocationScreen(auth: widget.auth),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: widget.auth.logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Đăng xuất'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  Widget _greeting() {
    final hour = DashboardService.vietnamTime(DateTime.now()).hour;
    final greeting = hour < 12
        ? 'Chào buổi sáng'
        : hour < 18
        ? 'Chào buổi chiều'
        : 'Chào buổi tối';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF132D50), Color(0xFF1C5279)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: const Color(0xFF87E7C2), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Color(0xFFD5E6F5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            '$greeting,',
            style: const TextStyle(color: Color(0xFFD5E6F5), fontSize: 16),
          ),
          const SizedBox(height: 5),
          Text(
            widget.user.fullName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            DashboardService.dateLabel(DateTime.now()),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Vai trò: ${widget.user.roleName}',
            style: const TextStyle(color: Color(0xFF87E7C2)),
          ),
        ],
      ),
    );
  }

  Widget _today(DashboardData? data, bool loading) {
    final failed = data?.errors.containsKey('attendance') == true;
    final records = failed ? null : data?.todayRecords;
    final checkIn = records?.where((r) => r.type == 'CheckIn').firstOrNull;
    final checkOut = records?.where((r) => r.type == 'CheckOut').firstOrNull;
    final status = loading
        ? (data?.todayRecords == null
              ? 'Đang kiểm tra trạng thái…'
              : 'Đang cập nhật trạng thái…')
        : records == null
        ? 'Chưa xác định trạng thái'
        : checkOut != null
        ? 'Đã ghi nhận chấm công ra'
        : checkIn != null
        ? 'Đã ghi nhận chấm công vào'
        : 'Chưa có bản ghi hôm nay';
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hôm nay · giờ Việt Nam',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              status,
              style: const TextStyle(
                color: Color(0xFF132D50),
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (data?.errors['attendance'] != null) ...[
              const SizedBox(height: 12),
              Text(data!.errors['attendance']!),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _reload,
                  child: const Text('Thử lại'),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                Text('Vào: ${checkIn == null ? '—' : _clock(checkIn.time)}'),
                Text('Ra: ${checkOut == null ? '—' : _clock(checkOut.time)}'),
                if (checkIn?.location != null) Text('Tại ${checkIn!.location}'),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: loading || checkIn != null
                      ? null
                      : () => _open(
                          () => AttendanceScreen(
                            auth: widget.auth,
                            initialAction: AttendanceAction.checkIn,
                          ),
                        ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Chấm công vào'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      loading ||
                          checkOut != null ||
                          (records != null && checkIn == null)
                      ? null
                      : () => _open(
                          () => AttendanceScreen(
                            auth: widget.auth,
                            initialAction: AttendanceAction.checkOut,
                          ),
                        ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Chấm công ra'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Các nút mở quy trình chuẩn bị; bạn xác nhận vị trí, QR và khuôn mặt trước khi gửi.',
              style: TextStyle(fontSize: 12, color: Color(0xFF63738A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: Color(0xFF63738A))),
    ],
  );
  Widget _shortcut(
    String title,
    IconData icon,
    String subtitle,
    Widget Function() page, {
    bool refreshOnReturn = true,
  }) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE2E9F3)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _open(page, refreshOnReturn: refreshOnReturn),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFECF5F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: const Color(0xFF196B77)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF63738A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
