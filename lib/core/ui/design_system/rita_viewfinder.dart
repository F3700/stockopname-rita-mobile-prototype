import 'package:flutter/material.dart';

import 'rita_tokens.dart';

/// Corner marks viewfinder v5 (4 sudut L putih) — dipakai layar scan rak
/// dan scan QR. Mengisi parent (Stack size) dengan inset standar 16.
class RitaCornerMarks extends StatelessWidget {
  const RitaCornerMarks({
    super.key,
    this.color = Colors.white,
    this.inset = RitaSpace.md,
    this.length = 26,
    this.thickness = 4,
  });

  final Color color;
  final double inset;
  final double length;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final pos in const [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ])
          Align(
            alignment: pos,
            child: Padding(
              padding: EdgeInsets.all(inset),
              child: SizedBox(
                width: length,
                height: length,
                child: CustomPaint(
                  painter: RitaCornerPainter(
                    alignment: pos,
                    color: color,
                    thickness: thickness,
                    length: length,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Menggambar dua garis sudut (L) sesuai alignment.
class RitaCornerPainter extends CustomPainter {
  const RitaCornerPainter({
    required this.alignment,
    required this.color,
    required this.thickness,
    required this.length,
  });

  final Alignment alignment;
  final Color color;
  final double thickness;
  final double length;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    final left = alignment.x < 0;
    final top = alignment.y < 0;
    final x = left ? thickness / 2 : size.width - thickness / 2;
    final y = top ? thickness / 2 : size.height - thickness / 2;
    canvas.drawLine(
      Offset(x, y),
      Offset(left ? x + length : x - length, y),
      paint,
    );
    canvas.drawLine(
      Offset(x, y),
      Offset(x, top ? y + length : y - length),
      paint,
    );
  }

  @override
  bool shouldRepaint(RitaCornerPainter old) =>
      old.alignment != alignment || old.color != color;
}
