import 'package:flutter/material.dart';

import 'floral_background.dart';

class LilySplash extends StatelessWidget {
  const LilySplash({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: FloralBackground(
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.96 + (value * 0.04),
                  child: child,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloralCornerDecoration(
                    size: 96,
                    opacity: colors.brightness == Brightness.dark ? 0.16 : 0.22,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Couple App',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'un espacio cálido para cuidarse',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
