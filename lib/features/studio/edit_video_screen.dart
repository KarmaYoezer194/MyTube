import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/upload_validation.dart';
import '../../core/widgets/network_thumbnail.dart';
import '../../data/models/video.dart';
import '../../data/repositories/upload_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../upload/upload_screen.dart' show uploadCategories;

/// Opens "Edit video" over everything (like the upload screen).
Future<void> openEditVideo(BuildContext context, Video video) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => EditVideoScreen(video: video)),
  );
}

/// Studio → Edit: title, description, category, visibility and a new
/// thumbnail. (The video file itself can't be changed.)
class EditVideoScreen extends ConsumerStatefulWidget {
  const EditVideoScreen({super.key, required this.video});

  final Video video;

  @override
  ConsumerState<EditVideoScreen> createState() => _EditVideoScreenState();
}

class _EditVideoScreenState extends ConsumerState<EditVideoScreen> {
  late final _title = TextEditingController(text: widget.video.title);
  late final _description = TextEditingController(
    text: widget.video.description,
  );
  late String _category = uploadCategories.contains(widget.video.category)
      ? widget.video.category
      : 'Other';
  late String _visibility = widget.video.isUnlisted ? 'unlisted' : 'public';

  /// A new thumbnail picked on this page (uploaded when you tap Save).
  Uint8List? _thumbBytes;
  String? _thumbName;

  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _changed =>
      _title.text.trim() != widget.video.title ||
      _description.text.trim() != widget.video.description ||
      _category != widget.video.category ||
      _visibility != (widget.video.isUnlisted ? 'unlisted' : 'public') ||
      _thumbBytes != null;

  bool get _canSave => _changed && !_saving && _title.text.trim().isNotEmpty;

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickThumbnail() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final size = await file.length() ?? 0;
    if (!mounted) return;
    final problem = checkImageFile(fileName: file.name, sizeBytes: size);
    if (problem != null) {
      _showMessage(problem);
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _thumbBytes = bytes;
      _thumbName = file.name;
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      String? thumbnailUrl;
      if (_thumbBytes case final bytes?) {
        thumbnailUrl = await ref
            .read(uploadRepositoryProvider)
            .uploadImage(bytes: bytes, filename: _thumbName ?? 'thumbnail.jpg');
      }
      await ref
          .read(videoRepositoryProvider)
          .updateDetails(
            widget.video.id,
            title: _title.text.trim(),
            description: _description.text.trim(),
            category: _category,
            visibility: _visibility,
            thumbnailUrl: thumbnailUrl,
          )
          .timeout(const Duration(seconds: 15));
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Changes saved')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(
        // A DioException comes from the thumbnail upload (Cloudinary).
        error is DioException
            ? "Couldn't upload the thumbnail: "
                  '${UploadRepository.describeError(error)}'
            : "Couldn't save. Check your internet connection.",
      );
    }
  }

  Future<void> _close() async {
    if (!_changed) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            onPressed: _saving ? null : _close,
            icon: const Icon(Symbols.close),
          ),
          title: Text(widget.video.isShort ? 'Edit Short' : 'Edit video'),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else
              TextButton(
                onPressed: _canSave ? _save : null,
                child: const Text('Save'),
              ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---- Thumbnail ----
              Text(
                'Thumbnail',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _thumbBytes != null
                      ? Image.memory(_thumbBytes!, fit: BoxFit.cover)
                      : NetworkThumbnail(url: widget.video.thumbnailUrl),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickThumbnail,
                    icon: const Icon(Symbols.image),
                    label: const Text('Change thumbnail'),
                  ),
                  if (_thumbBytes != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _thumbBytes = null;
                        _thumbName = null;
                      }),
                      child: const Text('Undo'),
                    ),
                  ],
                ],
              ),
              Text(
                'JPG, PNG or WEBP, up to 5 MB.',
                style: AppTextStyles.meta.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 20),

              // ---- Title + description ----
              TextField(
                controller: _title,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Title (required)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                maxLength: 5000,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),

              // ---- Category ----
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in uploadCategories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 20),

              // ---- Visibility ----
              Text(
                'Visibility',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'public',
                    label: Text('Public'),
                    icon: Icon(Symbols.public),
                  ),
                  ButtonSegment(
                    value: 'unlisted',
                    label: Text('Unlisted'),
                    icon: Icon(Symbols.link),
                  ),
                ],
                selected: {_visibility},
                onSelectionChanged: (selection) =>
                    setState(() => _visibility = selection.first),
              ),
              const SizedBox(height: 6),
              Text(
                _visibility == 'public'
                    ? 'Everyone can find it on Home, in Shorts and in search.'
                    : "Only people with the link can watch it. It won't show "
                          'on Home, in Shorts or in search.',
                style: AppTextStyles.meta.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
