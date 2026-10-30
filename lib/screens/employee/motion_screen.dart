import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/motion_sample.dart';
import '../../services/motion_service.dart';
import '../../widgets/insight_widgets.dart';
import '../../widgets/motion_widgets.dart';

class MotionScreen extends StatefulWidget {
  const MotionScreen({super.key});
  @override
  State<MotionScreen> createState() => _MotionScreenState();
}

class _MotionScreenState extends State<MotionScreen>
    with WidgetsBindingObserver {
  final _motion = MotionService();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (_motion.running || _motion.starting)) {
      unawaited(_motion.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đo chuyển động')),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final sample = _motion.latest;
          final status = switch (_motion.phase) {
            MotionPhase.idle => 'Chưa bắt đầu đo',
            MotionPhase.starting => 'Đang chờ gia tốc kế…',
            MotionPhase.measuring => sample?.level.label ?? 'Đang chờ mẫu',
            MotionPhase.stopped => 'Đã dừng đo',
            MotionPhase.unavailable => 'Cảm biến không khả dụng',
          };
          final color = _motion.running && sample?.level == MotionLevel.strong
              ? const Color(0xFFB66B24)
              : const Color(0xFF16845B);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.vibration_rounded,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            size: 36,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            status,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _motion.running
                                ? 'Đang đọc cảm biến trực tiếp trên thiết bị.'
                                : 'Cảm biến chỉ hoạt động sau khi bấm Bắt đầu.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_motion.message != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(_motion.message!),
                        ),
                      ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _motion.running || _motion.starting
                              ? null
                              : _motion.start,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Bắt đầu'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _motion.running || _motion.starting
                              ? _motion.stop
                              : null,
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('Dừng'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _motion.running
                          ? 'Tần suất yêu cầu 10 Hz; tốc độ thực tế tùy thiết bị.'
                          : 'Số liệu còn hiển thị là lần đo trước, không phải dữ liệu đang cập nhật.',
                    ),
                    const SizedBox(height: 20),
                    InsightCardGrid(
                      children: [
                        MotionReadingCard(
                          label: 'Gia tốc X',
                          value: sample?.x,
                          color: const Color(0xFF235AA7),
                        ),
                        MotionReadingCard(
                          label: 'Gia tốc Y',
                          value: sample?.y,
                          color: const Color(0xFF16845B),
                        ),
                        MotionReadingCard(
                          label: 'Gia tốc Z',
                          value: sample?.z,
                          color: const Color(0xFF9A5D25),
                        ),
                        MotionReadingCard(
                          label: 'Độ lớn √(X² + Y² + Z²)',
                          value: sample?.magnitude,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        MotionReadingCard(
                          label: 'Biến thiên đã làm mượt',
                          value: sample?.variation,
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    MotionChart(samples: _motion.samples),
                    const SizedBox(height: 16),
                    const Text(
                      'Gia tốc thô bao gồm trọng lực, nên khi đứng yên độ lớn thường gần 9,81 m/s². Trạng thái là ước lượng từ biến thiên giữa các mẫu (ngưỡng 0,35 và 1,8 m/s²); nghiêng máy cũng có thể làm thay đổi. Không dùng để suy ra tốc độ, quãng đường hoặc kết quả chấm công.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Dữ liệu chỉ giữ trong phiên đo, không lưu tệp hoặc gửi máy chủ. Rời màn hình hoặc đưa app xuống nền sẽ dừng cảm biến; Bắt đầu sẽ mở phiên đo mới.',
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
