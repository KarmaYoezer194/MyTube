import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';

/// One number on a grey card: icon, big value, label underneath.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.meta.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// [tiles] in a grid, 3 per row.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.05,
      children: tiles,
    );
  }
}

/// A section title inside the Studio pages.
class StudioSectionTitle extends StatelessWidget {
  const StudioSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.sectionHeader.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
