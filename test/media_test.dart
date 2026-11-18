import 'package:flutter_test/flutter_test.dart';
import 'package:almurshid/media/downloads.dart';
import 'package:almurshid/media/files.dart';

void main() {
  test('numbering helpers round-trip', () {
    expect(numberedName(3, 'Limits', '.mp4'), '003 - Limits.mp4');
    expect(numberedName(null, 'Limits', '.mp4'), 'Limits.mp4');
    expect(numberOf('003 - Limits.mp4'), 3);
    expect(numberOf('Limits.mp4'), isNull);
    expect(titlePart('003 - Limits.mp4'), 'Limits');
    expect(titlePart('Notes.pdf'), 'Notes');
  });

  test('safe names and extensions', () {
    expect(safeName('a/b:c*?"<>|d'), 'a_b_c______d');
    expect(safeName('   '), 'ملف');
    expect(extOf('/x/y/lec.PDF'), 'pdf');
    expect(extOf('/x/y/noext'), '');
    expect(isVideo('/a/b.MP4'), isTrue);
    expect(isPdf('/a/b.pdf'), isTrue);
    expect(isImage('/a/b.jpeg'), isTrue);
    expect(isAudio('/a/b.m4a'), isTrue);
  });

  test('natural sort puts lecture 2 before lecture 10', () {
    final l = ['Lecture 10', 'Lecture 2', 'Lecture 1']..sort(naturalCompare);
    expect(l, ['Lecture 1', 'Lecture 2', 'Lecture 10']);
  });

  test('sizes and quality ranking', () {
    expect(fmtSize(2 * 1048576), '2.0 MB');
    expect(fmtSize(512 * 1024), '512 KB');
    expect(qualityRank('1080p60'), 1080);
    expect(qualityRank('360p'), 360);
    expect(qualityRank('audio'), 0);
  });
}
