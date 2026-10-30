import 'package:flutter/material.dart';

import '../models/leave_request_model.dart';

class TriSearchBar extends StatelessWidget {
  const TriSearchBar({
    super.key,
    required this.onChanged,
    this.hint = 'Tìm kiếm',
  });
  final ValueChanged<String> onChanged;
  final String hint;
  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final LeaveStatus status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      LeaveStatus.pending => Theme.of(context).colorScheme.tertiary,
      LeaveStatus.approved => Theme.of(context).colorScheme.primary,
      LeaveStatus.rejected => Theme.of(context).colorScheme.error,
    };
    return Chip(
      label: Text(status.label, style: TextStyle(color: color)),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide.none,
    );
  }
}

class CrudEmptyState extends StatelessWidget {
  const CrudEmptyState({super.key, this.message = 'Chưa có dữ liệu.'});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class CrudErrorState extends StatelessWidget {
  const CrudErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_rounded, size: 40),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại'),
        ),
      ],
    ),
  );
}

Future<bool> confirmCrudAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Xác nhận',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

class CrudTextField extends StatelessWidget {
  const CrudTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.hint,
  });
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? hint;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
}
