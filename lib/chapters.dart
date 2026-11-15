// Pure Dart: splits a course's study items into chapters so lectures, files and assignments are not one pile.
//
// Order of evidence for each item:
//  1) an explicit chapter number in its title or section ("Chapter 3", "الفصل 2", "Ch4", "شابتر 5")
//  2) a meaningful Moodle section (only when the course has at least two non-generic sections)
//  3) the upload rhythm: instructors publish a batch of 3-4 items within ~3 days, then stay silent for
//     4-6 days. Items first seen close together form one batch = one expected chapter.
//  4) items that were already there at the first import have no known upload time: kept apart.
import 'models.dart';
import 'planner.dart';
import 'study_models.dart';

class ChapterGroup {
  final String label;
  final String basis; // explicit | section | batch | baseline
  final List<Task> tasks;
  ChapterGroup(this.label, this.basis, this.tasks);
}

const _arDigits = '٠١٢٣٤٥٦٧٨٩';

String _digits(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = _arDigits.indexOf(c);
    b.write(i >= 0 ? '$i' : c);
  }
  return b.toString();
}

final _chapterRe = RegExp(
    r'(?<![A-Za-z])(?:chapter|chap|ch|unit)\s*\.?\s*[-_:]?\s*(\d{1,2})|(?:الفصل|فصل|الوحدة|وحدة|الشابتر|شابتر|الباب|باب)\s*[-_:]?\s*(\d{1,2})',
    caseSensitive: false);

/// Chapter number written in [s], or null
int? explicitChapter(String s) {
  final m = _chapterRe.firstMatch(_digits(s));
  if (m == null) return null;
  return int.parse(m.group(1) ?? m.group(2)!);
}

bool _generic(String s) {
  final t = s.trim().toLowerCase();
  return t.isEmpty || const ['general', 'عام', 'عامة', 'main', 'مقدمة المقرر'].contains(t);
}

int _rank(ItemKind k) {
  switch (k) {
    case ItemKind.video:
      return 0;
    case ItemKind.pdf:
      return 1;
    case ItemKind.document:
      return 2;
    case ItemKind.file:
      return 3;
    case ItemKind.page:
      return 4;
    case ItemKind.book:
      return 5;
    case ItemKind.quiz:
      return 6;
    case ItemKind.assignment:
      return 7;
    default:
      return 9;
  }
}

/// Which sub-list of a chapter an item belongs to
String bucketOf(ItemKind k) {
  switch (k) {
    case ItemKind.video:
      return 'المحاضرات (فيديو)';
    case ItemKind.quiz:
    case ItemKind.assignment:
      return 'واجبات واختبارات';
    default:
      return 'ملفات ومراجع';
  }
}

String _dm(DateTime d) => '${d.day}/${d.month}';

List<ChapterGroup> groupChapters(List<Task> tasks, Map<String, ItemState> states, {int gapDays = 3}) {
  final usefulSections = tasks.map((t) => t.section.trim()).where((s) => !_generic(s)).toSet().length >= 2;
  final explicit = <int, List<Task>>{};
  final bySection = <String, List<Task>>{};
  final timed = <Task>[];
  final baseline = <Task>[];

  for (final t in tasks) {
    final n = explicitChapter(t.title) ?? explicitChapter(t.section);
    if (n != null) {
      explicit.putIfAbsent(n, () => []).add(t);
      continue;
    }
    if (usefulSections && !_generic(t.section)) {
      bySection.putIfAbsent(t.section.trim(), () => []).add(t);
      continue;
    }
    final st = states[t.id];
    if (st?.firstSeen != null && !st!.baseline) {
      timed.add(t);
    } else {
      baseline.add(t);
    }
  }

  int cmp(Task a, Task b) {
    final r = _rank(a.kind).compareTo(_rank(b.kind));
    return r != 0 ? r : a.order.compareTo(b.order);
  }

  final out = <ChapterGroup>[];
  for (final n in (explicit.keys.toList()..sort())) {
    out.add(ChapterGroup('الشابتر $n', 'explicit', explicit[n]!..sort(cmp)));
  }
  bySection.forEach((k, v) => out.add(ChapterGroup(k, 'section', v..sort(cmp))));

  timed.sort((a, b) {
    final c = states[a.id]!.firstSeen!.compareTo(states[b.id]!.firstSeen!);
    return c != 0 ? c : a.order.compareTo(b.order);
  });
  var batch = <Task>[];
  var count = 0;
  void flush() {
    if (batch.isEmpty) return;
    count++;
    final a = states[batch.first.id]!.firstSeen!;
    final b = states[batch.last.id]!.firstSeen!;
    final range = dayDiff(a, b) == 0 ? _dm(a) : '${_dm(a)} - ${_dm(b)}';
    out.add(ChapterGroup('فصل متوقع $count  (نُزّل $range)', 'batch', batch..sort(cmp)));
    batch = <Task>[];
  }

  for (final t in timed) {
    if (batch.isNotEmpty && dayDiff(states[batch.last.id]!.firstSeen!, states[t.id]!.firstSeen!) > gapDays) flush();
    batch.add(t);
  }
  flush();

  if (baseline.isNotEmpty) out.add(ChapterGroup('مواد سابقة (قبل أول مزامنة)', 'baseline', baseline..sort(cmp)));
  return out;
}
