import 'package:flutter/material.dart';

class TriWorkLogo extends StatelessWidget {
  const TriWorkLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.more_time_rounded,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 44,
            semanticLabel: 'Biểu tượng chấm công TriWork',
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'TriWork',
          style: TextStyle(
            color: primary,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Mỗi ngày làm việc, một bước tiến.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
