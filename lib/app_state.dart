import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'notifier.dart';
import 'planner.dart';
import 'storage.dart';
import 'study_models.dart';
import 'study_store.dart';

class AppState extends ChangeNotifier {
  Tree? tree;
  StudyData data = StudyData();
  SyncNews? news;
  List<Task> tasks = [];
  Plan? plan;
  bool loaded = false;
  Timer? _remTimer;

  Settings get settings => data.settings;

  Future<void> init() async {
    tree = await loadTree();
    data = await loadStudy();
    news = await loadNews();
    rebuild();
    loaded = true;
    notifyListeners();
    rescheduleReminders(tree, data); // deadline / exam / daily reminders
  }

  void rebuild() {
    final t = tree;
    if (t == null) {
      tasks = [];
      plan = null;
      return;
    }
    for (final c in t.courses) {
      data.cfg(c.id);
    }
    tasks = buildTasks(t, data);
    plan = buildPlan(tasks: tasks, cfg: data.courses, settings: data.settings);
  }

  /// Call after changing [data]: rebuilds the plan, saves, refreshes the screens
  Future<void> commit() async {
    rebuild();
    notifyListeners();
    await saveStudy(data);
    // keep reminders in step with exam dates / settings / finished tasks (debounced)
    _remTimer?.cancel();
    _remTimer = Timer(const Duration(seconds: 2), () => rescheduleReminders(tree, data));
  }

  /// Text of a backup of the student's own data (no AI key, no Moodle session).
  Future<String> makeBackup() async => buildBackup(data, await loadLog());

  /// Replaces the current study data with a backup. Returns an error message, or null on success.
  /// The AI key stays as it is on this phone.
  Future<String?> restoreBackup(String text) async {
    try {
      final r = parseBackup(text);
      r.data.settings.apiKey = data.settings.apiKey;
      data = r.data;
      await saveLog(r.log);
      await commit();
      return null;
    } catch (e) {
      return e is String ? e : 'تعذّرت الاستعادة';
    }
  }

  /// Deletes every local file, the AI key and the Moodle session, then shows an empty app.
  Future<void> resetAll() async {
    _remTimer?.cancel();
    await wipeLocalData();
    tree = null;
    data = StudyData();
    news = null;
    rebuild();
    notifyListeners();
  }

  Future<void> toggle(Task t) async {
    final st = data.state(t.id);
    st.done = !st.done;
    st.doneAt = st.done ? DateTime.now() : null;
    await commit();
  }

  List<Task> tasksOf(String courseId) => tasks.where((t) => t.courseId == courseId).toList();

  int remainingMin(String courseId) =>
      tasks.where((t) => t.courseId == courseId && !t.done).fold(0, (a, t) => a + t.minutes);

  double courseProgress(String courseId) {
    final l = tasksOf(courseId);
    if (l.isEmpty) return 0;
    final all = l.fold<int>(0, (a, t) => a + t.minutes);
    final done = l.where((t) => t.done).fold<int>(0, (a, t) => a + t.minutes);
    return all == 0 ? 0 : done / all;
  }
}

final app = AppState();
