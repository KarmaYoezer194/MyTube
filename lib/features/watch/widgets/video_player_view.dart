import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../../core/utils/durations.dart';
import '../../../core/widgets/network_thumbnail.dart';
import '../../../data/models/video.dart';
import '../../settings/settings_providers.dart';
import '../playback_controller.dart';
import 'playback_speed_sheet.dart';
import 'player_progress_bar.dart';
import 'seek_ripple.dart';
import 'up_next_overlay.dart';

/// The black player area at the top of the watch page.
/// Shows a spinner while loading, "Video unavailable" if the link is broken,
/// and the video with YouTube-style controls when ready.
class VideoPlayerView extends ConsumerWidget {
  const VideoPlayerView({
    super.key,
    required this.video,
    required this.upNext,
    required this.hasPrevious,
    required this.onPrevious,
    required this.onNext,
    required this.onMinimize,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.compact = false,
  });

  final Video video;

  /// true while the panel is being dragged or is the mini player:
  /// show only the video, no controls.
  final bool compact;

  /// The video that plays next (null if there is none).
  final Video? upNext;
  final bool hasPrevious;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onMinimize;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);

    return ColoredBox(
      color: Colors.black,
      child: switch (playback) {
        AsyncData(:final value?) => _PlayerSurface(
          // A new video = a new controller = fresh controls state.
          key: ObjectKey(value),
          controller: value,
          view: this,
        ),
        AsyncError() when compact => const Center(
          child: Icon(Symbols.error, color: Colors.white70),
        ),
        AsyncError() => _UnavailableView(
          onRetry: () => ref.invalidate(playbackProvider),
          onMinimize: onMinimize,
        ),
        _ when compact => NetworkThumbnail(url: video.thumbnailUrl),
        _ => _LoadingView(
          thumbnailUrl: video.thumbnailUrl,
          onMinimize: onMinimize,
        ),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Loading and error states
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.thumbnailUrl, required this.onMinimize});

  final String thumbnailUrl;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.5,
          child: NetworkThumbnail(url: thumbnailUrl, fit: BoxFit.contain),
        ),
        const Center(child: _Spinner()),
        _MinimizeButton(onPressed: onMinimize),
      ],
    );
  }
}

class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.onRetry, required this.onMinimize});

  final VoidCallback onRetry;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.error, color: Colors.white70, size: 40),
              const SizedBox(height: 8),
              const Text(
                'Video unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "This video can't be played right now.",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        _MinimizeButton(onPressed: onMinimize),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 44,
      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
    );
  }
}

class _MinimizeButton extends StatelessWidget {
  const _MinimizeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: IconButton(
        tooltip: 'Minimize',
        onPressed: onPressed,
        icon: const Icon(Symbols.keyboard_arrow_down, color: Colors.white),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The playing video + controls
// ---------------------------------------------------------------------------

class _PlayerSurface extends ConsumerStatefulWidget {
  const _PlayerSurface({
    super.key,
    required this.controller,
    required this.view,
  });

  final VideoPlayerController controller;

  /// The settings and callbacks passed to [VideoPlayerView].
  final VideoPlayerView view;

  @override
  ConsumerState<_PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends ConsumerState<_PlayerSurface> {
  VideoPlayerController get _controller => widget.controller;
  VideoPlayerView get _view => widget.view;

  bool _controlsVisible = true;
  Timer? _hideTimer;

  bool _ended = false;
  bool _countdownCancelled = false;

  // Double-tap seek ripple.
  double _playerWidth = 0;
  double _doubleTapX = 0;
  SeekSide? _rippleSide;
  int _rippleSeconds = 0;
  int _ripplePulse = 0;
  Timer? _rippleTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPlayerChanged);
    _scheduleHide();
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerChanged);
    _hideTimer?.cancel();
    _rippleTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Back to the full page: show the controls for a moment.
    if (oldWidget.view.compact && !_view.compact) {
      _controlsVisible = true;
      _scheduleHide();
    }
  }

  /// Watches for the video reaching its end.
  void _onPlayerChanged() {
    final v = _controller.value;
    final ended =
        !v.isPlaying &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 250);
    if (ended == _ended) return;
    setState(() {
      _ended = ended;
      if (ended) {
        _controlsVisible = true;
        _hideTimer?.cancel();
      } else {
        _countdownCancelled = false;
      }
    });

    // In the mini player there's no room for the countdown, so autoplay
    // goes straight to the next video.
    if (ended &&
        _view.compact &&
        ref.read(autoplayProvider) &&
        _view.upNext != null) {
      _view.onNext();
    }
  }

  // ---- Showing / hiding the controls ----

  /// Hide the controls 3 seconds from now (only while playing).
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying && !_ended) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      setState(() => _controlsVisible = true);
      _scheduleHide();
    }
  }

  // ---- Actions ----

  void _togglePlay() {
    if (_ended) {
      _controller.seekTo(Duration.zero);
      _controller.play();
    } else if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    _scheduleHide();
  }

  void _seekBy(int seconds) {
    final v = _controller.value;
    var target = v.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > v.duration) target = v.duration;
    _controller.seekTo(target);
  }

  void _onDoubleTap() {
    final side = _doubleTapX > _playerWidth / 2
        ? SeekSide.forward
        : SeekSide.back;
    setState(() {
      // Keep adding up while you keep tapping the same side.
      if (_rippleSide != side) _rippleSeconds = 0;
      _rippleSide = side;
      _rippleSeconds += 10;
      _ripplePulse++;
      _controlsVisible = false;
    });
    _seekBy(side == SeekSide.forward ? 10 : -10);

    _rippleTimer?.cancel();
    _rippleTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _rippleSide = null;
          _rippleSeconds = 0;
        });
      }
    });
  }

  void _toggleAutoplay(bool enabled) {
    ref.read(autoplayProvider.notifier).setEnabled(enabled);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Autoplay is ${enabled ? 'on' : 'off'}'),
          duration: const Duration(seconds: 2),
        ),
      );
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final autoplay = ref.watch(autoplayProvider);
    final muted = ref.watch(playerMutedProvider);
    final upNext = _view.upNext;
    final showUpNext =
        _ended && autoplay && upNext != null && !_countdownCancelled;

    return LayoutBuilder(
      builder: (context, constraints) {
        _playerWidth = constraints.maxWidth;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. The video itself (black bars if its shape is different).
            //    Always the FIRST child, so it stays the same widget when
            //    the controls below are added or removed (no flicker).
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),

            // Mini player / dragging: nothing else.
            if (!_view.compact) ...[
              // 2. Taps on the video: tap = show/hide controls,
              //    double-tap left/right = seek -10s/+10s.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                onDoubleTapDown: (details) =>
                    _doubleTapX = details.localPosition.dx,
                onDoubleTap: _onDoubleTap,
              ),

              // 3. Buffering spinner.
              IgnorePointer(
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _controller,
                  builder: (context, v, _) => v.isBuffering && !_ended
                      ? const Center(child: _Spinner())
                      : const SizedBox.shrink(),
                ),
              ),

              // 4. "10 seconds" ripple.
              if (_rippleSide != null)
                IgnorePointer(
                  child: SeekRipple(
                    side: _rippleSide!,
                    seconds: _rippleSeconds,
                    pulse: _ripplePulse,
                  ),
                ),

              // 5. The controls (fade in/out).
              IgnorePointer(
                ignoring: !_controlsVisible,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: _buildControls(muted: muted, autoplay: autoplay),
                ),
              ),

              // 6. Thin red line at the bottom while the controls are hidden.
              if (!_controlsVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 2,
                  child: PlayerProgressBar(
                    controller: _controller,
                    interactive: false,
                  ),
                ),

              // 7. "Tap to unmute" (Chrome makes videos start muted).
              if (muted && !_controlsVisible && !showUpNext)
                Positioned(
                  top: 10,
                  left: 10,
                  child: _UnmutePill(
                    onTap: () =>
                        ref.read(playerMutedProvider.notifier).setMuted(false),
                  ),
                ),

              // 8. "Up next" countdown when the video ends.
              if (showUpNext)
                UpNextOverlay(
                  next: upNext,
                  onPlayNow: _view.onNext,
                  onCancel: () => setState(() => _countdownCancelled = true),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildControls({required bool muted, required bool autoplay}) {
    const white = Colors.white;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark see-through layer so the white icons are readable.
        // (IgnorePointer: taps go through it to the video.)
        const IgnorePointer(child: ColoredBox(color: Color(0x66000000))),

        // Top left: minimize.
        Positioned(
          top: 0,
          left: 0,
          child: IconButton(
            tooltip: _view.isFullscreen ? 'Exit full screen' : 'Minimize',
            onPressed: _view.onMinimize,
            icon: const Icon(Symbols.keyboard_arrow_down, color: white),
          ),
        ),

        // Top right: sound, autoplay switch, settings.
        Positioned(
          top: 0,
          right: 0,
          child: Row(
            children: [
              IconButton(
                tooltip: muted ? 'Unmute' : 'Mute',
                onPressed: () {
                  ref.read(playerMutedProvider.notifier).setMuted(!muted);
                  _scheduleHide();
                },
                icon: Icon(
                  muted ? Symbols.volume_off : Symbols.volume_up,
                  color: white,
                ),
              ),
              _AutoplaySwitch(value: autoplay, onChanged: _toggleAutoplay),
              IconButton(
                tooltip: 'Playback speed',
                onPressed: () {
                  _hideTimer?.cancel();
                  showPlaybackSpeedSheet(
                    context,
                    ref,
                  ).then((_) => _scheduleHide());
                },
                icon: const Icon(Symbols.settings, color: white),
              ),
            ],
          ),
        ),

        // Middle: previous, play/pause (or replay), next.
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CenterButton(
                icon: Symbols.skip_previous,
                tooltip: 'Previous video',
                onPressed: _view.hasPrevious ? _view.onPrevious : null,
              ),
              const SizedBox(width: 28),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller,
                builder: (context, v, _) => _CenterButton(
                  icon: _ended
                      ? Symbols.replay
                      : (v.isPlaying ? Symbols.pause : Symbols.play_arrow),
                  tooltip: _ended ? 'Replay' : (v.isPlaying ? 'Pause' : 'Play'),
                  size: 56,
                  onPressed: _togglePlay,
                ),
              ),
              const SizedBox(width: 28),
              _CenterButton(
                icon: Symbols.skip_next,
                tooltip: 'Next video',
                onPressed: _view.upNext != null ? _view.onNext : null,
              ),
            ],
          ),
        ),

        // Bottom: time and full screen button.
        Positioned(
          left: 12,
          right: 0,
          bottom: 16,
          child: Row(
            children: [
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller,
                builder: (context, v, _) => Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: formatDuration(v.position)),
                      TextSpan(
                        text: ' / ${formatDuration(v.duration)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  style: const TextStyle(color: white, fontSize: 12),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: _view.isFullscreen
                    ? 'Exit full screen'
                    : 'Full screen',
                onPressed: _view.onToggleFullscreen,
                icon: Icon(
                  _view.isFullscreen
                      ? Symbols.fullscreen_exit
                      : Symbols.fullscreen,
                  color: white,
                ),
              ),
            ],
          ),
        ),

        // Very bottom: the red progress bar with the scrubber dot.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 24,
          child: PlayerProgressBar(
            controller: _controller,
            onInteraction: _scheduleHide,
          ),
        ),
      ],
    );
  }
}

/// White play/pause/next/previous icon in the middle of the player.
class _CenterButton extends StatelessWidget {
  const _CenterButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 36,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: size,
      color: Colors.white,
      disabledColor: Colors.white38,
      icon: Icon(icon, fill: 1),
    );
  }
}

/// YouTube's little autoplay switch: a track with a round knob showing
/// ▶ (on) or ❚❚ (off).
class _AutoplaySwitch extends StatelessWidget {
  const _AutoplaySwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Autoplay is ${value ? 'on' : 'off'}',
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 34,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: value ? Colors.white : Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    value ? Symbols.play_arrow : Symbols.pause,
                    fill: 1,
                    size: 14,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnmutePill extends StatelessWidget {
  const _UnmutePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.volume_off, size: 18, color: Colors.black),
            SizedBox(width: 6),
            Text(
              'Tap to unmute',
              style: TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
