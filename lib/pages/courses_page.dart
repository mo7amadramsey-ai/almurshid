import 'package:flutter/material.dart';
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
          return const EmptyNote(icon: Icons.menu_book_outlined, title: 'لا مواد بعد', body: 'استورد موادك من مودل أولاً.');
        }
        final now = dOnly(DateTime.now());
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          for (final course in t.courses)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CoursePage(course: course))),
                child: Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(course.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.3)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                          value: app.courseProgress(course.id), minHeight: 7, color: kForest, backgroundColor: kSurface2),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 14, runSpacing: 4, children: [
                      Text('متبقٍ ${fmtMin(app.remainingMin(course.id))}', style: const TextStyle(color: kMoss)),
                      Text('صعوبة ${app.data.cfg(course.id).difficulty}/5', style: const TextStyle(color: kMoss)),
                      Text(
                        app.data.cfg(course.id).exam == null
                            ? 'بلا موعد امتحان'
                            : 'امتحان ${fmtDm(app.data.cfg(course.id).exam!)} (بعد ${dayDiff(now, app.data.cfg(course.id).exam!)} يوم)',
                        style: TextStyle(color: app.data.cfg(course.id).exam == null ? const Color(0xFF9A4A1F) : kMoss),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
        ]);
      });
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
        title: const Text('وقت دراسة هذا العنصر'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'دقيقة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, ''), child: const Text('تقدير تلقائي')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('حفظ')),
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
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 4),
            child: Row(children: [
              Expanded(child: Text(g.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kForest))),
              Text('$doneN/${g.tasks.length}', style: const TextStyle(color: kMoss)),
            ]),
          ));
          String? bucket;
          for (final t in g.tasks) {
          final b = bucketOf(t.kind);
          if (b != bucket) {
            bucket = b;
            rows.add(Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 4),
              child: Text(b, style: const TextStyle(fontWeight: FontWeight.w700, color: kMoss, fontSize: 12.5)),
            ));
          }
          rows.add(Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: cardBox(14),
            child: ListTile(
              dense: true,
              leading: Checkbox(value: t.done, activeColor: kForest, onChanged: (_) => app.toggle(t)),
              title: Text(t.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(decoration: t.done ? TextDecoration.lineThrough : null)),
              subtitle: Text(kindLabels[t.kind] ?? ''),
              trailing: TextButton.icon(
                onPressed: () => _editMinutes(t),
                icon: Icon(kindIcon(t.kind), size: 16),
                label: Text(fmtMin(t.minutes)),
              ),
            ),
          ));
          }
        }
        return Scaffold(
          appBar: AppBar(title: Text(course.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('الأولوية', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    segments: const [
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
                const SizedBox(height: 14),
                Text('الصعوبة: ${cfg.difficulty}/5', style: const TextStyle(fontWeight: FontWeight.w700)),
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
                  leading: const Icon(Icons.event_outlined, color: kMoss),
                  title: Text(cfg.exam == null ? 'حدّد موعد الامتحان' : 'الامتحان: ${fmtDm(cfg.exam!)}/${cfg.exam!.year}'),
                  subtitle: const Text('تنتهي دراسة المادة قبله بيوم'),
                  trailing: cfg.exam == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
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
                const SizedBox(height: 4),
                FilledButton.icon(
                  onPressed: busy ? null : _analyze,
                  icon: busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome),
                  label: Text(busy ? 'جارٍ التحليل…' : 'حلّل المادة بالذكاء الاصطناعي'),
                ),
                if (cfg.aiNote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(cfg.aiNote, style: const TextStyle(height: 1.6)),
                ],
              ]),
            ),
            const Heading('عناصر الدراسة'),
            if (tasks.isEmpty) const Text('لم أجد عناصر للدراسة في هذه المادة.'),
            ...rows,
          ]),
        );
      });
}
