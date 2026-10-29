import '../core/network/api_client.dart';
import '../core/network/api_failure.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../models/user_model.dart';
import 'attendance_service.dart';
import 'auth_service.dart';
import 'department_service.dart';
import 'employee_service.dart';
import 'leave_service.dart';
import 'location_service.dart';
import 'shift_service.dart';

class DashboardData {
  const DashboardData({
    required this.todayRecords,
    required this.counts,
    required this.errors,
    required this.loadedAt,
    this.pending = const {},
    this.cachedParts = const {},
  });
  final List<AttendanceRecord>? todayRecords;
  final Map<String, int?> counts;
  final Map<String, String> errors;
  final DateTime loadedAt;
  final Set<String> pending;
  final Set<String> cachedParts;
}

class DashboardService {
  DashboardService(this.auth);
  final AuthService auth;
  static DateTime vietnamTime(DateTime time) =>
      time.toUtc().add(const Duration(hours: 7));
  static String dayKey(DateTime time) {
    final vn = vietnamTime(time);
    return '${vn.year}-${vn.month}-${vn.day}';
  }

  static String dateLabel(DateTime time) {
    final vn = vietnamTime(time);
    const days = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ nhật',
    ];
    return '${days[vn.weekday - 1]}, ${vn.day.toString().padLeft(2, '0')}/${vn.month.toString().padLeft(2, '0')}/${vn.year}';
  }

  Future<DashboardData> load({
    bool forceRefresh = false,
    DashboardData? previous,
    void Function(DashboardData)? onUpdate,
  }) => forceRefresh
      ? ApiClient.freshReads(() => _load(previous, onUpdate))
      : _load(previous, onUpdate);

  Future<DashboardData> _load(
    DashboardData? previous,
    void Function(DashboardData)? onUpdate,
  ) async {
    final user = auth.user;
    if (user == null) throw const ApiFailure('Vui lòng đăng nhập lại.');
    final errors = <String, String>{};
    final counts = Map<String, int?>.of(previous?.counts ?? {});
    final cached = <String>{};
    final pending = <String>{
      'attendance',
      if (user.role != UserRole.employee) ...[
        'Nhân viên',
        'Phòng ban',
        'Ca làm',
        'Địa điểm',
        'Đơn chờ duyệt',
      ],
    };
    List<AttendanceRecord>? records =
        previous != null && dayKey(previous.loadedAt) == dayKey(DateTime.now())
        ? previous.todayRecords
        : null;
    DateTime? oldestCache;
    DashboardData snapshot() => DashboardData(
      todayRecords: records,
      counts: Map.unmodifiable(counts),
      errors: Map.unmodifiable(errors),
      pending: Set.unmodifiable(pending),
      cachedParts: Set.unmodifiable(cached),
      loadedAt: oldestCache ?? DateTime.now(),
    );
    void publish() {
      onUpdate?.call(snapshot());
    }

    Future<void> part(String key, Future<void> Function() action) async {
      try {
        await ApiClient.observeReads(action, (at) {
          cached.add(key);
          if (oldestCache == null || at.isBefore(oldestCache!)) {
            oldestCache = at;
          }
        });
      } on ApiFailure catch (error) {
        errors[key] = error.message;
      } finally {
        pending.remove(key);
        publish();
      }
    }

    final tasks = <Future<void>>[
      part('attendance', () async {
        final history = await AttendanceService(auth).history(days: 2);
        records = history
            .where((r) => dayKey(r.time) == dayKey(DateTime.now()))
            .toList();
      }),
    ];
    Future<void> count(String key, Future<int> Function() read) =>
        part(key, () async {
          counts[key] = await read();
        });
    if (user.role != UserRole.employee) {
      tasks.addAll([
        count(
          'Nhân viên',
          () async => (await EmployeeService(auth).list(pageSize: 1)).total,
        ),
        count(
          'Phòng ban',
          () async => (await DepartmentService(auth).list(pageSize: 1)).total,
        ),
        count(
          'Ca làm',
          () async => (await ShiftService(auth).list(pageSize: 1)).total,
        ),
        count(
          'Địa điểm',
          () async => (await LocationService(auth).list(pageSize: 1)).total,
        ),
        count(
          'Đơn chờ duyệt',
          () async =>
              (await LeaveService(auth).list(status: LeaveStatus.pending))
                  .length,
        ),
      ]);
    }
    await Future.wait(tasks);
    return snapshot();
  }
}
