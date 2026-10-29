import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/user_repository.dart';

/// Makes sure the user has a name before they comment or upload.
///
/// - Already has a profile: returns it straight away.
/// - First time: asks "Choose your name", creates users/{uid} with a
///   generated @handle and returns it.
/// - Cancelled: returns null (so the caller does nothing).
Future<AppUser?> ensureProfile(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);

  // Read the profile straight from Firestore, once.
  // (Not `ref.read(myProfileProvider.future)`: in Riverpod 3 a provider that
  // no widget is watching is paused, so that future would never finish.)
  // Don't wait forever if Firestore can't be reached.
  final AppUser? existing;
  try {
    existing = await ref
        .read(userRepositoryProvider)
        .getProfile()
        .timeout(const Duration(seconds: 10));
  } catch (error) {
    debugPrint('PROFILE: could not load your profile: $error');
    messenger.showSnackBar(const SnackBar(
      content: Text("Can't reach the database. Check your internet "
          'connection and try again.'),
    ));
    return null;
  }
  if (existing != null) return existing;
  if (!context.mounted) return null;

  final name = await showDialog<String>(
    context: context,
    builder: (_) => const _ChooseNameDialog(),
  );
  if (name == null) return null;
  return ref.read(userRepositoryProvider).createProfile(name);
}

class _ChooseNameDialog extends StatefulWidget {
  const _ChooseNameDialog();

  @override
  State<_ChooseNameDialog> createState() => _ChooseNameDialogState();
}

class _ChooseNameDialogState extends State<_ChooseNameDialog> {
  final _controller = TextEditingController();

  bool get _valid => _controller.text.trim().length >= 2;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_valid) Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose your name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This is how other people will see you on MyTube.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 30,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Your name'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _valid ? _submit : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
