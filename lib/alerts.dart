// Pure Dart: the texts of the notifications (new items after a sync) and the scheduled reminders.
import 'models.dart';
import 'study_models.dart';

class Note {
  final String title, body;
  Note(this.title, this.body);
}

ItemKind _kind(String n) => ItemKind.values.firstWhere((k) => k.name == n, orElse: () => ItemKind.other);

String _label(ItemKind k) => k == ItemKind.video ? 'محاضرة' : (kindLabels[k] ?? 'عنصر');

/// One notification per course that received new items (at most [maxNotes])
List<Note> newsNotes(SyncNews n, {int maxNotes = 5}) {
  if (n.first || n.added.isEmpty) return [];
  final byCourse = <String, List<NewsEntry>>{};
  for (final e in n.added) {
    byCourse.putIfAbsent(e.course, () => []).add(e);
  }
  final out = <Note>[];
  byCourse.forEach((course, list) {
    final title = list.length == 1
        ? 'تم تنزيل ${_label(_kind(list.first.kind))} جديد'
        : 'تم تنزيل ${list.length} عناصر جديدة';
    final lines = [for (final e in list.take(6)) '• ${_label(_kind(e.kind))}: ${e.title}'];
    if (list.length > 6) lines.add('و ${list.length - 6} أخرى');
    out.add(Note('$title - $course', lines.join('\n')));
  });
  return out.take(maxNotes).toList();
}

class Reminder {
  final DateTime at;
  final String title, body;
  Reminder(this.at, this.title, this.body);
}

String _hm(DateTime d) => '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Reminders for the next days: assignment / quiz deadlines (1 day and 3 hours before, only if not
/// submitted or done), exams (3 days and 1 day before, 18:00) and a daily study call at 17:00.
List<Reminder> buildReminders({required Tree tree, required StudyData data, required DateTime now}) {
  final out = <Reminder>[];
  for (final c in tree.courses) {
    for (final i in c.allItems) {
      if (i.kind != ItemKind.assignment && i.kind != ItemKind.quiz) continue;
      final due = i.due;
      if (due == null || i.submitted == true) continue;
      if (data.items['${c.id}|${i.url}']?.done ?? false) continue;
      for (final h in [24, 3]) {
        final at = data.settings.clampToWindow(due.subtract(Duration(hours: h)), earlier: true);
        if (at.isAfter(now)) {
          out.add(Reminder(at, 'تذكير: ${kindLabels[i.kind]} خلال ${h == 24 ? 'يوم' : '3 ساعات'}',
              '${i.title}\n${c.title}\nالموعد: ${_hm(due)}'));
        }
      }
    }
    final ex = data.courses[c.id]?.exam;
    if (ex != null) {
      for (final d in [3, 1]) {
        final at = data.settings.clampToWindow(DateTime(ex.year, ex.month, ex.day - d, 18));
        if (at.isAfter(now)) {
          out.add(Reminder(at, d == 1 ? 'امتحان ${c.title} غداً' : 'امتحان ${c.title} بعد $d أيام',
              'راجع خطتك في «اليوم» وأنهِ ما تبقى من المادة.'));
        }
      }
    }
  }
  for (var k = 0; k < 7; k++) {
    final day = DateTime(now.year, now.month, now.day + k);
    final at = data.settings.clampToWindow(DateTime(day.year, day.month, day.day, 17));
    final h = data.settings.hours[day.weekday - 1];
    if (at.isAfter(now) && h > 0) {
      out.add(Reminder(at, 'وقت المذاكرة', 'خصّصت ${h.toStringAsFixed(h == h.roundToDouble() ? 0 : 1)} ساعات اليوم. افتح «اليوم» لترى خطتك.'));
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out.take(60).toList();
}
