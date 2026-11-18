import '../media/download_sheet.dart';
import 'package:flutter/material.dart';
import '../viewer/open_item.dart';
import '../ai.dart';
import '../app_state.dart';
import '../chapters.dart';
import '../models.dart';
import '../planner.dart';
import '../study_models.dart';
import '../theme.dart';
import '../widgets.dart';

class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (c, _) {
        final t = app.tree;
        if (t == null) {
          return EmptyNote(icon: Icons.menu_book_outlined, title: 'لا مواد بعد', body: 'استورد موادك من مودل أولاً.');
        }
        final now = dOnly(DateTime.now());
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          for (final course in t.courses) _CourseCard(course: course, now: now),
        ]);
      });
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final DateTime now;
  const _CourseCard({required this.course, required this.now});

  @override
  Widget build(BuildContext context) {
    final cfg = app.data.cfg(course.id);
    final p = app.courseProgress(course.id);
    final exam = cfg.exam;
    final left = exam == null ? null : dayDiff(now, dOnly(exam));
    final hot = left != null && left <= 3;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: kOutline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CoursePage(course: course))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              ProgressRing(
                value: p,
                size: 66,
                child: Text('${(p * 100).round()}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(course.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.35)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    Pill('متبقٍ ${fmtMin(app.remainingMin(course.id))}', icon: Icons.timelapse),
                    Pill('صعوبة ${cfg.difficulty}/5', icon: Icons.speed),
                    exam == null
                        ? Pill('بلا موعد امتحان', icon: Icons.event_busy, bg: kWarnBg, fg: kWarnText)
                        : Pill('امتحان ${fmtDm(exam)}  ·  ${left! < 0 ? 'فات' : 'بعد $left يوم'}',
                            icon: Icons.quiz_outlined, bg: hot ? kWarnBg : kBrownLight, fg: hot ? kWarnText : kBrownDark),
                  ]),
                ]),
              ),
              Icon(Icons.chevron_left, color: kInk.withValues(alpha: 0.4)),
            ]),
          ),
        ),
      ),
    );
  }
}

class CoursePage extends StatefulWidget {
  final Course course;
  const CoursePage({super.key, required this.course});
  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  bool busy = false;

  Future<void> _analyze() async {
    final tasks = app.tasksOf(widget.course.id);
    if (tasks.isEmpty) {
      toast(context, 'لا عناصر للدراسة في هذه المادة');
      return;
    }
    setState(() => busy = true);
    try {
      final r = await analyzeCourse(app.settings, widget.course.title, tasks);
      final cfg = app.data.cfg(widget.course.id);
      cfg.difficulty = r.difficulty;
      cfg.aiNote = r.reason;
      final shown = tasks.take(150).toList();
      r.minutes.forEach((i, m) => app.data.state(shown[i].id).aiMinutes = m);
      await app.commit();
      if (mounted) toast(context, 'تم التحليل: صعوبة ${r.difficulty}/5');
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _editMinutes(Task t) async {
    final ctrl = TextEditingController(text: '${t.minutes}');
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('وقت دراسة هذا العنصر'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(suffixText: 'دقيقة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, ''), child: Text('تقدير تلقائي')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text('حفظ')),
        ],
      ),
    );
    if (res == null) return;
    final st = app.data.state(t.id);
    final v = int.tryParse(res.trim());
    st.minutes = (v == null || v <= 0) ? null : v;
    if (res.isEmpty) st.aiMinutes = null;
    await app.commit();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (c, _) {
        final course = widget.course;
        final cfg = app.data.cfg(course.id);
        final tasks = app.tasksOf(course.id);
        final rows = <Widget>[];
        for (final g in groupChapters(tasks, app.data.items)) {
          final doneN = g.tasks.where((t) => t.done).length;
          rows.add(Padding(
            padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
            child: Row(children: [
              Expanded(child: Text(g.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kInk))),
              Pill('$doneN/${g.tasks.length}', icon: doneN == g.tasks.length ? Icons.check_circle_outline : null),
            ]),
          ));
          String? bucket;
          for (final t in g.tasks) {
            final b = bucketOf(t.kind);
            if (b != bucket) {
              bucket = b;
              rows.add(Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                child: Text(b, style: TextStyle(fontWeight: FontWeight.w600, color: kMoss, fontSize: 12.5)),
              ));
            }
            rows.add(Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: kSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: kOutline)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openItem(context, url: t.item.url, title: t.title, kind: t.kind),
                  onLongPress: () => showItemActions(context, url: t.item.url, title: t.title, course: course.title),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
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
                          Text(kindLabels[t.kind] ?? '', style: TextStyle(fontSize: 12.5, color: kInk.withValues(alpha: 0.6))),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _editMinutes(t),
                        child: Pill(fmtMin(t.minutes), icon: kindIcon(t.kind)),
                      ),
                    ]),
                  ),
                ),
              ),
            ));
          }
        }
        return Scaffold(
          appBar: AppBar(title: Text(course.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          body: ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الأولوية', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 1, label: Text('منخفضة')),
                      ButtonSegment(value: 2, label: Text('عادية')),
                      ButtonSegment(value: 3, label: Text('عالية')),
                    ],
                    selected: {cfg.priority},
                    onSelectionChanged: (s) {
                      cfg.priority = s.first;
                      app.commit();
                    },
                  ),
                ),
                SizedBox(height: 14),
                Text('الصعوبة: ${cfg.difficulty}/5', style: TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                  value: cfg.difficulty.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: kForest,
                  onChanged: (v) {
                    cfg.difficulty = v.round();
                    app.commit();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.event_outlined, color: kMoss),
                  title: Text(cfg.exam == null ? 'حدّد موعد الامتحان' : 'الامتحان: ${fmtDm(cfg.exam!)}/${cfg.exam!.year}'),
                  subtitle: Text('تنتهي دراسة المادة قبله بيوم'),
                  trailing: cfg.exam == null
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () {
                            cfg.exam = null;
                            app.commit();
                          }),
                  onTap: () async {
                    final d = await pickDate(context, cfg.exam);
                    if (d != null) {
                      cfg.exam = d;
                      app.commit();
                    }
                  },
                ),
                SizedBox(height: 4),
                FilledButton.icon(
                  onPressed: busy ? null : _analyze,
                  icon: busy
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.auto_awesome),
                  label: Text(busy ? 'جارٍ التحليل…' : 'حلّل المادة بالذكاء الاصطناعي'),
                ),
                if (cfg.aiNote.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Text(cfg.aiNote, style: TextStyle(height: 1.6)),
                ],
              ]),
            ),
            Heading('عناصر الدراسة'),
            if (tasks.isEmpty) Text('لم أجد عناصر للدراسة في هذه المادة.'),
            ...rows,
          ]),
        );
      });
}
