import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../../core/utils/format_views.dart';
import '../../../core/utils/share_video.dart';
import '../../../core/widgets/animated_toggle_icon.dart';
import '../../../core/widgets/channel_avatar.dart';
import '../../../core/widgets/network_thumbnail.dart';
import '../../../core/widgets/subscribe_button.dart';
import '../../../data/models/video.dart';
import '../../../data/repositories/comment_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/video_repository.dart';
import '../../auth/require_account.dart';
import '../../comments/comments_sheet.dart';
import '../../watch/playback_controller.dart';
import '../../watch/widgets/player_progress_bar.dart';

/// ONE Short, filling the whole screen.
///
/// Each page has its own small video player. It loads as soon as the page
/// is built (the next Short is built in advance, so swiping is quick), but
/// only PLAYS while [isActive] is true, i.e. it is the page on screen and
/// the Shorts tab is visible. It loops forever.
class ShortPage extends ConsumerStatefulWidget {
  const ShortPage({super.key, required this.video, required this.isActive});

  final Video video;
  final bool isActive;

  @override
  ConsumerState<ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends ConsumerState<ShortPage> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));

  bool _ready = false;
  bool _failed = false;
  bool _countedView = false;

  /// The big ▶ / ❚❚ that flashes in the middle when you tap.
  IconData? _flashIcon;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _controller.initialize();
    } catch (error) {
      debugPrint(
        'SHORT UNAVAILABLE (${widget.video.id}): '
        '${widget.video.videoUrl}\n$error',
      );
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) return;
    await _controller.setLooping(true);
    await _controller.setVolume(ref.read(playerMutedProvider) ? 0 : 1);

    // Save the length if it's longer than the one in Firestore - see the
    // note in playback_controller.dart about Cloudinary's first conversion
    // (a wrong length is always too short).
    final seconds = _controller.value.duration.inSeconds;
    if (seconds > widget.video.durationSeconds + 1) {
      ref
          .read(videoRepositoryProvider)
          .updateDuration(widget.video.id, seconds)
          .catchError((Object e) => debugPrint('Saving duration failed: $e'));
    }

    setState(() => _ready = true);
    _syncPlaying();
  }

  @override
  void didUpdateWidget(ShortPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) _syncPlaying();
  }

  /// Play when this page is the one on screen, pause otherwise.
  void _syncPlaying() {
    if (!_ready) return;
    if (widget.isActive) {
      _controller.play();
      if (!_countedView) {
        _countedView = true;
        ref
            .read(videoRepositoryProvider)
            .incrementViews(widget.video.id)
            .catchError((Object e) => debugPrint('Counting view failed: $e'));
      }
    } else {
      _controller.pause();
    }
  }

  void _togglePlay() {
    if (!_ready) return;
    final playing = _controller.value.isPlaying;
    playing ? _controller.pause() : _controller.play();
    setState(() => _flashIcon = playing ? Symbols.pause : Symbols.play_arrow);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _flashIcon = null);
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Follow the app-wide mute switch (shared with the watch page).
    ref.listen(playerMutedProvider, (_, muted) {
      if (_ready) _controller.setVolume(muted ? 0 : 1);
    });

    final video = widget.video;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ---- The video, filling the screen (cropped if needed) ----
        if (_ready)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          )
        else
          NetworkThumbnail(url: video.thumbnailUrl),

        if (!_ready && !_failed)
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (_failed) const _UnavailableMessage(),

        // ---- Tap anywhere = pause / play ----
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: _togglePlay),

        // ---- Big ▶ / ❚❚ that flashes after a tap ----
        IgnorePointer(
          child: Center(
            child: AnimatedOpacity(
              opacity: _flashIcon == null ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _flashIcon ?? Symbols.play_arrow,
                  fill: 1,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

        // ---- Dark fade at the bottom so the white text is readable ----
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.6, 1],
                colors: [Colors.transparent, Color(0xAA000000)],
              ),
            ),
          ),
        ),

        // ---- Right side: like, dislike, comments, share, remix ----
        Positioned(right: 8, bottom: 24, child: _ActionColumn(video: video)),

        // ---- Bottom left: channel, Subscribe, title ----
        Positioned(
          left: 12,
          right: 84,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChannelAvatar(
                    name: video.channelName,
                    imageUrl: video.channelAvatarUrl,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      // "Quick Clips" -> "@quickclips"
                      '@${video.channelId.replaceAll('-', '')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SubscribeButton(
                    channelId: video.channelId,
                    channelName: video.channelName,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),

        // ---- Thin progress bar along the bottom edge ----
        // The touch area is 24px tall (easy to grab) but it LOOKS like a
        // 2px line until you drag it sideways to skip ahead or back.
        if (_ready)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 24,
            child: PlayerProgressBar(
              controller: _controller,
              thinUntilDragged: true,
            ),
          ),
      ],
    );
  }
}

class _UnavailableMessage extends StatelessWidget {
  const _UnavailableMessage();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.error, color: Colors.white70, size: 40),
            SizedBox(height: 8),
            Text(
              'Video unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The column of round buttons on the right of a Short.
class _ActionColumn extends ConsumerWidget {
  const _ActionColumn({required this.video});

  final Video video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reaction = ref.watch(reactionProvider(video.id)).value ?? 0;
    final commentCount = ref.watch(commentsProvider(video.id)).value?.length;
    final messenger = ScaffoldMessenger.of(context);

    void showMessage(String text) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }

    void react(int tapped) {
      // Guests get the "Sign in to …" sheet instead.
      final reason = tapped == 1 ? SignInReason.like : SignInReason.dislike;
      if (!checkSignedIn(context, ref, reason: reason)) return;
      ref
          .read(userRepositoryProvider)
          .react(videoId: video.id, current: reaction, tapped: tapped)
          .catchError(
            (Object _) =>
                showMessage("Couldn't save. Check your internet connection."),
          );
    }

    return Column(
      children: [
        _ActionButton(
          icon: Symbols.thumb_up,
          active: reaction == 1,
          label: formatCompactCount(video.likes),
          tooltip: 'Like',
          onTap: () => react(1),
        ),
        _ActionButton(
          icon: Symbols.thumb_down,
          active: reaction == -1,
          label: 'Dislike',
          tooltip: 'Dislike',
          onTap: () => react(-1),
        ),
        _ActionButton(
          icon: Symbols.comment,
          label: commentCount == null ? '' : formatCompactCount(commentCount),
          tooltip: 'Comments',
          onTap: () => showCommentsSheet(context, video.id),
        ),
        _ActionButton(
          icon: Symbols.share,
          label: 'Share',
          tooltip: 'Share',
          onTap: () => shareVideo(messenger, video),
        ),
        _ActionButton(
          icon: Symbols.autorenew,
          label: 'Remix',
          tooltip: 'Remix',
          onTap: () => showMessage('Remix is not available in this demo'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.15),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Tooltip(
                message: tooltip,
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: AnimatedToggleIcon(
                      icon: icon,
                      active: active,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }
}
