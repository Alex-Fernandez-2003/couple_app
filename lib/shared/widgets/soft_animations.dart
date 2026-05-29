import 'dart:math' as math;

import 'package:flutter/material.dart';

bool softAnimationsEnabled(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  return mediaQuery?.disableAnimations != true &&
      mediaQuery?.accessibleNavigation != true;
}

class SoftFadeSlide extends StatelessWidget {
  const SoftFadeSlide({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 260),
    this.offset = const Offset(0, 0.04),
    super.key,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    if (!softAnimationsEnabled(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final delayFraction = delay.inMilliseconds <= 0
            ? 0.0
            : delay.inMilliseconds /
                  math.max(1, duration.inMilliseconds + delay.inMilliseconds);
        final normalized = value <= delayFraction
            ? 0.0
            : ((value - delayFraction) / (1 - delayFraction)).clamp(0.0, 1.0);

        return Opacity(
          opacity: normalized,
          child: FractionalTranslation(
            translation: Offset.lerp(offset, Offset.zero, normalized)!,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class SoftPressable extends StatefulWidget {
  const SoftPressable({
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.duration = const Duration(milliseconds: 110),
    this.borderRadius,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  final BorderRadius? borderRadius;

  @override
  State<SoftPressable> createState() => _SoftPressableState();
}

class _SoftPressableState extends State<SoftPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!softAnimationsEnabled(context)) {
      return InkWell(
        onTap: widget.onTap,
        borderRadius: widget.borderRadius,
        child: widget.child,
      );
    }

    return Listener(
      onPointerDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onPointerUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onPointerCancel: widget.onTap == null ? null : (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: widget.borderRadius,
          child: widget.child,
        ),
      ),
    );
  }
}

class AnimatedCheckIcon extends StatelessWidget {
  const AnimatedCheckIcon({
    required this.checked,
    this.checkedIcon = Icons.check_circle,
    this.uncheckedIcon = Icons.radio_button_unchecked,
    this.size = 26,
    super.key,
  });

  final bool checked;
  final IconData checkedIcon;
  final IconData uncheckedIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (!softAnimationsEnabled(context)) {
      return Icon(
        checked ? checkedIcon : uncheckedIcon,
        color: checked ? colors.primary : colors.outline,
        size: size,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.82, end: 1).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Icon(
        checked ? checkedIcon : uncheckedIcon,
        key: ValueKey(checked),
        color: checked ? colors.primary : colors.outline,
        size: size,
      ),
    );
  }
}

class SoftAnimatedCheckbox extends StatelessWidget {
  const SoftAnimatedCheckbox({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final checkbox = Checkbox(
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).colorScheme.primary,
    );

    if (!softAnimationsEnabled(context)) return checkbox;

    return AnimatedScale(
      key: ValueKey(value),
      scale: value ? 1.04 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      child: checkbox,
    );
  }
}

class CelebrationBurst extends StatelessWidget {
  const CelebrationBurst({
    required this.title,
    required this.message,
    this.actionLabel = 'Celebrar',
    super.key,
  });

  final String title;
  final String message;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final animated = softAnimationsEnabled(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: animated ? 0 : 1, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        builder: (context, value, child) => Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.94 + (0.06 * value), child: child),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 96,
                width: 150,
                child: CustomPaint(
                  painter: _CelebrationBurstPainter(
                    primary: colors.primary,
                    secondary: colors.secondary,
                    isDark: colors.brightness == Brightness.dark,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.72),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CelebrationBurstPainter extends CustomPainter {
  const _CelebrationBurstPainter({
    required this.primary,
    required this.secondary,
    required this.isDark,
  });

  final Color primary;
  final Color secondary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.58);
    final accents = [
      (const Offset(-52, -24), primary, Icons.favorite),
      (const Offset(44, -30), secondary, Icons.local_florist),
      (const Offset(-18, -46), secondary, Icons.auto_awesome),
      (const Offset(24, -10), primary, Icons.favorite_border),
    ];
    final opacity = isDark ? 0.48 : 0.62;

    for (final accent in accents) {
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(accent.$3.codePoint),
          style: TextStyle(
            fontFamily: accent.$3.fontFamily,
            package: accent.$3.fontPackage,
            fontSize: 24,
            color: accent.$2.withValues(alpha: opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, center + accent.$1);
    }

    final brush = Paint()
      ..color = primary.withValues(alpha: isDark ? 0.16 : 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final angle in [-0.8, -0.35, 0.2, 0.65]) {
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle) * 58, math.sin(angle) * 44),
        brush,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationBurstPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.isDark != isDark;
  }
}
