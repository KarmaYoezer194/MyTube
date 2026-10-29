import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/mp4_length.dart';
import '../../core/utils/upload_validation.dart';
import '../../data/models/video.dart';
import '../../data/repositories/upload_repository.dart';
import 'upload_flow.dart';

const List<String> uploadCategories = [
  'Animation',
  'Cars',
  'Entertainment',
  'Sci-Fi',
  'Other',
];

/// Where the upload is at.
enum _Stage { editing, thumbnail, video, processing, saving, failed }

/// "Add details": preview, thumbnail, title, description, category,
/// visibility, then Upload (with a progress bar).
class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key, required this.draft});

  final UploadDraft draft;

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _category = uploadCategories.first;
  String _visibility = 'public';

  /// Custom thumbnail (optional). null = Cloudinary makes one from the video.
  Uint8List? _thumbBytes;
  String? _thumbName;

  _Stage _stage = _Stage.editing;
  double _progress = 0;
  String? _error;
  CancelToken? _cancelToken;

  /// Small muted preview of the picked video (plays from your computer).
  late final VideoPlayerController _preview = VideoPlayerController.networkUrl(
    widget.draft.file.uri,
  );
  bool _previewReady = false;

  /// Set when the video is too long (e.g. a Short over 60 seconds).
  String? _lengthProblem;

  bool get _busy => _stage != _Stage.editing && _stage != _Stage.failed;

  @override
  void initState() {
    super.initState();
    _initPreview();
  }

  Future<void> _initPreview() async {
    try {
      await _preview.initialize();
      await _preview.setVolume(0);
      await _preview.setLooping(true);
      await _preview.play();
      final problem = checkVideoLength(
        seconds: _preview.value.duration.inSeconds,
        isShort: widget.draft.isShort,
      );
      if (mounted) {
        setState(() {
          _previewReady = true;
          _lengthProblem = problem;
        });
      }
    } catch (_) {
      // No preview (unusual format) - the upload can still work.
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _preview.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  // ---- Thumbnail ----

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

  // ---- Upload ----

  Future<void> _upload() async {
    final draft = widget.draft;
    final repository = ref.read(uploadRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    setState(() {
      _stage = _Stage.thumbnail;
      _progress = 0;
      _error = null;
    });

    try {
      // 0. Check the length before sending anything. The browser's length
      // can be wrong for some MP4s, so the file itself is read too.
      final bytes = await draft.file.readAsBytes();
      final fileSeconds = math.max(
        mp4LengthSeconds(bytes),
        _preview.value.isInitialized ? _preview.value.duration.inSeconds : 0,
      );
      final lengthProblem = checkVideoLength(
        seconds: fileSeconds,
        isShort: draft.isShort,
      );
      if (lengthProblem != null) {
        debugPrint('UPLOAD: refused - $lengthProblem');
        if (!mounted) return;
        setState(() {
          _stage = _Stage.failed;
          _error = lengthProblem;
          _lengthProblem = lengthProblem;
        });
        return;
      }

      // 1. Custom thumbnail first (small and quick).
      String? thumbnailUrl;
      if (_thumbBytes != null) {
        thumbnailUrl = await repository.uploadImage(
          bytes: _thumbBytes!,
          filename: _thumbName ?? 'thumbnail.jpg',
          cancelToken: cancelToken,
        );
      }

      // 2. The video, with progress.
      setState(() => _stage = _Stage.video);
      debugPrint('UPLOAD: sending ${bytes.length} bytes to Cloudinary');
      final uploaded = await repository.uploadVideo(
        bytes: bytes,
        filename: draft.file.name,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            // Everything is sent; Cloudinary is now processing it.
            if (progress >= 1) _stage = _Stage.processing;
          });
        },
      );

      // 3. Save it in Firestore so it shows up in the app.
      debugPrint('UPLOAD: Cloudinary OK -> ${uploaded.secureUrl}');
      setState(() => _stage = _Stage.saving);
      final author = draft.author;
      final id = await repository.saveVideo(
        Video(
          id: '',
          title: _title.text.trim(),
          description: _description.text.trim(),
          videoUrl: uploaded.secureUrl,
          thumbnailUrl:
              thumbnailUrl ??
              UploadRepository.videoThumbnailUrl(uploaded.publicId),
          // Cloudinary's length, or the one read from the file if that's
          // longer (fragmented MP4s can fool Cloudinary and the browser).
          durationSeconds: math.max(
            uploaded.durationSeconds,
            mp4LengthSeconds(bytes),
          ),
          channelId: 'user-${author.uid}',
          channelName: author.displayName,
          channelAvatarUrl: author.avatarUrl,
          channelAvatarColor: author.avatarColor,
          subscriberCount: 0,
          views: 0,
          likes: 0,
          category: _category,
          isShort: draft.isShort,
          uploaderUid: author.uid,
          createdAt: DateTime.now(),
          visibility: _visibility,
        ),
      );

      // 4. Done!
      debugPrint('UPLOAD: saved in Firestore as videos/$id');
      final unlisted = _visibility == 'unlisted';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            unlisted
                ? "Uploaded as Unlisted: it won't appear on Home or in Shorts."
                : 'Upload complete!',
          ),
        ),
      );
      // Close this screen, then show where the new video is.
      navigator.pop();
      router.go(draft.isShort && !unlisted ? '/shorts?v=$id' : '/home');
    } on DioException catch (error) {
      debugPrint(
        'UPLOAD FAILED (network/Cloudinary): ${error.type} '
        '${error.response?.statusCode} ${error.response?.data} '
        '${error.message}',
      );
      if (!mounted) return;
      if (CancelToken.isCancel(error)) {
        setState(() => _stage = _Stage.editing);
        _showMessage('Upload cancelled');
      } else {
        setState(() {
          _stage = _Stage.failed;
          _error = UploadRepository.describeError(error);
        });
      }
    } catch (error, stackTrace) {
      debugPrint('UPLOAD FAILED: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        // Show the real reason, so it's easy to report.
        _error = '$error';
      });
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _close() async {
    if (_busy) {
      final stop = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: const Text('Cancel the upload?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep uploading'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel upload'),
            ),
          ],
        ),
      );
      if (!(stop ?? false)) return;
      _cancelToken?.cancel();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final draft = widget.draft;
    final canUpload =
        !_busy && _title.text.trim().isNotEmpty && _lengthProblem == null;
    final sizeMb = (draft.sizeBytes / (1024 * 1024)).toStringAsFixed(1);

    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            onPressed: _close,
            icon: const Icon(Symbols.close),
          ),
          title: Text(draft.isShort ? 'New Short' : 'Add details'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: canUpload ? _upload : null,
                child: Text(_stage == _Stage.failed ? 'Try again' : 'Upload'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ---- Progress (while uploading / after an error) ----
            if (_stage != _Stage.editing) ...[
              _ProgressPanel(
                stage: _stage,
                progress: _progress,
                error: _error,
                onCancel: _busy ? () => _cancelToken?.cancel() : null,
              ),
              const SizedBox(height: 16),
            ],

            // ---- Preview ----
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: draft.isShort ? 180 : double.infinity,
                  child: AspectRatio(
                    aspectRatio: draft.isShort ? 9 / 16 : 16 / 9,
                    child: ColoredBox(
                      color: Colors.black,
                      child: _previewReady
                          ? FittedBox(
                              fit: draft.isShort
                                  ? BoxFit.cover
                                  : BoxFit.contain,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: _preview.value.size.width,
                                height: _preview.value.size.height,
                                child: VideoPlayer(_preview),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Symbols.movie,
                                color: Colors.white54,
                                size: 48,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            if (_lengthProblem != null) ...[
              const SizedBox(height: 8),
              Text(
                _lengthProblem!,
                textAlign: TextAlign.center,
                style: AppTextStyles.meta.copyWith(color: AppColors.brandRed),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${draft.file.name} · $sizeMb MB',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.meta.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 20),

            // ---- Thumbnail ----
            Text(
              'Thumbnail',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 120,
                    height: 68,
                    child: _thumbBytes != null
                        ? Image.memory(_thumbBytes!, fit: BoxFit.cover)
                        : ColoredBox(
                            color: context.isDarkMode
                                ? AppColors.placeholderDark
                                : AppColors.placeholderLight,
                            child: Icon(
                              Symbols.play_circle,
                              color: colors.textSecondary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _thumbBytes == null
                            ? 'Automatic (a frame from your video)'
                            : 'Your picture',
                        style: AppTextStyles.meta.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          TextButton(
                            onPressed: _busy ? null : _pickThumbnail,
                            child: Text(
                              _thumbBytes == null ? 'Choose' : 'Change',
                            ),
                          ),
                          if (_thumbBytes != null)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _thumbBytes = null;
                                      _thumbName = null;
                                    }),
                              child: const Text('Remove'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ---- Title, description ----
            TextField(
              controller: _title,
              enabled: !_busy,
              maxLength: 100,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Title (required)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              enabled: !_busy,
              maxLength: 5000,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
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
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _category = value!),
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
              onSelectionChanged: _busy
                  ? null
                  : (selection) =>
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
    );
  }
}

/// The box at the top while uploading: what's happening, a progress bar
/// and a Cancel button. Shows the error if it failed.
class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.stage,
    required this.progress,
    required this.error,
    required this.onCancel,
  });

  final _Stage stage;
  final double progress;
  final String? error;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final failed = stage == _Stage.failed;

    final label = switch (stage) {
      _Stage.thumbnail => 'Uploading thumbnail...',
      _Stage.video => 'Uploading video... ${(progress * 100).floor()}%',
      _Stage.processing => 'Processing on Cloudinary...',
      _Stage.saving => 'Saving...',
      _Stage.failed => 'Upload failed: ${error ?? ''}',
      _Stage.editing => '',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                failed ? Symbols.error : Symbols.cloud_upload,
                color: failed ? AppColors.brandRed : colors.textPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: TextStyle(color: colors.textPrimary)),
              ),
              if (onCancel != null)
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
          if (!failed) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: TweenAnimationBuilder<double>(
                // Smoothly slides to the new percentage.
                tween: Tween(end: progress),
                duration: const Duration(milliseconds: 250),
                builder: (context, value, _) => LinearProgressIndicator(
                  minHeight: 4,
                  // No exact number while thumbnail/processing/saving.
                  value: stage == _Stage.video ? value : null,
                  backgroundColor: colors.divider,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
