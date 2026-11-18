// One entry point to open any course item INSIDE the app (never leaves to the YouTube / Drive apps).
import 'package:flutter/material.dart';
import '../models.dart' show ItemKind;
import '../widgets.dart' show toast;
import '../crawler/classify.dart' show isMoodleHost;
import '../media/downloads.dart' show cookiesFor;
import '../media/files.dart' show isVideo;
import '../media/stream.dart';
import '../media/viewers.dart' show VideoFilePage;
import 'guarded_web.dart';
import 'recents.dart';
import 'youtube_page.dart';

IconData iconForUrl(String url) {
  final u = Uri.tryParse(url);
  if (u == null) return Icons.link;
  if (youtubeIdOf(u) != null) return Icons.play_circle_outline;
  final h = u.host.toLowerCase();
  if (h.contains('drive.google') || h.contains('docs.google')) return Icons.cloud_outlined;
  if (h.endsWith('ucas.edu.ps')) return Icons.school_outlined;
  return Icons.public;
}

Future<void> openItem(BuildContext c, {required String url, required String title, ItemKind? kind}) async {
  final u = Uri.tryParse(url);
  if (u == null || !(u.scheme == 'http' || u.scheme == 'https')) {
    toast(c, 'رابط غير صالح');
    return;
  }
  final id = youtubeIdOf(u);
  if (id == null && !hostAllowed(u.host)) {
    toast(c, 'هذا الرابط خارج المواقع المسموحة (مودل، يوتيوب، درايف)');
    return;
  }
  await recents.add(title, url);
  if (!c.mounted) return;
  // YouTube lectures play in the app's own player (no embed errors, no recommendations)
  if (id != null) {
    final su = await _withSpinner(c, youtubeStreamUrl(id));
    if (!c.mounted) return;
    if (su != null) {
      await Navigator.push(c, MaterialPageRoute(builder: (_) => VideoFilePage(path: 'yt:$id', streamUrl: su, title: title)));
      return;
    }
  } else if (isMoodleHost(u.host) && isVideo(Uri.decodeFull(u.path))) {
    final ck = await cookiesFor(url);
    if (!c.mounted) return;
    await Navigator.push(
        c,
        MaterialPageRoute(
            builder: (_) => VideoFilePage(path: 'moodle:$url', streamUrl: url, title: title, headers: {if (ck.isNotEmpty) 'Cookie': ck})));
    return;
  }
  // Fallbacks: the embedded YouTube player, then the restricted browser
  final Widget page = id != null
      ? YoutubePlayerPage(videoId: id, title: title, originalUrl: url)
      : GuardedWebPage(url: url, title: title);
  await Navigator.push(c, MaterialPageRoute(builder: (_) => page));
}

Future<T> _withSpinner<T>(BuildContext c, Future<T> f) async {
  showDialog<void>(context: c, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  try {
    return await f;
  } finally {
    if (c.mounted) Navigator.of(c, rootNavigator: true).pop();
  }
}
