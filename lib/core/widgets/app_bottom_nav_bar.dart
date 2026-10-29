import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

/// One item in the bottom bar.
class _NavItemData {
  const _NavItemData(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// YouTube-style bottom bar: Home, Shorts, (+), Subscriptions, You.
///
/// Icons are OUTLINED when not selected and smoothly fill in when selected.
/// [forceDark] makes the bar black with white icons (used on the Shorts tab).
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.forceDark = false,
    this.youAvatar,
  });

  /// Index of the selected item (0..4). The Create button (2) is never
  /// "selected" because it opens a sheet instead of a tab.
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool forceDark;

  /// When signed in: your small avatar replaces the "You" icon (like
  /// YouTube). null for guests (the normal person icon).
  final Widget? youAvatar;

  static const int createIndex = 2;
  static const int youIndex = 4;
  static const double height = 52;

  /// The real height on screen, including the phone's bottom safe area
  /// (the home-indicator strip on iPhones; 0 in Chrome).
  static double totalHeight(BuildContext context) =>
      height + MediaQuery.paddingOf(context).bottom;

  static const _items = [
    _NavItemData(Symbols.home, 'Home'),
    _NavItemData(Symbols.smart_display, 'Shorts'),
    _NavItemData(Symbols.add, ''), // Create (+), drawn differently
    _NavItemData(Symbols.subscriptions, 'Subscriptions'),
    _NavItemData(Symbols.account_circle, 'You'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = forceDark ? AppColors.dark : context.colors;
    final background = forceDark ? Colors.black : colors.background;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: totalHeight(context),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: background,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: i == createIndex
                  ? _CreateButton(colors: colors, onTap: () => onTap(i))
                  : _NavItem(
                      data: _items[i],
                      selected: i == selectedIndex,
                      colors: colors,
                      onTap: () => onTap(i),
                      avatar: i == youIndex ? youAvatar : null,
                    ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.colors,
    required this.onTap,
    this.avatar,
  });

  final _NavItemData data;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  /// Shown instead of the icon (the "You" item when signed in).
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 32,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (avatar != null)
            // Your avatar, with a ring around it when the tab is selected.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.textPrimary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: FittedBox(child: avatar),
            )
          else
            // Animates the icon "fill" from 0 (outlined) to 1 (filled).
            TweenAnimationBuilder<double>(
              tween: Tween(end: selected ? 1 : 0),
              duration: const Duration(milliseconds: 200),
              builder: (context, fill, _) => Icon(
                data.icon,
                fill: fill,
                size: 24,
                color: colors.textPrimary,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.navLabel.copyWith(
              color: colors.textPrimary,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// The round (+) button in the middle.
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.colors, required this.onTap});

  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Symbols.add,
            size: 30,
            weight: 300,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
