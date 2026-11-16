// Study planner. Pure Dart: same input -> same plan, offline, free.
//
// 1) Every study item gets a time estimate (typed by the user > AI > duration found in the title > default
//    per kind), scaled by video factor and course difficulty.
// 2) Each course has its own study deadline (its exam date - 1 day, or the global deadline - 1 day).
// 3) Day by day, the day's time is split between courses by urgency = priority x (minutes left / study days left)
//    so the courses with the least slack get the most time. Safety (buffer) days before each exam stay free
//    unless something does not fit elsewhere.
// 4) Anything that still does not fit is reported as a shortfall with the extra hours/day needed.
// The plan is rebuilt from today every time, so a missed day is redistributed automatically.
import 'models.dart';
import 'study_models.dart';

const _studyKinds = {
  ItemKind.video,
  ItemKind.pdf,
  ItemKind.document,
  ItemKind.file,
  ItemKind.page,
  ItemKind.book,
  ItemKind.assignment,
  ItemKind.quiz,
};

bool isStudyable(Item i) {
  if (!_studyKinds.contains(i.kind)) return false;
  // pages / books that list other items are containers: the children are the real items
  if ((i.kind == ItemKind.page || i.kind == ItemKind.book) && i.children.isNotEmpty) return false;
  return true;
}

int _r5(num v) {
  final r = (v / 5).round() * 5;
  return r < 5 ? 5 : r;
}

int baseMinutes(ItemKind k) {
  switch (k) {
    case ItemKind.video:
      return 40;
    case ItemKind.pdf:
      return 30;
    case ItemKind.document:
      return 25;
    case ItemKind.file:
      return 15;
    case ItemKind.page:
      return 15;
    case ItemKind.book:
      return 30;
    case ItemKind.assignment:
      return 60;
    case ItemKind.quiz:
      return 30;
    default:
      return 0;
  }
}

/// A duration written in the title: "(45 min)", "50 دقيقة", or "12:30" / "1:05:00" for videos
int? detectMinutes(Item i) {
  final t = i.title;
  final m = RegExp(r'(\d{1,3})\s*(?:min|mins|minutes|دقيقة|دقائق)', caseSensitive: false).firstMatch(t);
  if (m != null) return int.parse(m.group(1)!);
  if (i.kind == ItemKind.video) {
    final h = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?').firstMatch(t);
    if (h != null) {
      final a = int.parse(h.group(1)!);
      final b = int.parse(h.group(2)!);
      if (h.group(3) != null) return a * 60 + b;
      return b >= 30 ? a + 1 : a;
    }
  }
  return null;
}

int estimateMinutes(Item i, CourseCfg c, Settings s, ItemState? st) {
  if (st?.minutes != null) return st!.minutes!;
  if (st?.aiMinutes != null) return _r5(st!.aiMinutes!);
  final base = detectMinutes(i) ?? baseMinutes(i.kind);
  final video = i.kind == ItemKind.video ? s.videoFactor : 1.0;
  final diff = 0.7 + 0.15 * c.difficulty; // 1 -> 0.85 ... 5 -> 1.45
  return _r5(base * video * diff);
}

class Task {
  final String id; // "courseId|url"
  final String courseId;
  final String courseTitle;
  final String section;
  final Item item;
  final int order;
  final int minutes;
  bool done;
  DateTime? doneAt;
  Task({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.section,
    required this.item,
    required this.order,
    required this.minutes,
    required this.done,
    required this.doneAt,
  });
  String get title => item.title;
  ItemKind get kind => item.kind;
}

List<Task> buildTasks(Tree tree, StudyData data) {
  final out = <Task>[];
  for (final c in tree.courses) {
    final cfg = data.cfg(c.id);
    final seen = <String>{};
    var n = 0;
    for (final s in c.sections) {
      for (final top in s.items) {
        for (final i in top.flatten()) {
          if (!isStudyable(i)) continue;
          final id = '${c.id}|${i.url}';
          if (!seen.add(id)) continue;
          final st = data.items[id];
          out.add(Task(
            id: id,
            courseId: c.id,
            courseTitle: c.title,
            section: s.title,
            item: i,
            order: n++,
            minutes: estimateMinutes(i, cfg, data.settings, st),
            done: (st?.done ?? false) || i.submitted == true,
            doneAt: st?.doneAt,
          ));
        }
      }
    }
  }
  return out;
}

class Slot {
  final Task task;
  int minutes;
  bool partial = false;
  Slot(this.task, this.minutes);
}

class DayPlan {
  final DateTime date;
  final int capacity;
  final List<Slot> slots = [];
  DayPlan(this.date, this.capacity);
  int get used => slots.fold(0, (a, s) => a + s.minutes);
  int get free => capacity - used;
}

class Report {
  int daysLeft = 0;
  int totalMin = 0; // still to do
  int doneMin = 0;
  int availableMin = 0;
  int shortfallMin = 0;
  double extraHoursPerDay = 0;
  final Map<String, int> shortfallByCourse = {}; // course title -> minutes
  final List<String> warnings = [];
  bool get feasible => shortfallMin == 0;
  double get progress => (doneMin + totalMin) == 0 ? 0 : doneMin / (doneMin + totalMin);
}

class Plan {
  final List<DayPlan> days;
  final Report report;
  Plan(this.days, this.report);
  DayPlan? get today => days.isEmpty ? null : days.first;
}

DateTime studyUntil(String courseId, Map<String, CourseCfg> cfg, Settings s) {
  // A course with its own exam date: study until the day before the exam.
  final exam = cfg[courseId]?.exam;
  if (exam != null) {
    final d = dOnly(exam);
    return DateTime(d.year, d.month, d.day - 1);
  }
  // Otherwise: the last study day is exactly the day the user chose in settings.
  return dOnly(s.deadline);
}

Plan buildPlan({
  required List<Task> tasks,
  required Map<String, CourseCfg> cfg,
  required Settings settings,
  DateTime? now,
}) {
  final s = settings;
  final today = dOnly(now ?? DateTime.now());
  final report = Report();
  final todo = tasks.where((t) => !t.done).toList();
  report.doneMin = tasks.where((t) => t.done).fold(0, (a, t) => a + t.minutes);
  report.totalMin = todo.fold(0, (a, t) => a + t.minutes);

  DateTime? last;
  for (final t in todo) {
    final u = studyUntil(t.courseId, cfg, s);
    if (last == null || u.isAfter(last)) last = u;
  }

  var doneToday = 0;
  for (final t in tasks) {
    if (t.done && t.doneAt != null && dOnly(t.doneAt!) == today) doneToday += t.minutes;
  }

  final days = <DayPlan>[];
  if (last != null) {
    for (var d = today; !d.isAfter(last); d = DateTime(d.year, d.month, d.day + 1)) {
      var cap = ((s.hours[d.weekday - 1] * 60 * (s.tired ? 0.75 : 1.0)) / 5).floor() * 5;
      if (days.isEmpty) cap = cap - doneToday < 0 ? 0 : cap - doneToday;
      days.add(DayPlan(d, cap));
    }
  }
  report.daysLeft = days.isEmpty ? 0 : days.length - 1;
  report.availableMin = days.fold(0, (a, d) => a + d.capacity);

  final rem = <String, int>{for (final t in todo) t.id: t.minutes};
  final byCourse = <String, List<Task>>{};
  for (final t in todo) {
    byCourse.putIfAbsent(t.courseId, () => []).add(t);
  }
  for (final l in byCourse.values) {
    l.sort((a, b) => a.order.compareTo(b.order));
  }

  // last day index of each course (exam - 1) and of its regular (non-buffer) study
  final lastIdx = <String, int>{};
  final regIdx = <String, int>{};
  for (final cid in byCourse.keys) {
    final u = dayDiff(today, studyUntil(cid, cfg, s));
    lastIdx[cid] = u;
    regIdx[cid] = (u - s.bufferDays) >= 0 ? u - s.bufferDays : u;
  }
  int prio(String cid) => cfg[cid]?.priority ?? 2;
  int courseRem(String cid) => byCourse[cid]!.fold(0, (a, t) => a + (rem[t.id] ?? 0));

  int place(DayPlan day, Task t, int want) {
    final left = rem[t.id] ?? 0;
    if (left <= 0) return 0;
    var fit = day.free < want ? day.free : want;
    if (fit > left) fit = left;
    if (fit <= 0) return 0;
    if (fit < 10 && fit < left) return 0; // no tiny fragments
    final existing = day.slots.where((x) => x.task.id == t.id);
    if (existing.isNotEmpty) {
      existing.first.minutes += fit;
    } else {
      day.slots.add(Slot(t, fit));
    }
    rem[t.id] = left - fit;
    return fit;
  }

  int placeCourse(DayPlan day, String cid, int quota) {
    var used = 0;
    for (final t in byCourse[cid]!) {
      if (quota - used <= 0 || day.free < 5) break;
      final r = rem[t.id] ?? 0;
      if (r <= 0) continue;
      used += place(day, t, quota - used < r ? quota - used : r);
    }
    return used;
  }

  // ---- pass 1: day by day, split by urgency ----
  for (var i = 0; i < days.length; i++) {
    final day = days[i];
    if (day.free < 5) continue;
    final weight = <String, double>{};
    for (final cid in byCourse.keys) {
      if (i > regIdx[cid]!) continue;
      final r = courseRem(cid);
      if (r <= 0) continue;
      var capDays = 0;
      for (var k = i; k <= regIdx[cid]! && k < days.length; k++) {
        if (days[k].capacity >= 5) capDays++;
      }
      weight[cid] = prio(cid) * r / (capDays < 1 ? 1 : capDays);
    }
    if (weight.isEmpty) continue;
    final totalW = weight.values.fold<double>(0, (a, b) => a + b);
    final ids = weight.keys.toList()..sort((a, b) => weight[b]!.compareTo(weight[a]!));
    final startFree = day.free;
    for (final cid in ids) {
      var quota = (startFree * weight[cid]! / totalW).floor();
      quota -= quota % 5;
      if (quota > 0) placeCourse(day, cid, quota);
    }
    // time still free that day goes to the most urgent courses
    for (final cid in ids) {
      if (day.free < 5) break;
      placeCourse(day, cid, day.free);
    }
  }

  // ---- pass 2: spill leftovers into any free time up to each course's last study day ----
  final spill = todo.where((t) => (rem[t.id] ?? 0) > 0).toList()
    ..sort((a, b) {
      final c = lastIdx[a.courseId]!.compareTo(lastIdx[b.courseId]!);
      return c != 0 ? c : a.order.compareTo(b.order);
    });
  for (final t in spill) {
    final lim = lastIdx[t.courseId]!;
    for (var i = 0; i < days.length && i <= lim; i++) {
      if ((rem[t.id] ?? 0) <= 0) break;
      place(days[i], t, rem[t.id]!);
    }
  }

  // ---- bookkeeping ----
  report.shortfallMin = rem.values.fold(0, (a, b) => a + b);
  for (final t in todo) {
    final r = rem[t.id] ?? 0;
    if (r > 0) report.shortfallByCourse[t.courseTitle] = (report.shortfallByCourse[t.courseTitle] ?? 0) + r;
  }
  final capDays = days.where((d) => d.capacity > 0).length;
  if (capDays > 0) report.extraHoursPerDay = report.shortfallMin / capDays / 60;

  for (final cid in byCourse.keys) {
    final title = byCourse[cid]!.first.courseTitle;
    final u = studyUntil(cid, cfg, s);
    if (u.isBefore(today)) {
      report.warnings.add('!موعد «$title» فات أو هو اليوم وما زال فيها ${_h(courseRem(cid))} غير منجزة');
    } else if ((report.shortfallByCourse[title] ?? 0) > 0) {
      report.warnings.add(
          '!«$title» ينقصها ${_h(report.shortfallByCourse[title]!)} قبل ${_dm(DateTime(u.year, u.month, u.day + 1))}');
    }
  }

  final counts = <String, int>{};
  for (final d in days) {
    for (final sl in d.slots) {
      counts[sl.task.id] = (counts[sl.task.id] ?? 0) + 1;
    }
  }
  for (final d in days) {
    for (final sl in d.slots) {
      sl.partial = (counts[sl.task.id] ?? 0) > 1 || (rem[sl.task.id] ?? 0) > 0;
    }
  }
  return Plan(days, report);
}

String _dm(DateTime d) => '${d.day}/${d.month}';
String _h(int m) {
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return '$r د';
  return r == 0 ? '$h س' : '$h س $r د';
}
