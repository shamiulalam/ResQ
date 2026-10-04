import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Small dot-row indicator shown at the bottom of the Welcome screen
/// (matches the "....." dots under the illustration in the mockup).
class PageIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;

  const PageIndicator({
    super.key,
    this.count = 5,
    this.activeIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final bool isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.pageIndicatorActive
                : AppColors.pageIndicatorInactive,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
