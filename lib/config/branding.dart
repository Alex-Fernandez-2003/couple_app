import 'package:flutter/material.dart';

class AppBranding {
  const AppBranding._();

  static const displayName = 'Couple App';
  static const tagline = 'un espacio calido para cuidarse';

  static const melonPink = Color(0xFFFD8392);
  static const lilyPink = Color(0xFFF7C0C9);
  static const clinicCream = Color(0xFFFFF7F2);
  static const warmSurface = Color(0xFFFFFBF8);
  static const softLavender = Color(0xFFE8DDF8);
  static const dentalMint = Color(0xFFDFF7F2);
  static const ink = Color(0xFF2D3748);

  static const splashBackground = clinicCream;
  static const splashFadeDuration = Duration(milliseconds: 420);
  static const splashHoldDuration = Duration(milliseconds: 850);

  static const cardRadius = 20.0;
  static const buttonRadius = 16.0;
  static const iconRadius = 18.0;
  static const softElevation = 4.0;

  static BoxShadow softShadow(Color color) {
    return BoxShadow(
      color: color.withValues(alpha: 0.12),
      blurRadius: 18,
      offset: const Offset(0, 8),
    );
  }
}

class BrandingAssetPaths {
  const BrandingAssetPaths._();

  static const iconForegroundPlaceholder =
      'assets/branding/icons/icon_foreground_placeholder.svg';
  static const iconBackgroundPlaceholder =
      'assets/branding/icons/icon_background_placeholder.svg';
  static const iconMonochromePlaceholder =
      'assets/branding/icons/icon_monochrome_placeholder.svg';
  static const splashLogoPlaceholder =
      'assets/branding/splash/splash_logo_placeholder.svg';
  static const lilyIllustrationPlaceholder =
      'assets/branding/illustrations/lily_placeholder.svg';
}
