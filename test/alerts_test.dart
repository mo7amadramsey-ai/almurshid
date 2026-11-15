import 'package:flutter_test/flutter_test.dart';
import 'package:almurshid/alerts.dart';
import 'package:almurshid/models.dart';
import 'package:almurshid/study_models.dart';

void main() {
  test('news notification names the course and the kind', () {
    final n = SyncNews(at: DateTime(2026, 11, 15), first: false, added: [
      NewsEntry('Physics', 'Lecture 4', 'video', 'u1'),
      NewsEntry('Physics', 'Slides 4', 'pdf', 'u2'),
      NewsEntry('Math', 'HW 2', 'assignment', 'u3'),
    ]);
    final notes = newsNotes(n);
    expect(notes.length, 2);
    expect(notes[0].title, contains('Physics'));
    expect(notes[0].body, contains('محاضرة: Lecture 4'));
    expect(notes[1].title, contains('Math'));
    expect(newsNotes(SyncNews(at: DateTime(2026, 11, 15), first: true, added: [])), isEmpty);
  });

  test('reminders: deadline, exam and daily study; submitted work is skipped', () {
    final now = DateTime(2026, 11, 15, 10);
    final todo = Item(title: 'HW 1', url: 'https://x/a', kind: ItemKind.assignment, due: DateTime(2026, 11, 18, 23, 59));
    final sent = Item(title: 'HW 0', url: 'https://x/b', kind: ItemKind.assignment, due: DateTime(2026, 11, 18, 23, 59), submitted: true);
    final c = Course(id: '1', title: 'Physics', url: 'https://x/c', sections: [
      Section(title: 'General', items: [todo, sent]),
    ]);
    final tree = Tree(fetchedAt: now, courses: [c]);
    final d = StudyData();
    d.cfg('1').exam = DateTime(2026, 11, 20);
    final r = buildReminders(tree: tree, data: d, now: now);
    expect(r.where((e) => e.title.contains('تذكير')).length, 2); // HW 1 only: 24h + 3h
    expect(r.any((e) => e.body.contains('HW 0')), isFalse);
    expect(r.any((e) => e.title.contains('امتحان Physics غداً')), isTrue);
    expect(r.where((e) => e.title == 'وقت المذاكرة').length, 7);
    for (var i = 1; i < r.length; i++) {
      expect(r[i].at.isBefore(r[i - 1].at), isFalse);
    }
  });
}
