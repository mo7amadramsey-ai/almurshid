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

        String status(Item i) {
          if (i.submitted == true) return 'تم التسليم';
          if (i.due == null) return i.submitted == false ? 'لم يُسلَّم' : 'بلا موعد معروف';
          if (i.due!.isBefore(now)) return i.submitted == false ? 'فات الموعد ولم يُسلَّم' : 'انتهى الموعد';
          final d = dayDiff(DateTime(now.year, now.month, now.day), i.due!);
          return (i.submitted == false ? 'لم يُسلَّم' : 'الحالة غير معروفة') + ' - باقٍ ${d == 0 ? 'اليوم' : '$d يوم'}';
        }

        return ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          Heading('الواجبات والاختبارات'),
          if (work.isEmpty) Text('لم أجد واجبات أو اختبارات في موادك.'),
          for (final e in work)
            Container(
              margin: EdgeInsets.only(bottom: 6),
              decoration: cardBox(14),
              child: ListTile(
                dense: true,
                leading: Icon(e.value.submitted == true ? Icons.check_circle : kindIcon(e.value.kind),
                    color: e.value.submitted == true ? kForest : kMoss),
                title: Text(e.value.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${e.key.title}\n${status(e.value)}${e.value.due == null ? '' : ' - ${fmtDm(e.value.due!)}'}'),
                isThreeLine: true,
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
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.download_done, color: kForest),
                    title: Text('تم تنزيل ${e.kind == 'video' ? 'محاضرة' : (kindLabels[ItemKind.values.firstWhere((k) => k.name == e.kind, orElse: () => ItemKind.other)] ?? 'عنصر')}: ${e.title}',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${e.course} - ${fmtDm(e.at)}'),
                  ),
              ]);
            },
          ),
        ]);
      });
}
