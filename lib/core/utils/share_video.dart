import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/video.dart';
import 'app_links.dart';

/// Share = copy the video's MyTube link (e.g. ".../#/watch?v=sintel"; a
/// Short gets ".../#/shorts/ID"). Opening it plays the video, even after
/// a refresh.
Future<void> shareVideo(ScaffoldMessengerState messenger, Video video) =>
    copyLink(messenger, appLink(videoPath(video)));

/// Copies [link] and says so.
Future<void> copyLink(ScaffoldMessengerState messenger, String link) async {
  try {
    await Clipboard.setData(ClipboardData(text: link));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Link copied')));
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: SelectableText(link)));
  }
}
