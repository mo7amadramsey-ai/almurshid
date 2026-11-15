import 'package:flutter/foundation.dart';
import 'models.dart';
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

  Settings get settings => data.settings;

  Future<void> init() async {
    tree = await loadTree();
    data = await loadStudy();
    news = await loadNews();
    rebuild();
    loaded = true;
    notifyListeners();
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
