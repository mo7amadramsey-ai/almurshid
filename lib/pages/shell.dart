import 'package:flutter/material.dart';
import '../app_state.dart';
import '../sync_page.dart';
import '../theme.dart';
import 'courses_page.dart';
import 'mentor_page.dart';
import 'plan_page.dart';
import 'settings_page.dart';
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
  }

  Future<void> _sync() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncPage()));
    await app.init();
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['اليوم', 'الخطة', 'المواد', 'المرشد'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tab]),
        actions: [
          IconButton(tooltip: 'استيراد من مودل', icon: const Icon(Icons.sync), onPressed: _sync),
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: IndexedStack(index: tab, children: [
        TodayPage(onSync: _sync, onPlan: () => setState(() => tab = 1)),
        const PlanPage(),
        const CoursesPage(),
        const MentorPage(),
      ]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: kSurface,
        indicatorColor: kSurface2,
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'اليوم'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'الخطة'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'المواد'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'المرشد'),
        ],
      ),
    );
  }
}
