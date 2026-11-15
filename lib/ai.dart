// AI layer: talks to the Claude API directly from the phone with the user's own key.
// The key lives only in the app's private storage on the phone; it is never in the repository.
import 'dart:convert';
import 'dart:io';
import 'planner.dart';
import 'study_models.dart';

Future<String> claudeAsk({
  required Settings settings,
  required String system,
  required List<Map<String, String>> messages,
  int maxTokens = 1500,
}) async {
  if (settings.apiKey.trim().isEmpty) throw 'أضف مفتاح Claude من الإعدادات أولاً';
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final req = await client.postUrl(Uri.parse('https://api.anthropic.com/v1/messages'));
    req.headers.set('content-type', 'application/json');
    req.headers.set('x-api-key', settings.apiKey.trim());
    req.headers.set('anthropic-version', '2023-06-01');
    req.add(utf8.encode(jsonEncode({
      'model': settings.model,
      'max_tokens': maxTokens,
      'system': system,
      'messages': messages,
    })));
    final res = await req.close().timeout(const Duration(seconds: 90));
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      var msg = text;
      try {
        msg = (jsonDecode(text) as Map<String, dynamic>)['error']['message'] as String;
      } catch (_) {}
      throw 'خطأ ${res.statusCode}: $msg';
    }
    final j = jsonDecode(text) as Map<String, dynamic>;
    return (j['content'] as List)
        .where((c) => (c as Map)['type'] == 'text')
        .map((c) => (c as Map)['text'] as String)
        .join('\n');
  } finally {
    client.close();
  }
}

class CourseAnalysis {
  final int difficulty;
  final String reason;
  final Map<int, int> minutes; // task index -> minutes
  CourseAnalysis(this.difficulty, this.reason, this.minutes);
}

dynamic _extractJson(String t) {
  final a = t.indexOf('{');
  final b = t.lastIndexOf('}');
  if (a < 0 || b <= a) throw 'ردّ غير مفهوم من الذكاء الاصطناعي';
  return jsonDecode(t.substring(a, b + 1));
}

/// Rates a course's difficulty (1-5) and estimates study minutes for items whose length cannot be known
/// from Moodle. It only sees titles and kinds - nothing else leaves the phone.
Future<CourseAnalysis> analyzeCourse(Settings s, String courseTitle, List<Task> tasks) async {
  final list = tasks.take(150).toList();
  final lines = StringBuffer();
  for (var i = 0; i < list.length; i++) {
    lines.writeln('$i|${list[i].kind.name}|${list[i].section}|${list[i].title}');
  }
  const system = 'أنت مرشد دراسي لطالب جامعي. تقيّم صعوبة المواد وتقدّر وقت الدراسة بواقعية. '
      'أجب بكائن JSON واحد فقط بدون أي نص آخر.';
  final user = 'المادة: $courseTitle\n'
      'عناصر المادة بصيغة رقم|النوع|القسم|العنوان:\n$lines\n'
      'المطلوب JSON بهذا الشكل بالضبط:\n'
      '{"difficulty": رقم من 1 إلى 5, "reason": "جملة أو جملتان بالعربية عن سبب الصعوبة وكيف يذاكرها الطالب", '
      '"minutes": {"رقم العنصر": دقائق الدراسة الفعلية}}\n'
      'قدّر الدقائق للمستندات والصفحات والتكاليف والاختبارات حسب عنوانها. '
      'لا تقدّر مدة أي فيديو لا تعرف مدته، واترك رقمه خارج القائمة. اجعل الأرقام من مضاعفات 5.';
  final out = await claudeAsk(settings: s, system: system, messages: [
    {'role': 'user', 'content': user}
  ]);
  final j = _extractJson(out) as Map<String, dynamic>;
  final mins = <int, int>{};
  ((j['minutes'] as Map?) ?? {}).forEach((k, v) {
    final i = int.tryParse('$k');
    final m = (v as num?)?.toInt();
    if (i != null && m != null && i >= 0 && i < list.length && m > 0 && m <= 600) mins[i] = m;
  });
  final d = ((j['difficulty'] as num?)?.toInt() ?? 3).clamp(1, 5);
  return CourseAnalysis(d, (j['reason'] as String?) ?? '', mins);
}
