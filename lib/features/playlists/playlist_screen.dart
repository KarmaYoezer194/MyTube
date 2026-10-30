import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/compact_video_row.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/network_thumbnail.dart';
import '../../data/models/playlist.dart';
import '../../data/models/video.dart';
import '../../data/repositories/channel_repository.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_lookup.dart';
import '../home/widgets/video_options_sheet.dart';
import 'play_queue.dart';
import 'playlist_dialogs.dart';

/// A playlist page: one of mine, someone's public playlist, or the
/// built-in Liked videos ([Playlist.likedId]) / Watch later
/// ([Playlist.watchLaterId]).
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRepository = ref.read(userRepositoryProvider);

    // The built-in lists: always mine, private, not reorderable.
    if (Playlist.isBuiltIn(playlistId)) {
      final liked = playlistId == Playlist.likedId;
      final ids = ref.watch(
        liked ? likedVideoIdsProvider : watchLaterIdsProvider,
      );
      return _withVideos(
        ref,
        ids: ids,
        build: (videos) => _PlaylistPage(
          playlistId: playlistId,
          title: liked ? 'Liked videos' : 'Watch later',
          ownerName: ref.watch(myProfileProvider).value?.displayName ?? '',
          isPrivate: true,
          videos: videos,
          isOwner: true,
          removeLabel: liked
              ? 'Remove from Liked videos'
              : 'Remove from Watch later',
          onRemove: (video) => liked
              // Removing a liked video = taking the like back.
              ? userRepository.react(videoId: video.id, current: 1, tapped: 1)
              : userRepository.setWatchLater(video.id, saved: false),
        ),
      );
    }

    final playlistAsync = ref.watch(playlistProvider(playlistId));
    final playlist = playlistAsync.value;
    if (playlistAsync.hasError ||
        (playlistAsync.hasValue && playlist == null)) {
      // Deleted, or someone else's private playlist.
      return const _Unavailable();
    }
    if (playlist == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isOwner =
        ref.watch(isSignedInProvider) &&
        playlist.ownerUid == ref.watch(currentUidProvider);
    final channel = ref.watch(channelProvider(playlist.channelId)).value;
    final repository = ref.read(playlistRepositoryProvider);

    return _withVideos(
      ref,
      ids: AsyncData(playlist.videoIds),
      build: (videos) => _PlaylistPage(
        playlistId: playlist.id,
        title: playlist.title,
        ownerName: channel?.name ?? '',
        isPrivate: playlist.isPrivate,
        videos: videos,
        isOwner: isOwner,
        canReorder: isOwner,
        removeLabel: 'Remove from ${playlist.title}',
        onRemove: (video) =>
            repository.setContains(playlist.id, video.id, contains: false),
        onReorder: (videos) =>
            repository.reorder(playlist.id, [for (final v in videos) v.id]),
        onEdit: () async {
          final details = await showPlaylistDetailsDialog(
            context,
            isNew: false,
            title: playlist.title,
            visibility: playlist.visibility,
          );
          if (details == null) return;
          await repository.updateDetails(
            playlist.id,
            title: details.title,
            visibility: details.visibility,
          );
        },
        onDelete: () => repository.delete(playlist.id),
      ),
    );
  }

  /// Turns the playlist's video ids into videos (in order; deleted videos
  /// are skipped), with loading / error pages. Videos older than the
  /// catalog are looked up by id.
  Widget _withVideos(
    WidgetRef ref, {
    required AsyncValue<List<String>> ids,
    required Widget Function(List<Video> videos) build,
  }) {
    if (ids.hasError) return const _Unavailable();
    final idList = ids.value;
    final lookup = idList == null
        ? null
        : ref.watch(videoLookupProvider(idsKeyOf(idList)));
    if (lookup != null && lookup.hasError && !lookup.hasValue) {
      return const _Unavailable();
    }
    final byId = lookup?.value;
    if (idList == null || byId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return build(videosInOrder(idList, byId));
  }
}

class _PlaylistPage extends ConsumerStatefulWidget {
  const _PlaylistPage({
    required this.playlistId,
    required this.title,
    required this.ownerName,
    required this.isPrivate,
    required this.videos,
    required this.isOwner,
    required this.removeLabel,
    required this.onRemove,
    this.canReorder = false,
    this.onReorder,
    this.onEdit,
    this.onDelete,
  });

  final String playlistId;
  final String title;
  final String ownerName;
  final bool isPrivate;
  final List<Video> videos;
  final bool isOwner;
  final bool canReorder;
  final String removeLabel;
  final Future<void> Function(Video video) onRemove;
  final Future<void> Function(List<Video> videos)? onReorder;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onDelete;

  @override
  ConsumerState<_PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends ConsumerState<_PlaylistPage> {
  /// The order after dragging, shown until the saved order comes back.
  List<Video>? _order;

  @override
  void didUpdateWidget(_PlaylistPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new order or other videos came in (not just new view counts).
    if (!listEquals(
      [for (final v in oldWidget.videos) v.id],
      [for (final v in widget.videos) v.id],
    )) {
      _order = null;
    }
  }

  List<Video> get _videos => _order ?? widget.videos;

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _play({String? startId, bool shuffle = false}) {
    final started = playPlaylist(
      ref,
      playlistId: widget.playlistId,
      title: widget.title,
      videos: _videos,
      startId: startId,
      shuffle: shuffle,
    );
    if (!started) _showMessage('There are no videos to play here.');
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final reordered = moveItem(_videos, oldIndex, newIndex);
    setState(() => _order = reordered);
    try {
      await widget.onReorder?.call(reordered);
    } catch (_) {
      if (!mounted) return;
      setState(() => _order = null);
      _showMessage("Couldn't save the new order. Check your connection.");
    }
  }

  Future<void> _remove(Video video) async {
    try {
      await widget.onRemove(video);
      _showMessage(
        widget.removeLabel.replaceFirst('Remove from', 'Removed from'),
      );
    } catch (_) {
      _showMessage("Couldn't remove it. Check your internet connection.");
    }
  }

  Future<void> _confirmDelete() async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text(
          '"${widget.title}" will be deleted for good. The videos themselves '
          'are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete != true || !mounted) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onDelete?.call();
      if (ref.read(playQueueProvider)?.playlistId == widget.playlistId) {
        ref.read(playQueueProvider.notifier).clear();
      }
      router.canPop() ? router.pop() : router.go('/you');
      messenger.showSnackBar(const SnackBar(content: Text('Playlist deleted')));
    } catch (_) {
      _showMessage("Couldn't delete it. Check your internet connection.");
    }
  }

  Future<void> _edit() async {
    try {
      await widget.onEdit?.call();
    } catch (_) {
      _showMessage("Couldn't save. Check your internet connection.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = _videos;
    final editable = widget.onEdit != null && widget.isOwner;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/you'),
          icon: const Icon(Symbols.arrow_back),
        ),
        actions: [
          if (editable)
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Symbols.more_vert),
              onSelected: (choice) =>
                  choice == 'edit' ? _edit() : _confirmDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete playlist')),
              ],
            ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        buildDefaultDragHandles: false,
        header: _Header(
          title: widget.title,
          ownerName: widget.ownerName,
          isPrivate: widget.isPrivate,
          videos: videos,
          onPlayAll: () => _play(),
          onShuffle: () => _play(shuffle: true),
        ),
        footer: videos.isEmpty
            ? const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Symbols.playlist_play,
                  title: 'No videos yet',
                  message: 'Use Save on a video to add it here.',
                ),
              )
            : null,
        itemCount: videos.length,
        onReorderItem: widget.canReorder ? _reorder : (_, _) {},
        itemBuilder: (context, index) {
          final video = videos[index];
          return Row(
            key: ValueKey(video.id),
            children: [
              if (widget.canReorder)
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Symbols.drag_indicator,
                      semanticLabel: 'Drag to reorder',
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              Expanded(
                child: CompactVideoRow(
                  video: video,
                  onTap: () => _play(startId: video.id),
                  menuActions: [
                    if (widget.isOwner)
                      VideoMenuAction(
                        icon: Symbols.delete,
                        label: widget.removeLabel,
                        onTap: () => _remove(video),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Big thumbnail, title, owner, "Private · 3 videos", Play all / Shuffle.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.ownerName,
    required this.isPrivate,
    required this.videos,
    required this.onPlayAll,
    required this.onShuffle,
  });

  final String title;
  final String ownerName;
  final bool isPrivate;
  final List<Video> videos;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final first = videos.firstOrNull;
    final canPlay = videos.any((v) => !v.isShort);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: first != null
                  ? NetworkThumbnail(url: first.thumbnailUrl)
                  : ColoredBox(
                      color: colors.surface,
                      child: Icon(
                        Symbols.playlist_play,
                        size: 48,
                        color: colors.textSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.watchTitle.copyWith(
              fontSize: 22,
              color: colors.textPrimary,
            ),
          ),
          if (ownerName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'by $ownerName',
              style: AppTextStyles.body.copyWith(color: colors.textPrimary),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            playlistSubtitle(isPrivate: isPrivate, count: videos.length),
            style: AppTextStyles.meta.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: canPlay ? onPlayAll : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.chipSelectedBackground,
                    foregroundColor: colors.chipSelectedForeground,
                  ),
                  icon: const Icon(Symbols.play_arrow, fill: 1),
                  label: const Text('Play all'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canPlay ? onShuffle : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.textPrimary,
                  ),
                  icon: const Icon(Symbols.shuffle),
                  label: const Text('Shuffle'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Deleted, or someone else's private playlist.
class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/you'),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: const EmptyState(
        icon: Symbols.playlist_remove,
        title: 'Playlist unavailable',
        message: 'It may be private, or it was deleted.',
      ),
    );
  }
}
