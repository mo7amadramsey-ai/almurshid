// One entry point to open any course item INSIDE the app (never leaves to the YouTube / Drive apps).
import 'package:flutter/material.dart';
import '../models.dart' show ItemKind;
import '../widgets.dart' show toast;
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
  final Widget page = id != null
      ? YoutubePlayerPage(videoId: id, title: title, originalUrl: url)
      : GuardedWebPage(url: url, title: title);
  await Navigator.push(c, MaterialPageRoute(builder: (_) => page));
}
