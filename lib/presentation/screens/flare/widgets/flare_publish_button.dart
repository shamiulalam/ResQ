import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Centered publish button — vibrant gradient, stadium shape, no animation.
class FlarePublishButton extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback? onPressed;

  const FlarePublishButton({
    super.key,
    required this.isSubmitting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Center(
      child: GestureDetector(
        onTap: isSubmitting ? null : onPressed,
        child: Container(
          width: 180,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFFF8A3D), Color(0xFFFFC06A)],
            ),
            boxShadow: [
              BoxShadow(
                color: ext.accentOrange.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            isSubmitting ? 'POSTING...' : 'POST FLARE',
            style: const TextStyle(
              color: Color(0xFF1E1E1E),
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
