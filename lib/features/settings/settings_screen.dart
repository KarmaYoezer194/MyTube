import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/user_repository.dart';
import 'settings_providers.dart';

/// Settings: Appearance (device / dark / light), Autoplay, Clear watch
/// history, and an About section with the video credits.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Use device theme',
        ThemeMode.dark => 'Dark theme',
        ThemeMode.light => 'Light theme',
      };

  Future<void> _chooseAppearance(BuildContext context, WidgetRef ref) {
    final controller = ref.read(themeModeProvider.notifier);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Appearance'),
        contentPadding: const EdgeInsets.only(top: 12, bottom: 8),
        content: RadioGroup<ThemeMode>(
          groupValue: ref.read(themeModeProvider),
          onChanged: (mode) {
            if (mode != null) controller.setMode(mode);
            Navigator.pop(dialogContext);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in [
                ThemeMode.system,
                ThemeMode.dark,
                ThemeMode.light,
              ])
                RadioListTile<ThemeMode>(
                  value: mode,
                  title: Text(_themeLabel(mode)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
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
    if (!(clear ?? false)) return;
    try {
      await ref.read(userRepositoryProvider).clearHistory();
      messenger.showSnackBar(
        const SnackBar(content: Text('Watch history cleared')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't clear history. Check your connection."),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final themeMode = ref.watch(themeModeProvider);
    final autoplay = ref.watch(autoplayProvider);

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(
            text,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/you'),
          icon: const Icon(Symbols.arrow_back),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          sectionTitle('General'),
          ListTile(
            leading: const Icon(Symbols.contrast),
            title: const Text('Appearance'),
            subtitle: Text(_themeLabel(themeMode)),
            onTap: () => _chooseAppearance(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Symbols.autoplay),
            title: const Text('Autoplay'),
            subtitle: const Text('Play the next video when one ends'),
            value: autoplay,
            onChanged: ref.read(autoplayProvider.notifier).setEnabled,
          ),

          sectionTitle('History & privacy'),
          ListTile(
            leading: const Icon(Symbols.delete_sweep),
            title: const Text('Clear watch history'),
            subtitle: const Text('Also forgets where you stopped watching'),
            onTap: () => _clearHistory(context, ref),
          ),

          sectionTitle('About'),
          const ListTile(
            leading: Icon(Symbols.info),
            title: Text('MyTube'),
            subtitle: Text(
              'A university demo app built with Flutter, Firebase and '
              'Cloudinary. Not affiliated with any real video platform.',
            ),
          ),
          const ListTile(
            leading: Icon(Symbols.copyright),
            title: Text('Video credits'),
            subtitle: Text(
              'Big Buck Bunny, Elephants Dream, Sintel and Tears of Steel: '
              '© Blender Foundation (CC BY). Other sample clips: Wikimedia '
              'Commons contributors (CC BY / CC BY-SA), credited in each '
              "video's description.",
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
