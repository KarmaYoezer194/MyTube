import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/format_views.dart';
import '../../../core/widgets/channel_avatar.dart';
import '../../../data/models/video.dart';

/// Opens when you tap the title on the watch page: likes, exact views,
/// upload date and the full description. Drag it up to make it taller.
Future<void> showDescriptionSheet(BuildContext context, Video video) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final colors = context.colors;
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Description',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Symbols.close),
                ),
              ],
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(video.title, style: AppTextStyles.watchTitle),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(
                        value: formatCompactCount(video.likes),
                        label: 'Likes',
                      ),
                      _Stat(
                        value: NumberFormat.decimalPattern().format(
                          video.views,
                        ),
                        label: 'Views',
                      ),
                      _Stat(
                        value: DateFormat('MMM d').format(video.createdAt),
                        label: DateFormat('y').format(video.createdAt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      video.description.isEmpty
                          ? 'No description.'
                          : video.description,
                      style: AppTextStyles.body.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ChannelAvatar(
                        name: video.channelName,
                        imageUrl: video.channelAvatarUrl,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.channelName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              formatSubscribers(video.subscriberCount),
                              style: AppTextStyles.meta.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.meta.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
