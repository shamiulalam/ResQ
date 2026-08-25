import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Shared box decoration for flare form fields and cards.
BoxDecoration flareFieldBox(
    {required ResQThemeExtension ext, Color? borderColor}) {
  return BoxDecoration(
    color: ext.fieldFill,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: borderColor ?? ext.fieldBorder),
  );
}

/// Ambient background glow orb used on the Create Flare screen.
Widget flareBlurGlow(Color color) {
  return Container(
    width: 220,
    height: 220,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [
        BoxShadow(
          color: color,
          blurRadius: 90,
          spreadRadius: 28,
        ),
      ],
    ),
  );
}
