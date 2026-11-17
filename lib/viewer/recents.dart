// "Recent screens" inside the app: the last things the student opened (videos, Moodle pages, Drive files).
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class Recent {
  final String title;
  final String url;
  final int ts; // ms since epoch
  Recent(this.title, this.url, this.ts);
  Map<String, dynamic> toJson() => {'t': title, 'u': url, 'ts': ts};
  factory Recent.fromJson(Map<String, dynamic> j) => Recent(j['t'] as String, j['u'] as String, (j['ts'] as num).toInt());
}

class RecentsStore extends ChangeNotifier {
  static const maxItems = 20;
  final List<Recent> items = [];
  bool _loaded = false;

  Future<File> _file() async => File('${(await getApplicationSupportDirectory()).path}/recents.json');

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _file();
      if (await f.exists()) {
        final l = jsonDecode(await f.readAsString()) as List;
        items
          ..clear()
          ..addAll(l.map((e) => Recent.fromJson(e as Map<String, dynamic>)));
        notifyListeners();
      }
    } catch (_) {}
  }

  // Newest first; the same url is kept once.
  Future<void> add(String title, String url) async {
    await load();
    items.removeWhere((r) => r.url == url);
    items.insert(0, Recent(title.isEmpty ? url : title, url, DateTime.now().millisecondsSinceEpoch));
    if (items.length > maxItems) items.removeRange(maxItems, items.length);
    notifyListeners();
    try {
      await (await _file()).writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  // Forget everything (used by "delete all my data")
  Future<void> clear() async {
    items.clear();
    notifyListeners();
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

final recents = RecentsStore();
