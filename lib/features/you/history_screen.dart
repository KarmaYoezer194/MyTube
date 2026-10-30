import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/compact_video_row.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../home/widgets/video_options_sheet.dart';
import '../settings/settings_providers.dart';
import 'history_groups.dart';
import 'you_providers.dart';

/// The History page: videos grouped by day (Today, Yesterday, ...), with
/// search, "Remove from watch history", Pause and Clear.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _remove(String videoId) async {
    try {
      await ref.read(userRepositoryProvider).removeFromHistory(videoId);
      _showMessage('Removed from watch history');
    } catch (_) {
      _showMessage("Couldn't remove it. Check your internet connection.");
    }
  }

  Future<void> _confirmClear() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear watch history?'),
        content: const Text(
          'Your history and the places where you stopped watching will be '
          'deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (clear != true) return;
    try {
      await ref.read(userRepositoryProvider).clearHistory();
      _showMessage('Watch history cleared');
    } catch (_) {
      _showMessage("Couldn't clear history. Check your connection.");
    }
  }

  void _setPaused(bool paused) {
    ref.read(historyPausedProvider.notifier).setPaused(paused);
    _showMessage(paused ? 'Watch history paused' : 'Watch history is on');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final history = ref.watch(historyVideosProvider);
    final paused = ref.watch(historyPausedProvider);
    final query = _search.text.trim();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (_searching) {
              setState(() {
                _searching = false;
                _search.clear();
              });
            } else {
              context.canPop() ? context.pop() : context.go('/you');
            }
          },
          icon: const Icon(Symbols.arrow_back),
        ),
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search watch history',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : const Text('History'),
        actions: [
          if (!_searching)
            IconButton(
              tooltip: 'Search watch history',
              onPressed: () => setState(() => _searching = true),
              icon: const Icon(Symbols.search),
            )
          else if (query.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: () => setState(_search.clear),
              icon: const Icon(Symbols.close),
            ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Symbols.more_vert),
            onSelected: (choice) => switch (choice) {
              'pause' => _setPaused(!paused),
              _ => _confirmClear(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pause',
                child: Text(
                  paused ? 'Turn on watch history' : 'Pause watch history',
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear all watch history'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (paused)
            Material(
              color: colors.surface,
              child: ListTile(
                leading: const Icon(Symbols.history_toggle_off),
                title: const Text('Watch history is paused'),
                subtitle: const Text("Videos you watch won't show up here."),
                trailing: TextButton(
                  onPressed: () => _setPaused(false),
                  child: const Text('Turn on'),
                ),
              ),
            ),
          Expanded(
            child: history.when(
              loading: () => ListView.builder(
                itemCount: 6,
                itemBuilder: (context, index) =>
                    const CompactVideoRowSkeleton(),
              ),
              error: (error, stackTrace) => EmptyState(
                icon: Symbols.cloud_off,
                title: "Couldn't load your history",
                message: 'Check your internet connection and try again.',
                actionLabel: 'Retry',
                onAction: () {
                  ref.invalidate(allVideosProvider);
                  ref.invalidate(historyEntriesProvider);
                },
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Symbols.history,
                    title: 'No watch history yet',
                    message: 'Videos you watch will show up here.',
                    actionLabel: 'Explore videos',
                    onAction: () => context.go('/home'),
                  );
                }
                final found = query.isEmpty
                    ? items
                    : [
                        for (final item in items)
                          if (matchesHistorySearch(item.video, query)) item,
                      ];
                if (found.isEmpty) {
                  return EmptyState(
                    icon: Symbols.search_off,
                    title: 'No results',
                    message: 'Nothing in your history matches "$query".',
                  );
                }
                final days = groupByDay(
                  found,
                  (item) => item.watchedAt ?? DateTime.now(),
                  DateTime.now(),
                );
                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final day in days) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          day.label,
                          style: AppTextStyles.sectionHeader.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      for (final item in day.items)
                        CompactVideoRow(
                          key: ValueKey(item.video.id),
                          video: item.video,
                          progress: item.progress,
                          menuActions: [
                            VideoMenuAction(
                              icon: Symbols.delete,
                              label: 'Remove from watch history',
                              onTap: () => _remove(item.video.id),
                            ),
                          ],
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
