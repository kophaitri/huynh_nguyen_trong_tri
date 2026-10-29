import 'package:flutter/material.dart';

import '../../core/network/api_failure.dart';
import '../../models/shift_model.dart';
import '../../services/auth_service.dart';
import '../../services/smart_insights_service.dart';
import '../../widgets/auth_frame.dart';
import '../../widgets/crud_widgets.dart';
import '../../widgets/insight_widgets.dart';
import '../../widgets/cached_load_view.dart';

class SmartInsightsScreen extends StatefulWidget {
  const SmartInsightsScreen({
    super.key,
    required this.auth,
    this.active = true,
  });
  final AuthService auth;
  final bool active;
  @override
  State<SmartInsightsScreen> createState() => _SmartInsightsScreenState();
}

class _SmartInsightsScreenState extends State<SmartInsightsScreen> {
  int _days = 30;
  int? _shiftId;
  final _loadKey = GlobalKey<CachedLoadViewState<SmartInsightsData>>();
  Future<void> _reload() => _loadKey.currentState?.refresh() ?? Future.value();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Smart Insights'),
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: 'Làm mới',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: CachedLoadView<SmartInsightsData>(
        key: _loadKey,
        active: widget.active,
        dataKey: _days,
        expand: true,
        load: (force) =>
            SmartInsightsService(widget.auth)
                .load(days: _days, forceRefresh: force),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang phân tích lịch sử của bạn…'),
                ],
              ),
            );
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return Center(
              child: CrudErrorState(
                message: snapshot.error is ApiFailure
                    ? (snapshot.error as ApiFailure).message
                    : 'Không thể đọc dữ liệu phân tích.',
                onRetry: _reload,
              ),
            );
          }
          final data = snapshot.data!;
          final insights = data.insights;
          final selected = data.shifts
              .where((s) => s.id == _shiftId)
              .firstOrNull;
          final suggestion = selected == null
              ? null
              : insights.preparationFor(selected);
          String count(int? value) => value?.toString() ?? 'Chưa đủ dữ liệu';
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF132D50), Color(0xFF215F8C)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.insights_rounded,
                                color: Color(0xFF77E0BE),
                                size: 34,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Hiểu nhịp làm việc của bạn',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Lịch sử thật được phân tích ngay trên thiết bị của bạn.',
                                style: TextStyle(color: Color(0xFFD4E3F3)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<int>(
                          initialValue: _days,
                          decoration: const InputDecoration(
                            labelText: 'Dữ liệu phân tích',
                          ),
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
                        const SizedBox(height: 20),
                        if (insights.checkInCount == 0 &&
                            insights.unknownTypeCount == 0)
                          const CrudEmptyState(
                            message: 'Chưa có buổi chấm công vào trong khoảng thời gian này. Không tạo dữ liệu mẫu.',
                          ),
                        InsightCardGrid(
                          children: [
                            InsightStatCard(
                              label: 'Buổi đã chấm công',
                              value: count(insights.sessionCount),
                              icon: Icons.event_available_outlined,
                              note: 'Mỗi CheckIn là một buổi; không đếm CheckOut.',
                            ),
                            InsightStatCard(
                              label: 'Buổi đúng giờ',
                              value: count(insights.onTimeCount),
                              icon: Icons.check_circle_outline,
                              color: const Color(0xFF16845B),
                              note: 'Theo cờ isLate = false của máy chủ.',
                            ),
                            InsightStatCard(
                              label: 'Buổi đi muộn',
                              value: count(insights.lateCount),
                              icon: Icons.schedule,
                              color: const Color(0xFFB66B24),
                              note: 'Theo cờ isLate = true của máy chủ.',
                            ),
                            InsightStatCard(
                              label: 'Phút đi muộn trung bình',
                              value: 'Chưa đủ dữ liệu',
                              icon: Icons.timelapse,
                              note: 'API chưa trả phút muộn hoặc giờ bắt đầu ca lịch sử.',
                            ),
                            InsightStatCard(
                              label: 'Tỷ lệ đúng giờ',
                              value: insights.onTimeRate == null
                                  ? 'Chưa đủ dữ liệu'
                                  : '${(insights.onTimeRate! * 100).toStringAsFixed(1)}%',
                              icon: Icons.pie_chart_outline,
                              note: 'Buổi đúng giờ / tổng CheckIn có trạng thái đầy đủ.',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        PunctualityChart(insights: insights),
                        const SizedBox(height: 16),
                        const AuthMessage(
                          '“Đúng giờ” ở đây là không bị server đánh dấu muộn. Lịch sử không có thông tin ca/giờ chuẩn tại thời điểm chấm công để kiểm tra lại độc lập.',
                          isError: false,
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Mốc chuẩn bị đi làm',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Chọn ca hiện tại làm tham khảo; đây không phải ca được phân công hoặc ca lịch sử đã xác minh.',
                                ),
                                const SizedBox(height: 16),
                                if (data.shiftError != null)
                                  AuthMessage(
                                    'Chưa đọc được ca làm: ${data.shiftError}',
                                  )
                                else if (data.shifts.isEmpty)
                                  const Text(
                                    'Chưa đủ dữ liệu ca làm để gợi ý giờ chuẩn bị.',
                                  )
                                else
                                  DropdownButtonFormField<int>(
                                    key: ValueKey(
                                      '${data.shifts.map((s) => s.id).join(',')}:${selected?.id}',
                                    ),
                                    initialValue: selected?.id,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Ca làm tham khảo',
                                    ),
                                    items: data.shifts
                                        .map(
                                          (ShiftModel s) => DropdownMenuItem(
                                            value: s.id,
                                            child: Text(
                                              '${s.name} · ${s.startTime}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (id) =>
                                        setState(() => _shiftId = id),
                                  ),
                                const SizedBox(height: 18),
                                if (selected == null)
                                  const Text(
                                    'Chọn một ca để xem mốc tham khảo.',
                                  )
                                else if (suggestion == null)
                                  const Text(
                                    'Chưa đủ dữ liệu: giờ bắt đầu ca không ở định dạng được hỗ trợ.',
                                  )
                                else ...[
                                  Text(
                                    '${suggestion.time}${suggestion.previousDay ? ' · ngày trước ca' : ''}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: const Color(0xFF132D50),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Mốc tham khảo = ${suggestion.startTime} − 15 phút đệm.',
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Gợi ý cá nhân hóa: Chưa đủ dữ liệu. Chưa thể trừ thêm mức muộn trung bình. Không tính hoặc ước lượng thời gian di chuyển thực tế.',
                                  ),
                                ],
                              ],
                            ),
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
    ),
  );
}
