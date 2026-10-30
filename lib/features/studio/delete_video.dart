import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/video.dart';
import '../../data/repositories/video_repository.dart';
import '../mini_player/player_panel_provider.dart';
import 'studio_stats.dart';

/// Asks, then deletes [video] from MyTube. Returns true if it was deleted.
///
/// Only the Firestore data goes. The file in Cloudinary can't be deleted
/// from the app (that needs the API secret, which must never be in the
/// code), so the dialog shows the file names to delete by hand in
/// Cloudinary → Media Library.
Future<bool> confirmAndDeleteVideo(
  BuildContext context,
  WidgetRef ref,
  Video video,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final files = cloudinaryFilesOf(video);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(video.isShort ? 'Delete Short?' : 'Delete video?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${video.title}" will be removed from MyTube for good. Its '
              "views, likes and comments won't show anywhere any more. "
              "This can't be undone.",
            ),
            if (files.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'The file stays in your Cloudinary account. To free that '
                'space, delete it in Cloudinary → Media Library. Search for:',
              ),
              const SizedBox(height: 8),
              for (final file in files)
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        file,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Symbols.content_copy, size: 18),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: file)),
                    ),
                  ],
                ),
            ],
          ],
        ),
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
  if (confirmed != true) return false;

  // Stop playing it first.
  if (ref.read(playerPanelProvider).videoId == video.id) {
    ref.read(playerPanelProvider.notifier).close();
  }
  try {
    await ref
        .read(videoRepositoryProvider)
        .deleteVideo(video.id)
        .timeout(const Duration(seconds: 15));
    messenger.showSnackBar(
      SnackBar(
        content: Text(video.isShort ? 'Short deleted' : 'Video deleted'),
      ),
    );
    return true;
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Couldn't delete it. Check your internet connection."),
      ),
    );
    return false;
  }
}

/// The Cloudinary file names of an upload: the video, and its own
/// thumbnail picture if one was uploaded (a thumbnail made from the video
/// is not a separate file).
List<String> cloudinaryFilesOf(Video video) {
  final videoId = cloudinaryPublicId(video.videoUrl);
  final thumbnail = video.thumbnailUrl.contains('/image/upload/')
      ? cloudinaryPublicId(video.thumbnailUrl)
      : null;
  return {?videoId, ?thumbnail}.toList();
}
