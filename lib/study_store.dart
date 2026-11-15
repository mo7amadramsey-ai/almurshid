import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'study_models.dart';

Future<File> _f(String name) async => File('${(await getApplicationDocumentsDirectory()).path}/$name');

Future<StudyData> loadStudy() async {
  try {
    final f = await _f('study.json');
    if (!await f.exists()) return StudyData();
    return StudyData.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
  } catch (_) {
    return StudyData();
  }
}

Future<void> saveStudy(StudyData d) async => (await _f('study.json')).writeAsString(jsonEncode(d.toJson()));

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
