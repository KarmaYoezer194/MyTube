import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/compact_video_row.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/paged_footer.dart';
import 'discovery_providers.dart';
import 'hidden_content.dart';

/// Explore: what's popular. "Trending" = the most viewed public videos;
/// the other chips narrow it to one category. Loads page by page.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  static const List<(String, IconData)> chips = [
    (trendingChip, Symbols.local_fire_department),
    ('Animation', Symbols.animation),
    ('Cars', Symbols.directions_car),
    ('Entertainment', Symbols.theater_comedy),
    ('Sci-Fi', Symbols.rocket_launch),
  ];

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String _chip = trendingChip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final page = ref.watch(trendingProvider(_chip));
    final controller = ref.read(trendingProvider(_chip).notifier);
    final taste = ref.watch(tasteProfileProvider);
    final videos = [
      for (final video in page.items)
        if (!taste.hides(video)) video,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Symbols.arrow_back),
        ),
        title: const Text('Explore'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(trendingProvider(_chip)),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => loadMoreWhenNearEnd(n, controller.loadMore),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: ExploreScreen.chips.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final (label, icon) = ExploreScreen.chips[index];
                      return CategoryChip(
                        icon: icon,
                        label: label,
                        selected: label == _chip,
                        onTap: () => setState(() => _chip = label),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    _chip == trendingChip
                        ? 'Most viewed on MyTube'
                        : 'Most viewed in $_chip',
                    style: AppTextStyles.sectionHeader.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (page.isFirstLoad)
                SliverList.builder(
                  itemCount: 6,
                  itemBuilder: (context, index) =>
                      const CompactVideoRowSkeleton(),
                )
              else if (page.items.isEmpty && page.error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Symbols.cloud_off,
                    title: "Couldn't load videos",
                    message: 'Check your internet connection and try again.',
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(trendingProvider(_chip)),
                  ),
                )
              else if (videos.isEmpty && !page.hasMore)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Symbols.explore,
                    title: 'Nothing here yet',
                    message: 'Try another chip.',
                  ),
                )
              else ...[
                SliverList.builder(
                  itemCount: videos.length,
                  itemBuilder: (context, index) => _RankedRow(
                    key: ValueKey(videos[index].id),
                    rank: index + 1,
                    child: CompactVideoRow(video: videos[index]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: PagedFooter(page: page, onRetry: controller.loadMore),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "#1", "#2", ... in front of a row.
class _RankedRow extends StatelessWidget {
  const _RankedRow({super.key, required this.rank, required this.child});

  final int rank;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            '#$rank',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
