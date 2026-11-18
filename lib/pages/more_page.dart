import 'package:flutter/material.dart';
import '../media/downloads_page.dart';
import '../media/library_page.dart';
import '../theme.dart';
import 'calendar_page.dart';
import 'mentor_page.dart';
import 'settings_page.dart';
import 'strict_page.dart';

/// Fifth tab: everything that is not a daily screen.
class MorePage extends StatelessWidget {
  final VoidCallback onSync;
  const MorePage({super.key, required this.onSync});

  void _open(BuildContext c, Widget page) => Navigator.push(c, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String, VoidCallback)>[
      (Icons.auto_awesome_outlined, 'المرشد الذكي', 'اسأل واطلب شرحاً أو جدولاً أو اختباراً',
          () => _open(context, Scaffold(appBar: AppBar(title: const Text('المرشد الذكي')), body: MentorPage()))),
      (Icons.lock_clock, 'الختم الدراسي', 'جلسة قفل بمدة تحددها', () => _open(context, StrictPage())),
      (Icons.calendar_month_outlined, 'التقويم', 'الامتحانات والتسليمات', () => _open(context, CalendarPage())),
      (Icons.video_library_outlined, 'مكتبتي', 'ملفاتك المحمّلة', () => _open(context, LibraryPage())),
      (Icons.download_outlined, 'التنزيلات', 'متابعة التحميل الجاري', () => _open(context, DownloadsPage())),
      (Icons.sync, 'استيراد من مودل', 'مزامنة المواد والمحتوى الجديد', onSync),
      (Icons.tune, 'الإعدادات', 'المظهر، الوقت، الأمان والنسخ الاحتياطي', () => _open(context, SettingsPage())),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      for (final r in rows)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: cardBox(16),
          child: ListTile(
            leading: Icon(r.$1, color: kMoss),
            title: Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(r.$3),
            trailing: const Icon(Icons.chevron_left),
            onTap: r.$4,
          ),
        ),
    ]);
  }
}
