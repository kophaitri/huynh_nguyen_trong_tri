import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextResultCard extends StatelessWidget {
  const TextResultCard({super.key, required this.title, required this.text});
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Sao chép',
                icon: const Icon(Icons.copy_outlined),
                onPressed: text.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép nội dung.'),
                            ),
                          );
                        }
                      },
              ),
            ],
          ),
          const Divider(),
          SelectableText(text.isEmpty ? 'Chưa có nội dung.' : text),
        ],
      ),
    ),
  );
}
