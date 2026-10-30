import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/widgets/compact_video_row.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/repositories/video_repository.dart';
import '../upload/create_sheet.dart';
import 'you_providers.dart';

/// "Your videos": everything I uploaded, including unlisted videos.
/// (History has its own page; Liked videos and Watch later open as
/// playlists.)
class YourVideosScreen extends ConsumerWidget {
  const YourVideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(myVideosProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/you'),
          icon: const Icon(Symbols.arrow_back),
        ),
        title: const Text('Your videos'),
      ),
      body: items.when(
        loading: () => ListView.builder(
          itemCount: 6,
          itemBuilder: (context, index) => const CompactVideoRowSkeleton(),
        ),
        error: (error, stackTrace) => EmptyState(
          icon: Symbols.cloud_off,
          title: "Couldn't load your videos",
          message: 'Check your internet connection and try again.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(allVideosProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Symbols.video_library,
              title: 'No videos yet',
              message:
                  'Videos you upload will show up here, including unlisted '
                  'ones.',
              actionLabel: 'Upload a video',
              onAction: () => showCreateSheet(context, ref),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: list.length,
            itemBuilder: (context, index) => CompactVideoRow(
              key: ValueKey(list[index].video.id),
              video: list[index].video,
            ),
          );
        },
      ),
    );
  }
}
