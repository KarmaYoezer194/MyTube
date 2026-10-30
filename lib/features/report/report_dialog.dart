import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video.dart';
import '../../data/repositories/report_repository.dart';
import '../auth/require_account.dart';

/// ⋮ → Report: pick a reason (and optionally say more), then it is saved
/// as a report document. Guests get the "Sign in to …" sheet; each person
/// can report a video once.
Future<void> reportVideo(
  BuildContext context,
  WidgetRef ref,
  Video video,
) async {
  if (!checkSignedIn(context, ref, reason: SignInReason.report)) return;
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(reportRepositoryProvider);

  void show(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  try {
    if (await repository.hasReported(video.id)) {
      show('You already reported this video. Thanks!');
      return;
    }
  } catch (_) {
    // Can't check (offline?): just try to send it below.
  }
  if (!context.mounted) return;

  final result = await showDialog<({String reason, String details})>(
    context: context,
    builder: (_) => const _ReportDialog(),
  );
  if (result == null) return;
  try {
    await repository
        .report(
          videoId: video.id,
          reason: result.reason,
          details: result.details,
        )
        .timeout(const Duration(seconds: 15));
    show('Thanks for reporting. We got your report.');
  } catch (_) {
    show("Couldn't send the report. Check your internet connection.");
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _reason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report video'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: RadioGroup<String>(
            groupValue: _reason,
            onChanged: (value) => setState(() => _reason = value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in reportReasons.entries)
                  RadioListTile<String>(
                    dense: true,
                    value: entry.key,
                    title: Text(entry.value),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: TextField(
                    controller: _details,
                    maxLength: 500,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: 'More details (optional)',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _reason == null
              ? null
              : () => Navigator.pop(context, (
                  reason: _reason!,
                  details: _details.text,
                )),
          child: const Text('Report'),
        ),
      ],
    );
  }
}
