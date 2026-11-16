import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'secrets.dart';
import 'study_models.dart';

Future<File> _f(String name) async => File('${(await getApplicationDocumentsDirectory()).path}/$name');

Future<StudyData> loadStudy() async {
  try {
    final f = await _f('study.json');
    if (!await f.exists()) return StudyData();
    final d = StudyData.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    // Move an old plain-text API key into Keystore, then rewrite the file without it.
    if (await loadApiKey(d.settings, secrets)) await saveStudy(d);
    return d;
  } catch (_) {
    return StudyData();
  }
}

Future<void> saveStudy(StudyData d) async {
  await saveApiKey(d.settings, secrets); // key -> Keystore (the JSON never gets it, except a legacy key that could not be moved)
  await (await _f('study.json')).writeAsString(jsonEncode(d.toJson()));
}

Future<SyncNews?> loadNews() async {
  try {
    final f = await _f('news.json');
    if (!await f.exists()) return null;
    return SyncNews.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

Future<void> saveNews(SyncNews n) async => (await _f('news.json')).writeAsString(jsonEncode(n.toJson()));

Future<List<ActivityEntry>> loadLog() async {
  try {
    final f = await _f('log.json');
    if (!await f.exists()) return [];
    return (jsonDecode(await f.readAsString()) as List)
        .map((e) => ActivityEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveLog(List<ActivityEntry> l) async =>
    (await _f('log.json')).writeAsString(jsonEncode(l.map((e) => e.toJson()).toList()));
