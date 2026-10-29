import 'package:flutter_test/flutter_test.dart';
import 'package:mytube/core/utils/upload_validation.dart';

void main() {
  group('fileExtension', () {
    test('lower-cases the extension', () {
      expect(fileExtension('Clip.MOV'), 'mov');
      expect(fileExtension('my.holiday.mp4'), 'mp4');
    });

    test('is empty without an extension', () {
      expect(fileExtension('video'), '');
      expect(fileExtension('video.'), '');
    });
  });

  group('checkVideoFile', () {
    test('accepts allowed formats under 50 MB', () {
      for (final name in ['a.mp4', 'b.MOV', 'c.webm', 'd.m4v']) {
        expect(checkVideoFile(fileName: name, sizeBytes: 1000), isNull);
      }
    });

    test('refuses other formats', () {
      expect(checkVideoFile(fileName: 'a.avi', sizeBytes: 1000), isNotNull);
      expect(checkVideoFile(fileName: 'a.exe', sizeBytes: 1000), isNotNull);
      expect(checkVideoFile(fileName: 'noext', sizeBytes: 1000), isNotNull);
    });

    test('refuses empty and too big files', () {
      expect(checkVideoFile(fileName: 'a.mp4', sizeBytes: 0), isNotNull);
      expect(
        checkVideoFile(
          fileName: 'a.mp4',
          sizeBytes: UploadLimits.maxVideoBytes + 1,
        ),
        contains('under 50 MB'),
      );
      expect(
        checkVideoFile(
          fileName: 'a.mp4',
          sizeBytes: UploadLimits.maxVideoBytes,
        ),
        isNull,
      );
    });
  });

  group('checkImageFile', () {
    test('accepts pictures under 5 MB', () {
      for (final name in ['a.jpg', 'b.JPEG', 'c.png', 'd.webp']) {
        expect(checkImageFile(fileName: name, sizeBytes: 1000), isNull);
      }
    });

    test('refuses other formats and big files', () {
      expect(checkImageFile(fileName: 'a.gif', sizeBytes: 1000), isNotNull);
      expect(checkImageFile(fileName: 'a.svg', sizeBytes: 1000), isNotNull);
      expect(
        checkImageFile(
          fileName: 'a.png',
          sizeBytes: UploadLimits.maxImageBytes + 1,
        ),
        isNotNull,
      );
    });
  });

  group('checkVideoLength', () {
    test('unknown length (0) is allowed', () {
      expect(checkVideoLength(seconds: 0, isShort: true), isNull);
      expect(checkVideoLength(seconds: 0, isShort: false), isNull);
    });

    test('Shorts are up to 60 seconds', () {
      expect(checkVideoLength(seconds: 60, isShort: true), isNull);
      expect(checkVideoLength(seconds: 61, isShort: true), isNull);
      expect(
        checkVideoLength(seconds: 75, isShort: true),
        'Shorts can be up to 60 seconds long. This video is 1:15.',
      );
    });

    test('videos are up to 15 minutes', () {
      expect(checkVideoLength(seconds: 900, isShort: false), isNull);
      expect(checkVideoLength(seconds: 901, isShort: false), contains('15:01'));
    });
  });
}
