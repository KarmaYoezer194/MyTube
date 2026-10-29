// ONE-TIME SCRIPT: copies the 13 seed videos into YOUR Cloudinary account.
//
// Run it from the project folder:
//   dart run tool/upload_seed_media.dart              (all clips)
//   dart run tool/upload_seed_media.dart sintel tgv_passing   (only these)
//
// - archive.org clips: Cloudinary fetches them itself (nothing is
//   downloaded to your computer).
// - Wikimedia Commons clips: Wikimedia blocks Cloudinary's servers
//   ("429 Too Many Requests"), so these are downloaded to a temporary
//   folder on your computer first, uploaded, then deleted.
//
// Running it again is safe: unsigned uploads can't overwrite, so clips
// that already exist stay as they are.
//
// All clips are free to use. Their licenses and authors are credited in
// lib/data/seed/seed_videos.dart.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mytube/core/constants/cloudinary_config.dart';

const _commons = 'https://upload.wikimedia.org/wikipedia/commons/transcoded';

/// Seed key -> public source address.
const Map<String, String> sources = {
  // Blender open movies (Internet Archive, CC BY)
  'big_buck_bunny':
      'https://archive.org/download/BigBuckBunny_124/Content/big_buck_bunny_720p_surround.mp4',
  'elephants_dream':
      'https://archive.org/download/ElephantsDream/ed_1024_512kb.mp4',
  'sintel': 'https://archive.org/download/Sintel/sintel-2048-stereo_512kb.mp4',
  // Wikimedia Commons (smaller transcoded versions)
  'tears_of_steel':
      '$_commons/c/cb/Tears_of_Steel_1080p.webm/Tears_of_Steel_1080p.webm.360p.vp9.webm',
  'zeekr_x_review':
      '$_commons/a/af/2024_Zeekr_X_review-_Fast%2C_funky%2C_full-featured_%E2%80%94_time_to_go_Chinese-_-_MrChia_SG.webm/2024_Zeekr_X_review-_Fast%2C_funky%2C_full-featured_%E2%80%94_time_to_go_Chinese-_-_MrChia_SG.webm.360p.vp9.webm',
  'rally_drone_chase':
      '$_commons/a/ab/Aerial_drone_chase_of_rally_cars.webm/Aerial_drone_chase_of_rally_cars.webm.480p.vp9.webm',
  'snow_forest_drive':
      '$_commons/e/ea/Aerial_views_of_a_car_driving_in_snow_through_a_forest.webm/Aerial_views_of_a_car_driving_in_snow_through_a_forest.webm.480p.vp9.webm',
  'sherp_icebergs':
      '$_commons/9/91/Sherp_Off_Road_Vehicle_with_Jon_Bowe_Part_7_On_River_of_Icebergs.webm/Sherp_Off_Road_Vehicle_with_Jon_Bowe_Part_7_On_River_of_Icebergs.webm.360p.vp9.webm',
  'bund_fireworks':
      '$_commons/d/d3/Shanghai_Bund_fireworks_show_%2820250502_~_Video_1%29.webm/Shanghai_Bund_fireworks_show_%2820250502_~_Video_1%29.webm.480p.vp9.webm',
  'fire_juggling':
      '$_commons/2/28/Firejuggling_2009_ubt.ogv/Firejuggling_2009_ubt.ogv.480p.vp9.webm',
  'vettisfossen_waterfall':
      '$_commons/2/29/Vettisfossenvideo.webm/Vettisfossenvideo.webm.480p.vp9.webm',
  'tgv_passing':
      '$_commons/1/12/Passage_d%27un_TGV_en_Gare_de_Labenne.webm/Passage_d%27un_TGV_en_Gare_de_Labenne.webm.480p.vp9.webm',
  'magpies_calling':
      '$_commons/b/bf/Group_of_magpies_calling.webm/Group_of_magpies_calling.webm.480p.vp9.webm',
};

/// Wikimedia asks every program to say who it is.
const _userAgent = 'MyTubeStudentProject/1.0 (Flutter university demo)';

Future<void> main(List<String> args) async {
  if (cloudinaryCloudName.startsWith('YOUR_')) {
    stderr.writeln('First put your cloud name in '
        'lib/core/constants/cloudinary_config.dart');
    exit(1);
  }

  final keys = args.isEmpty ? sources.keys.toList() : args;
  final unknown = keys.where((k) => !sources.containsKey(k)).toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown clip(s): ${unknown.join(', ')}');
    exit(1);
  }

  final dio = Dio(BaseOptions(
    headers: {'User-Agent': _userAgent},
    // Big videos take a while.
    receiveTimeout: const Duration(minutes: 10),
    sendTimeout: const Duration(minutes: 10),
  ));
  final endpoint =
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/video/upload';
  final tempDir = await Directory.systemTemp.createTemp('mytube_seed_');
  var failures = 0;

  for (final key in keys) {
    final source = sources[key]!;
    stdout.write('Uploading $key ... ');
    try {
      final Object file;
      if (source.contains('wikimedia.org')) {
        // Download to our computer first, then send the file itself.
        final localPath = '${tempDir.path}${Platform.pathSeparator}$key.webm';
        // Short pause first: Wikimedia answers "429 Too Many Requests"
        // if we download several files back to back.
        await Future<void>.delayed(const Duration(seconds: 5));
        await dio.download(source, localPath);
        file = await MultipartFile.fromFile(localPath, filename: '$key.webm');
      } else {
        // Let Cloudinary fetch it directly.
        file = source;
      }

      final response = await dio.post<Map<String, dynamic>>(
        endpoint,
        data: FormData.fromMap({
          'file': file,
          'upload_preset': cloudinaryUploadPreset,
          'public_id': 'mytube/seed/$key',
        }),
      );
      final json = response.data!;
      final seconds = (json['duration'] as num?)?.round();
      final megabytes = ((json['bytes'] as num? ?? 0) / 1e6).toStringAsFixed(1);
      stdout.writeln('OK  .${json['format']}  ${seconds}s  ${megabytes}MB');
    } on DioException catch (error) {
      failures++;
      final data = error.response?.data;
      final message = data is Map ? (data['error']?['message']) : null;
      stdout.writeln('FAILED: ${message ?? error.message}');
    }
  }

  dio.close();
  await tempDir.delete(recursive: true);
  stdout.writeln(failures == 0
      ? '\nDone: ${keys.length} clip(s) are in Cloudinary.'
      : '\n$failures clip(s) failed. Run the script again with their names '
          'to retry them.');
}
