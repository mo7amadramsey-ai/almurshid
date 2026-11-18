// Plays a YouTube lecture inside the app: finds the direct video+audio stream (up to 720p) so the app's own
// player can show it. No YouTube page, no recommendations, no embed restrictions.
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'downloads.dart' show qualityRank;

Future<String?> youtubeStreamUrl(String videoId) async {
  final yt = YoutubeExplode();
  try {
    final m = await yt.videos.streamsClient.getManifest(VideoId(videoId)).timeout(const Duration(seconds: 20));
    final all = m.muxed.toList();
    if (all.isEmpty) return null;
    all.sort((a, b) => qualityRank(b.videoQualityLabel).compareTo(qualityRank(a.videoQualityLabel)));
    final fit = all.where((s) => qualityRank(s.videoQualityLabel) <= 720).toList();
    return (fit.isNotEmpty ? fit.first : all.last).url.toString();
  } catch (_) {
    return null;
  } finally {
    yt.close();
  }
}
