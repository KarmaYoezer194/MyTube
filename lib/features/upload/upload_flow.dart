import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/require_account.dart';
import '../../data/models/app_user.dart';
import '../../core/utils/upload_validation.dart';
import 'upload_screen.dart';

/// Everything the details screen needs: the picked file, its size, who is
/// uploading, and whether it's a Short.
class UploadDraft {
  const UploadDraft({
    required this.file,
    required this.sizeBytes,
    required this.author,
    required this.isShort,
  });

  final PlatformFile file;
  final int sizeBytes;
  final AppUser author;
  final bool isShort;
}

/// "Upload a video" / "Create a Short":
/// 1. guests can't upload: check for an account first (no waiting)
/// 2. pick a video file (straight after your tap, because browsers only
///    open the file picker right after a click)
/// 3. check its type and size (see core/utils/upload_validation.dart)
/// 4. load your profile (name, @handle) for the channel name
/// 5. open the details screen
///
/// Every step is printed in the `flutter run` terminal / browser console
/// ("UPLOAD: ...") and any error is shown on screen, never swallowed.
Future<void> startUpload(
  BuildContext context,
  WidgetRef ref, {
  required bool isShort,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  void showMessage(String text) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  if (!checkSignedIn(context, ref, reason: SignInReason.upload)) {
    debugPrint('UPLOAD: stopped - guests cannot upload');
    return;
  }

  try {
    debugPrint('UPLOAD: opening the file picker');
    final file = await FilePicker.pickFile(type: FileType.video);
    if (file == null) {
      debugPrint('UPLOAD: no file picked (cancelled)');
      return;
    }
    final size = await file.length() ?? 0;
    debugPrint('UPLOAD: picked ${file.name} ($size bytes)');

    final problem = checkVideoFile(fileName: file.name, sizeBytes: size);
    if (problem != null) {
      debugPrint('UPLOAD: refused - $problem');
      showMessage(problem);
      return;
    }

    // Let you know the file was received while we check your profile.
    showMessage('Preparing ${file.name}...');

    if (!context.mounted) return;
    final author = await loadMyProfile(context, ref);
    if (author == null) {
      debugPrint('UPLOAD: stopped - no profile');
      return;
    }
    debugPrint('UPLOAD: uploading as ${author.handle}, opening details');
    messenger.hideCurrentSnackBar();

    // A plain Navigator page (not a go_router address): the picked file
    // can't be put in a web address, so we hand it over directly.
    await navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => UploadScreen(
          draft: UploadDraft(
            file: file,
            sizeBytes: size,
            author: author,
            isShort: isShort,
          ),
        ),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('UPLOAD FAILED before the details screen: $error\n$stackTrace');
    showMessage('Upload problem: $error');
  }
}
