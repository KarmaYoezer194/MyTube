import 'dart:typed_data';

/// Reads a video's length (in seconds) straight from an .mp4 / .mov file.
///
/// Why: some files (screen recordings, some editors) are "fragmented" MP4s.
/// Their header says the length is 0, the video is stored in small pieces,
/// and browsers then guess a wrong length (e.g. "0:03" for a 3-minute
/// video). Here we add up the pieces ourselves.
///
/// Returns 0 if the file isn't an MP4 or can't be read.
int mp4LengthSeconds(Uint8List bytes) {
  try {
    final data = ByteData.sublistView(bytes);
    final timescales = <int, int>{}; // track id -> ticks per second
    final defaultSampleTime = <int, int>{}; // track id -> ticks per frame
    var headerSeconds = 0.0; // length written in the header (0 if fragmented)
    final ends = <int, int>{}; // track id -> last tick seen in the pieces

    for (final box in _boxes(data, 0, data.lengthInBytes)) {
      if (box.type == 'moov') {
        for (final b in _boxes(data, box.start, box.end)) {
          if (b.type == 'mvhd') {
            final v1 = data.getUint8(b.start) == 1;
            final scale = data.getUint32(b.start + (v1 ? 20 : 12));
            final dur = v1
                ? _uint64(data, b.start + 24)
                : data.getUint32(b.start + 16);
            if (scale > 0) headerSeconds = dur / scale;
          } else if (b.type == 'trak') {
            int? trackId;
            for (final t in _boxes(data, b.start, b.end)) {
              if (t.type == 'tkhd') {
                final v1 = data.getUint8(t.start) == 1;
                trackId = data.getUint32(t.start + (v1 ? 20 : 12));
              } else if (t.type == 'mdia' && trackId != null) {
                for (final m in _boxes(data, t.start, t.end)) {
                  if (m.type == 'mdhd') {
                    final v1 = data.getUint8(m.start) == 1;
                    timescales[trackId] = data.getUint32(
                      m.start + (v1 ? 20 : 12),
                    );
                  }
                }
              }
            }
          } else if (b.type == 'mvex') {
            for (final t in _boxes(data, b.start, b.end)) {
              if (t.type == 'trex') {
                defaultSampleTime[data.getUint32(t.start + 4)] = data.getUint32(
                  t.start + 12,
                );
              }
            }
          }
        }
      } else if (box.type == 'moof') {
        for (final traf in _boxes(data, box.start, box.end)) {
          if (traf.type != 'traf') continue;
          int? trackId;
          int? sampleTime;
          var base = 0;
          var total = 0;
          for (final b in _boxes(data, traf.start, traf.end)) {
            final flags = data.getUint32(b.start) & 0xFFFFFF;
            if (b.type == 'tfhd') {
              trackId = data.getUint32(b.start + 4);
              var p = b.start + 8;
              if (flags & 0x1 != 0) p += 8;
              if (flags & 0x2 != 0) p += 4;
              if (flags & 0x8 != 0) sampleTime = data.getUint32(p);
            } else if (b.type == 'tfdt') {
              base = data.getUint8(b.start) == 1
                  ? _uint64(data, b.start + 4)
                  : data.getUint32(b.start + 4);
            } else if (b.type == 'trun') {
              final count = data.getUint32(b.start + 4);
              var p = b.start + 8;
              if (flags & 0x1 != 0) p += 4;
              if (flags & 0x4 != 0) p += 4;
              for (var i = 0; i < count; i++) {
                if (flags & 0x100 != 0) {
                  total += data.getUint32(p);
                  p += 4;
                } else {
                  total += sampleTime ?? defaultSampleTime[trackId] ?? 0;
                }
                if (flags & 0x200 != 0) p += 4;
                if (flags & 0x400 != 0) p += 4;
                if (flags & 0x800 != 0) p += 4;
              }
            }
          }
          if (trackId != null) {
            final end = base + total;
            if (end > (ends[trackId] ?? 0)) ends[trackId] = end;
          }
        }
      }
    }

    // The longest of: the header, and every track's pieces.
    var seconds = headerSeconds;
    ends.forEach((trackId, end) {
      final scale = timescales[trackId] ?? 0;
      if (scale > 0 && end / scale > seconds) seconds = end / scale;
    });
    return seconds.round();
  } catch (_) {
    return 0; // Not an MP4, or a file we don't understand.
  }
}

class _Box {
  const _Box(this.type, this.start, this.end);
  final String type;
  final int start; // where the box's content starts
  final int end; // where the box ends
}

/// The boxes ("atoms") an MP4 is made of, between [from] and [to].
Iterable<_Box> _boxes(ByteData data, int from, int to) sync* {
  var i = from;
  while (i + 8 <= to) {
    var size = data.getUint32(i);
    var header = 8;
    if (size == 1) {
      size = _uint64(data, i + 8);
      header = 16;
    } else if (size == 0) {
      size = to - i;
    }
    if (size < header || i + size > to) return;
    final type = String.fromCharCodes([
      for (var k = 4; k < 8; k++) data.getUint8(i + k),
    ]);
    yield _Box(type, i + header, i + size);
    i += size;
  }
}

/// 64-bit number (works on the web too, where getUint64 doesn't exist).
int _uint64(ByteData data, int offset) =>
    data.getUint32(offset) * 0x100000000 + data.getUint32(offset + 4);
