import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/widgets/compact_video_row.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../upload/create_sheet.dart';
import 'you_providers.dart';

/// The 4 full lists reachable from the You tab.
enum VideoListKind { history, liked, watchLater, yourVideos }

/// "View all" screens: History, Liked videos, Watch later, Your videos.
class VideoListScreen extends ConsumerWidget {
  const VideoListScreen({super.key, required this.kind});

  final VideoListKind kind;

  String get _title => switch (kind) {
    VideoListKind.history => 'History',
    VideoListKind.liked => 'Liked videos',
    VideoListKind.watchLater => 'Watch later',
    VideoListKind.yourVideos => 'Your videos',
  };

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final clear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear watch history?'),
        content: const Text(
          'Your history and the places where you stopped watching will be '
          'deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (!(clear ?? false)) return;
    try {
      await ref.read(userRepositoryProvider).clearHistory();
      messenger.showSnackBar(
        const SnackBar(content: Text('Watch history cleared')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't clear history. Check your connection."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = switch (kind) {
      VideoListKind.history => ref.watch(historyVideosProvider),
      VideoListKind.liked => ref.watch(likedVideosProvider),
      VideoListKind.watchLater => ref.watch(watchLaterVideosProvider),
      VideoListKind.yourVideos => ref.watch(myVideosProvider),
    };
    final hasItems = items.value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/you'),
          icon: const Icon(Symbols.arrow_back),
        ),
        title: Text(_title),
        actions: [
          if (kind == VideoListKind.history && hasItems)
            IconButton(
              tooltip: 'Clear watch history',
              onPressed: () => _confirmClearHistory(context, ref),
              icon: const Icon(Symbols.delete_sweep),
            ),
        ],
      ),
      body: items.when(
        loading: () => ListView.builder(
          itemCount: 6,
          itemBuilder: (context, index) => const CompactVideoRowSkeleton(),
        ),
        error: (error, stackTrace) => EmptyState(
          icon: Symbols.cloud_off,
          title: "Couldn't load $_title",
          message: 'Check your internet connection and try again.',
          actionLabel: 'Retry',
          onAction: () {
            ref.invalidate(allVideosProvider);
            ref.invalidate(historyEntriesProvider);
            ref.invalidate(likedVideoIdsProvider);
            ref.invalidate(watchLaterIdsProvider);
          },
        ),
        data: (list) {
          if (list.isEmpty) return _empty(context, ref);
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: list.length,
            itemBuilder: (context, index) => CompactVideoRow(
              key: ValueKey(list[index].video.id),
              video: list[index].video,
              progress: list[index].progress,
            ),
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref) {
    return switch (kind) {
      VideoListKind.history => EmptyState(
        icon: Symbols.history,
        title: 'No watch history yet',
        message: 'Videos you watch will show up here.',
        actionLabel: 'Explore videos',
        onAction: () => context.go('/home'),
      ),
      VideoListKind.liked => EmptyState(
        icon: Symbols.thumb_up,
        title: 'No liked videos yet',
        message: 'Tap 👍 on a video to save it here.',
        actionLabel: 'Explore videos',
        onAction: () => context.go('/home'),
      ),
      VideoListKind.watchLater => EmptyState(
        icon: Symbols.schedule,
        title: 'Nothing saved for later',
        message: 'Tap Save on a video to watch it later.',
        actionLabel: 'Explore videos',
        onAction: () => context.go('/home'),
      ),
      VideoListKind.yourVideos => EmptyState(
        icon: Symbols.video_library,
        title: 'No videos yet',
        message:
            'Videos you upload will show up here, including unlisted '
            'ones.',
        actionLabel: 'Upload a video',
        onAction: () => showCreateSheet(context, ref),
      ),
    };
  }
}
