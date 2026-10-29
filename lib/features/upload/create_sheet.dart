import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import 'upload_flow.dart';

/// Opens the "Create" bottom sheet from the (+) button.
/// ("Go live" is left out on purpose: live streaming isn't part of the demo.)
Future<void> showCreateSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      void upload({required bool isShort}) {
        Navigator.pop(sheetContext);
        startUpload(context, ref, isShort: isShort);
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Create',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            _CreateOption(
              icon: Symbols.smart_display,
              label: 'Create a Short',
              onTap: () => upload(isShort: true),
            ),
            _CreateOption(
              icon: Symbols.upload,
              label: 'Upload a video',
              onTap: () => upload(isShort: false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        child: Icon(icon),
      ),
      title: Text(label),
      onTap: onTap,
    );
  }
}
