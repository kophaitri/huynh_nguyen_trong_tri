import 'package:flutter/material.dart';

import '../models/smart_insights_model.dart';

class InsightStatCard extends StatelessWidget {
  const InsightStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.note,
    this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final String? note;
  final Color? color;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color ?? Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(
              note!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class InsightCardGrid extends StatelessWidget {
  const InsightCardGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 820
          ? 3
          : constraints.maxWidth >= 420
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}

class PunctualityChart extends StatelessWidget {
  const PunctualityChart({super.key, required this.insights});
  final SmartInsightsModel insights;
  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16845B);
    const orange = Color(0xFFD77D26);
    const grey = Color(0xFF8292AA);
    final parts = [
      (insights.knownOnTimeCount, green, 'Đúng giờ'),
      (insights.knownLateCount, orange, 'Đi muộn'),
      (insights.unknownStatusCount, grey, 'Chưa rõ'),
    ];
    return Semantics(
      label:
          'Phân bố CheckIn: ${insights.knownOnTimeCount} đúng giờ, ${insights.knownLateCount} đi muộn, ${insights.unknownStatusCount} chưa rõ trạng thái.',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Phân bố buổi chấm công vào',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              if (insights.checkInCount > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 26,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final part in parts)
                          if (part.$1 > 0)
                            Expanded(
                              flex: part.$1,
                              child: ColoredBox(color: part.$2),
                            ),
                      ],
                    ),
                  ),
                )
              else
                const Text('Chưa đủ dữ liệu để vẽ biểu đồ.'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                children: parts
                    .map(
                      (part) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 10, color: part.$2),
                          const SizedBox(width: 6),
                          Text('${part.$3}: ${part.$1}'),
                        ],
                      ),
                    )
                    .toList(),
              ),
              if (insights.unknownTypeCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${insights.unknownTypeCount} bản ghi chưa xác định loại, không được gán vào biểu đồ.',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
