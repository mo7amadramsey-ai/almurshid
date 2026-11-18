import 'package:flutter_test/flutter_test.dart';
import 'package:almurshid/chapters.dart';
import 'package:almurshid/models.dart';
import 'package:almurshid/planner.dart';
import 'package:almurshid/study_models.dart';

Course course(List<Section> secs) => Course(id: '1', title: 'Course 1', url: 'https://x/c', sections: secs);
Tree tree(List<Course> cs, DateTime at) => Tree(fetchedAt: at, courses: cs);
Item vid(String t) => Item(title: t, url: 'https://x/$t', kind: ItemKind.video);
Item pdf(String t) => Item(title: t, url: 'https://x/$t', kind: ItemKind.pdf);

void main() {
  test('explicit chapter numbers, Latin and Arabic digits', () {
    expect(explicitChapter('Chapter 3 - Intro'), 3);
    expect(explicitChapter('Ch4 slides'), 4);
    expect(explicitChapter('الفصل ٢ المحاضرة الأولى'), 2);
    expect(explicitChapter('شابتر 5'), 5);
    expect(explicitChapter('Much 5 text'), isNull);
    expect(explicitChapter('Lecture 7'), isNull);
  });

  test('items in one generic section are split into batches by upload rhythm', () {
    final c = course([
      Section(title: 'General', items: [vid('a'), vid('b'), pdf('c'), vid('d'), vid('e'), vid('f')]),
    ]);
    final first = tree([c], DateTime(2026, 11, 1));
    final d = StudyData();
    stampFirstSeen(d, null, first); // first import: everything is baseline
    expect(d.items.values.every((s) => s.baseline), isTrue);

    // second sync, 6 days later: a,b,c were already known; d,e arrive together, f 5 days later
    final second = tree([c], DateTime(2026, 11, 7));
    stampFirstSeen(d, first, second);
    d.items['1|https://x/d']!
      ..firstSeen = DateTime(2026, 11, 7)
      ..baseline = false;
    d.items['1|https://x/e']!
      ..firstSeen = DateTime(2026, 11, 8)
      ..baseline = false;
    d.items['1|https://x/f']!
      ..firstSeen = DateTime(2026, 11, 13)
      ..baseline = false;

    final tasks = buildTasks(second, d);
    final g = groupChapters(tasks, d.items);
    expect(g.map((e) => e.basis).toList(), ['batch', 'batch', 'baseline']);
    expect(g[0].tasks.map((t) => t.title).toList(), ['d', 'e']);
    expect(g[1].tasks.map((t) => t.title).toList(), ['f']);
    // the PDF 'c' is supporting material, not a task
    expect(g[2].tasks.map((t) => t.title).toSet(), {'a', 'b'});
  });

  test('explicit numbers win and meaningful sections are kept', () {
    final c = course([
      Section(title: 'Week 1', items: [vid('Chapter 2 video'), vid('notes video')]),
      Section(title: 'Week 2', items: [vid('lec')]),
    ]);
    final t = tree([c], DateTime(2026, 11, 1));
    final d = StudyData();
    final g = groupChapters(buildTasks(t, d), d.items);
    expect(g.first.label, 'الشابتر 2');
    expect(g.map((e) => e.label), containsAll(['Week 1', 'Week 2']));
  });

  test('inside a chapter videos come first, then assignments; PDFs are not tasks', () {
    final c = course([
      Section(title: 'General', items: [
        Item(title: 'Chapter 1 hw', url: 'https://x/h', kind: ItemKind.assignment),
        pdf('Chapter 1 slides'),
        vid('Chapter 1 lecture'),
      ]),
    ]);
    final d = StudyData();
    final g = groupChapters(buildTasks(tree([c], DateTime(2026, 11, 1)), d), d.items);
    expect(g.single.tasks.map((t) => t.kind).toList(), [ItemKind.video, ItemKind.assignment]);
  });
}
