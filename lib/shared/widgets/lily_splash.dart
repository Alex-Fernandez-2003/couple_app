import 'package:flutter/material.dart';

import '../../config/branding.dart';
import 'brand_mark.dart';
import 'floral_background.dart';

class LilySplash extends StatelessWidget {
  const LilySplash({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: FloralBackground(
        child: Container(
          color: colors.brightness == Brightness.dark
              ? Theme.of(context).scaffoldBackgroundColor
              : AppBranding.splashBackground,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppBranding.splashFadeDuration,
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
                  const BrandMark(size: 104),
                  const SizedBox(height: 18),
                  Text(
                    AppBranding.displayName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppBranding.tagline,
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
