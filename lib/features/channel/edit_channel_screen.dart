import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/avatar_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/upload_validation.dart';
import '../../core/widgets/channel_avatar.dart';
import '../../core/widgets/network_thumbnail.dart';
import '../../data/models/channel.dart';
import '../../data/repositories/channel_repository.dart';
import '../../data/repositories/upload_repository.dart';

/// Opens "Edit channel" for your own [channel] (full screen, above the
/// tabs).
Future<void> openEditChannel(BuildContext context, Channel channel) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => EditChannelScreen(channel: channel),
    ),
  );
}

/// "Your channel" editing: banner, avatar color, name, @handle and
/// description. Saved all at once (see ChannelRepository.saveMyChannel).
class EditChannelScreen extends ConsumerStatefulWidget {
  const EditChannelScreen({super.key, required this.channel});

  final Channel channel;

  @override
  ConsumerState<EditChannelScreen> createState() => _EditChannelScreenState();
}

class _EditChannelScreenState extends ConsumerState<EditChannelScreen> {
  late final _name = TextEditingController(text: widget.channel.name);
  late final _handle = TextEditingController(
    text: widget.channel.handle.replaceFirst('@', ''),
  );
  late final _description = TextEditingController(
    text: widget.channel.description,
  );
  late int _color = widget.channel.avatarColor;

  /// The banner as saved, '' = none.
  late String _bannerUrl = widget.channel.bannerUrl;

  /// A new banner picked on this screen (uploaded when you tap Save).
  Uint8List? _newBanner;
  String? _newBannerName;

  bool _saving = false;
  String? _nameError;
  String? _handleError;

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _description.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickBanner() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final size = await file.length() ?? 0;
    final problem = checkImageFile(fileName: file.name, sizeBytes: size);
    if (problem != null) {
      _showMessage(problem);
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _newBanner = bytes;
      _newBannerName = file.name;
    });
  }

  void _removeBanner() => setState(() {
    _newBanner = null;
    _newBannerName = null;
    _bannerUrl = '';
  });

  Future<void> _save() async {
    final name = _name.text.trim();
    final handle = normalizeHandle(_handle.text);
    setState(() {
      _nameError = channelNameProblem(name);
      _handleError = handleProblem(handle);
    });
    if (_nameError != null || _handleError != null) return;

    final repository = ref.read(channelRepositoryProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      if (handle != widget.channel.handle &&
          !await repository.isHandleAvailable(handle)) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _handleError = 'This handle is already taken. Try another one.';
        });
        return;
      }

      var bannerUrl = _bannerUrl;
      if (_newBanner != null) {
        bannerUrl = await ref
            .read(uploadRepositoryProvider)
            .uploadImage(
              bytes: _newBanner!,
              filename: _newBannerName ?? 'banner.jpg',
            );
      }

      await repository.saveMyChannel(
        current: widget.channel,
        name: name,
        handle: handle,
        description: _description.text.trim(),
        bannerUrl: bannerUrl,
        avatarColor: _color,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Channel updated')));
      navigator.pop();
    } catch (error) {
      debugPrint('EDIT CHANNEL failed: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(
        error.toString().contains('permission-denied')
            ? "Couldn't save: this handle may already be taken."
            : "Couldn't save. Check your connection and try again.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = TextStyle(
      color: colors.textPrimary,
      fontWeight: FontWeight.w500,
    );
    final hint = AppTextStyles.meta.copyWith(color: colors.textSecondary);
    final previewName = _name.text.trim().isEmpty
        ? widget.channel.name
        : _name.text.trim();

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Symbols.close),
          ),
          title: const Text('Edit channel'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ---- Banner ----
            Text('Banner', style: label),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4,
                child: _newBanner != null
                    ? Image.memory(_newBanner!, fit: BoxFit.cover)
                    : _bannerUrl.isNotEmpty
                    ? NetworkThumbnail(url: _bannerUrl)
                    : ColoredBox(
                        color: Color(_color).withValues(alpha: 0.35),
                        child: Icon(Symbols.image, color: colors.textSecondary),
                      ),
              ),
            ),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: _saving ? null : _pickBanner,
                  child: Text(
                    _newBanner == null && _bannerUrl.isEmpty
                        ? 'Add banner'
                        : 'Change',
                  ),
                ),
                if (_newBanner != null || _bannerUrl.isNotEmpty)
                  TextButton(
                    onPressed: _saving ? null : _removeBanner,
                    child: const Text('Remove'),
                  ),
              ],
            ),
            Text(
              'Wide pictures look best (4:1). JPG, PNG or WEBP, up to 5 MB.',
              style: hint,
            ),
            const SizedBox(height: 20),

            // ---- Avatar color ----
            Text('Avatar color', style: label),
            const SizedBox(height: 12),
            Row(
              children: [
                ChannelAvatar(
                  name: previewName,
                  color: Color(_color),
                  size: 64,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final color in avatarPalette)
                        _ColorDot(
                          color: color,
                          selected: color.toARGB32() == _color,
                          onTap: _saving
                              ? null
                              : () => setState(() => _color = color.toARGB32()),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ---- Name, handle, description ----
            TextField(
              controller: _name,
              enabled: !_saving,
              maxLength: Channel.maxNameLength,
              onChanged: (_) => setState(() => _nameError = null),
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _handle,
              enabled: !_saving,
              maxLength: 30,
              autocorrect: false,
              onChanged: (_) => setState(() => _handleError = null),
              decoration: InputDecoration(
                labelText: 'Handle',
                prefixText: '@',
                errorText: _handleError,
                helperText:
                    'Letters, numbers, periods, dashes and underscores.',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              enabled: !_saving,
              maxLength: Channel.maxDescriptionLength,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Avatar color',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? context.colors.textPrimary : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? const Icon(Symbols.check, size: 18, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
