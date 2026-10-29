import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the player panel is doing right now.
///
/// - closed:   nothing is playing ([videoId] is null)
/// - expanded: the full watch page covers the screen
/// - mini:     the small player sits above the bottom nav
@immutable
class PlayerPanelState {
  const PlayerPanelState({
    this.videoId,
    this.isExpanded = false,
    this.previousIds = const [],
  });

  final String? videoId;
  final bool isExpanded;

  /// Videos watched before this one (newest last), for the ⏮ button.
  final List<String> previousIds;

  bool get isOpen => videoId != null;
  bool get isMini => isOpen && !isExpanded;
  bool get hasPrevious => previousIds.isNotEmpty;
}

/// Opens, shrinks, expands and closes the player panel.
///
/// The panel lives in the app shell ABOVE the tabs, so the video keeps
/// playing while you switch tabs.
class PlayerPanelController extends Notifier<PlayerPanelState> {
  @override
  PlayerPanelState build() => const PlayerPanelState();

  /// Start watching a video (opens the full watch page).
  /// The video that was playing before is remembered for ⏮.
  void open(String videoId) {
    final current = state.videoId;
    if (current == videoId) {
      expand();
      return;
    }
    state = PlayerPanelState(
      videoId: videoId,
      isExpanded: true,
      // `?current` adds it only if it isn't null.
      previousIds: [...state.previousIds, ?current],
    );
  }

  /// Play another video but stay as you are (full page or mini player).
  /// Used by ⏭ and autoplay.
  void switchTo(String videoId) {
    final current = state.videoId;
    if (current == null || current == videoId) return;
    state = PlayerPanelState(
      videoId: videoId,
      isExpanded: state.isExpanded,
      previousIds: [...state.previousIds, current],
    );
  }

  /// Go back to the video watched before this one.
  void openPrevious() {
    if (!state.hasPrevious) return;
    final previous = [...state.previousIds];
    final id = previous.removeLast();
    state = PlayerPanelState(
      videoId: id,
      isExpanded: state.isExpanded,
      previousIds: previous,
    );
  }

  /// Shrink to the mini player.
  void minimize() {
    if (!state.isOpen) return;
    state = PlayerPanelState(
      videoId: state.videoId,
      isExpanded: false,
      previousIds: state.previousIds,
    );
  }

  /// Grow back to the full watch page.
  void expand() {
    if (!state.isOpen) return;
    state = PlayerPanelState(
      videoId: state.videoId,
      isExpanded: true,
      previousIds: state.previousIds,
    );
  }

  /// Stop and remove the player.
  void close() {
    state = const PlayerPanelState();
  }
}

final playerPanelProvider =
    NotifierProvider<PlayerPanelController, PlayerPanelState>(
      PlayerPanelController.new,
    );
