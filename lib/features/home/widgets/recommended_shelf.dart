import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/duration_badge.dart';
import '../../../core/widgets/network_thumbnail.dart';
import '../../../data/models/video.dart';
import '../../mini_player/player_panel_provider.dart';

/// "Recommended for you" on Home: a row of videos picked from my history,
/// subscriptions and popular videos (see discovery/recommendations.dart).
class RecommendedShelf extends ConsumerWidget {
  const RecommendedShelf({super.key, required this.videos});

  final List<Video> videos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Icon(Symbols.auto_awesome, size: 20, color: colors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  'Recommended for you',
                  style: AppTextStyles.sectionHeader.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            // 16:9 picture (124 px) + 2 title lines + channel line, with
            // room to spare for bigger text settings.
            height: 204,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: videos.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final video = videos[index];
                return _Card(
                  key: ValueKey(video.id),
                  video: video,
                  onTap: () =>
                      ref.read(playerPanelProvider.notifier).open(video.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.video, required this.onTap});

  final Video video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkThumbnail(url: video.thumbnailUrl),
                    if (video.durationSeconds > 0)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: DurationBadge(duration: video.duration),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.videoTitle.copyWith(
                fontSize: 13,
                color: colors.textPrimary,
              ),
            ),
            // Takes what's left, so the card can never overflow.
            Flexible(
              child: Text(
                video.channelName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.meta.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
