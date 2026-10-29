import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/text_styles.dart';
import '../utils/durations.dart';

/// The small "9:57" label in the corner of a thumbnail.
class DurationBadge extends StatelessWidget {
  const DurationBadge({super.key, required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.durationBadge,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(formatDuration(duration), style: AppTextStyles.durationBadge),
    );
  }
}
