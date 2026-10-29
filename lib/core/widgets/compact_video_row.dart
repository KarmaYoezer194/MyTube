import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/video.dart';
import '../../features/home/widgets/video_options_sheet.dart';
import '../../features/mini_player/player_panel_provider.dart';
import '../theme/app_colors.dart';
import '../theme/text_styles.dart';
import '../utils/format_views.dart';
import '../utils/time_ago.dart';
import 'duration_badge.dart';
import 'network_thumbnail.dart';
import 'skeleton.dart';

/// A small video row: 160x90 thumbnail on the left, title + channel +
/// "views · time" on the right, and a ⋮ menu. Used for search results and
/// (in Phase 10) the history list.
///
/// Tapping a video opens the player; tapping a Short opens the Shorts tab.
class CompactVideoRow extends ConsumerWidget {
  const CompactVideoRow({super.key, required this.video, this.progress});

  final Video video;

  /// 0..1: how much you watched. Shows a red bar under the thumbnail.
  final double? progress;

  static const double thumbWidth = 160;
  static const double thumbHeight = 90;

  void _open(BuildContext context, WidgetRef ref) {
    if (video.isShort) {
      context.go('/shorts?v=${video.id}');
    } else {
      ref.read(playerPanelProvider.notifier).open(video.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final meta = AppTextStyles.meta.copyWith(color: colors.textSecondary);

    return InkWell(
      onTap: () => _open(context, ref),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: thumbWidth,
                height: thumbHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkThumbnail(url: video.thumbnailUrl),
                    Positioned(
                      right: 4,
                      bottom: progress == null ? 4 : 7,
                      child: video.isShort
                          ? const _ShortsBadge()
                          : (video.durationSeconds > 0
                                ? DurationBadge(duration: video.duration)
                                : const SizedBox.shrink()),
                    ),
                    if (progress != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 3,
                        child: LinearProgressIndicator(
                          value: progress!.clamp(0.0, 1.0),
                          backgroundColor: Colors.white38,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.videoTitle.copyWith(
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.channelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: meta,
                  ),
                  Text(
                    '${formatViews(video.views)} · ${timeAgo(video.createdAt)}'
                    '${video.isUnlisted ? ' · Unlisted' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: meta,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'More actions',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Symbols.more_vert, size: 20),
              onPressed: () => showVideoOptionsSheet(context, ref, video),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortsBadge extends StatelessWidget {
  const _ShortsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.durationBadge,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.smart_display, fill: 1, size: 12, color: Colors.white),
          SizedBox(width: 2),
          Text('Shorts', style: AppTextStyles.durationBadge),
        ],
      ),
    );
  }
}

/// Grey shimmering shape of a [CompactVideoRow].
class CompactVideoRowSkeleton extends StatelessWidget {
  const CompactVideoRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(
              width: CompactVideoRow.thumbWidth,
              height: CompactVideoRow.thumbHeight,
              radius: 8,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: double.infinity, height: 14),
                  SizedBox(height: 6),
                  SkeletonBox(width: 120, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 90, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
