// Pure Dart (no Flutter / no IO): study settings, per-course config, per-item state, sync news.
import 'models.dart';

DateTime dOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole days from [a] to [b] (calendar days, immune to daylight-saving shifts)
int dayDiff(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

class CourseCfg {
  int priority; // 1 low, 2 normal, 3 high
  int difficulty; // 1 easy .. 5 very hard
  DateTime? exam; // midterm / final date; study must end the day before
  String aiNote;
  CourseCfg({this.priority = 2, this.difficulty = 3, this.exam, this.aiNote = ''});

  Map<String, dynamic> toJson() => {
        'priority': priority,
        'difficulty': difficulty,
        'exam': exam?.toIso8601String(),
        'aiNote': aiNote,
      };

  factory CourseCfg.fromJson(Map<String, dynamic> j) => CourseCfg(
        priority: (j['priority'] as num?)?.toInt() ?? 2,
        difficulty: (j['difficulty'] as num?)?.toInt() ?? 3,
        exam: j['exam'] == null ? null : DateTime.parse(j['exam'] as String),
        aiNote: (j['aiNote'] as String?) ?? '',
      );
}

class ItemState {
  bool done;
  DateTime? doneAt;
  int? minutes; // typed by the user (wins over everything)
  int? aiMinutes; // estimated by the AI
  DateTime? firstSeen; // when the app first saw this item (proxy for the upload time)
  bool baseline; // seen in the very first import: its real upload time is unknown
  ItemState({this.done = false, this.doneAt, this.minutes, this.aiMinutes, this.firstSeen, this.baseline = false});

  Map<String, dynamic> toJson() => {
        'done': done,
        'doneAt': doneAt?.toIso8601String(),
        'minutes': minutes,
        'aiMinutes': aiMinutes,
        'firstSeen': firstSeen?.toIso8601String(),
        'baseline': baseline,
      };

  factory ItemState.fromJson(Map<String, dynamic> j) => ItemState(
        done: (j['done'] as bool?) ?? false,
        doneAt: j['doneAt'] == null ? null : DateTime.parse(j['doneAt'] as String),
        minutes: (j['minutes'] as num?)?.toInt(),
        aiMinutes: (j['aiMinutes'] as num?)?.toInt(),
        firstSeen: j['firstSeen'] == null ? null : DateTime.tryParse(j['firstSeen'] as String),
        baseline: (j['baseline'] as bool?) ?? false,
      );
}

class Settings {
  DateTime deadline; // fallback exam date for courses without their own
  List<double> hours; // study hours per weekday, index = DateTime.weekday - 1 (Mon..Sun)
  int bufferDays; // safety days kept free before each exam
  double videoFactor; // video minutes x factor (pauses, notes)
  bool tired; // "I'm tired": capacity x 0.75
  String apiKey;
  String model;
  String provider; // id from aiProviders
  String baseUrl; // empty = provider default
  Settings({
    DateTime? deadline,
    List<double>? hours,
    this.bufferDays = 2,
    this.videoFactor = 1.5,
    this.tired = false,
    this.apiKey = '',
    this.model = '',
    this.provider = 'gemini',
    this.baseUrl = '',
  })  : deadline = deadline ?? DateTime(2026, 12, 2),
        hours = hours ?? List<double>.filled(7, 4.0);

  Map<String, dynamic> toJson() => {
        'deadline': deadline.toIso8601String(),
        'hours': hours,
        'bufferDays': bufferDays,
        'videoFactor': videoFactor,
        'tired': tired,
        'apiKey': apiKey,
        'model': model,
        'provider': provider,
        'baseUrl': baseUrl,
      };

  factory Settings.fromJson(Map<String, dynamic> j) {
    final h = ((j['hours'] as List?) ?? []).map((e) => (e as num).toDouble()).toList();
    return Settings(
      deadline: j['deadline'] == null ? null : DateTime.parse(j['deadline'] as String),
      hours: h.length == 7 ? h : null,
      bufferDays: (j['bufferDays'] as num?)?.toInt() ?? 2,
      videoFactor: (j['videoFactor'] as num?)?.toDouble() ?? 1.5,
      tired: (j['tired'] as bool?) ?? false,
      apiKey: (j['apiKey'] as String?) ?? '',
      model: (j['model'] as String?) ?? '',
      provider: (j['provider'] as String?) ?? 'anthropic',
      baseUrl: (j['baseUrl'] as String?) ?? '',
    );
  }
}

class StudyData {
  Settings settings;
  final Map<String, CourseCfg> courses; // by course id
  final Map<String, ItemState> items; // by "courseId|url"
  StudyData({Settings? settings, Map<String, CourseCfg>? courses, Map<String, ItemState>? items})
      : settings = settings ?? Settings(),
        courses = courses ?? {},
        items = items ?? {};

  CourseCfg cfg(String courseId) => courses.putIfAbsent(courseId, () => CourseCfg());
  ItemState state(String id) => items.putIfAbsent(id, () => ItemState());

  Map<String, dynamic> toJson() => {
        'settings': settings.toJson(),
        'courses': courses.map((k, v) => MapEntry(k, v.toJson())),
        'items': items.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory StudyData.fromJson(Map<String, dynamic> j) => StudyData(
        settings: j['settings'] == null ? null : Settings.fromJson(j['settings'] as Map<String, dynamic>),
        courses: ((j['courses'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, CourseCfg.fromJson(v as Map<String, dynamic>))),
        items: ((j['items'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, ItemState.fromJson(v as Map<String, dynamic>))),
      );
}

// ---------------------------------------------------------------- what's new

class NewsEntry {
  final String course;
  final String title;
  final String kind; // ItemKind.name
  final String url;
  NewsEntry(this.course, this.title, this.kind, this.url);
  Map<String, dynamic> toJson() => {'course': course, 'title': title, 'kind': kind, 'url': url};
  factory NewsEntry.fromJson(Map<String, dynamic> j) =>
      NewsEntry(j['course'] as String, j['title'] as String, j['kind'] as String, j['url'] as String);
}

class SyncNews {
  final DateTime at;
  final bool first; // first import: nothing to compare with
  final List<NewsEntry> added;
  SyncNews({required this.at, required this.first, required this.added});
  Map<String, dynamic> toJson() =>
      {'at': at.toIso8601String(), 'first': first, 'added': added.map((e) => e.toJson()).toList()};
  factory SyncNews.fromJson(Map<String, dynamic> j) => SyncNews(
        at: DateTime.parse(j['at'] as String),
        first: (j['first'] as bool?) ?? false,
        added: ((j['added'] as List?) ?? []).map((e) => NewsEntry.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Items present in [now] but absent from [old] (same course, same URL)
SyncNews computeNews(Tree? old, Tree now) {
  if (old == null) return SyncNews(at: now.fetchedAt, first: true, added: []);
  final before = <String>{
    for (final c in old.courses)
      for (final i in c.allItems) '${c.id}|${i.url}',
  };
  final added = <NewsEntry>[];
  for (final c in now.courses) {
    for (final i in c.allItems) {
      if (i.kind == ItemKind.forum || i.kind == ItemKind.other) continue;
      if (!before.contains('${c.id}|${i.url}')) {
        added.add(NewsEntry(c.title, i.title, i.kind.name, i.url));
      }
    }
  }
  return SyncNews(at: now.fetchedAt, first: false, added: added.take(300).toList());
}

/// Records when each item was first seen. Items that were already in the previous tree (or in the very
/// first import) are flagged [ItemState.baseline]: their real upload time is unknown, so the chapter
/// grouping does not use their timestamp.
void stampFirstSeen(StudyData d, Tree? old, Tree now) {
  final before = <String>{
    if (old != null)
      for (final c in old.courses)
        for (final i in c.allItems) '${c.id}|${i.url}',
  };
  for (final c in now.courses) {
    for (final i in c.allItems) {
      final id = '${c.id}|${i.url}';
      final st = d.state(id);
      if (st.firstSeen != null) continue;
      st.firstSeen = now.fetchedAt;
      st.baseline = old == null || before.contains(id);
    }
  }
}

/// One line of the personal follow-up log ("a new lecture was uploaded", ...)
class ActivityEntry {
  final DateTime at;
  final String course, title, kind;
  ActivityEntry(this.at, this.course, this.title, this.kind);
  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'course': course, 'title': title, 'kind': kind};
  factory ActivityEntry.fromJson(Map<String, dynamic> j) => ActivityEntry(
      DateTime.parse(j['at'] as String), j['course'] as String, j['title'] as String, j['kind'] as String);
}

/// Appends the news of one sync to [log] (newest first, capped)
List<ActivityEntry> appendActivity(List<ActivityEntry> log, SyncNews n, {int cap = 300}) {
  if (n.first) return log;
  final add = [for (final e in n.added) ActivityEntry(n.at, e.course, e.title, e.kind)];
  return [...add, ...log].take(cap).toList();
}
