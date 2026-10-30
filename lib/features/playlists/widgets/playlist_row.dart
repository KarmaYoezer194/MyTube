import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/network_thumbnail.dart';
import '../../../data/models/playlist.dart';
import '../../../data/models/video.dart';
import '../../../data/repositories/video_repository.dart';

/// A playlist in a list (e.g. a channel's Playlists tab): thumbnail with a
/// dark strip showing the number of videos, the title and "Public · N
/// videos".
class PlaylistRow extends ConsumerWidget {
  const PlaylistRow({super.key, required this.playlist, required this.onTap});

  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final videos = ref.watch(allVideosProvider).value ?? const <Video>[];
    final byId = {for (final video in videos) video.id: video};
    final first = [for (final id in playlist.videoIds) ?byId[id]].firstOrNull;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 160,
                height: 90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (first != null)
                      NetworkThumbnail(url: first.thumbnailUrl)
                    else
                      ColoredBox(color: colors.surface),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 56,
                        color: Colors.black54,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${playlist.videoIds.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Icon(
                              Symbols.playlist_play,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
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
                    playlist.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.videoTitle.copyWith(
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playlistSubtitle(
                      isPrivate: playlist.isPrivate,
                      count: playlist.videoIds.length,
                    ),
                    style: AppTextStyles.meta.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  Text(
                    'View full playlist',
                    style: AppTextStyles.meta.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
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
