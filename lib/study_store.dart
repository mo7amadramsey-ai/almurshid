// Local storage of the student's data. Rules:
//  * writes are atomic (tmp file + rename) and the previous version is kept as study.json.bak
//  * a damaged file is never silently thrown away: it is moved aside and the backup is tried first
//  * the AI key never goes into these files (see secrets.dart)
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'channel.dart';
import 'secrets.dart';
import 'study_models.dart';
import 'viewer/recents.dart';

/// Tests point this at a temp folder.
Directory? dirOverride;

Future<Directory> _dir() async => dirOverride ?? await getApplicationDocumentsDirectory();
Future<File> _f(String name) async => File('${(await _dir()).path}/$name');

/// Set when loading had to recover or reset something (null = everything was fine). Shown to the user.
final studyLoadNotice = ValueNotifier<String?>(null);

/// Upgrades an older data file to the current format. v1 -> v2 only added the version marker.
/// A file written by a NEWER app version is read as far as possible instead of being rejected.
Map<String, dynamic> migrateStudyJson(Map<String, dynamic> j) => j;

StudyData? _tryDecode(String? text) {
  if (text == null) return null;
  try {
    return StudyData.fromJson(migrateStudyJson(jsonDecode(text) as Map<String, dynamic>));
  } catch (_) {
    return null;
  }
}

Future<StudyData> _afterLoad(StudyData d) async {
  // Move an old plain-text API key into Keystore, then rewrite the file without it.
  if (await loadApiKey(d.settings, secrets)) await saveStudy(d);
  return d;
}

Future<StudyData> loadStudy() async {
  try {
    final f = await _f('study.json');
    final b = await _f('study.json.bak');
    final backup = await b.exists() ? _tryDecode(await b.readAsString()) : null;
    if (!await f.exists()) {
      if (backup != null) {
        studyLoadNotice.value = 'استُعيدت بياناتك من النسخة الاحتياطية الداخلية.';
        return _afterLoad(backup);
      }
      return StudyData();
    }
    final d = _tryDecode(await f.readAsString());
    if (d != null) return _afterLoad(d);
    // The file is damaged: keep it for inspection, then fall back to the backup.
    final aside = '${f.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}';
    try {
      await f.rename(aside);
    } catch (_) {}
    if (backup != null) {
      studyLoadNotice.value = 'كان ملف البيانات تالفاً، فاستُعيدت بياناتك من النسخة الاحتياطية الداخلية.';
      await saveStudy(backup);
      return _afterLoad(backup);
    }
    studyLoadNotice.value = 'تعذّرت قراءة ملف البيانات. حُفظت نسخة منه جانباً وبدأت بيانات جديدة.';
    return StudyData();
  } catch (_) {
    return StudyData();
  }
}

Future<void> saveStudy(StudyData d) async {
  await saveApiKey(d.settings, secrets); // key -> Keystore (the JSON only keeps a legacy key that could not be moved)
  final f = await _f('study.json');
  final tmp = await _f('study.json.tmp');
  final bak = await _f('study.json.bak');
  await tmp.writeAsString(jsonEncode(d.toJson()), flush: true);
  if (await f.exists()) {
    try {
      await f.copy(bak.path); // previous good version
    } catch (_) {}
  }
  await tmp.rename(f.path);
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

// ---------------------------------------------------------------- backup / restore

/// A backup holds the student's own data (settings, exam dates, finished items, activity log).
/// It never contains the AI key or the Moodle session, and the course tree is re-imported from Moodle.
String buildBackup(StudyData d, List<ActivityEntry> log, {DateTime? now}) {
  final data = d.toJson();
  (data['settings'] as Map<String, dynamic>).remove('apiKey');
  return jsonEncode({
    'app': 'almurshid',
    'kind': 'backup',
    'v': kSchema,
    'at': (now ?? DateTime.now()).toIso8601String(),
    'data': data,
    'log': log.map((e) => e.toJson()).toList(),
  });
}

class RestoredBackup {
  final StudyData data;
  final List<ActivityEntry> log;
  RestoredBackup(this.data, this.log);
}

/// Throws a readable Arabic message when [text] is not a valid backup of this app.
RestoredBackup parseBackup(String text) {
  final dynamic j;
  try {
    j = jsonDecode(text);
  } catch (_) {
    throw 'النص ليس نسخة احتياطية صالحة';
  }
  if (j is! Map || j['app'] != 'almurshid' || j['kind'] != 'backup' || j['data'] is! Map) {
    throw 'هذا ليس ملف نسخة احتياطية من المرشد';
  }
  try {
    final data = StudyData.fromJson(migrateStudyJson(Map<String, dynamic>.from(j['data'] as Map)));
    final log = ((j['log'] as List?) ?? []).map((e) => ActivityEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    return RestoredBackup(data, log);
  } catch (_) {
    throw 'تعذّرت قراءة محتوى النسخة الاحتياطية';
  }
}

// ---------------------------------------------------------------- delete everything

/// Removes every file the app keeps about the student, the AI key, the Moodle session and the recent screens,
/// and cancels the scheduled reminders.
Future<void> wipeLocalData() async {
  final dir = await _dir();
  try {
    final r = await _f('reminders.json');
    if (await r.exists()) {
      for (final id in jsonDecode(await r.readAsString()) as List) {
        await ch.invokeMethod('cancelReminder', {'id': id});
      }
    }
  } catch (_) {}
  for (final n in ['study.json', 'study.json.bak', 'study.json.tmp', 'news.json', 'log.json', 'tree.json', 'reminders.json']) {
    try {
      final f = File('${dir.path}/$n');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
  try {
    for (final e in dir.listSync()) {
      if (e is File && e.path.contains('study.json.corrupt-')) await e.delete();
    }
  } catch (_) {}
  try {
    await secrets.delete(kAiKey);
  } catch (_) {}
  resetSecretsCache();
  try {
    await WebViewCookieManager().clearCookies();
  } catch (_) {}
  try {
    await recents.clear();
  } catch (_) {}
  studyLoadNotice.value = null;
}
