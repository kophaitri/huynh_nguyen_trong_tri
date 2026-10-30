import 'package:flutter/material.dart';

class QrScanOverlay extends StatelessWidget {
  const QrScanOverlay({super.key, required this.window});
  final Rect window;
  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: _ScanPainter(window)));
}

class _ScanPainter extends CustomPainter {
  const _ScanPainter(this.window);
  final Rect window;
  @override
  void paint(Canvas canvas, Size size) {
    final cutout = RRect.fromRectAndRadius(window, const Radius.circular(20));
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(cutout);
    canvas.drawPath(mask, Paint()..color = const Color(0x9909182D));
    canvas.drawRRect(
      cutout,
      Paint()
        ..color = const Color(0xFF87E7C2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawLine(
      Offset(window.left + 12, window.center.dy),
      Offset(window.right - 12, window.center.dy),
      Paint()
        ..color = const Color(0x6687E7C2)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_ScanPainter oldDelegate) => oldDelegate.window != window;
}
