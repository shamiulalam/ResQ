import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// A full-width rounded pill button. Used for the two big CTAs on the
/// Welcome screen ("Lost A Pet?" / "Spotted a Stray?") and reused
/// throughout the app wherever a primary/secondary action is needed.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor = AppColors.primaryBlue,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.textOnPrimary, size: 20),
              const SizedBox(width: 8),
            ],
            Text(label, style: AppTextStyles.buttonLabel),
          ],
        ),
      ),
    );
  }
}
