// Locks the whole app behind the phone's own fingerprint / PIN / pattern (spec section 5).
// - No screen lock on the phone -> opens directly (nothing to check against).
// - Re-locks after 45 s in the background, but never while a strict study session is running.
// - The phone's lock code is never read or stored: Android's BiometricPrompt does the check.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'channel.dart';
import 'theme.dart';

const relockAfter = Duration(seconds: 45);

/// Pure rule (tested): re-lock only after enough time away and never during a strict session
bool shouldRelock({required Duration away, required bool strictActive, Duration after = relockAfter}) =>
    !strictActive && away >= after;

// ---- on/off switch (kept in its own tiny file so it is known before the app data loads)
final appLockEnabled = ValueNotifier<bool>(true);

Future<File> _flag() async => File('${(await getApplicationSupportDirectory()).path}/app_lock.json');

Future<void> loadAppLock() async {
  try {
    final f = await _flag();
    if (f.existsSync()) {
      appLockEnabled.value = (jsonDecode(await f.readAsString())['enabled'] as bool?) ?? true;
    }
  } catch (_) {}
}

Future<void> setAppLock(bool on) async {
  appLockEnabled.value = on;
  try {
    await (await _flag()).writeAsString(jsonEncode({'enabled': on}));
  } catch (_) {}
}

Future<bool> _strictRunning() async {
  try {
    final s = await ch.invokeMethod<Map>('getSession');
    return s != null && ((s['left'] as num?)?.toInt() ?? 0) > 0;
  } catch (_) {
    return false;
  }
}

class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});
  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  bool ready = false, unlocked = false, everUnlocked = false, authing = false;
  DateTime? _bg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    await loadAppLock();
    if (!mounted) return;
    setState(() => ready = true);
    await _authenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) async {
    if (authing || !appLockEnabled.value) return; // the system prompt itself pauses the app
    if (s == AppLifecycleState.paused) {
      _bg = DateTime.now();
    } else if (s == AppLifecycleState.resumed) {
      final away = _bg == null ? Duration.zero : DateTime.now().difference(_bg!);
      _bg = null;
      if (!unlocked) return;
      final strict = await _strictRunning();
      if (!mounted) return;
      if (shouldRelock(away: away, strictActive: strict)) {
        setState(() => unlocked = false);
        _authenticate();
      }
    }
  }

  Future<void> _authenticate() async {
    if (authing) return;
    if (!appLockEnabled.value) {
      setState(() {
        unlocked = true;
        everUnlocked = true;
      });
      return;
    }
    authing = true;
    var ok = false;
    try {
      if (!await _auth.isDeviceSupported()) {
        ok = true; // the phone has no screen lock at all
      } else {
        ok = await _auth.authenticate(
          localizedReason: 'أثبت أنك صاحب الهاتف لفتح المُلزم',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
        );
      }
    } catch (_) {
      ok = false;
    }
    authing = false;
    if (!mounted) return;
    setState(() {
      unlocked = ok;
      if (ok) everUnlocked = true;
    });
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        if (everUnlocked) widget.child,
        if (!unlocked)
          Positioned.fill(
            child: Material(
              color: kBg,
              child: Center(
                child: ready
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.lock_outline, size: 56, color: kMoss),
                          const SizedBox(height: 16),
                          Text('المُلزم', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kInk)),
                          const SizedBox(height: 8),
                          Text('التطبيق مقفل. استخدم بصمتك أو رمز هاتفك.', style: TextStyle(color: kInk)),
                          const SizedBox(height: 24),
                          FilledButton.icon(onPressed: _authenticate, icon: const Icon(Icons.fingerprint), label: const Text('فتح')),
                        ]),
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
      ]);
}
