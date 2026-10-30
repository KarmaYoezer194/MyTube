import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../data/models/video.dart';
import '../../data/repositories/video_repository.dart';
import '../watch/keyboard_shortcuts.dart';
import '../watch/playback_controller.dart';
import '../watch/widgets/playback_speed_sheet.dart';
import '../watch/watch_body.dart';
import '../playlists/play_queue.dart';
import '../watch/widgets/player_progress_bar.dart';
import '../watch/widgets/video_player_view.dart';
import 'player_panel_provider.dart';

/// Height of the mini player bar.
const double kMiniPlayerHeight = 64;

/// The player panel: ONE widget that is either the full watch page or the
/// mini player above the bottom nav, and everything in between.
///
/// How it works: a number `t` goes from 0 (full page) to 1 (mini player).
/// Every size and position is calculated from `t`, so when you drag, the
/// page shrinks and moves exactly with your finger. When you let go, it
/// animates to whichever end is closer (or the way you flicked).
class PlayerPanel extends ConsumerStatefulWidget {
  const PlayerPanel({super.key, required this.bottomInset});

  /// Height of the bottom nav: the mini player sits right on top of it.
  final double bottomInset;

  @override
  ConsumerState<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends ConsumerState<PlayerPanel>
    with TickerProviderStateMixin {
  /// 0 = full watch page, 1 = mini player.
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  /// Slides the whole page up from the bottom when a video is opened.
  late final AnimationController _slideIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );
  late final Animation<Offset> _slideOffset = Tween(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _slideIn, curve: Curves.easeOutCubic));

  bool _fullscreen = false;

  /// How many pixels the top of the panel travels from full to mini.
  double _travel = 1;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _t.dispose();
    _slideIn.dispose();
    super.dispose();
  }

  PlayerPanelController get _panel => ref.read(playerPanelProvider.notifier);

  // ---- Keyboard shortcuts (while the full watch page is open) ----

  /// Handles a key, or returns false to let it go on (e.g. to a text box).
  bool _onKey(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    if (!mounted || !ref.read(playerPanelProvider).isExpanded) return false;
    if (isTypingInTextField()) return false;
    final command = shortcutFor(
      event.logicalKey,
      shift: HardwareKeyboard.instance.isShiftPressed,
    );
    if (command == null) return false;
    // Holding a key repeats only seeking and volume.
    if (event is KeyRepeatEvent &&
        !const {
          PlayerShortcut.back5,
          PlayerShortcut.forward5,
          PlayerShortcut.back10,
          PlayerShortcut.forward10,
          PlayerShortcut.volumeUp,
          PlayerShortcut.volumeDown,
        }.contains(command.action)) {
      return true;
    }
    _run(command);
    return true;
  }

  void _flash(String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  void _run(ShortcutCommand command) {
    final controller = ref.read(playbackProvider).value;
    final value = controller?.value;
    final ready = controller != null && value!.isInitialized;

    void seekTo(Duration target) {
      if (!ready) return;
      final end = value.duration;
      controller.seekTo(
        target < Duration.zero ? Duration.zero : (target > end ? end : target),
      );
    }

    void seekBy(int seconds) {
      if (ready) seekTo(value.position + Duration(seconds: seconds));
    }

    void setVolume(double volume) {
      final v = volume.clamp(0.0, 1.0);
      ref.read(playerVolumeProvider.notifier).setVolume(v);
      ref.read(playerMutedProvider.notifier).setMuted(v == 0);
      _flash('Volume ${(v * 100).round()}%');
    }

    switch (command.action) {
      case PlayerShortcut.playPause:
        if (!ready) return;
        if (value.isPlaying) {
          controller.pause();
        } else {
          if (value.position >= value.duration) {
            controller.seekTo(Duration.zero);
          }
          controller.play();
        }
      case PlayerShortcut.back10:
        seekBy(-10);
      case PlayerShortcut.forward10:
        seekBy(10);
      case PlayerShortcut.back5:
        seekBy(-5);
      case PlayerShortcut.forward5:
        seekBy(5);
      case PlayerShortcut.seekPercent:
        if (ready) seekTo(value.duration * (command.percent / 100));
      case PlayerShortcut.toStart:
        seekTo(Duration.zero);
      case PlayerShortcut.toEnd:
        if (ready) seekTo(value.duration);
      case PlayerShortcut.volumeUp:
        final muted = ref.read(playerMutedProvider);
        setVolume((muted ? 0 : ref.read(playerVolumeProvider)) + 0.05);
      case PlayerShortcut.volumeDown:
        final muted = ref.read(playerMutedProvider);
        setVolume((muted ? 0 : ref.read(playerVolumeProvider)) - 0.05);
      case PlayerShortcut.mute:
        final muted = !ref.read(playerMutedProvider);
        ref.read(playerMutedProvider.notifier).setMuted(muted);
        _flash(muted ? 'Muted' : 'Sound on');
      case PlayerShortcut.faster || PlayerShortcut.slower:
        final speed = stepSpeed(
          playbackSpeeds,
          ref.read(playbackSpeedProvider),
          up: command.action == PlayerShortcut.faster,
        );
        ref.read(playbackSpeedProvider.notifier).setSpeed(speed);
        _flash('Speed: ${speedLabel(speed)}');
      case PlayerShortcut.fullscreen:
        setState(() => _fullscreen = !_fullscreen);
      case PlayerShortcut.exitOrMinimize:
        _exitFullscreenOrMinimize();
      case PlayerShortcut.miniPlayer:
        setState(() => _fullscreen = false);
        _panel.minimize();
      case PlayerShortcut.next:
        final id = ref.read(playerPanelProvider).videoId;
        final next = id == null ? null : ref.read(nextVideoProvider(id));
        if (next != null) _panel.switchTo(next.id);
      case PlayerShortcut.previous:
        _panel.openPrevious();
      case PlayerShortcut.help:
        showShortcutHelp(context);
    }
  }

  /// React to open / minimize / expand coming from anywhere in the app
  /// (tapping a video, the ⌄ button, the back button...).
  void _onPanelChanged(PlayerPanelState? before, PlayerPanelState now) {
    if (!now.isOpen) return;
    final wasOpen = before?.isOpen ?? false;
    if (!wasOpen) {
      // Just opened: start full size and slide up from the bottom.
      _t.value = now.isExpanded ? 0 : 1;
      _slideIn.forward(from: 0);
      setState(() => _fullscreen = false);
      return;
    }
    if (before!.isExpanded != now.isExpanded) {
      if (!now.isExpanded) setState(() => _fullscreen = false);
      _t.animateTo(now.isExpanded ? 0 : 1, curve: Curves.easeOutCubic);
    }
  }

  // ---- Dragging ----

  void _onDragUpdate(DragUpdateDetails details) {
    _t.value += details.primaryDelta! / _travel;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    // A quick flick decides by direction; a slow drag by position.
    final toMini = velocity.abs() > 700 ? velocity > 0 : _t.value > 0.5;
    // `.then` only runs if the animation FINISHES. If you grab the panel
    // again halfway, nothing is reported and your finger stays in control.
    _t.animateTo(toMini ? 1 : 0, curve: Curves.easeOutCubic).then((_) {
      if (!mounted) return;
      // Tell the rest of the app (nav bar, padding, back button).
      toMini ? _panel.minimize() : _panel.expand();
    });
  }

  void _exitFullscreenOrMinimize() {
    if (_fullscreen) {
      setState(() => _fullscreen = false);
    } else {
      _panel.minimize();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerPanelProvider, _onPanelChanged);

    final panel = ref.watch(playerPanelProvider);
    final videoId = panel.videoId;
    if (videoId == null) return const SizedBox.shrink();

    final video = ref.watch(videoProvider(videoId)).value;
    // The next video of the playing playlist, or the first "Up next".
    final next = ref.watch(nextVideoProvider(videoId));
    final colors = context.colors;
    final topPadding = MediaQuery.paddingOf(context).top;

    return PopScope(
      // Back button on the full page: leave full screen / shrink to mini.
      canPop: !panel.isExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitFullscreenOrMinimize();
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final fullHeight = box.maxHeight;
          final width = box.maxWidth;
          final miniTop = fullHeight - widget.bottomInset - kMiniPlayerHeight;
          _travel = miniTop;

          return SlideTransition(
            position: _slideOffset,
            child: AnimatedBuilder(
              animation: _t,
              builder: (context, _) {
                final t = _t.value;
                final top = _fullscreen ? 0.0 : topPadding * (1 - t);

                // Video size: full width 16:9 (or whole screen) -> small.
                final fullVideoHeight = _fullscreen
                    ? fullHeight
                    : width * 9 / 16;
                const miniVideoHeight = kMiniPlayerHeight - 2;
                final videoHeight = lerpDouble(
                  fullVideoHeight,
                  miniVideoHeight,
                  t,
                )!;
                final videoWidth = lerpDouble(
                  width,
                  miniVideoHeight * 16 / 9,
                  t,
                )!;

                // Details fade out fast; mini controls fade in at the end.
                final detailsOpacity = (1 - t * 2.5).clamp(0.0, 1.0);
                final miniOpacity = ((t - 0.6) / 0.4).clamp(0.0, 1.0);

                return Stack(
                  children: [
                    Positioned(
                      top: lerpDouble(0, miniTop, t),
                      left: 0,
                      right: 0,
                      height: lerpDouble(fullHeight, kMiniPlayerHeight, t),
                      child: GestureDetector(
                        // Lists inside (details, Up next) still scroll
                        // normally: they win the drag over this detector.
                        onVerticalDragUpdate: _fullscreen
                            ? null
                            : _onDragUpdate,
                        onVerticalDragEnd: _fullscreen ? null : _onDragEnd,
                        onTap: t == 1 ? _panel.expand : null,
                        child: Material(
                          color: _fullscreen
                              ? Colors.black
                              : Color.lerp(
                                  colors.background,
                                  colors.sheetBackground,
                                  t,
                                ),
                          elevation: t > 0 ? 4 : 0,
                          // Each layer has a fixed key: when a layer is added
                          // or removed, the others (especially the playing
                          // video) stay exactly where they are.
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              // Details + Up next under the video.
                              if (!_fullscreen && detailsOpacity > 0)
                                Positioned(
                                  key: const ValueKey('details'),
                                  top: top + videoHeight,
                                  left: 0,
                                  right: 0,
                                  // Keep the full-page height so the text
                                  // doesn't re-wrap while shrinking.
                                  height:
                                      fullHeight - topPadding - fullVideoHeight,
                                  child: IgnorePointer(
                                    ignoring: t > 0,
                                    child: Opacity(
                                      opacity: detailsOpacity,
                                      child: WatchBody(videoId: videoId),
                                    ),
                                  ),
                                ),

                              // The video.
                              Positioned(
                                key: const ValueKey('video'),
                                top: top,
                                left: 0,
                                width: videoWidth,
                                height: videoHeight,
                                child: video == null
                                    ? const ColoredBox(color: Colors.black)
                                    : VideoPlayerView(
                                        video: video,
                                        upNext: next,
                                        compact: t > 0,
                                        hasPrevious: panel.hasPrevious,
                                        onPrevious: _panel.openPrevious,
                                        onNext: () {
                                          if (next != null) {
                                            _panel.switchTo(next.id);
                                          }
                                        },
                                        onMinimize: _exitFullscreenOrMinimize,
                                        isFullscreen: _fullscreen,
                                        onToggleFullscreen: () => setState(
                                          () => _fullscreen = !_fullscreen,
                                        ),
                                      ),
                              ),

                              // Mini player: title, play/pause, close.
                              if (miniOpacity > 0)
                                Positioned(
                                  key: const ValueKey('mini-controls'),
                                  top: 0,
                                  left: videoWidth,
                                  right: 0,
                                  height: miniVideoHeight,
                                  child: Opacity(
                                    opacity: miniOpacity,
                                    child: _MiniControls(video: video),
                                  ),
                                ),

                              // Mini player: thin red progress line.
                              if (miniOpacity > 0)
                                Positioned(
                                  key: const ValueKey('mini-progress'),
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: 2,
                                  child: Opacity(
                                    opacity: miniOpacity,
                                    child: const _MiniProgress(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Title + channel, play/pause and close, to the right of the mini video.
class _MiniControls extends ConsumerWidget {
  const _MiniControls({required this.video});

  final Video? video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final controller = readyController(ref.watch(playbackProvider));

    return Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video?.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(color: colors.textPrimary),
              ),
              Text(
                video?.channelName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.meta.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        if (controller != null)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, v, _) => IconButton(
              tooltip: v.isPlaying ? 'Pause' : 'Play',
              onPressed: v.isPlaying ? controller.pause : controller.play,
              icon: Icon(
                v.isPlaying ? Symbols.pause : Symbols.play_arrow,
                fill: 1,
              ),
            ),
          ),
        IconButton(
          tooltip: 'Close',
          icon: const Icon(Symbols.close),
          onPressed: ref.read(playerPanelProvider.notifier).close,
        ),
      ],
    );
  }
}

class _MiniProgress extends ConsumerWidget {
  const _MiniProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = readyController(ref.watch(playbackProvider));
    if (controller == null) return const SizedBox.shrink();
    return PlayerProgressBar(controller: controller, interactive: false);
  }
}
