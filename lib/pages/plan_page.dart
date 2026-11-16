import 'package:flutter/material.dart';
import '../app_state.dart';
import '../planner.dart';
import '../theme.dart';
import '../widgets.dart';

class PlanPage extends StatelessWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (c, _) {
        final plan = app.plan;
        if (plan == null) {
          return const EmptyNote(icon: Icons.event_note_outlined, title: 'لا توجد خطة بعد', body: 'استورد موادك من مودل أولاً.');
        }
        final r = plan.report;
        final days = plan.days.where((d) => d.slots.isNotEmpty).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          Row(children: [
            Expanded(child: _Stat(icon: Icons.timelapse, label: 'المتبقي', value: fmtMin(r.totalMin))),
            const SizedBox(width: 10),
            Expanded(child: _Stat(icon: Icons.hourglass_bottom, label: 'المتاح', value: fmtMin(r.availableMin))),
            const SizedBox(width: 10),
            Expanded(child: _Stat(icon: Icons.calendar_today_outlined, label: 'الأيام', value: '${r.daysLeft + 1}')),
          ]),
          if (r.shortfallMin > 0) ...[
            const SizedBox(height: 10),
            Panel(
              color: kWarnBg,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.warning_amber_rounded, color: kWarn),
                  const SizedBox(width: 8),
                  Expanded(child: Text('لا يتسع ${fmtMin(r.shortfallMin)} في وقتك', style: TextStyle(fontWeight: FontWeight.w700, color: kWarnText))),
                ]),
                const SizedBox(height: 8),
                for (final e in r.shortfallByCourse.entries) Text('${e.key}: ينقص ${fmtMin(e.value)}', style: TextStyle(color: kWarnText, height: 1.6)),
                const SizedBox(height: 6),
                Text('الحل: زد ${r.extraHoursPerDay.toStringAsFixed(1)} ساعة يومياً، أو غيّر الأولويات، أو أبعد موعد الامتحان إن أمكن.', style: TextStyle(height: 1.6, color: kInk)),
              ]),
            ),
          ],
          if (days.isEmpty) const Padding(padding: EdgeInsets.only(top: 28), child: Text('لا توجد أيام مجدولة.', textAlign: TextAlign.center)),
          for (final d in days) _DayCard(day: d),
        ]);
      });
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Stat({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: cardBox(18),
        child: Column(children: [
          Icon(icon, size: 20, color: kForest),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(fontSize: 12, color: kInk.withValues(alpha: 0.65))),
        ]),
      );
}

class _DayCard extends StatelessWidget {
  final DayPlan day;
  const _DayCard({required this.day});
  @override
  Widget build(BuildContext context) {
    final isToday = dOnlyEq(day.date, DateTime.now());
    final doneN = day.slots.where((s) => s.task.done).length;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Panel(
        color: isToday ? kTint : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: isToday ? kForest : kSurface2, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text('${day.date.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isToday ? Colors.white : kInk)),
                Text('${day.date.month}', style: TextStyle(fontSize: 11.5, color: isToday ? Colors.white70 : kInk.withValues(alpha: 0.6))),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isToday ? 'اليوم  ·  ${weekdayNames[day.date.weekday - 1]}' : weekdayNames[day.date.weekday - 1], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                Text('$doneN من ${day.slots.length} منجزة', style: TextStyle(fontSize: 12.5, color: kInk.withValues(alpha: 0.65))),
              ]),
            ),
            Pill(fmtMin(day.used), icon: Icons.schedule, bg: isToday ? kSurface : null),
          ]),
          const SizedBox(height: 10),
          for (final s in day.slots)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Icon(s.task.done ? Icons.check_circle : kindIcon(s.task.kind), size: 19, color: s.task.done ? kForest : kMoss),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600, height: 1.3, decoration: s.task.done ? TextDecoration.lineThrough : null, color: s.task.done ? kInk.withValues(alpha: 0.5) : kInk)),
                    Text(s.task.courseTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: kInk.withValues(alpha: 0.6))),
                  ]),
                ),
                const SizedBox(width: 8),
                Text(fmtMin(s.minutes), style: TextStyle(fontSize: 12.5, color: kMoss)),
              ]),
            ),
        ]),
      ),
    );
  }
}

bool dOnlyEq(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
