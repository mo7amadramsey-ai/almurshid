// AI layer: talks to any provider (Gemini, Groq, OpenRouter, OpenAI, Claude, or a custom/local server) directly from the phone with the user's own key.
// The key lives only in the app's private storage on the phone; it is never in the repository.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'planner.dart';
import 'study_models.dart';

class AiProvider {
  final String id, name, baseUrl, model, keyHint;
  final bool anthropic; // true: Anthropic Messages API; false: OpenAI-compatible chat/completions
  final bool needsKey;
  const AiProvider(this.id, this.name, this.baseUrl, this.model, this.keyHint,
      {this.anthropic = false, this.needsKey = true});
}

/// Every provider except Claude speaks the OpenAI-compatible protocol, so any new service
/// (or a local server) works through the "custom" entry with its own base URL.
const aiProviders = <AiProvider>[
  AiProvider('gemini', 'Google Gemini (مفتاح مجاني)', 'https://generativelanguage.googleapis.com/v1beta/openai',
      'gemini-2.5-flash', 'من aistudio.google.com/apikey'),
  AiProvider('groq', 'Groq (مجاني)', 'https://api.groq.com/openai/v1', 'llama-3.3-70b-versatile', 'من console.groq.com/keys'),
  AiProvider('openrouter', 'OpenRouter (نماذج مجانية)', 'https://openrouter.ai/api/v1', 'meta-llama/llama-3.3-70b-instruct:free',
      'من openrouter.ai/keys'),
  AiProvider('openai', 'ChatGPT / OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini', 'من platform.openai.com/api-keys'),
  AiProvider('anthropic', 'Claude / Anthropic', 'https://api.anthropic.com/v1/messages', 'claude-sonnet-5-5',
      'من console.anthropic.com', anthropic: true),
  AiProvider('custom', 'مخصص (أي خدمة متوافقة مع OpenAI، أو Ollama على جهازك)', 'http://192.168.1.10:11434/v1', 'llama3.1', 'اتركه فارغاً لو لا يحتاج مفتاحاً',
      needsKey: false),
];

AiProvider providerById(String id) => aiProviders.firstWhere((p) => p.id == id, orElse: () => aiProviders.first);

bool aiReady(Settings s) {
  final p = providerById(s.provider);
  return s.apiKey.trim().isNotEmpty || !p.needsKey;
}

bool _isLocalHost(String h) {
  final x = h.toLowerCase();
  if (x == 'localhost' || x.endsWith('.local')) return true;
  final p = x.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.any((e) => e == null)) return false;
  final a = p[0]!, b = p[1]!;
  return a == 127 || a == 10 || (a == 192 && b == 168) || (a == 172 && b >= 16 && b <= 31);
}

/// Throws a clear message when the address is unsafe: HTTPS is required whenever a key is sent;
/// plain HTTP is only accepted for a keyless server on the local network (e.g. Ollama).
void checkEndpoint(String url, {required bool hasKey}) {
  final u = Uri.tryParse(url);
  if (u == null || u.host.isEmpty || !(u.scheme == 'https' || u.scheme == 'http')) throw 'عنوان الخدمة غير صالح';
  if (u.scheme == 'http') {
    if (hasKey) throw 'لا يُسمح بإرسال المفتاح عبر اتصال غير مشفّر (http). استخدم عنواناً يبدأ بـ https.';
    if (!_isLocalHost(u.host)) throw 'اتصال http مسموح فقط لخادم على شبكتك المحلية بدون مفتاح.';
  }
}

Future<String> aiAsk({
  required Settings settings,
  required String system,
  required List<Map<String, String>> messages,
  int maxTokens = 1500,
}) async {
  final p = providerById(settings.provider);
  if (!aiReady(settings)) throw 'أضف مفتاح الذكاء الاصطناعي من الإعدادات أولاً';
  final base = (settings.baseUrl.trim().isEmpty ? p.baseUrl : settings.baseUrl.trim()).replaceAll(RegExp(r'/+$'), '');
  final model = settings.model.trim().isEmpty ? p.model : settings.model.trim();
  // Pasted keys often carry spaces/line breaks/invisible chars; strip them.
  final key = settings.apiKey.replaceAll(RegExp(r'[\s\u200B-\u200F\u202A-\u202E\uFEFF]'), '');
  checkEndpoint(base, hasKey: key.isNotEmpty);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    late final HttpClientRequest req;
    late final String body;
    if (p.anthropic) {
      final url = base.endsWith('/messages') ? base : '$base/messages';
      req = await client.postUrl(Uri.parse(url));
      req.headers.set('x-api-key', key);
      req.headers.set('anthropic-version', '2023-06-01');
      body = jsonEncode({'model': model, 'max_tokens': maxTokens, 'system': system, 'messages': messages});
    } else {
      req = await client.postUrl(Uri.parse('$base/chat/completions'));
      if (key.isNotEmpty) req.headers.set('authorization', 'Bearer $key');
      // Gemini 2.5 thinks first; thinking tokens count against max_tokens, so a small limit
      // returns empty content (null). Leave headroom.
      final limit = p.id == 'gemini' ? maxTokens + 6000 : maxTokens;
      body = jsonEncode({
        'model': model,
        'max_tokens': limit,
        'messages': [
          {'role': 'system', 'content': system},
          ...messages,
        ],
      });
    }
    req.headers.set('content-type', 'application/json');
    req.add(utf8.encode(body));
    final res = await req.close().timeout(const Duration(seconds: 90));
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      var msg = text.length > 300 ? text.substring(0, 300) : text;
      try {
        final e = (jsonDecode(text) as dynamic);
        final err = e is List ? e.first['error'] : e['error'];
        msg = err is Map ? '${err['message']}' : '$err';
      } catch (_) {}
      final hint = switch (res.statusCode) {
        400 => ' (تأكد من اسم النموذج ومن المفتاح)',
        401 || 403 => ' (المفتاح مرفوض: انسخه من جديد من ${p.keyHint})',
        404 => ' (اسم النموذج أو العنوان غير صحيح)',
        429 => ' (تجاوزت الحد المجاني: انتظر دقيقة أو بدّل النموذج)',
        _ => '',
      };
      throw 'خطأ ${res.statusCode}: $msg$hint';
    }
    final j = jsonDecode(text) as Map<String, dynamic>;
    if (p.anthropic) {
      return (j['content'] as List)
          .where((c) => (c as Map)['type'] == 'text')
          .map((c) => (c as Map)['text'] as String)
          .join('\n');
    }
    final choices = j['choices'] as List?;
    if (choices == null || choices.isEmpty) throw 'ردّ فارغ من ${p.name}';
    final c0 = choices.first as Map;
    final content = (c0['message'] as Map?)?['content'];
    if (content is! String || content.trim().isEmpty) {
      throw 'النموذج لم يُرجع نصاً (السبب: ${c0['finish_reason']}). جرّب نموذجاً آخر من الإعدادات.';
    }
    return content;
  } on SocketException {
    throw 'تعذّر الاتصال بالخادم: تأكد من الإنترنت (أو أوقف VPN) ثم أعد المحاولة';
  } on HandshakeException {
    throw 'فشل الاتصال الآمن: تأكد من تاريخ ووقت الهاتف ومن الإنترنت';
  } on TimeoutException {
    throw 'انتهت مهلة الاتصال: الشبكة بطيئة، أعد المحاولة';
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
  final out = await aiAsk(settings: s, system: system, messages: [
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
