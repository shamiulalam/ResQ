import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable theme-adaptive screen background.
///
/// In **Dark** mode it shows the near-black fill + faint paw-print watermark.
/// In **Light** mode it shows the warm cream fill with a subtler watermark.
///
/// Usage — wrap the whole `Scaffold` in your screen's `build()`:
///
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return AppBackground(
///     child: Scaffold(
///       backgroundColor: Colors.transparent,
///       appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
///       body: SafeArea(child: ...),
///     ),
///   );
/// }
/// ```
///
/// All params are optional — `AppBackground(child: ...)` reproduces the
/// correct appearance for whichever theme is active.
class AppBackground extends StatelessWidget {
  final Widget child;

  /// Override the background fill. Defaults to the current theme's
  /// `scaffoldBackgroundColor` (automatically adapts to Light / Dark).
  final Color? backgroundColor;

  /// Set false to get a flat fill with no watermark icon.
  final bool showWatermark;

  /// 0.0–1.0. Defaults to 0.05 in Dark theme, 0.04 in Light theme.
  final double? watermarkOpacity;

  /// Which icon to use for the watermark. Defaults to a paw print.
  final IconData watermarkIcon;

  const AppBackground({
    super.key,
    required this.child,
    this.backgroundColor,
    this.showWatermark = true,
    this.watermarkOpacity,
    this.watermarkIcon = Icons.pets,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = backgroundColor ?? ext.scaffoldBackground;
    final wmOpacity = watermarkOpacity ?? (isDark ? 0.05 : 0.04);
    final wmColor = ext.watermarkColor;

    return Container(
      color: bgColor,
      child: Stack(
        children: [
          if (showWatermark)
            Positioned.fill(
              child: _Watermark(
                opacity: wmOpacity,
                icon: watermarkIcon,
                color: wmColor,
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Purely decorative — sits behind everything, ignores touches.
class _Watermark extends StatelessWidget {
  final double opacity;
  final IconData icon;
  final Color color;

  const _Watermark({
    required this.opacity,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 90),
            child: Icon(icon, size: 220, color: color),
          ),
        ),
      ),
    );
  }
}
