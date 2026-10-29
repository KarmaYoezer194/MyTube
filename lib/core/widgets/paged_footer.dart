import 'package:flutter/material.dart';

import '../../data/repositories/paged_videos.dart';
import '../theme/app_colors.dart';

/// The bottom of a list that loads page by page: a spinner while the next
/// page loads, or a message with Retry if it failed.
class PagedFooter extends StatelessWidget {
  const PagedFooter({super.key, required this.page, required this.onRetry});

  final PagedVideos page;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (page.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          children: [
            Text(
              "Couldn't load more videos.",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (page.isLoading && page.items.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

/// Calls [onNearEnd] when a scroll view gets within [threshold] pixels of
/// its end, so the next page starts loading before you reach the bottom.
bool loadMoreWhenNearEnd(
  ScrollNotification notification,
  VoidCallback onNearEnd, {
  double threshold = 600,
}) {
  if (notification.metrics.axis == Axis.vertical &&
      notification.metrics.extentAfter < threshold) {
    onNearEnd();
  }
  return false;
}
