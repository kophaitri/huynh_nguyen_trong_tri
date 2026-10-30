import 'package:flutter/material.dart';

import '../models/attendance_model.dart';

class AttendanceStepCard extends StatelessWidget {
  const AttendanceStepCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.buttonLabel,
    required this.onPressed,
  });
  final String title;
  final String description;
  final IconData icon;
  final String buttonLabel;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(description),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    ),
  );
}

class AttendanceReceiptCard extends StatelessWidget {
  const AttendanceReceiptCard({super.key, required this.record, this.location});
  final AttendanceRecord record;
  final String? location;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(record.label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text('Thời gian: ${record.time.toLocal()}'),
          if (record.location != null || location != null)
            Text('Địa điểm: ${record.location ?? location}'),
          Text('Khoảng cách tới điểm: ${record.distance.toStringAsFixed(0)} m'),
          if (record.isLate)
            Text(
              'Đi trễ',
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
            ),
          if (record.isEarlyLeave)
            Text(
              'Về sớm',
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
            ),
          if (record.flags.isNotEmpty)
            const Text('Máy chủ có ghi nhận cảnh báo cho lần chấm công này.'),
        ],
      ),
    ),
  );
}
