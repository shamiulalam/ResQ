import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// App bar header for flare creation
class FlareHeader extends StatelessWidget {
  final VoidCallback onBack;

  const FlareHeader({
    super.key,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Container(
      color: Colors.transparent, // Background handled by AppBackground
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 14),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: ext.textPrimary,
                ),
              ),
              Expanded(
                child: Text(
                  'Create New Flare',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ext.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: ext.textSecondary.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: ext.textSecondary, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
