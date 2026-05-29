import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/branding.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 96, this.showHeart = true, super.key});

  final double size;
  final bool showHeart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '${AppBranding.displayName} brand mark',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _BrandMarkPainter(
            primary: colors.primary,
            secondary: colors.secondary,
            surface: colors.surface,
            showHeart: showHeart,
          ),
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.showHeart,
  });

  final Color primary;
  final Color secondary;
  final Color surface;
  final bool showHeart;

  @override
  void paint(Canvas canvas, Size size) {
    final badge = Paint()
      ..color = surface
      ..style = PaintingStyle.fill;
    final badgeStroke = Paint()
      ..color = primary.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width * 0.45, badge);
    canvas.drawCircle(center, size.width * 0.45, badgeStroke);

    final toothPaint = Paint()
      ..color = primary.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final tooth = Path()
      ..moveTo(size.width * 0.36, size.height * 0.27)
      ..cubicTo(
        size.width * 0.27,
        size.height * 0.33,
        size.width * 0.30,
        size.height * 0.58,
        size.width * 0.38,
        size.height * 0.72,
      )
      ..cubicTo(
        size.width * 0.44,
        size.height * 0.81,
        size.width * 0.47,
        size.height * 0.62,
        size.width * 0.50,
        size.height * 0.62,
      )
      ..cubicTo(
        size.width * 0.53,
        size.height * 0.62,
        size.width * 0.56,
        size.height * 0.81,
        size.width * 0.62,
        size.height * 0.72,
      )
      ..cubicTo(
        size.width * 0.70,
        size.height * 0.58,
        size.width * 0.73,
        size.height * 0.33,
        size.width * 0.64,
        size.height * 0.27,
      )
      ..cubicTo(
        size.width * 0.57,
        size.height * 0.22,
        size.width * 0.54,
        size.height * 0.31,
        size.width * 0.50,
        size.height * 0.31,
      )
      ..cubicTo(
        size.width * 0.46,
        size.height * 0.31,
        size.width * 0.43,
        size.height * 0.22,
        size.width * 0.36,
        size.height * 0.27,
      )
      ..close();
    canvas.drawPath(tooth, toothPaint);

    final petalPaint = Paint()
      ..color = secondary.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    for (final angle in const [-0.7, -0.25, 0.2]) {
      canvas.save();
      canvas.translate(size.width * 0.70, size.height * 0.28);
      canvas.rotate(angle);
      final petal = Path()
        ..moveTo(0, 0)
        ..cubicTo(
          size.width * 0.04,
          -size.height * 0.12,
          size.width * 0.18,
          -size.height * 0.12,
          size.width * 0.19,
          0,
        )
        ..cubicTo(
          size.width * 0.13,
          size.height * 0.06,
          size.width * 0.04,
          size.height * 0.05,
          0,
          0,
        );
      canvas.drawPath(petal, petalPaint);
      canvas.restore();
    }

    if (!showHeart) return;
    final heartPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.favorite.codePoint),
        style: TextStyle(
          fontFamily: Icons.favorite.fontFamily,
          fontSize: size.width * 0.18,
          color: AppBranding.melonPink.withValues(alpha: 0.78),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    heartPainter.paint(
      canvas,
      center + Offset(-heartPainter.width / 2, size.height * 0.02),
    );

    final sparkle = Paint()
      ..color = primary.withValues(alpha: 0.28)
      ..strokeWidth = size.width * 0.015
      ..strokeCap = StrokeCap.round;
    for (final angle in const [0.0, math.pi / 2]) {
      canvas.save();
      canvas.translate(size.width * 0.27, size.height * 0.30);
      canvas.rotate(angle);
      canvas.drawLine(
        Offset(-size.width * 0.035, 0),
        Offset(size.width * 0.035, 0),
        sparkle,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.surface != surface ||
        oldDelegate.showHeart != showHeart;
  }
}
