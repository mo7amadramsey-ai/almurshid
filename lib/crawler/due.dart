// Pure Dart: finds the deadline written on a Moodle assignment / quiz page.
// Works on the visible text, in English or Arabic ("Due: Monday, 2 December 2026, 11:59 PM",
// "تاريخ التسليم: الاثنين، 2 كانون الأول 2026، 11:59 م"). Returns null when nothing is found.
import 'package:html/parser.dart' as hp;

const _months = <String, int>{
  'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3, 'april': 4, 'apr': 4, 'may': 5,
  'june': 6, 'jun': 6, 'july': 7, 'jul': 7, 'august': 8, 'aug': 8, 'september': 9, 'sep': 9, 'sept': 9,
  'october': 10, 'oct': 10, 'november': 11, 'nov': 11, 'december': 12, 'dec': 12,
  'يناير': 1, 'فبراير': 2, 'مارس': 3, 'أبريل': 4, 'ابريل': 4, 'مايو': 5, 'يونيو': 6, 'يوليو': 7,
  'أغسطس': 8, 'اغسطس': 8, 'سبتمبر': 9, 'أكتوبر': 10, 'اكتوبر': 10, 'نوفمبر': 11, 'ديسمبر': 12,
  'شباط': 2, 'آذار': 3, 'نيسان': 4, 'أيار': 5, 'حزيران': 6, 'تموز': 7, 'آب': 8, 'أيلول': 9,
};

// Two-word Levantine month names are folded into one token before matching
const _multi = <String, String>{
  'كانون الثاني': 'يناير',
  'كانون الأول': 'ديسمبر',
  'تشرين الأول': 'أكتوبر',
  'تشرين الثاني': 'نوفمبر',
};

const _labels = <String>[
  'due:', 'due date', 'due ', 'تاريخ التسليم', 'موعد التسليم', 'موعد الاستحقاق', 'مستحق',
  'closes:', 'closes', 'close:', 'will close', 'يغلق', 'يُغلق', 'ينتهي', 'إغلاق', 'closing',
];

String _digits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = ar.indexOf(c);
    b.write(i >= 0 ? '$i' : c);
  }
  return b.toString();
}

String _plain(String html) {
  final doc = hp.parse(html);
  doc.querySelectorAll('script,style,nav').forEach((e) => e.remove());
  var t = _digits(doc.body?.text ?? doc.documentElement?.text ?? '');
  _multi.forEach((k, v) => t = t.replaceAll(k, v));
  return t.replaceAll(RegExp(r'\s+'), ' ');
}

final _dayFirst = RegExp(
    r'(\d{1,2})\s+([A-Za-z\u0600-\u06FF]+)\s*,?،?\s*(\d{4})(?:\s*,?،?\s*(\d{1,2}):(\d{2})\s*([AaPp]\.?[Mm]\.?|ص|م)?)?');
final _monthFirst =
    RegExp(r'([A-Za-z]+)\s+(\d{1,2})\s*,?\s*(\d{4})(?:\s*,?\s*(\d{1,2}):(\d{2})\s*([AaPp]\.?[Mm]\.?|ص|م)?)?');

DateTime? _build(int d, String mon, int y, String? hh, String? mm, String? ap) {
  final m = _months[mon.toLowerCase()];
  if (m == null || d < 1 || d > 31) return null;
  var h = hh == null ? 23 : int.parse(hh);
  final mi = mm == null ? 59 : int.parse(mm);
  if (ap != null) {
    final pm = ap.toLowerCase().startsWith('p') || ap == 'م';
    if (pm && h < 12) h += 12;
    if (!pm && h == 12) h = 0;
  }
  return DateTime(y, m, d, h, mi);
}

DateTime? _parseAt(String s) {
  final a = _dayFirst.firstMatch(s);
  final b = _monthFirst.firstMatch(s);
  DateTime? ra, rb;
  if (a != null) ra = _build(int.parse(a.group(1)!), a.group(2)!, int.parse(a.group(3)!), a.group(4), a.group(5), a.group(6));
  if (b != null) rb = _build(int.parse(b.group(2)!), b.group(1)!, int.parse(b.group(3)!), b.group(4), b.group(5), b.group(6));
  if (ra != null && rb != null) return (a!.start <= b!.start) ? ra : rb;
  return ra ?? rb;
}

/// The first deadline found after a "due"-like label; "Opened:" dates are ignored.
DateTime? parseDueDate(String html) {
  final t = _plain(html);
  final low = t.toLowerCase();
  for (final l in _labels) {
    var from = 0;
    while (true) {
      final i = low.indexOf(l.toLowerCase(), from);
      if (i < 0) break;
      final end = (i + l.length + 90) > t.length ? t.length : i + l.length + 90;
      final d = _parseAt(t.substring(i + l.length, end));
      if (d != null) return d;
      from = i + l.length;
    }
  }
  return null;
}

/// Submission status printed on an assignment page: true = submitted, false = not submitted, null = unknown.
/// Only the text right after a "submission status" label is read, so instructions elsewhere on the page
/// ("... must be submitted for grading") are not mistaken for the student's status.
bool? parseSubmitted(String html) {
  final low = _plain(html).toLowerCase();
  const labels = ['submission status', 'حالة التسليم', 'حالة التقديم', 'حالة الإرسال'];
  for (final l in labels) {
    final i = low.indexOf(l);
    if (i < 0) continue;
    final end = (i + l.length + 90) > low.length ? low.length : i + l.length + 90;
    final w = low.substring(i + l.length, end);
    const no = ['no attempt', 'not submitted', 'no submissions', 'draft', 'لم يتم', 'لا توجد محاولة', 'غير مسلّم', 'غير مسلم', 'لا يوجد تسليم'];
    for (final n in no) {
      if (w.contains(n)) return false;
    }
    const yes = ['submitted for grading', 'submitted', 'تم التسليم', 'تم تسليم', 'تم الإرسال', 'تم تقديم'];
    for (final y in yes) {
      if (w.contains(y)) return true;
    }
  }
  return null;
}
