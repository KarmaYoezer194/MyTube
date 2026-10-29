import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/video.dart';

/// Opens the system share sheet for a video. If sharing isn't possible,
/// copies the link instead and says so.
Future<void> shareVideo(ScaffoldMessengerState messenger, Video video) async {
  final text = '${video.title}\n${video.videoUrl}';
  try {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: video.title),
    );
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Link copied')));
  }
}
