import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class SettingsPreview extends StatelessWidget {
  const SettingsPreview({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SettingsSection(
      title: 'Xem trước giao diện',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TriWork · Ngày làm việc của bạn',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: 10),
          const Text('Đây là cỡ chữ và màu sắc đang áp dụng trong ứng dụng.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Chip(
                avatar: Icon(
                  Icons.palette_outlined,
                  color: scheme.onPrimaryContainer,
                ),
                backgroundColor: scheme.primaryContainer,
                label: const Text('Màu chủ đạo'),
              ),
              const Chip(label: Text('TriWork')),
            ],
          ),
        ],
      ),
    );
  }
}
