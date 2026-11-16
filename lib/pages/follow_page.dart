import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../study_models.dart';
import '../study_store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Personal follow-up: what was uploaded (log of every sync) and the assignments with their status.
class FollowPage extends StatefulWidget {
  const FollowPage({super.key});
  @override
  State<FollowPage> createState() => _FollowPageState();
}

class _FollowPageState extends State<FollowPage> {
  late Future<List<ActivityEntry>> log = loadLog();

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (c, _) {
        final t = app.tree;
        if (t == null) {
          return EmptyNote(icon: Icons.notifications_none, title: 'لا متابعة بعد', body: 'استورد موادك من مودل أولاً.');
        }
        log = loadLog(); // refreshed whenever the app state changes (after a sync)
        final now = DateTime.now();
        final work = <MapEntry<Course, Item>>[
          for (final co in t.courses)
            for (final i in co.allItems)
              if (i.kind == ItemKind.assignment || i.kind == ItemKind.quiz) MapEntry(co, i),
        ]..sort((a, b) => (a.value.due ?? DateTime(2100)).compareTo(b.value.due ?? DateTime(2100)));

        // level: 0 submitted, 1 upcoming, 2 urgent or overdue, 3 unknown
        (String, int) status(Item i) {
          if (i.submitted == true) return ('تم التسليم', 0);
          final due = i.due;
          if (due == null) return (i.submitted == false ? 'لم يُسلَّم' : 'بلا موعد', 3);
          final d = dayDiff(DateTime(now.year, now.month, now.day), due);
          if (due.isBefore(now)) return (i.submitted == false ? 'فات الموعد' : 'انتهى الموعد', 2);
          if (d <= 1) return (d == 0 ? 'اليوم' : 'غداً', 2);
          return ('بعد $d يوم', 1);
        }

        final upcoming = work.where((e) => status(e.value).$2 == 1 || status(e.value).$2 == 2 && e.value.due != null && !e.value.due!.isBefore(now)).length;
        final overdue = work.where((e) => e.value.submitted != true && e.value.due != null && e.value.due!.isBefore(now)).length;
        final sent = work.where((e) => e.value.submitted == true).length;

        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          Row(children: [
            Expanded(child: _Count('$upcoming', 'قادمة', Icons.upcoming_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _Count('$overdue', 'فاتت', Icons.error_outline, warn: overdue > 0)),
            const SizedBox(width: 10),
            Expanded(child: _Count('$sent', 'مُسلَّمة', Icons.check_circle_outline)),
          ]),
          const Heading('الواجبات والاختبارات'),
          if (work.isEmpty) const Text('لم أجد واجبات أو اختبارات في موادك.'),
          for (final e in work)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  IconBadge(e.value.submitted == true ? Icons.check_circle_outline : kindIcon(e.value.kind)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.value.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
                      Text('${e.key.title}${e.value.due == null ? '' : '  ·  ${fmtDm(e.value.due!)}'}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: kInk.withValues(alpha: 0.65))),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Builder(builder: (_) {
                    final st = status(e.value);
                    return Pill(st.$1,
                        icon: st.$2 == 0 ? Icons.check : (st.$2 == 2 ? Icons.priority_high : null),
                        bg: st.$2 == 2 ? kWarnBg : null,
                        fg: st.$2 == 2 ? kWarnText : null);
                  }),
                ]),
              ),
            ),
          Heading('سجل ما نُزِّل'),
          FutureBuilder<List<ActivityEntry>>(
            future: log,
            builder: (c, snap) {
              final l = snap.data ?? [];
              if (l.isEmpty) {
                return Text('سيظهر هنا كل ما يُرفع على مودل بعد كل استيراد (مثل: تم تنزيل محاضرة جديدة).');
              }
              return Column(children: [
                for (final e in l.take(80))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(Icons.download_done, size: 20, color: kForest),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('تم تنزيل ${e.kind == 'video' ? 'محاضرة' : (kindLabels[ItemKind.values.firstWhere((k) => k.name == e.kind, orElse: () => ItemKind.other)] ?? 'عنصر')}: ${e.title}',
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.3)),
                          Text('${e.course}  ·  ${fmtDm(e.at)}', style: TextStyle(fontSize: 12, color: kInk.withValues(alpha: 0.6))),
                        ]),
                      ),
                    ]),
                  ),
              ]);
            },
          ),
        ]);
      });
}

class _Count extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final bool warn;
  const _Count(this.value, this.label, this.icon, {this.warn = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: cardBox(18).copyWith(color: warn ? kWarnBg : null),
        child: Column(children: [
          Icon(icon, size: 20, color: warn ? kWarn : kForest),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: warn ? kWarnText : kInk)),
          Text(label, style: TextStyle(fontSize: 12, color: kInk.withValues(alpha: 0.65))),
        ]),
      );
}
