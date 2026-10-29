import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/widgets/empty_state.dart';
import '../../data/repositories/video_repository.dart';
import '../home/widgets/video_card.dart';
import 'watch_providers.dart';
import 'widgets/watch_details.dart';

/// Everything on the watch page UNDER the player: details and "Up next".
/// (The player itself is drawn by the player panel, so it can shrink into
/// the mini player.)
class WatchBody extends ConsumerWidget {
  const WatchBody({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoAsync = ref.watch(videoProvider(videoId));
    final video = videoAsync.value;
    final upNext = ref.watch(upNextProvider(videoId));

    if (video != null) {
      return ListView(
        // New video = start again at the top.
        key: ValueKey(videoId),
        padding: EdgeInsets.zero,
        children: [
          WatchDetails(video: video),
          for (final v in upNext) VideoCard(key: ValueKey(v.id), video: v),
        ],
      );
    }
    if (videoAsync is AsyncLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return const EmptyState(
      icon: Symbols.error,
      title: 'Video unavailable',
      message: 'This video may have been removed.',
    );
  }
}
