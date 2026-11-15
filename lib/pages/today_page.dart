import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../planner.dart';
import '../study_models.dart';
import '../theme.dart';
import '../widgets.dart';

class TodayPage extends StatelessWidget {
  final VoidCallback onSync;
  final VoidCallback onPlan;
  const TodayPage({super.key, required this.onSync, required this.onPlan});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (c, _) => _body(c));

  Widget _body(BuildContext context) {
    if (!app.loaded) return const Center(child: CircularProgressIndicator(color: kOlive));
    final tree = app.tree;
    final plan = app.plan;
    if (tree == null || plan == null) {
      return EmptyNote(
        icon: Icons.school_outlined,
        title: 'ابدأ باستيراد موادك',
        body: 'سجّل دخولك لمودل مرة واحدة، وسيقرأ المرشد كل موادك ويبني لك خطة يومية.',
        action: FilledButton.icon(onPressed: onSync, icon: const Icon(Icons.sync), label: const Text('استيراد من مودل')),
      );
    }
    final r = plan.report;
    final today = plan.today;
    final news = app.news;
    final exams = <MapEntry<Course, DateTime>>[
      for (final c in tree.courses)
        if (app.data.cfg(c.id).exam != null) MapEntry(c, dOnly(app.data.cfg(c.id).exam!)),
    ]..sort((a, b) => a.value.compareTo(b.value));
    final now = dOnly(DateTime.now());

    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
      // ---- overall status
      Panel(
        color: r.feasible ? null : const Color(0xFFF3E1D3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(r.feasible ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                color: r.feasible ? kOlive : const Color(0xFFB5602E)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                r.totalMin == 0
                    ? 'لا يوجد شيء متبقٍ في الخطة'
                    : r.feasible
                        ? 'الوقت يكفي لإنهاء كل شيء قبل مواعيدك'
                        : 'الوقت لا يكفي، تحتاج ${r.extraHoursPerDay.toStringAsFixed(1)} ساعة زيادة يومياً',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.4),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
                value: r.progress, minHeight: 9, color: kOlive, backgroundColor: kSurface2),
          ),
          const SizedBox(height: 8),
          Text('أنجزت ${(r.progress * 100).round()}%  ·  المتبقي ${fmtMin(r.totalMin)}',
              style: const TextStyle(height: 1.4)),
          for (final w in r.warnings.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(w.startsWith('!') ? w.substring(1) : w,
                  style: const TextStyle(color: Color(0xFF9A4A1F), height: 1.4)),
            ),
        ]),
      ),

      // ---- today's checklist
      Heading('مهام اليوم${today == null ? '' : '  ·  ${fmtMin(today.used)}'}',
          trailing: TextButton(onPressed: onPlan, child: const Text('الخطة كاملة'))),
      if (today == null || today.slots.isEmpty)
        const Panel(child: Text('لا مهام مجدولة اليوم. إن كنت قد أنجزت ساعات اليوم أو أضفت وقتاً أقل، يظهر هنا ما تبقى.', style: TextStyle(height: 1.5)))
      else
        for (final s in today.slots) _SlotTile(slot: s),

      // ---- what's new
      if (news != null && !news.first && news.added.isNotEmpty) ...[
        Heading('جديد في مودل  ·  ${news.added.length}'),
        Panel(
          child: Column(children: [
            for (final e in news.added.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Icon(kindIcon(ItemKind.values.firstWhere((k) => k.name == e.kind, orElse: () => ItemKind.other)),
                      size: 20, color: kOlive),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(e.course, style: const TextStyle(fontSize: 12, color: kBrown)),
                    ]),
                  ),
                ]),
              ),
            if (news.added.length > 8)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('و ${news.added.length - 8} عناصر أخرى', style: const TextStyle(color: kBrown)),
              ),
          ]),
        ),
      ] else if (news != null && !news.first)
        const Padding(
          padding: EdgeInsets.only(top: 14),
          child: Text('لا جديد في مودل منذ آخر استيراد.', style: TextStyle(color: kBrown)),
        ),

      // ---- exams
      if (exams.isNotEmpty) ...[
        const Heading('الامتحانات'),
        for (final e in exams)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Expanded(child: Text(e.key.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('${fmtDm(e.value)}  ·  ${dayDiff(now, e.value) < 0 ? 'فات' : 'بعد ${dayDiff(now, e.value)} يوم'}',
                    style: const TextStyle(color: kBrown)),
              ]),
            ),
          ),
      ] else
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text('حدّد موعد امتحان كل مادة من تبويب «المواد» ليبني المرشد خطتك على مواعيدك الحقيقية.',
              style: TextStyle(color: kBrown, height: 1.5)),
        ),
    ]);
  }
}

class _SlotTile extends StatelessWidget {
  final Slot slot;
  const _SlotTile({required this.slot});
  @override
  Widget build(BuildContext context) {
    final t = slot.task;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: cardBox(18),
        child: CheckboxListTile(
          value: t.done,
          activeColor: kOlive,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (_) => app.toggle(t),
          secondary: Icon(kindIcon(t.kind), color: kBrown),
          title: Text(t.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(decoration: t.done ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w600)),
          subtitle: Text('${t.courseTitle}  ·  ${fmtMin(slot.minutes)}${slot.partial ? '  ·  جزء من المهمة' : ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
