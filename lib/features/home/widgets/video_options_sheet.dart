import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/share_video.dart';
import '../../../data/models/video.dart';
import '../../../data/repositories/user_repository.dart';
import '../home_providers.dart';

/// The ⋮ menu of a video card: Save to Watch later, Share, Not interested.
Future<void> showVideoOptionsSheet(
  BuildContext context,
  WidgetRef ref,
  Video video,
) {
  // Grab these now: after "Not interested" the card disappears, and a
  // removed widget can't use `ref` or `context` any more.
  final messenger = ScaffoldMessenger.of(context);
  final notInterested = ref.read(notInterestedProvider.notifier);
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
          // Consumer: lets this one row read whether the video is saved.
          Consumer(
            builder: (context, ref, _) {
              final saved =
                  ref.watch(isInWatchLaterProvider(video.id)).value ?? false;
              return ListTile(
                leading: Icon(Symbols.schedule, fill: saved ? 1 : 0),
                title: Text(
                  saved ? 'Remove from Watch later' : 'Save to Watch later',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  repository
                      .setWatchLater(video.id, saved: !saved)
                      .then((_) => showMessage(saved
                          ? 'Removed from Watch later'
                          : 'Saved to Watch later'))
                      .catchError((Object _) => showMessage(
                          "Couldn't save. Check your internet connection."));
                },
              );
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
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
