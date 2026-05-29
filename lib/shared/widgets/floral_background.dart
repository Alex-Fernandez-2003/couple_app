import 'dart:math' as math;

import 'package:flutter/material.dart';

class FloralBackground extends StatelessWidget {
  const FloralBackground({
    required this.child,
    this.includeBottomCorner = true,
    super.key,
  });

  final Widget child;
  final bool includeBottomCorner;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    final opacity = isDark ? 0.055 : 0.09;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: -34,
          right: -26,
          child: IgnorePointer(
            child: FloralCornerDecoration(
              size: 180,
              opacity: opacity,
              color: colors.primary,
            ),
          ),
        ),
        if (includeBottomCorner)
          Positioned(
            bottom: -44,
            left: -36,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: math.pi,
                child: FloralCornerDecoration(
                  size: 160,
                  opacity: opacity * 0.75,
                  color: colors.secondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class FloralCornerDecoration extends StatelessWidget {
  const FloralCornerDecoration({
    this.size = 160,
    this.opacity = 0.08,
    this.color,
    super.key,
  });

  final double size;
  final double opacity;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final paintColor = (color ?? Theme.of(context).colorScheme.primary)
        .withValues(alpha: opacity.clamp(0.0, 0.12));
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LilyCornerPainter(paintColor)),
    );
  }
}

class PetalAccent extends StatelessWidget {
  const PetalAccent({this.size = 76, this.opacity, super.key});

  final double size;
  final double? opacity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size * 0.74,
      child: CustomPaint(
        painter: _PetalAccentPainter(
          primary: colors.primary.withValues(
            alpha: opacity ?? (isDark ? 0.16 : 0.22),
          ),
          secondary: colors.secondary.withValues(
            alpha: opacity ?? (isDark ? 0.12 : 0.18),
          ),
        ),
      ),
    );
  }
}

class FloralEmptyState extends StatelessWidget {
  const FloralEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PetalAccent(),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.16),
                  ),
                ),
                child: Icon(icon, size: 54, color: colors.primary),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: colors.onSurface.withValues(alpha: 0.72),
                ),
                textAlign: TextAlign.center,
              ),
              if (onAction != null) ...[
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add),
                  label: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ClinicAccentIcon extends StatelessWidget {
  const ClinicAccentIcon({required this.icon, this.size = 34, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.secondary.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, size: size, color: colors.primary),
    );
  }
}

class _LilyCornerPainter extends CustomPainter {
  const _LilyCornerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final center = Offset(size.width * 0.58, size.height * 0.42);
    for (final angle in const [-0.9, -0.35, 0.2, 0.75, 1.25]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final petal = Path()
        ..moveTo(0, 0)
        ..cubicTo(
          size.width * 0.06,
          -size.height * 0.22,
          size.width * 0.28,
          -size.height * 0.30,
          size.width * 0.34,
          -size.height * 0.06,
        )
        ..cubicTo(
          size.width * 0.20,
          size.height * 0.02,
          size.width * 0.08,
          size.height * 0.04,
          0,
          0,
        );
      canvas.drawPath(petal, paint);
      canvas.restore();
    }

    final stemPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.32,
        size.width * 0.7,
        size.height * 0.9,
      ),
      math.pi,
      math.pi * 0.35,
      false,
      stemPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LilyCornerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PetalAccentPainter extends CustomPainter {
  const _PetalAccentPainter({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    void petal(Offset center, double rotation, Color color, double scale) {
      final paint = Paint()..color = color;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.scale(scale);
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(10, -18, 30, -16, 34, 0)
        ..cubicTo(24, 12, 10, 12, 0, 0);
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    petal(Offset(size.width * 0.18, size.height * 0.60), -0.45, primary, 0.55);
    petal(Offset(size.width * 0.48, size.height * 0.38), 0.18, secondary, 0.48);
    petal(Offset(size.width * 0.72, size.height * 0.58), 0.62, primary, 0.42);
  }

  @override
  bool shouldRepaint(covariant _PetalAccentPainter oldDelegate) {
    return oldDelegate.primary != primary || oldDelegate.secondary != secondary;
  }
}
