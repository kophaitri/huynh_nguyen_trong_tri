import 'package:flutter/material.dart';

import '../../core/network/api_failure.dart';
import '../../models/attendance_model.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/attendance_widgets.dart';
import '../../widgets/crud_widgets.dart';
import '../../widgets/cached_load_view.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({
    super.key,
    required this.auth,
    this.active = true,
  });
  final AuthService auth;
  final bool active;
  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  int _days = 30;
  final _loadKey = GlobalKey<CachedLoadViewState<List<AttendanceRecord>>>();
  Future<void> _reload() => _loadKey.currentState?.refresh() ?? Future.value();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Lịch sử chấm công của tôi'),
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: 'Làm mới',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: DropdownButtonFormField<int>(
              initialValue: _days,
              decoration: const InputDecoration(labelText: 'Khoảng thời gian'),
              items: const [7, 30, 90, 365]
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text('$d ngày gần đây'),
                    ),
                  )
                  .toList(),
              onChanged: (days) {
                if (days != null) {
                  setState(() => _days = days);
                }
              },
            ),
          ),
          Expanded(
            child: CachedLoadView<List<AttendanceRecord>>(
              key: _loadKey,
              active: widget.active,
              dataKey: _days,
              expand: true,
              cached: () =>
                  AttendanceService(widget.auth).cachedHistory(days: _days),
              load: (force) =>
                  AttendanceService(widget.auth)
                      .history(days: _days, forceRefresh: force),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError && !snapshot.hasData) {
                  return Center(
                    child: CrudErrorState(
                      message: snapshot.error is ApiFailure
                          ? (snapshot.error as ApiFailure).message
                          : 'Không thể đọc lịch sử.',
                      onRetry: _reload,
                    ),
                  );
                }
                final records = snapshot.data ?? [];
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (records.isEmpty)
                        const CrudEmptyState(
                          message:
                              'Chưa có bản ghi chấm công trong thời gian này.',
                        ),
                      ...records.map((r) => AttendanceReceiptCard(record: r)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
