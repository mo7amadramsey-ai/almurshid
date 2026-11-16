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
          return EmptyNote(icon: Icons.event_note_outlined, title: 'لا توجد خطة بعد', body: 'استورد موادك من مودل أولاً.');
        }
        final r = plan.report;
        final days = plan.days.where((d) => d.slots.isNotEmpty).toList();
        return ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('متبقٍ ${fmtMin(r.totalMin)} على ${r.daysLeft + 1} يوم', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(height: 6),
              Text('الوقت المتاح ${fmtMin(r.availableMin)}'
                  '${r.shortfallMin > 0 ? '  ·  لا يتسع ${fmtMin(r.shortfallMin)}' : ''}'),
              if (r.shortfallByCourse.isNotEmpty) ...[
                SizedBox(height: 8),
                for (final e in r.shortfallByCourse.entries)
                  Text('${e.key}: ينقص ${fmtMin(e.value)}', style: TextStyle(color: kWarnText, height: 1.5)),
                SizedBox(height: 4),
                Text('الحل: زد ${r.extraHoursPerDay.toStringAsFixed(1)} ساعة يومياً، أو غيّر الأولويات، أو أبعد موعد الامتحان إن أمكن.',
                    style: TextStyle(height: 1.5)),
              ],
            ]),
          ),
          if (days.isEmpty)
            Padding(padding: EdgeInsets.only(top: 24), child: Text('لا توجد أيام مجدولة.', textAlign: TextAlign.center)),
          for (final d in days) _DayCard(day: d),
        ]);
      });
}

class _DayCard extends StatelessWidget {
  final DayPlan day;
  const _DayCard({required this.day});
  @override
  Widget build(BuildContext context) {
    final isToday = dOnlyEq(day.date, DateTime.now());
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${weekdayNames[day.date.weekday - 1]}  ${fmtDm(day.date)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: isToday ? kForest : kInk)),
            if (isToday) Padding(padding: EdgeInsetsDirectional.only(start: 8), child: Text('اليوم', style: TextStyle(color: kForest))),
            Spacer(),
            Text(fmtMin(day.used), style: TextStyle(color: kMoss)),
          ]),
          Divider(height: 18),
          for (final s in day.slots)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(kindIcon(s.task.kind), size: 18, color: s.task.done ? kForest : kMoss),
                SizedBox(width: 8),
                Expanded(
                  child: Text('${s.task.title}\n${s.task.courseTitle}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(height: 1.3, decoration: s.task.done ? TextDecoration.lineThrough : null)),
                ),
                Text(fmtMin(s.minutes), style: TextStyle(color: kMoss)),
              ]),
            ),
        ]),
      ),
    );
  }
}

bool dOnlyEq(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
