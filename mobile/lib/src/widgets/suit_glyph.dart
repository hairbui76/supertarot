import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The five deck symbols, drawn as vector paths.
///
/// Material's icon set has no sword, chalice or pentacle, and substituting
/// element icons (fire, water drop, wind) names the correspondence rather than
/// the suit. These are drawn on a 24x24 grid with heavy strokes so they sit
/// beside the rest of the neubrutalist UI.
enum SuitSymbol { majorArcana, wand, cup, sword, pentacle }

class SuitGlyph extends StatelessWidget {
  const SuitGlyph(
    this.symbol, {
    super.key,
    this.size = 24,
    this.color,
  });

  final SuitSymbol symbol;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SuitPainter(
          symbol: symbol,
          color: color ?? IconTheme.of(context).color ?? Colors.black,
        ),
      ),
    );
  }
}

class _SuitPainter extends CustomPainter {
  const _SuitPainter({required this.symbol, required this.color});

  final SuitSymbol symbol;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Everything below is authored on a 24x24 grid.
    final double k = size.width / 24;
    canvas.save();
    canvas.scale(k, k);

    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (symbol) {
      case SuitSymbol.majorArcana:
        _sparkle(canvas, fill);
      case SuitSymbol.wand:
        _wand(canvas, stroke, fill);
      case SuitSymbol.cup:
        _cup(canvas, stroke);
      case SuitSymbol.sword:
        _sword(canvas, stroke, fill);
      case SuitSymbol.pentacle:
        _pentacle(canvas, stroke, fill);
    }

    canvas.restore();
  }

  /// Four-point star: the Major Arcana is the only suit without a physical
  /// object, so it gets the "special" mark.
  void _sparkle(Canvas canvas, Paint fill) {
    final Path path = Path()
      ..moveTo(12, 1.5)
      ..cubicTo(13.2, 8.4, 15.6, 10.8, 22.5, 12)
      ..cubicTo(15.6, 13.2, 13.2, 15.6, 12, 22.5)
      ..cubicTo(10.8, 15.6, 8.4, 13.2, 1.5, 12)
      ..cubicTo(8.4, 10.8, 10.8, 8.4, 12, 1.5)
      ..close();
    canvas.drawPath(path, fill);
  }

  /// A living staff: shaft, budding knob, one sprouting leaf.
  void _wand(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawLine(const Offset(4.5, 19.5), const Offset(16, 8), stroke);
    canvas.drawCircle(const Offset(18.2, 5.8), 2.6, fill);
    final Path leaf = Path()
      ..moveTo(10.5, 13.5)
      ..quadraticBezierTo(7.5, 11.5, 6.5, 13.8)
      ..quadraticBezierTo(8.8, 15.2, 10.5, 13.5)
      ..close();
    canvas.drawPath(leaf, fill);
  }

  /// A chalice: bowl, stem, foot.
  void _cup(Canvas canvas, Paint stroke) {
    final Path bowl = Path()
      ..moveTo(5, 5.5)
      ..lineTo(19, 5.5)
      ..cubicTo(19, 11.5, 16, 15, 12, 15)
      ..cubicTo(8, 15, 5, 11.5, 5, 5.5)
      ..close();
    canvas.drawPath(bowl, stroke);
    canvas.drawLine(const Offset(12, 15), const Offset(12, 19), stroke);
    canvas.drawLine(const Offset(8, 19.5), const Offset(16, 19.5), stroke);
  }

  /// A blade point-up, with crossguard, grip and pommel.
  void _sword(Canvas canvas, Paint stroke, Paint fill) {
    final Path blade = Path()
      ..moveTo(12, 1.6)
      ..lineTo(14.6, 6.5)
      ..lineTo(14.6, 14)
      ..lineTo(9.4, 14)
      ..lineTo(9.4, 6.5)
      ..close();
    canvas.drawPath(blade, stroke);
    canvas.drawLine(const Offset(6.5, 14.8), const Offset(17.5, 14.8), stroke);
    canvas.drawLine(const Offset(12, 15.6), const Offset(12, 19.6), stroke);
    canvas.drawCircle(const Offset(12, 20.8), 1.5, fill);
  }

  /// A coin carrying a pentagram — the suit's namesake.
  void _pentacle(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawCircle(const Offset(12, 12), 9.2, stroke);

    const double radius = 5.6;
    final List<Offset> points = <Offset>[
      for (int i = 0; i < 5; i++)
        Offset(
          12 + radius * math.cos(-math.pi / 2 + i * 2 * math.pi / 5),
          12 + radius * math.sin(-math.pi / 2 + i * 2 * math.pi / 5),
        ),
    ];

    // Step by two to draw the pentagram in one continuous stroke.
    final Path star = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i <= 5; i++) {
      final Offset point = points[(i * 2) % 5];
      star.lineTo(point.dx, point.dy);
    }
    star.close();

    canvas.drawPath(
      star,
      Paint()
        ..color = fill.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SuitPainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.color != color;
}
