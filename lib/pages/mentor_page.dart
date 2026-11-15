import 'package:flutter/material.dart';
import '../ai.dart';
import '../app_state.dart';
import '../study_models.dart';
import '../theme.dart';
import '../widgets.dart';

class _Msg {
  final bool user;
  final String text;
  _Msg(this.user, this.text);
}

/// What the mentor knows about the student's situation right now (short, built from local data)
String mentorContext() {
  final b = StringBuffer();
  final now = DateTime.now();
  final s = app.settings;
  b.writeln('اليوم: ${weekdayNames[now.weekday - 1]} ${fmtDm(now)}/${now.year}');
  b.writeln('وضع الطاقة: ${s.tired ? 'متعب (السعة اليومية مخفضة 25%)' : 'عادي'}');
  b.writeln('ساعات الدراسة اليومية المحددة (اثنين..أحد): ${s.hours.map((h) => h.toStringAsFixed(1)).join(', ')}');
  final plan = app.plan;
  final t = app.tree;
  if (t != null) {
    b.writeln('المواد:');
    for (final c in t.courses) {
      final cfg = app.data.cfg(c.id);
      b.writeln('- ${c.title} | أولوية ${cfg.priority}/3 | صعوبة ${cfg.difficulty}/5 | '
          'امتحان ${cfg.exam == null ? 'غير محدد' : '${fmtDm(cfg.exam!)} (بعد ${dayDiff(dOnly(now), cfg.exam!)} يوم)'} | '
          'متبقٍ ${fmtMin(app.remainingMin(c.id))} | منجز ${(app.courseProgress(c.id) * 100).round()}%');
    }
  }
  if (plan != null) {
    final r = plan.report;
    b.writeln('المتبقي كله ${fmtMin(r.totalMin)}، لا يتسع ${fmtMin(r.shortfallMin)}'
        '${r.shortfallMin > 0 ? '، يلزم ${r.extraHoursPerDay.toStringAsFixed(1)} ساعة زيادة يومياً' : ''}');
    final today = plan.today;
    if (today != null && today.slots.isNotEmpty) {
      b.writeln('مهام اليوم المجدولة:');
      for (final sl in today.slots.take(12)) {
        b.writeln('- ${sl.task.title} (${sl.task.courseTitle}) ${fmtMin(sl.minutes)}${sl.task.done ? ' [منجز]' : ''}');
      }
    }
    for (final w in r.warnings.take(4)) {
      b.writeln('تحذير: ${w.startsWith('!') ? w.substring(1) : w}');
    }
  }
  final n = app.news;
  if (n != null && !n.first && n.added.isNotEmpty) {
    b.writeln('عناصر جديدة في مودل منذ آخر استيراد: ${n.added.length} (مثل: ${n.added.take(4).map((e) => e.title).join('، ')})');
  }
  return b.toString();
}

const _system = 'أنت «المرشد»، مرشد دراسي شخصي داخل تطبيق «المرشد الدراسي» لطالب جامعي يدرس عبر مودل. '
    'ساعده على ترتيب وقته ومتابعة دراسته والتغلب على التعب وتشتت التركيز. '
    'اعتمد على بيانات حالته المرفقة ولا تخترع مواعيد أو مواد غير موجودة فيها؛ إن نقصتك معلومة فاسأل سؤالاً واحداً قصيراً. '
    'جاوب بالعربية بلهجة بسيطة ودودة، بإيجاز (بضع جمل أو قائمة قصيرة)، وكن صريحاً: إن كان الوقت لا يكفي فقل ذلك واقترح حلولاً واقعية. '
    'تقترح ولا تُغيّر إعدادات التطبيق بنفسك؛ والطالب هو من يطبّق.';

class MentorPage extends StatefulWidget {
  const MentorPage({super.key});
  @override
  State<MentorPage> createState() => _MentorPageState();
}

class _MentorPageState extends State<MentorPage> {
  final msgs = <_Msg>[];
  final ctrl = TextEditingController();
  final scroll = ScrollController();
  bool busy = false;

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || busy) return;
    ctrl.clear();
    setState(() {
      msgs.add(_Msg(true, q));
      busy = true;
    });
    _down();
    try {
      final history = msgs.length > 12 ? msgs.sublist(msgs.length - 12) : msgs;
      final turns = <Map<String, String>>[];
      for (final m in history) {
        final role = m.user ? 'user' : 'assistant';
        if (turns.isNotEmpty && turns.last['role'] == role) {
          turns.last['content'] = '${turns.last['content']}\n${m.text}';
        } else {
          turns.add({'role': role, 'content': m.text});
        }
      }
      if (turns.first['role'] != 'user') turns.removeAt(0);
      final out = await claudeAsk(
        settings: app.settings,
        system: '$_system\n\n--- حالة الطالب الآن ---\n${mentorContext()}',
        messages: turns,
      );
      if (mounted) setState(() => msgs.add(_Msg(false, out.trim())));
    } catch (e) {
      if (mounted) setState(() => msgs.add(_Msg(false, '$e')));
    } finally {
      if (mounted) setState(() => busy = false);
      _down();
    }
  }

  void _down() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (c, _) {
        if (app.settings.apiKey.trim().isEmpty) {
          return const EmptyNote(
            icon: Icons.auto_awesome,
            title: 'فعّل المرشد الذكي',
            body: 'أضف مفتاح Claude من الإعدادات (أيقونة الترس بالأعلى). يبقى المفتاح على هاتفك فقط.',
          );
        }
        return Column(children: [
          Expanded(
            child: msgs.isEmpty
                ? ListView(controller: scroll, padding: const EdgeInsets.all(16), children: [
                    const Text('اسألني أي شيء عن دراستك، أعرف خطتك ومواعيدك:', style: TextStyle(height: 1.6)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final q in const [
                        'ماذا أدرس اليوم؟',
                        'أنا متعب اليوم، ماذا أفعل؟',
                        'هل أستطيع إنهاء كل شيء قبل الامتحانات؟',
                        'ما أخطر مادة عندي الآن؟',
                      ])
                        ActionChip(label: Text(q), onPressed: () => _send(q)),
                    ]),
                  ])
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: msgs.length + (busy ? 1 : 0),
                    itemBuilder: (c, i) {
                      if (i == msgs.length) return const Padding(padding: EdgeInsets.all(8), child: Align(alignment: AlignmentDirectional.centerStart, child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kOlive))));
                      final m = msgs[i];
                      return Align(
                        alignment: m.user ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                          decoration: BoxDecoration(
                            color: m.user ? kOlive : kSurface,
                            borderRadius: BorderRadius.circular(18),
                            border: m.user ? null : Border.all(color: kOutline),
                          ),
                          child: SelectableText(m.text, style: TextStyle(height: 1.55, color: m.user ? Colors.white : kBrownDark)),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: 'اكتب سؤالك للمرشد',
                      filled: true,
                      fillColor: kSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: kOutline)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: kOutline)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: kOlive),
                  onPressed: busy ? null : () => _send(ctrl.text),
                  icon: const Icon(Icons.send),
                ),
              ]),
            ),
          ),
        ]);
      });
}
