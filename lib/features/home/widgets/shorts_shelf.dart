import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/format_views.dart';
import '../../../core/widgets/network_thumbnail.dart';
import '../../../data/models/video.dart';

/// The "Shorts" row on Home: tall 9:16 cards you scroll sideways.
/// About two cards fit on screen, like on YouTube.
class ShortsShelf extends StatelessWidget {
  const ShortsShelf({super.key, required this.shorts});

  final List<Video> shorts;

  static const double _sidePadding = 12;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider, width: 4)),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(_sidePadding, 0, 12, 12),
            child: Row(
              children: [
                const Icon(
                  Symbols.smart_display,
                  fill: 1,
                  size: 28,
                  color: AppColors.brandRed,
                ),
                const SizedBox(width: 8),
                Text(
                  'Shorts',
                  style: AppTextStyles.sectionHeader.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth =
                  (constraints.maxWidth - _sidePadding * 2 - _gap) / 2;
              return SizedBox(
                height: cardWidth * 16 / 9,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
                  itemCount: shorts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: _gap),
                  itemBuilder: (context, index) =>
                      _ShortCard(video: shorts[index], width: cardWidth),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShortCard extends StatelessWidget {
  const _ShortCard({required this.video, required this.width});

  final Video video;
  final double width;

  static const _shadow = [Shadow(blurRadius: 4, color: Colors.black54)];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Opens the Shorts tab at this exact Short.
      onTap: () => context.go('/shorts?v=${video.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              NetworkThumbnail(url: video.thumbnailUrl),
              // Dark fade at the bottom so the white text is readable.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.55, 1],
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              const Positioned(
                top: 6,
                right: 2,
                child: Icon(
                  Symbols.more_vert,
                  color: Colors.white,
                  size: 20,
                  shadows: _shadow,
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        shadows: _shadow,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatViews(video.views),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        shadows: _shadow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
