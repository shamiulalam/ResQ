import 'package:flutter/material.dart';

/// Central color palette for ResQ.
/// Pulled from the Welcome / Onboarding mockup:
/// warm cream background, primary blue CTA, coral/orange secondary CTA.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFFFBEFE2); // warm cream
  static const Color surface = Color(0xFFFFFFFF);

  // Brand
  static const Color primaryBlue = Color(0xFF3B82F6); // "Lost A Pet?" button
  static const Color primaryBlueDark = Color(0xFF2563EB);
  static const Color secondaryCoral =
      Color(0xFFF97350); // "Spotted a Stray?" button
  static const Color secondaryCoralDark = Color(0xFFE35B3A);

  // Text
  static const Color textPrimary = Color(0xFF2A2A2A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status (used later on dashboards)
  static const Color statusActive = Color(0xFF3B82F6);
  static const Color statusMatched = Color(0xFFF59E0B);
  static const Color statusResolved = Color(0xFF22C55E);

  // Utility
  static const Color divider = Color(0xFFE7DCCB);
  static const Color pageIndicatorActive = Color(0xFF2A2A2A);
  static const Color pageIndicatorInactive = Color(0xFFD9CCB8);

  // --- "Flare" creation flow (vibrant dark aesthetic) ---
  // Kept separate from the app's main light palette above. When the
  // app-wide Light/Dark theme toggle is built, this ramp becomes the
  // seed for the Dark theme; for now it's scoped to CreateFlareScreen.
  static const Color flareBackground = Color(0xFF121214);
  static const Color flareSurface = Color(0xFF232326);
  static const Color flareBorder = Color(0xFF3A3A3E);
  static const Color flareTextPrimary = Color(0xFFF5F3F0);
  static const Color flareTextSecondary = Color(0xFFA6A4A0);
  static const Color flareGradientStart = Color(0xFFFF8A3D);
  static const Color flareGradientMid = Color(0xFFE85B92);
  static const Color flareGradientEnd = Color(0xFF6C5CE7);
  static const Color flareGlow = Color(0xFFFF7A3D);
  // Blue-tinted field styling (matches the "Create Flare" preview design —
  // distinct from flareSurface/flareBorder above, used specifically for
  // form fields, the map card, and the date/time card on that screen).
  static const Color flareFieldTop = Color(0xFF1C2836);
  static const Color flareFieldBottom = Color(0xFF141D29);
  static const Color flareFieldBorder = Color(0xFF2A3B52);
  static const Color flareLabelMuted = Color(0xFF7D8BA0);

  // Create Flare screen — extended palette (extracted from inline literals)
  static const Color flareScreenBackground = Color(0xFF090F1F);
  static const Color flareGlowBlue = Color(0xFF2F6BFF);
  static const Color flareCardBackground = Color(0xFF1A2740);
  static const Color flareCardBackgroundAlt = Color(0xFF18263E);
  static const Color flareAccentOrange = Color(0xFFFFA85C);
  static const Color flareAccentOrangeLight = Color(0xFFFFA95A);
  static const Color flareProgressTrack = Color(0xFF37527C);
  static const Color flarePublishStart = Color(0xFFFFA65B);
  static const Color flarePublishEnd = Color(0xFFFF8655);
  static const Color flarePublishGlow = Color(0xFFEBB89B);
  static const Color flarePublishText = Color(0xFF1E1E1E);
  static const Color flareMapPin = Color(0xFFFF9D56);
  static const Color flareLocationOverlay = Color(0xC5111D31);
  static const Color flareHintText = Color(0xFF5F6D80);
  static const Color flareSectionTitle = Color(0xFFD9E6F8);
  static const Color flarePickerBackground = Color(0xFF0A1020);
  static const Color flarePickerAppBar = Color(0xFF1A243A);

  static const LinearGradient flareHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF9550),
      Color(0xFFE8639A),
      Color(0xFF2298FF),
    ],
  );

  static const LinearGradient flarePublishGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFF8A3D), Color(0xFFFFC06A)],
  );

  static const Color flareActionPanelBg = Color(0xFF141B2B);
  static const Color flareStepBadgeBorder = Color(0xFF3A4558);
  static const Color flareProgressSegmentInactive = Color(0xFF2A3344);
  static const Color flareSaveDraft = Color(0xFFFF9A5C);
}
