import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/format_views.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/channel_avatar.dart';
import '../../core/widgets/compact_video_row.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/paged_footer.dart';
import '../../core/widgets/subscribe_button.dart';
import '../../data/models/channel.dart';
import '../../data/models/video.dart';
import '../../data/repositories/video_repository.dart';
import '../channel/channel_navigation.dart';
import '../discovery/discovery_providers.dart';
import '../discovery/hidden_content.dart';
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

  SearchFilter _filter = SearchFilter.all;
  SearchSort _sort = SearchSort.relevance;

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
    final taste = ref.watch(tasteProfileProvider);
    final videos = [
      for (final video in ref.watch(allVideosProvider).value ?? const <Video>[])
        if (!taste.hides(video)) video,
    ];
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

  /// After searching: filter chips + sort, then channels and videos,
  /// loaded page by page from Firestore.
  Widget _buildResults(String query) {
    final colors = context.colors;
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  children: [
                    for (final filter in SearchFilter.values) ...[
                      CategoryChip(
                        label: switch (filter) {
                          SearchFilter.all => 'All',
                          SearchFilter.videos => 'Videos',
                          SearchFilter.shorts => 'Shorts',
                          SearchFilter.channels => 'Channels',
                        },
                        selected: _filter == filter,
                        onTap: () => setState(() => _filter = filter),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              if (_filter != SearchFilter.channels)
                PopupMenuButton<SearchSort>(
                  tooltip: 'Sort by',
                  initialValue: _sort,
                  icon: Icon(Symbols.tune, color: colors.textPrimary),
                  onSelected: (sort) => setState(() => _sort = sort),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: SearchSort.relevance,
                      child: Text('Relevance'),
                    ),
                    PopupMenuItem(
                      value: SearchSort.date,
                      child: Text('Upload date'),
                    ),
                    PopupMenuItem(
                      value: SearchSort.views,
                      child: Text('View count'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: _filter == SearchFilter.channels
              ? _channelResults(query)
              : _videoResults(query),
        ),
      ],
    );
  }

  Widget _channelResults(String query) {
    return ref
        .watch(searchChannelsProvider(query))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => EmptyState(
            icon: Symbols.cloud_off,
            title: "Couldn't search channels",
            message: 'Check your internet connection and try again.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(searchChannelsProvider(query)),
          ),
          data: (channels) => channels.isEmpty
              ? EmptyState(
                  icon: Symbols.search_off,
                  title: 'No channels found',
                  message: 'No channel name or handle starts with "$query".',
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    for (final channel in channels)
                      ChannelResultRow(
                        key: ValueKey(channel.id),
                        channel: channel,
                      ),
                  ],
                ),
        );
  }

  Widget _videoResults(String query) {
    final arg = (query: query, filter: _filter, sort: _sort);
    final page = ref.watch(searchVideosProvider(arg));
    final controller = ref.read(searchVideosProvider(arg).notifier);
    final videos = visibleSearchResults(
      page.items,
      query,
      _sort,
      ref.watch(tasteProfileProvider),
    );
    // "All" also shows the best matching channels on top.
    final channels = _filter == SearchFilter.all
        ? (ref.watch(searchChannelsProvider(query)).value ?? const <Channel>[])
              .take(2)
              .toList()
        : const <Channel>[];

    // A page where nothing matched every word: load the next one.
    if (videos.isEmpty &&
        page.items.isNotEmpty &&
        page.hasMore &&
        !page.isLoading &&
        page.error == null) {
      Future.microtask(controller.loadMore);
    }

    if (page.isFirstLoad) {
      return ListView.builder(
        itemCount: 6,
        itemBuilder: (context, index) => const CompactVideoRowSkeleton(),
      );
    }
    if (page.items.isEmpty && page.error != null) {
      return EmptyState(
        icon: Symbols.cloud_off,
        title: "Couldn't search",
        message: 'Check your internet connection and try again.',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(searchVideosProvider(arg)),
      );
    }
    if (videos.isEmpty && channels.isEmpty && !page.hasMore) {
      return EmptyState(
        icon: Symbols.search_off,
        title: 'No results found',
        message: 'Try different keywords for "$query".',
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) => loadMoreWhenNearEnd(n, controller.loadMore),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final channel in channels)
            ChannelResultRow(key: ValueKey(channel.id), channel: channel),
          if (channels.isNotEmpty) const Divider(),
          for (final video in videos)
            CompactVideoRow(key: ValueKey(video.id), video: video),
          PagedFooter(page: page, onRetry: controller.loadMore),
        ],
      ),
    );
  }
}

/// A channel in the search results: avatar, name, @handle · subscribers,
/// Subscribe. Tap = the channel page.
class ChannelResultRow extends ConsumerWidget {
  const ChannelResultRow({super.key, required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return InkWell(
      onTap: () => openChannel(context, ref, channel.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          children: [
            ChannelAvatar(
              name: channel.name,
              imageUrl: channel.avatarUrl,
              color: channel.avatarColorValue,
              size: 56,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.videoTitle.copyWith(
                      fontSize: 15,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '${channel.handle} · '
                    '${formatSubscribers(channel.subscriberCount)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.meta.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SubscribeButton(channelId: channel.id, channelName: channel.name),
          ],
        ),
      ),
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
