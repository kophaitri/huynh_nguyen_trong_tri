import 'dart:math';

import 'package:flutter/material.dart';

import '../models/motion_sample.dart';

class MotionReadingCard extends StatelessWidget {
  const MotionReadingCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double? value;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value?.toStringAsFixed(2) ?? '—',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'm/s²',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class MotionChart extends StatelessWidget {
  const MotionChart({super.key, required this.samples});
  final List<MotionSample> samples;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Biểu đồ chuyển động',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Tối đa 100 mẫu gần nhất · trục dọc m/s²'),
          const SizedBox(height: 16),
          Semantics(
            label:
                'Biểu đồ ${samples.length} mẫu gia tốc thực tế. Số liệu hiện tại được hiển thị ở các thẻ phía trên.',
            child: SizedBox(
              height: 210,
              child: samples.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có dữ liệu cảm biến. Bấm Bắt đầu để đo.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : CustomPaint(
                      painter: _MotionPainter(
                        samples,
                        Theme.of(context).colorScheme,
                      ),
                    ),
            ),
          ),
          if (samples.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(samples.first.elapsed.inMilliseconds / 1000).toStringAsFixed(1)} s',
                  ),
                  Text(
                    '${(samples.last.elapsed.inMilliseconds / 1000).toStringAsFixed(1)} s',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _ChartLegend(
                color: Theme.of(context).colorScheme.primary,
                label: 'Độ lớn |a|',
              ),
              _ChartLegend(
                color: Theme.of(context).colorScheme.tertiary,
                label: 'Biến thiên đã làm mượt',
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.show_chart, size: 18, color: color),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

class _MotionPainter extends CustomPainter {
  _MotionPainter(this.samples, this.scheme);
  final List<MotionSample> samples;
  final ColorScheme scheme;
  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 40 || size.height <= 0) return;
    final bounds = Rect.fromLTWH(38, 8, size.width - 42, size.height - 24);
    final maxValue = samples.fold<double>(
      12,
      (value, sample) =>
          max(value, max(sample.magnitude, sample.variation ?? 0)),
    );
    final ceiling = (maxValue / 5).ceil() * 5.0;
    final grid = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = bounds.bottom - bounds.height * i / 3;
      canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), grid);
      final label = TextPainter(
        text: TextSpan(
          text: (ceiling * i / 3).toStringAsFixed(0),
          style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 34);
      label.paint(canvas, Offset(0, y - label.height / 2));
    }
    final start = samples.first.elapsed.inMicroseconds;
    final span = max(1, samples.last.elapsed.inMicroseconds - start);
    canvas.save();
    canvas.clipRect(bounds.inflate(2));
    void series(double? Function(MotionSample) valueOf, Color color) {
      final path = Path();
      Offset? first;
      var count = 0;
      for (final sample in samples) {
        final value = valueOf(sample);
        if (value == null) continue;
        final point = Offset(
          bounds.left +
              bounds.width * (sample.elapsed.inMicroseconds - start) / span,
          bounds.bottom - bounds.height * value / ceiling,
        );
        if (count == 0) {
          path.moveTo(point.dx, point.dy);
          first = point;
        } else {
          path.lineTo(point.dx, point.dy);
        }
        count++;
      }
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
      if (count == 1 && first != null) {
        canvas.drawCircle(first, 3, Paint()..color = color);
      }
    }

    series((s) => s.magnitude, scheme.primary);
    series((s) => s.variation, scheme.tertiary);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MotionPainter oldDelegate) =>
      oldDelegate.samples != samples || oldDelegate.scheme != scheme;
}
