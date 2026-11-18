import 'package:flutter/material.dart';
import '../app_state.dart';
import '../media/downloads_page.dart';
import '../media/library_page.dart';
import '../sync_page.dart';
import '../notifier.dart';
import 'follow_page.dart';
import 'calendar_page.dart';
import 'courses_page.dart';
import 'mentor_page.dart';
import 'plan_page.dart';
import 'settings_page.dart';
import 'strict_page.dart';
import 'today_page.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    app.init();
    askNotifPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) => resumeStrictIfAny(context));
  }

  Future<void> _sync() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SyncPage()));
    await app.init();
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['اليوم', 'الخطة', 'المواد', 'المتابعة', 'المرشد'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tab]),
        actions: [
          IconButton(tooltip: 'استيراد من مودل', icon: Icon(Icons.sync), onPressed: _sync),
          PopupMenuButton<int>(
            tooltip: 'المزيد',
            icon: Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (i) {
              final Widget page = [CalendarPage(), LibraryPage(), DownloadsPage(), SettingsPage()][i];
              Navigator.push(context, MaterialPageRoute(builder: (_) => page));
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 0, child: ListTile(leading: Icon(Icons.calendar_month_outlined), title: Text('التقويم'), dense: true)),
              PopupMenuItem(value: 1, child: ListTile(leading: Icon(Icons.video_library_outlined), title: Text('مكتبتي'), dense: true)),
              PopupMenuItem(value: 2, child: ListTile(leading: Icon(Icons.download_outlined), title: Text('التنزيلات'), dense: true)),
              PopupMenuItem(value: 3, child: ListTile(leading: Icon(Icons.tune), title: Text('الإعدادات'), dense: true)),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: tab, children: [
        TodayPage(onSync: _sync, onPlan: () => setState(() => tab = 1)),
        PlanPage(),
        CoursesPage(),
        FollowPage(),
        MentorPage(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'اليوم'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'الخطة'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'المواد'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'المتابعة'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'المرشد'),
        ],
      ),
    );
  }
}
