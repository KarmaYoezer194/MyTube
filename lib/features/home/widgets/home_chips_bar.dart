import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/category_chip.dart';
import '../home_providers.dart';

/// The row of category chips under the Home top bar. It is the `bottom` of
/// the SliverAppBar, so it hides and snaps back together with the bar.
class HomeChipsBar extends ConsumerWidget implements PreferredSizeWidget {
  const HomeChipsBar({super.key});

  static const double height = 48;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);
    final controller = ref.read(selectedCategoryProvider.notifier);

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: homeCategories.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return CategoryChip(
              icon: Symbols.explore,
              label: 'Explore',
              selected: false,
              onTap: () => context.push('/home/explore'),
            );
          }
          final category = homeCategories[index - 1];
          return CategoryChip(
            label: category,
            selected: category == selected,
            onTap: () => controller.select(category),
          );
        },
      ),
    );
  }
}
