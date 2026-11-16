import 'package:flutter/material.dart';
import '../viewer/open_item.dart';
import '../app_state.dart';
import '../models.dart';
import '../planner.dart';
import '../study_models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'calendar_page.dart';
import 'strict_page.dart';

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _when(int diff) {
  if (diff < 0) return 'متأخر ${-diff} يوم';
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'غداً';
  return 'بعد $diff يوم';
}

class _Upcoming {
  final DateTime when;
  final String title, sub;
  final IconData icon;
  _Upcoming(this.when, this.title, this.sub, this.icon);
}

/// Home: where am I, what is next, what is coming
class TodayPage extends StatelessWidget {
  final VoidCallback onSync;
  final VoidCallback onPlan;
  const TodayPage({super.key, required this.onSync, required this.onPlan});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (c, _) => _body(c));

  Widget _body(BuildContext context) {
    if (!app.loaded) return Center(child: CircularProgressIndicator(color: kForest));
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
    final slots = today?.slots ?? const <Slot>[];
    final doneToday = slots.where((s) => s.task.done).length;
    Slot? next;
    for (final s in slots) {
      if (!s.task.done) {
        next = s;
        break;
      }
    }
    final now = DateTime.now();
    final day = dOnly(now);
    final news = app.news;

    // exams + deadlines, nearest first
    final up = <_Upcoming>[];
    for (final c in tree.courses) {
      final e = app.data.cfg(c.id).exam;
      if (e == null) continue;
      final d = dayDiff(day, dOnly(e));
      if (d >= 0 && d <= 30) up.add(_Upcoming(dOnly(e), c.title, 'امتحان', Icons.quiz_outlined));
    }
    for (final t in app.tasks) {
      final d = t.item.due;
      if (d == null || t.done) continue;
      final k = dayDiff(day, dOnly(d));
      if (k >= -7 && k <= 14) up.add(_Upcoming(d, t.title, '${t.courseTitle}  ·  ${_hm(d)}', Icons.assignment_outlined));
    }
    up.sort((a, b) => a.when.compareTo(b.when));

    final hour = now.hour;
    final greet = hour < 12 ? 'صباح الخير' : 'مساء الخير';
    final pct = (r.progress * 100).round();

    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
      // ---- hero: greeting + overall progress
      Panel(
        child: Row(children: [
          ProgressRing(
            value: r.progress,
            size: 96,
            child: Text('$pct%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kInk)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greet, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kInk)),
              const SizedBox(height: 2),
              Text('${weekdayNames[now.weekday - 1]}  ${fmtDm(now)}', style: TextStyle(color: kInk.withValues(alpha: 0.65))),
              const SizedBox(height: 10),
              r.totalMin == 0
                  ? const Pill('أنجزت كل شيء', icon: Icons.check_circle_outline)
                  : r.feasible
                      ? Pill('المتبقي ${fmtMin(r.totalMin)}', icon: Icons.timelapse)
                      : Pill('زد ${r.extraHoursPerDay.toStringAsFixed(1)} ساعة يومياً', icon: Icons.warning_amber_rounded, bg: kWarnBg, fg: kWarnText),
            ]),
          ),
        ]),
      ),
      if (!r.feasible && r.warnings.isNotEmpty) ...[
        const SizedBox(height: 10),
        Panel(
          color: kWarnBg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final w in r.warnings.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(w.startsWith('!') ? w.substring(1) : w, style: TextStyle(color: kWarnText, height: 1.5)),
              ),
          ]),
        ),
      ],

      // ---- the one thing to do now
      if (next != null) ...[
        const SizedBox(height: 12),
        _FocusCard(slot: next),
      ],

      // ---- quick actions
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.lock_clock,
            label: 'الختم الدراسي',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StrictPage())),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.calendar_month_outlined,
            label: 'التقويم',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarPage())),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _QuickAction(icon: Icons.event_note_outlined, label: 'الخطة', onTap: onPlan)),
      ]),

      // ---- today's checklist
      Heading('مهام اليوم', trailing: slots.isEmpty ? null : Pill('$doneToday/${slots.length}  ·  ${fmtMin(today?.used ?? 0)}')),
      if (slots.isEmpty)
        const Panel(child: Text('لا مهام مجدولة اليوم. إن أنهيت ساعات اليوم يظهر هنا ما تبقى، أو غيّر الساعات من الإعدادات.', style: TextStyle(height: 1.6)))
      else
        for (final s in slots) _SlotTile(slot: s),

      // ---- coming up
      if (up.isNotEmpty) ...[
        const Heading('قريباً'),
        for (final u in up.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                IconBadge(u.icon, color: kBrown, bg: kBrownLight),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(u.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: kInk.withValues(alpha: 0.65))),
                  ]),
                ),
                Builder(builder: (_) {
                  final k = dayDiff(day, dOnly(u.when));
                  final hot = k <= 1;
                  return Pill(_when(k), icon: hot ? Icons.priority_high : null, bg: hot ? kWarnBg : null, fg: hot ? kWarnText : null);
                }),
              ]),
            ),
          ),
      ] else
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text('حدّد موعد امتحان كل مادة من تبويب «المواد» ليبني المرشد خطتك على مواعيدك الحقيقية.',
              style: TextStyle(color: kMoss, height: 1.6)),
        ),

      // ---- what's new on Moodle
      if (news != null && !news.first && news.added.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          decoration: cardBox(22),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const IconBadge(Icons.fiber_new_outlined),
              title: Text('جديد في مودل  ·  ${news.added.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                for (final e in news.added.take(10))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Icon(kindIcon(ItemKind.values.firstWhere((k) => k.name == e.kind, orElse: () => ItemKind.other)), size: 19, color: kForest),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          Text(e.course, style: TextStyle(fontSize: 12, color: kMoss)),
                        ]),
                      ),
                    ]),
                  ),
                if (news.added.length > 10)
                  Align(alignment: AlignmentDirectional.centerStart, child: Text('و ${news.added.length - 10} عناصر أخرى', style: TextStyle(color: kMoss))),
              ],
            ),
          ),
        ),
      ],

      // ---- last import
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('آخر استيراد: ${fmtDm(tree.fetchedAt)}  ${_hm(tree.fetchedAt)}', style: TextStyle(fontSize: 12.5, color: kInk.withValues(alpha: 0.6))),
          TextButton.icon(onPressed: onSync, icon: const Icon(Icons.sync, size: 18), label: const Text('استيراد الآن')),
        ]),
      ),
    ]);
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: kOutline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Icon(icon, color: kForest, size: 26),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}

class _FocusCard extends StatelessWidget {
  final Slot slot;
  const _FocusCard({required this.slot});
  @override
  Widget build(BuildContext context) {
    final t = slot.task;
    return Panel(
      color: kTint,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('التالي في خطتك', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kForest)),
        const SizedBox(height: 8),
        Row(children: [
          IconBadge(kindIcon(t.kind), bg: kSurface),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35)),
              const SizedBox(height: 2),
              Text('${t.courseTitle}  ·  ${fmtMin(slot.minutes)}${slot.partial ? '  ·  جزء من المهمة' : ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: kInk.withValues(alpha: 0.7))),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => openItem(context, url: t.item.url, title: t.title, kind: t.kind),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('ابدأ'),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StrictPage(task: t))),
            icon: const Icon(Icons.lock_clock),
            label: const Text('ختم دراسي'),
          ),
        ]),
      ]),
    );
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
      child: Material(
        color: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: kOutline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: t.done ? null : () => openItem(context, url: t.item.url, title: t.title, kind: t.kind),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
            child: Row(children: [
              Checkbox(
                value: t.done,
                shape: const CircleBorder(),
                activeColor: kForest,
                side: BorderSide(color: kMoss, width: 1.6),
                onChanged: (_) => app.toggle(t),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, decoration: t.done ? TextDecoration.lineThrough : null, color: t.done ? kInk.withValues(alpha: 0.5) : kInk)),
                  Text('${t.courseTitle}${slot.partial ? '  ·  جزء من المهمة' : ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: kInk.withValues(alpha: 0.6))),
                ]),
              ),
              const SizedBox(width: 8),
              Pill(fmtMin(slot.minutes), icon: kindIcon(t.kind)),
            ]),
          ),
        ),
      ),
    );
  }
}
