import 'package:flutter/material.dart';
import 'app_state.dart';
import 'pages/shell.dart';
import 'theme.dart';

void main() => runApp(const MurshidApp());

class MurshidApp extends StatefulWidget {
  const MurshidApp({super.key});
  @override
  State<MurshidApp> createState() => _MurshidAppState();
}

class _MurshidAppState extends State<MurshidApp> with WidgetsBindingObserver {
  bool _dark = false;

  bool _wantDark() {
    final mode = app.settings.themeMode;
    if (mode == 'dark') return true;
    if (mode == 'light') return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  void _sync() {
    final d = _wantDark();
    if (d == _dark && Pal.dark == d) return;
    _dark = d;
    Pal.dark = d;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => rebuildAll());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app.addListener(_sync); // the saved choice arrives after the data loads / changes in settings
    _dark = _wantDark();
    Pal.dark = _dark;
  }

  @override
  void didChangePlatformBrightness() => _sync();

  @override
  void dispose() {
    app.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'المرشد الدراسي',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Arabic-first app: force right-to-left layout
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: AppBackdrop(child: child!)),
        home: const Shell(),
      );
}
