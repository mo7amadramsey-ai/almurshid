import 'package:flutter_test/flutter_test.dart';
import 'package:almurshid/models.dart';
import 'package:almurshid/planner.dart';
import 'package:almurshid/study_models.dart';

Tree tree(List<Course> cs) => Tree(fetchedAt: DateTime(2026, 11, 15), courses: cs);

Course course(String id, List<Item> items) =>
    Course(id: id, title: 'Course $id', url: 'https://moodle.ucas.edu.ps/course/view.php?id=$id', sections: [
      Section(title: 'Week 1', items: items),
    ]);

Item item(String title, String url, ItemKind k) => Item(title: title, url: url, kind: k);

final now = DateTime(2026, 11, 15, 9);

StudyData dataWith({double hours = 4, DateTime? deadline}) {
  final d = StudyData();
  d.settings.hours = List<double>.filled(7, hours);
  d.settings.deadline = deadline ?? DateTime(2026, 12, 1);
  return d;
}

void main() {
  test('a day never holds more study than the allowed window', () {
    final t = tree([course('1', [item('A', 'https://x/a', ItemKind.pdf)])]);
    final data = dataWith(hours: 8);
    data.settings.windowStart = 9 * 60;
    data.settings.windowEnd = 11 * 60; // 2 hours only
    final plan = buildPlan(tasks: buildTasks(t, data), cfg: data.courses, settings: data.settings, now: now);
    expect(plan.days.every((d) => d.capacity <= 120), isTrue);
  });

  test('only study items become tasks, durations come from the title or defaults', () {
    final t = tree([
      course('1', [
        item('Intro 50 min', 'https://x/v1', ItemKind.video),
        item('Slides', 'https://x/p1', ItemKind.pdf),
        item('Forum', 'https://x/f', ItemKind.forum),
        item('Folder', 'https://x/d', ItemKind.folder),
      ]),
    ]);
    final data = dataWith();
    final tasks = buildTasks(t, data);
    expect(tasks.length, 2);
    // 50 min x 1.5 (video) x 1.15 (difficulty 3) = 86.25 -> 85
    expect(tasks.firstWhere((e) => e.kind == ItemKind.video).minutes, 85);
    // 30 min x 1.15 = 34.5 -> 35
    expect(tasks.firstWhere((e) => e.kind == ItemKind.pdf).minutes, 35);
  });

  test('the user-typed minutes win over every estimate', () {
    final t = tree([
      course('1', [item('Slides', 'https://x/p1', ItemKind.pdf)])
    ]);
    final data = dataWith();
    data.state('1|https://x/p1').minutes = 120;
    data.state('1|https://x/p1').aiMinutes = 10;
    expect(buildTasks(t, data).single.minutes, 120);
  });

  test('plenty of time: feasible, nothing left over, work starts today', () {
    final t = tree([
      course('1', [item('A', 'https://x/a', ItemKind.pdf), item('B', 'https://x/b', ItemKind.pdf)])
    ]);
    final data = dataWith(hours: 4);
    data.cfg('1').exam = DateTime(2026, 11, 25);
    final plan = buildPlan(tasks: buildTasks(t, data), cfg: data.courses, settings: data.settings, now: now);
    expect(plan.report.feasible, true);
    expect(plan.report.shortfallMin, 0);
    expect(plan.today!.slots, isNotEmpty);
  });

  test('not enough time: the shortfall is reported', () {
    final items = [for (var i = 0; i < 5; i++) item('Lecture $i 50 min', 'https://x/v$i', ItemKind.video)];
    final t = tree([course('1', items)]);
    final data = dataWith(hours: 1);
    data.cfg('1').exam = DateTime(2026, 11, 17); // study days: 15 and 16 -> 120 minutes
    final plan = buildPlan(tasks: buildTasks(t, data), cfg: data.courses, settings: data.settings, now: now);
    expect(plan.report.totalMin, 425);
    expect(plan.report.shortfallMin, 305);
    expect(plan.report.feasible, false);
    expect(plan.report.extraHoursPerDay > 0, true);
  });

  test('the course with the closer exam gets more of today', () {
    final t = tree([
      course('A', [item('A1', 'https://x/a1', ItemKind.pdf)]),
      course('B', [item('B1', 'https://x/b1', ItemKind.pdf)]),
    ]);
    final data = dataWith(hours: 4);
    data.state('A|https://x/a1').minutes = 200;
    data.state('B|https://x/b1').minutes = 200;
    data.cfg('A').exam = DateTime(2026, 11, 18);
    data.cfg('B').exam = DateTime(2026, 12, 5);
    final plan = buildPlan(tasks: buildTasks(t, data), cfg: data.courses, settings: data.settings, now: now);
    int minutesOf(String id) =>
        plan.today!.slots.where((s) => s.task.courseId == id).fold(0, (a, s) => a + s.minutes);
    expect(minutesOf('A') > minutesOf('B'), true);
  });

  test('finished items leave the plan and raise progress', () {
    final t = tree([
      course('1', [item('A', 'https://x/a', ItemKind.pdf), item('B', 'https://x/b', ItemKind.pdf)])
    ]);
    final data = dataWith();
    data.state('1|https://x/a').done = true;
    data.state('1|https://x/a').doneAt = now;
    final plan = buildPlan(tasks: buildTasks(t, data), cfg: data.courses, settings: data.settings, now: now);
    expect(plan.report.progress > 0 && plan.report.progress < 1, true);
    final scheduled = plan.days.expand((d) => d.slots).map((s) => s.task.title).toSet();
    expect(scheduled, {'B'});
  });

  test('computeNews lists only items that were not there before', () {
    final before = tree([
      course('1', [item('Old', 'https://x/old', ItemKind.pdf)])
    ]);
    final after = tree([
      course('1', [item('Old', 'https://x/old', ItemKind.pdf), item('New', 'https://x/new', ItemKind.video)])
    ]);
    expect(computeNews(null, after).first, true);
    final n = computeNews(before, after);
    expect(n.first, false);
    expect(n.added.map((e) => e.title).toList(), ['New']);
  });

  test('settings and study data survive a JSON round trip', () {
    final data = dataWith(hours: 3);
    data.settings.tired = true;
    data.cfg('7').exam = DateTime(2026, 12, 2);
    data.state('7|u').minutes = 45;
    final back = StudyData.fromJson(data.toJson());
    expect(back.settings.tired, true);
    expect(back.settings.hours.first, 3);
    expect(back.courses['7']!.exam, DateTime(2026, 12, 2));
    expect(back.items['7|u']!.minutes, 45);
  });

  test('last study day is chosen by the user; a course with an exam stops the day before it', () {
    final data = dataWith(deadline: DateTime(2026, 12, 2));
    expect(studyUntil('X', data.courses, data.settings), DateTime(2026, 12, 2));
    data.cfg('B').exam = DateTime(2026, 12, 5);
    expect(studyUntil('B', data.courses, data.settings), DateTime(2026, 12, 4));
  });
}
