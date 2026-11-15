// Bridges the pure alert texts (alerts.dart) to Android notifications through the native channel.
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'alerts.dart';
import 'channel.dart';
import 'models.dart';
import 'study_models.dart';

Future<void> askNotifPermission() async {
  try {
    await ch.invokeMethod('requestNotifPermission');
  } catch (_) {}
}

/// "A new lecture was uploaded" notifications after a sync
Future<void> notifyNews(SyncNews n) async {
  var id = 900;
  for (final note in newsNotes(n)) {
    try {
      await ch.invokeMethod('notify', {'id': id++, 'title': note.title, 'body': note.body});
    } catch (_) {}
  }
}

Future<File> _ids() async => File('${(await getApplicationDocumentsDirectory()).path}/reminders.json');

/// Cancels the reminders scheduled last time and schedules the current ones (ids 5000+)
Future<void> rescheduleReminders(Tree? tree, StudyData data) async {
  try {
    final f = await _ids();
    if (await f.exists()) {
      for (final id in (jsonDecode(await f.readAsString()) as List)) {
        await ch.invokeMethod('cancelReminder', {'id': id});
      }
    }
    if (tree == null) {
      await f.writeAsString('[]');
      return;
    }
    final list = buildReminders(tree: tree, data: data, now: DateTime.now());
    final ids = <int>[];
    for (var i = 0; i < list.length; i++) {
      final r = list[i];
      await ch.invokeMethod('schedule', {
        'id': 5000 + i,
        'at': r.at.millisecondsSinceEpoch,
        'title': r.title,
        'body': r.body,
      });
      ids.add(5000 + i);
    }
    await f.writeAsString(jsonEncode(ids));
  } catch (_) {}
}
