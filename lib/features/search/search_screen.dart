import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/compact_video_row.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/repositories/video_repository.dart';
import 'search_providers.dart';

/// Search: type in the box to see recent searches and suggestions; press
/// Enter (or tap a suggestion) to see the results.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  /// The search that was submitted. null = still typing (show suggestions).
  String? _query;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String text) {
    final query = text.trim();
    if (query.isEmpty) return;
    ref.read(recentSearchesProvider.notifier).add(query);
    _input.text = query;
    _focus.unfocus();
    setState(() => _query = query);
  }

  /// The ↖ arrow: put the text in the box without searching yet.
  void _fillIn(String text) {
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focus.requestFocus();
    setState(() {});
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _confirmRemove(String query) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(query),
        content: const Text('Remove from search history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove ?? false) {
      ref.read(recentSearchesProvider.notifier).remove(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _back,
          icon: const Icon(Symbols.arrow_back),
        ),
        title: TextField(
          controller: _input,
          focusNode: _focus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: _submit,
          // Typing again = back to suggestions.
          onChanged: (_) => setState(() => _query = null),
          onTap: () => setState(() => _query = null),
          decoration: InputDecoration(
            hintText: 'Search MyTube',
            isDense: true,
            filled: true,
            fillColor: colors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            suffixIcon: _input.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    onPressed: () {
                      _input.clear();
                      _focus.requestFocus();
                      setState(() => _query = null);
                    },
                    icon: const Icon(Symbols.close, size: 20),
                  ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: IconButton.filled(
              tooltip: 'Search with your voice',
              style: IconButton.styleFrom(
                backgroundColor: colors.surface,
                foregroundColor: colors.textPrimary,
              ),
              onPressed: () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Voice search is not available in this demo'),
                  ),
                ),
              icon: const Icon(Symbols.mic),
            ),
          ),
        ],
      ),
      body: _query == null ? _buildSuggestions() : _buildResults(_query!),
    );
  }

  /// While typing: matching recent searches (🕘) + suggestions (🔍).
  Widget _buildSuggestions() {
    final typed = _input.text.trim().toLowerCase();
    final recents = ref
        .watch(recentSearchesProvider)
        .where((s) => s.toLowerCase().contains(typed))
        .toList();
    final videos = ref.watch(allVideosProvider).value ?? const [];
    final suggestions = searchSuggestions(videos, typed)
        .where((s) => !recents.any((r) => r.toLowerCase() == s.toLowerCase()))
        .toList();

    if (recents.isEmpty && suggestions.isEmpty) {
      return typed.isEmpty
          ? const EmptyState(
              icon: Symbols.search,
              title: 'Search MyTube',
              message: 'Find videos by title, channel or category.',
            )
          : const SizedBox.shrink();
    }

    return ListView(
      children: [
        for (final text in recents)
          _SuggestionTile(
            icon: Symbols.history,
            text: text,
            onTap: () => _submit(text),
            onFillIn: () => _fillIn(text),
            onLongPress: () => _confirmRemove(text),
          ),
        for (final text in suggestions)
          _SuggestionTile(
            icon: Symbols.search,
            text: text,
            onTap: () => _submit(text),
            onFillIn: () => _fillIn(text),
          ),
      ],
    );
  }

  /// After searching: the matching videos as compact rows.
  Widget _buildResults(String query) {
    return ref
        .watch(allVideosProvider)
        .when(
          loading: () => ListView.builder(
            itemCount: 6,
            itemBuilder: (context, index) => const CompactVideoRowSkeleton(),
          ),
          error: (error, stackTrace) => EmptyState(
            icon: Symbols.cloud_off,
            title: "Couldn't search",
            message: 'Check your internet connection and try again.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(allVideosProvider),
          ),
          data: (videos) {
            final results = searchVideos(videos, query);
            if (results.isEmpty) {
              return EmptyState(
                icon: Symbols.search_off,
                title: 'No results found',
                message: 'Try different keywords for "$query".',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              itemCount: results.length,
              itemBuilder: (context, index) => CompactVideoRow(
                key: ValueKey(results[index].id),
                video: results[index],
              ),
            );
          },
        );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.text,
    required this.onTap,
    required this.onFillIn,
    this.onLongPress,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final VoidCallback onFillIn;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: 'Edit "$text"',
        onPressed: onFillIn,
        icon: const Icon(Symbols.north_west),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
