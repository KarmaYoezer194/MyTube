import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/network_thumbnail.dart';
import '../../../data/models/video.dart';
import '../../../data/repositories/video_repository.dart';
import '../../mini_player/player_panel_provider.dart';
import '../play_queue.dart';

/// The playlist box on the watch page while a playlist is playing:
/// "My mix · 3 / 12", tap to see the whole list, ✕ to stop the playlist.
class PlaylistPanel extends ConsumerStatefulWidget {
  const PlaylistPanel({super.key, required this.videoId});

  final String videoId;

  @override
  ConsumerState<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends ConsumerState<PlaylistPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(playQueueProvider);
    if (queue == null || !queue.contains(widget.videoId)) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    final videos = ref.watch(allVideosProvider).value ?? const <Video>[];
    final byId = {for (final video in videos) video.id: video};
    final index = queue.indexOf(widget.videoId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            queue.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.videoTitle.copyWith(
                              fontSize: 15,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (queue.shuffled) ...[
                                Icon(
                                  Symbols.shuffle,
                                  size: 14,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                '${index + 1} / ${queue.videoIds.length}',
                                style: AppTextStyles.meta.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Symbols.keyboard_arrow_up
                          : Symbols.keyboard_arrow_down,
                      color: colors.textPrimary,
                    ),
                    IconButton(
                      tooltip: 'Close playlist',
                      onPressed: ref.read(playQueueProvider.notifier).clear,
                      icon: Icon(Symbols.close, color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: queue.videoIds.length,
                  itemBuilder: (context, i) {
                    final video = byId[queue.videoIds[i]];
                    if (video == null) return const SizedBox.shrink();
                    return _QueueRow(
                      key: ValueKey(video.id),
                      video: video,
                      number: i + 1,
                      isCurrent: i == index,
                      onTap: () => ref
                          .read(playerPanelProvider.notifier)
                          .switchTo(video.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One video in the expanded playlist panel. The playing one shows ▶.
class _QueueRow extends StatelessWidget {
  const _QueueRow({
    super.key,
    required this.video,
    required this.number,
    required this.isCurrent,
    required this.onTap,
  });

  final Video video;
  final int number;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: isCurrent ? null : onTap,
      child: Container(
        color: isCurrent ? colors.divider.withValues(alpha: 0.5) : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: isCurrent
                  ? Icon(
                      Symbols.play_arrow,
                      fill: 1,
                      size: 16,
                      color: colors.textPrimary,
                    )
                  : Text(
                      '$number',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.meta.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(width: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 96,
                height: 54,
                child: NetworkThumbnail(url: video.thumbnailUrl),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.videoTitle.copyWith(
                      fontSize: 13,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    video.channelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.meta.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
