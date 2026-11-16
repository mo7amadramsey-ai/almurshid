import 'package:flutter_test/flutter_test.dart';
import 'package:almurshid/viewer/guarded_web.dart';
import 'package:almurshid/viewer/youtube_page.dart';

void main() {
  test('YouTube video ids are read from every common link shape', () {
    expect(youtubeIdOf(Uri.parse('https://www.youtube.com/watch?v=abc123&t=5')), 'abc123');
    expect(youtubeIdOf(Uri.parse('https://youtu.be/xyz789')), 'xyz789');
    expect(youtubeIdOf(Uri.parse('https://www.youtube.com/embed/emb456')), 'emb456');
    expect(youtubeIdOf(Uri.parse('https://m.youtube.com/shorts/sh1')), 'sh1');
    expect(youtubeIdOf(Uri.parse('https://moodle.ucas.edu.ps/mod/url/view.php?id=5')), null);
  });

  test('the browser only allows Moodle, YouTube and Google Drive / Docs', () {
    expect(hostAllowed('moodle.ucas.edu.ps'), true);
    expect(hostAllowed('m.youtube.com'), true);
    expect(hostAllowed('drive.google.com'), true);
    expect(hostAllowed('docs.google.com'), true);
    expect(hostAllowed('facebook.com'), false);
    expect(hostAllowed('evil-youtube.com.attacker.io'), false);
    expect(hostAllowed('notyoutube.com'), false);
  });
}
