import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../data/models/playlist.dart';
import '../../data/models/video.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../auth/require_account.dart';
import 'playlist_dialogs.dart';

/// "Save video to…": a checkbox for Watch later and for each of my
/// playlists, plus "New playlist". Opened by the watch page's Save button
/// and the ⋮ menu. Guests get the "Sign in to …" sheet instead.
Future<void> showSaveToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  Video video,
) async {
  if (!checkSignedIn(context, ref, reason: SignInReason.save)) return;
  final messenger = ScaffoldMessenger.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SaveSheet(video: video, messenger: messenger),
  );
}

class _SaveSheet extends ConsumerWidget {
  const _SaveSheet({required this.video, required this.messenger});

  final Video video;

  /// Messages go to the page under the sheet (they stay after it closes).
  final ScaffoldMessengerState messenger;

  void _show(String text) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _saveError(Object _) =>
      _show("Couldn't save. Check your internet connection.");

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final inWatchLater =
        ref.watch(isInWatchLaterProvider(video.id)).value ?? false;
    final playlists = ref.watch(myPlaylistsProvider);
    final repository = ref.read(playlistRepositoryProvider);

    void toggle(Playlist playlist, bool add) {
      if (add && playlist.isFull) {
        _show('${playlist.title} is full (${Playlist.maxVideos} videos).');
        return;
      }
      repository
          .setContains(playlist.id, video.id, contains: add)
          .then(
            (_) => _show(
              add
                  ? 'Saved to ${playlist.title}'
                  : 'Removed from ${playlist.title}',
            ),
          )
          .catchError(_saveError);
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Save video to...',
                      style: AppTextStyles.sectionHeader.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Symbols.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    value: inWatchLater,
                    title: const Text('Watch later'),
                    secondary: const Icon(Symbols.lock),
                    onChanged: (value) => ref
                        .read(userRepositoryProvider)
                        .setWatchLater(video.id, saved: value ?? false)
                        .then(
                          (_) => _show(
                            (value ?? false)
                                ? 'Saved to Watch later'
                                : 'Removed from Watch later',
                          ),
                        )
                        .catchError(_saveError),
                  ),
                  ...playlists.when(
                    loading: () => const [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      ),
                    ],
                    error: (error, stackTrace) => [
                      const ListTile(
                        title: Text("Couldn't load your playlists."),
                      ),
                    ],
                    data: (list) => [
                      for (final playlist in list)
                        CheckboxListTile(
                          key: ValueKey(playlist.id),
                          controlAffinity: ListTileControlAffinity.leading,
                          value: playlist.contains(video.id),
                          title: Text(
                            playlist.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondary: Icon(
                            playlist.isPrivate ? Symbols.lock : Symbols.public,
                          ),
                          onChanged: (value) =>
                              toggle(playlist, value ?? false),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Symbols.add),
              title: const Text('New playlist'),
              onTap: () =>
                  createPlaylistFlow(context, ref, firstVideoId: video.id),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
