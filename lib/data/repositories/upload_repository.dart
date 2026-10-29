import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/cloudinary_config.dart';
import '../models/video.dart';
import 'video_repository.dart';

/// What Cloudinary sends back after a video upload.
class CloudinaryVideo {
  const CloudinaryVideo({
    required this.secureUrl,
    required this.publicId,
    required this.durationSeconds,
  });

  final String secureUrl;
  final String publicId;
  final int durationSeconds;
}

/// Uploads files to YOUR Cloudinary account (free plan) with the unsigned
/// preset, then saves the video in Firestore.
///
/// Why dio and not http: on Flutter web, dio reports real upload progress
/// (onSendProgress), so the progress bar can move smoothly.
class UploadRepository {
  UploadRepository(this._db, this._dio);

  final FirebaseFirestore _db;
  final Dio _dio;

  /// Keep demo uploads small (Cloudinary free plan allows up to 100 MB).
  static const int maxVideoBytes = 50 * 1024 * 1024;
  static const int maxImageBytes = 5 * 1024 * 1024;

  static const String _api =
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName';

  /// Thumbnail made by Cloudinary from the video itself:
  /// the frame at second 1, 640px wide, as a .jpg.
  static String videoThumbnailUrl(String publicId) =>
      'https://res.cloudinary.com/$cloudinaryCloudName/video/upload/'
      'so_1,w_640/$publicId.jpg';

  /// Uploads a video. [onProgress] gets 0.0 -> 1.0 while the file is being
  /// sent. After 1.0 Cloudinary still needs a moment to process it.
  Future<CloudinaryVideo> uploadVideo({
    required Uint8List bytes,
    required String filename,
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_api/video/upload',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        'upload_preset': cloudinaryUploadPreset,
      }),
      cancelToken: cancelToken,
      onSendProgress: (sent, total) {
        if (total > 0) onProgress(sent / total);
      },
    );
    final json = response.data!;
    return CloudinaryVideo(
      secureUrl: json['secure_url'] as String,
      publicId: json['public_id'] as String,
      durationSeconds: (json['duration'] as num?)?.round() ?? 0,
    );
  }

  /// Uploads a custom thumbnail picture and returns its address.
  Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_api/image/upload',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        'upload_preset': cloudinaryUploadPreset,
      }),
      cancelToken: cancelToken,
    );
    return response.data!['secure_url'] as String;
  }

  /// Saves the video in Firestore and returns its new id.
  ///
  /// Firestore saves it on this device immediately (so it shows up in the
  /// app at once) and sends it to the server in the background. We wait up
  /// to 15 seconds for the server; if the connection is slow we carry on,
  /// and Firestore finishes the sync by itself when it can.
  Future<String> saveVideo(Video video) async {
    final doc = _db.collection('videos').doc();
    try {
      await doc.set(video.toFirestore()).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      debugPrint('UPLOAD: Firestore is slow - saved on this device, '
          'it will sync when the connection recovers.');
    }
    return doc.id;
  }

  /// Turns a failed upload into a short message for the user.
  static String describeError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is Map) {
        // Cloudinary explains what went wrong, e.g. "File size too large".
        return '${(data['error'] as Map)['message']}';
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'No internet connection.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}

final uploadRepositoryProvider = Provider<UploadRepository>(
  (ref) => UploadRepository(ref.watch(firestoreProvider), Dio()),
);
