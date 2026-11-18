import 'package:flutter/material.dart';
import '../app_state.dart';
import '../sync_page.dart';
import '../notifier.dart';
import 'follow_page.dart';
import 'courses_page.dart';
import 'mentor_page.dart';
import 'more_page.dart';
import 'plan_page.dart';
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
    const titles = ['اليوم', 'الخطة', 'المواد', 'المتابعة', 'المزيد'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tab]),
        actions: [
          IconButton(tooltip: 'استيراد من مودل', icon: Icon(Icons.sync), onPressed: _sync),
          IconButton(
            tooltip: 'المرشد الذكي',
            icon: Icon(Icons.auto_awesome_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text('المرشد الذكي')), body: MentorPage()))),
          ),
        ],
      ),
      body: IndexedStack(index: tab, children: [
        TodayPage(onSync: _sync, onPlan: () => setState(() => tab = 1)),
        PlanPage(),
        CoursesPage(),
        FollowPage(),
        MorePage(onSync: _sync),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'اليوم'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'الخطة'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'المواد'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'المتابعة'),
          NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'المزيد'),
        ],
      ),
    );
  }
}
