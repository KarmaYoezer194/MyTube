import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repositories/playlist_repository.dart';

/// What the playlist dialog returns.
typedef PlaylistDetails = ({String title, String visibility});

/// "New playlist" / "Edit playlist": a title and Private / Public.
/// Returns null if cancelled.
Future<PlaylistDetails?> showPlaylistDetailsDialog(
  BuildContext context, {
  bool isNew = true,
  String title = '',
  String visibility = 'private',
}) {
  return showDialog<PlaylistDetails>(
    context: context,
    builder: (_) => _PlaylistDetailsDialog(
      isNew: isNew,
      title: title,
      visibility: visibility,
    ),
  );
}

class _PlaylistDetailsDialog extends StatefulWidget {
  const _PlaylistDetailsDialog({
    required this.isNew,
    required this.title,
    required this.visibility,
  });

  final bool isNew;
  final String title;
  final String visibility;

  @override
  State<_PlaylistDetailsDialog> createState() => _PlaylistDetailsDialogState();
}

class _PlaylistDetailsDialogState extends State<_PlaylistDetailsDialog> {
  late final _title = TextEditingController(text: widget.title);
  late String _visibility = widget.visibility;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _done() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop<PlaylistDetails>(context, (
      title: title,
      visibility: _visibility,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'New playlist' : 'Edit playlist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: 150,
            decoration: const InputDecoration(labelText: 'Title'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _done(),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'private',
                label: Text('Private'),
                icon: Icon(Symbols.lock),
              ),
              ButtonSegment(
                value: 'public',
                label: Text('Public'),
                icon: Icon(Symbols.public),
              ),
            ],
            selected: {_visibility},
            onSelectionChanged: (value) =>
                setState(() => _visibility = value.first),
          ),
          const SizedBox(height: 8),
          Text(
            _visibility == 'public'
                ? 'Anyone can see it on your channel.'
                : 'Only you can see it.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _title.text.trim().isEmpty ? null : _done,
          child: Text(widget.isNew ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}

/// Asks for a title and makes a new playlist (with [firstVideoId] in it,
/// if given). Returns the new playlist's id, or null.
Future<String?> createPlaylistFlow(
  BuildContext context,
  WidgetRef ref, {
  String? firstVideoId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(playlistRepositoryProvider);
  final details = await showPlaylistDetailsDialog(context);
  if (details == null) return null;
  try {
    final id = await repository
        .create(
          title: details.title,
          visibility: details.visibility,
          firstVideoId: firstVideoId,
        )
        .timeout(const Duration(seconds: 15));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          firstVideoId == null
              ? 'Playlist created'
              : 'Saved to ${details.title}',
        ),
      ),
    );
    return id;
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Couldn't create the playlist. Check your connection."),
      ),
    );
    return null;
  }
}
