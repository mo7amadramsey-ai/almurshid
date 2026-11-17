import 'package:flutter/material.dart';
import '../app_state.dart';
import '../planner.dart';
import '../study_models.dart';
import '../theme.dart';
import '../widgets.dart';

const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _satFirst = ['س', 'أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع'];
Color get _examColor => kWarnText;

class _DayInfo {
  final List<String> exams = [];
  final List<Task> due = [];
  DayPlan? plan;
}

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Month calendar: exam dates, assignment / quiz deadlines (read from Moodle) and the study plan.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime sel = dOnly(DateTime.now());

  Map<DateTime, _DayInfo> _collect() {
    final m = <DateTime, _DayInfo>{};
    _DayInfo at(DateTime d) => m.putIfAbsent(dOnly(d), () => _DayInfo());
    for (final c in app.tree?.courses ?? []) {
      final e = app.data.courses[c.id]?.exam;
      if (e != null) at(e).exams.add(c.title);
    }
    for (final t in app.tasks) {
      final d = t.item.due;
      if (d != null) at(d).due.add(t);
    }
    for (final d in app.plan?.days ?? <DayPlan>[]) {
      if (d.slots.isNotEmpty) at(d.date).plan = d;
    }
    return m;
  }

  void _shift(int by) => setState(() => month = DateTime(month.year, month.month + by));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('التقويم')),
        body: ListenableBuilder(
          listenable: app,
          builder: (c, _) {
            final info = _collect();
            return ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
              Panel(child: Column(children: [_header(), SizedBox(height: 8), _weekdays(), SizedBox(height: 4), _grid(info)])),
              SizedBox(height: 8),
              _legend(),
              SizedBox(height: 8),
              _details(info[sel]),
            ]);
          },
        ),
      );

  Widget _header() => Row(children: [
        IconButton(onPressed: () => _shift(-1), icon: Icon(Icons.chevron_right)),
        Expanded(
            child: Text('${_months[month.month - 1]} ${month.year}',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        IconButton(onPressed: () => _shift(1), icon: Icon(Icons.chevron_left)),
      ]);

  Widget _weekdays() => Row(children: [
        for (final w in _satFirst) Expanded(child: Center(child: Text(w, style: TextStyle(fontSize: 12, color: kMoss, fontWeight: FontWeight.w700)))),
      ]);

  Widget _grid(Map<DateTime, _DayInfo> info) {
    final first = DateTime(month.year, month.month, 1);
    final offset = (first.weekday + 1) % 7; // Saturday-first week
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((offset + days) / 7).ceil();
    final today = dOnly(DateTime.now());
    return Column(children: [
      for (var r = 0; r < rows; r++)
        Row(children: [
          for (var col = 0; col < 7; col++) Expanded(child: _cell(r * 7 + col - offset + 1, days, info, today)),
        ]),
    ]);
  }

  Widget _cell(int n, int days, Map<DateTime, _DayInfo> info, DateTime today) {
    if (n < 1 || n > days) return SizedBox(height: 54);
    final d = DateTime(month.year, month.month, n);
    final i = info[d];
    final isSel = d == sel, isToday = d == today;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => sel = d),
      child: Container(
        height: 54,
        margin: EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSel ? kForest : (isToday ? kSurface2 : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: isToday && !isSel ? Border.all(color: kForest) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$n', style: TextStyle(fontWeight: FontWeight.w700, color: isSel ? Colors.white : kInk)),
          SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (i != null && i.exams.isNotEmpty) _dot(_examColor, isSel),
            if (i != null && i.due.isNotEmpty) _dot(kGold, isSel),
            if (i?.plan != null) _dot(kMoss, isSel),
          ]),
        ]),
      ),
    );
  }

  Widget _dot(Color c, bool onSel) => Container(
        width: 7,
        height: 7,
        margin: EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(color: onSel ? Colors.white : c, shape: BoxShape.circle),
      );

  Widget _legend() => Wrap(spacing: 16, runSpacing: 4, alignment: WrapAlignment.center, children: [
        for (final e in [('امتحان', _examColor), ('تسليم', kGold), ('دراسة', kMoss)])
          Row(mainAxisSize: MainAxisSize.min, children: [_dot(e.$2, false), Text(' ${e.$1}', style: TextStyle(fontSize: 12.5))]),
      ]);

  Widget _details(_DayInfo? i) {
    final head = '${weekdayNames[sel.weekday - 1]}  ${fmtDm(sel)}';
    final empty = i == null || (i.exams.isEmpty && i.due.isEmpty && i.plan == null);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(head, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Divider(height: 18),
        if (empty) Text('لا شيء في هذا اليوم.'),
        if (i != null) ...[
          for (final e in i.exams)
            _line(Icons.school, _examColor, 'امتحان $e', null),
          for (final t in i.due)
            _line(Icons.assignment_late_outlined, kGold, t.title, '${t.courseTitle}  ·  آخر موعد ${_hm(t.item.due!)}'
                '${t.item.submitted == true ? '  ·  تم التسليم' : ''}'),
          if (i.plan != null) ...[
            SizedBox(height: 6),
            Text('خطة الدراسة · ${fmtMin(i.plan!.used)}', style: TextStyle(fontWeight: FontWeight.w700, color: kMoss)),
            for (final s in i.plan!.slots) _line(kindIcon(s.task.kind), s.task.done ? kForest : kMoss, s.task.title, '${s.task.courseTitle}  ·  ${fmtMin(s.minutes)}'),
          ],
        ],
      ]),
    );
  }

  Widget _line(IconData ic, Color c, String title, String? sub) => Padding(
        padding: EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, size: 20, color: c),
          SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, height: 1.3)),
            if (sub != null) Text(sub, style: TextStyle(fontSize: 12.5, height: 1.4)),
          ])),
        ]),
      );
}
