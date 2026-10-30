import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/share_video.dart';
import '../../../data/models/video.dart';
import '../../../data/repositories/user_repository.dart';
import '../../auth/require_account.dart';
import '../../playlists/save_to_playlist_sheet.dart';
import '../home_providers.dart';

/// An extra row at the top of a video's ⋮ menu, e.g. "Remove from watch
/// history" on the History page. [onTap] runs after the menu closes.
class VideoMenuAction {
  const VideoMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// The ⋮ menu of a video: [extraActions], Save to Watch later, Save to
/// playlist, Share, Not interested, Don't recommend channel.
///
/// Hidden videos and channels stay out of Home, Explore, search and Up
/// next (saved in this browser; Settings can bring them back).
Future<void> showVideoOptionsSheet(
  BuildContext context,
  WidgetRef ref,
  Video video, {
  List<VideoMenuAction> extraActions = const [],
}) {
  // Grab these now: after "Not interested" the card disappears, and a
  // removed widget can't use `ref` or `context` any more.
  final messenger = ScaffoldMessenger.of(context);
  final notInterested = ref.read(notInterestedProvider.notifier);
  final hiddenChannels = ref.read(hiddenChannelsProvider.notifier);
  final repository = ref.read(userRepositoryProvider);

  void showMessage(String text, {SnackBarAction? action}) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), action: action, persist: false),
      );
  }

  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in extraActions)
            ListTile(
              leading: Icon(action.icon),
              title: Text(action.label),
              onTap: () {
                Navigator.pop(sheetContext);
                action.onTap();
              },
            ),
          // Consumer: lets this one row read whether the video is saved.
          // (Its own names rowContext/rowRef: the check below must use the
          // video card's `context`/`ref`, because this menu closes first.)
          Consumer(
            builder: (rowContext, rowRef, child) {
              final saved =
                  rowRef.watch(isInWatchLaterProvider(video.id)).value ?? false;
              return ListTile(
                leading: Icon(Symbols.schedule, fill: saved ? 1 : 0),
                title: Text(
                  saved ? 'Remove from Watch later' : 'Save to Watch later',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  // Guests get the "Sign in to …" sheet instead.
                  if (!checkSignedIn(context, ref, reason: SignInReason.save)) {
                    return;
                  }
                  repository
                      .setWatchLater(video.id, saved: !saved)
                      .then(
                        (_) => showMessage(
                          saved
                              ? 'Removed from Watch later'
                              : 'Saved to Watch later',
                        ),
                      )
                      .catchError(
                        (Object _) => showMessage(
                          "Couldn't save. Check your internet connection.",
                        ),
                      );
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Symbols.playlist_add),
            title: const Text('Save to playlist'),
            onTap: () {
              Navigator.pop(sheetContext);
              if (context.mounted) showSaveToPlaylistSheet(context, ref, video);
            },
          ),
          ListTile(
            leading: const Icon(Symbols.share),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(sheetContext);
              shareVideo(messenger, video);
            },
          ),
          ListTile(
            leading: const Icon(Symbols.block),
            title: const Text('Not interested'),
            onTap: () {
              Navigator.pop(sheetContext);
              notInterested.hide(video.id);
              showMessage(
                'Video removed',
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () => notInterested.undo(video.id),
                ),
              );
            },
          ),
          // Sample channels and other people's channels (not my own).
          if (video.channelId.isNotEmpty &&
              video.uploaderUid != ref.read(currentUidProvider))
            ListTile(
              leading: const Icon(Symbols.do_not_disturb_on),
              title: const Text("Don't recommend channel"),
              onTap: () {
                Navigator.pop(sheetContext);
                hiddenChannels.hide(video.channelId);
                showMessage(
                  "We won't recommend ${video.channelName} to you again",
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => hiddenChannels.undo(video.channelId),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
