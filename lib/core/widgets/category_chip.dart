import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

/// A category chip ("All", "Cars", ...). The selected chip smoothly turns
/// white with black text (dark theme) or black with white text (light).
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background =
        selected ? colors.chipSelectedBackground : colors.surface;
    final foreground =
        selected ? colors.chipSelectedForeground : colors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _duration,
        curve: Curves.easeOut,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 6),
            ],
            AnimatedDefaultTextStyle(
              duration: _duration,
              style: AppTextStyles.chip.copyWith(color: foreground),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
