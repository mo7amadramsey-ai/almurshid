import '../media/course_download.dart';
import '../media/download_sheet.dart';
import '../media/support_files.dart';
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
        final courses = app.orderedCourses;
        // Long-press the handle and drag: the order you set here shapes the study plan (first = most important)
        return ReorderableListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          buildDefaultDragHandles: false,
          onReorder: app.moveCourse,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text('رتّب موادك بالسحب: الأعلى أهم وتأخذ وقتاً أكبر في الخطة.', style: TextStyle(fontSize: 12.5, color: kInk.withValues(alpha: 0.65))),
          ),
          children: [
            for (var i = 0; i < courses.length; i++)
              _CourseCard(key: ValueKey(courses[i].id), course: courses[i], now: now, rank: i + 1, index: i),
          ],
        );
      });
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final DateTime now;
  final int rank;
  final int index;
  const _CourseCard({super.key, required this.course, required this.now, required this.rank, required this.index});

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
                size: 62,
                child: Text('$rank', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(course.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.35)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    if (app.settings.focusCourse == course.id) Pill('تركيز', icon: Icons.center_focus_strong, bg: kForest, fg: Colors.white),
                    Pill('${(p * 100).round()}%  ·  متبقٍ ${fmtMin(app.remainingMin(course.id))}', icon: Icons.timelapse),
                    exam == null
                        ? Pill('بلا موعد امتحان', icon: Icons.event_busy, bg: kWarnBg, fg: kWarnText)
                        : Pill('امتحان ${fmtDm(exam)}  ·  ${left! < 0 ? 'فات' : 'بعد $left يوم'}',
                            icon: Icons.quiz_outlined, bg: hot ? kWarnBg : kBrownLight, fg: hot ? kWarnText : kBrownDark),
                  ]),
                ]),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.drag_indicator, color: kInk.withValues(alpha: 0.4))),
              ),
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
        var openedOne = false;
        for (final g in groupChapters(tasks, app.data.items)) {
          final open = !openedOne && g.tasks.any((t) => !t.done);
          if (open) openedOne = true; // only the first unfinished chapter starts expanded
          rows.add(_ChapterTile(key: PageStorageKey('${course.id}|${g.label}'), group: g, course: course, open: open, onMinutes: _editMinutes));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(course.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'تحميل كل فيديوهات المادة',
                icon: const Icon(Icons.download_for_offline_outlined),
                onPressed: () => showCourseDownload(context, course),
              ),
            ],
          ),
          body: ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
            _CourseHeader(course: course, tasks: tasks),
            SizedBox(height: 10),
            Container(
              decoration: cardBox(22),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  shape: Border(),
                  collapsedShape: Border(),
                  leading: IconBadge(Icons.tune),
                  title: Text('إعدادات المادة', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('الأولوية، الصعوبة، موعد الامتحان، التحليل'),
                  childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: app.settings.focusCourse == course.id,
                  activeColor: kForest,
                  title: Text('ركّز على هذه المادة', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('تأخذ معظم وقت كل يوم، وبقية المواد تتقدم ببطء.'),
                  onChanged: (v) => app.setFocus(v ? course.id : null),
                ),
                SizedBox(height: 8),
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
                  ],
                ),
              ),
            ),
            Heading('الفيديوهات حسب الفصل'),
            if (tasks.isEmpty) Text('لم أجد عناصر للدراسة في هذه المادة.'),
            ...rows,
            SupportFiles(course: course),
          ]),
        );
      });
}


class _CourseHeader extends StatelessWidget {
  final Course course;
  final List<Task> tasks;
  const _CourseHeader({required this.course, required this.tasks});
  @override
  Widget build(BuildContext context) {
    final cfg = app.data.cfg(course.id);
    final done = tasks.where((t) => t.done).length;
    final focus = app.settings.focusCourse == course.id;
    final exam = cfg.exam;
    return Panel(
      child: Row(children: [
        ProgressRing(
          value: app.courseProgress(course.id),
          size: 70,
          child: Text('${(app.courseProgress(course.id) * 100).round()}%', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$done من ${tasks.length} منجزة', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              Pill('متبقٍ ${fmtMin(app.remainingMin(course.id))}', icon: Icons.timelapse),
              if (exam != null) Pill('امتحان ${fmtDm(exam)}', icon: Icons.quiz_outlined, bg: kBrownLight, fg: kBrownDark),
              FilterChip(
                label: const Text('تركيز'),
                avatar: Icon(Icons.center_focus_strong, size: 16, color: focus ? kForest : kMoss),
                selected: focus,
                onSelected: (v) => app.setFocus(v ? course.id : null),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final ChapterGroup group;
  final Course course;
  final bool open;
  final void Function(Task) onMinutes;
  const _ChapterTile({super.key, required this.group, required this.course, required this.open, required this.onMinutes});

  @override
  Widget build(BuildContext context) {
    final doneN = group.tasks.where((t) => t.done).length;
    final kids = <Widget>[];
    String? bucket;
    for (final t in group.tasks) {
      final b = bucketOf(t.kind);
      if (b != bucket) {
        bucket = b;
        kids.add(Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
          child: Text(b, style: TextStyle(fontWeight: FontWeight.w600, color: kMoss, fontSize: 12.5)),
        ));
      }
      kids.add(_ItemRow(task: t, course: course, onMinutes: onMinutes));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        decoration: cardBox(20),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: open,
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(group.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
            trailing: Pill('$doneN/${group.tasks.length}', icon: doneN == group.tasks.length ? Icons.check_circle_outline : null),
            childrenPadding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            children: kids,
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Task task;
  final Course course;
  final void Function(Task) onMinutes;
  const _ItemRow({required this.task, required this.course, required this.onMinutes});

  @override
  Widget build(BuildContext context) {
    final t = task;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openItem(context, url: t.item.url, title: t.title, kind: t.kind),
      onLongPress: () => showItemActions(context, url: t.item.url, title: t.title, course: course.title),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 8, 2),
        child: Row(children: [
          Checkbox(
            value: t.done,
            shape: const CircleBorder(),
            activeColor: kForest,
            side: BorderSide(color: kMoss, width: 1.6),
            onChanged: (_) => app.toggle(t),
          ),
          Expanded(
            child: Text(t.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(height: 1.3, fontWeight: FontWeight.w600, decoration: t.done ? TextDecoration.lineThrough : null, color: t.done ? kInk.withValues(alpha: 0.5) : kInk)),
          ),
          const SizedBox(width: 8),
          // videos carry the study time; supporting files only show their type
          t.minutes > 0
              ? InkWell(borderRadius: BorderRadius.circular(20), onTap: () => onMinutes(t), child: Pill(fmtMin(t.minutes), icon: kindIcon(t.kind)))
              : Icon(kindIcon(t.kind), size: 20, color: kMoss),
        ]),
      ),
    );
  }
}
