// Plays a YouTube lecture inside the app: finds the direct video+audio stream (up to 720p) so the app's own
// player can show it. No YouTube page, no recommendations, no embed restrictions.
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'downloads.dart' show qualityRank;

Future<String?> youtubeStreamUrl(String videoId) async {
  final yt = YoutubeExplode();
  try {
    final m = await yt.videos.streamsClient.getManifest(VideoId(videoId)).timeout(const Duration(seconds: 20));
    final all = m.muxed.toList();
    if (all.isEmpty) return null;
    all.sort((a, b) => qualityRank(b.videoQualityLabel).compareTo(qualityRank(a.videoQualityLabel)));
    // best first within 720p, then the rest; the first URL the server actually serves wins
    final fit = all.where((s) => qualityRank(s.videoQualityLabel) <= 720).toList();
    final ordered = [...fit, ...all.where((s) => !fit.contains(s)).toList().reversed];
    for (final s in ordered.take(4)) {
      final u = s.url.toString();
      if (await streamServes(u)) return u;
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    yt.close();
  }
}

/// Asks the server for the first bytes. 403 / 404 / 410 mean the link is unusable (expired or tied to
/// another client), so the caller tries the next stream instead of showing a broken player.
Future<bool> streamServes(String url) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final r = await c.getUrl(Uri.parse(url));
    r.headers.set('range', 'bytes=0-1');
    final res = await r.close().timeout(const Duration(seconds: 8));
    await res.drain<void>();
    return res.statusCode != 403 && res.statusCode != 404 && res.statusCode != 410;
  } catch (_) {
    return false;
  } finally {
    c.close(force: true);
  }
}
