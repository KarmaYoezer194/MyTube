import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/repositories/video_repository.dart';
import '../upload/create_sheet.dart';
import '../watch/playback_controller.dart';
import 'shorts_providers.dart';
import 'widgets/short_page.dart';

/// Shorts tab: swipe up/down through full-screen vertical videos.
/// Always dark, even in light theme (like YouTube).
class ShortsScreen extends ConsumerStatefulWidget {
  const ShortsScreen({super.key, this.initialVideoId});

  /// Open at this Short (from the Shorts shelf on Home: `/shorts?v=<id>`).
  final String? initialVideoId;

  @override
  ConsumerState<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends ConsumerState<ShortsScreen> {
  final _pages = PageController();
  int _current = 0;

  /// A Short we still have to jump to once the list is loaded.
  String? _jumpToId;

  /// Was the Shorts tab visible last time we built?
  bool _wasVisible = false;

  @override
  void initState() {
    super.initState();
    _jumpToId = widget.initialVideoId;
  }

  @override
  void didUpdateWidget(ShortsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialVideoId != oldWidget.initialVideoId) {
      _jumpToId = widget.initialVideoId;
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Opened from the shelf: jump straight to the Short you tapped.
  void _jumpIfNeeded(List<String> ids) {
    final id = _jumpToId;
    if (id == null) return;
    _jumpToId = null;
    final index = ids.indexOf(id);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients) return;
      _pages.jumpToPage(index);
      setState(() => _current = index);
    });
  }

  @override
  Widget build(BuildContext context) {
    // go_router keeps hidden tabs alive but turns their "ticker mode" off.
    // That's how we know whether the Shorts tab is on screen.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_wasVisible) {
      // Entering Shorts: pause the normal video so two don't play at once.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => readyController(ref.read(playbackProvider))?.pause(),
      );
    }
    _wasVisible = visible;

    final shorts = ref.watch(shortsFeedProvider);
    final muted = ref.watch(playerMutedProvider);

    return Theme(
      data: AppTheme.dark(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            shorts.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (error, stackTrace) => EmptyState(
                icon: Symbols.cloud_off,
                title: "Couldn't load Shorts",
                message: 'Check your internet connection and try again.',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(allVideosProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Symbols.smart_display,
                    title: 'No Shorts yet',
                    message: 'Make the first one!',
                    actionLabel: 'Create a Short',
                    onAction: () => showCreateSheet(context, ref),
                  );
                }
                _jumpIfNeeded([for (final v in list) v.id]);
                return PageView.builder(
                  controller: _pages,
                  scrollDirection: Axis.vertical,
                  // Also builds the next/previous page in advance, so its
                  // video is already loading when you swipe.
                  allowImplicitScrolling: true,
                  itemCount: list.length,
                  onPageChanged: (index) => setState(() => _current = index),
                  itemBuilder: (context, index) => ShortPage(
                    key: ValueKey(list[index].id),
                    video: list[index],
                    isActive: visible && index == _current,
                  ),
                );
              },
            ),

            // ---- Top bar: mute and search ----
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: muted ? 'Unmute' : 'Mute',
                      onPressed: () => ref
                          .read(playerMutedProvider.notifier)
                          .setMuted(!muted),
                      icon: Icon(
                        muted ? Symbols.volume_off : Symbols.volume_up,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Search',
                      onPressed: () => context.go('/home/search'),
                      icon: const Icon(Symbols.search, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            // ---- Chrome starts videos muted: offer to unmute ----
            if (muted && (shorts.value?.isNotEmpty ?? false))
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: GestureDetector(
                      onTap: () => ref
                          .read(playerMutedProvider.notifier)
                          .setMuted(false),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Symbols.volume_off,
                              size: 18,
                              color: Colors.black,
                            ),
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
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
