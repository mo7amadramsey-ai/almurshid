import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../app_state.dart';
import '../channel.dart';
import '../lock_setup.dart';
import '../planner.dart';
import '../theme.dart';

/// Re-opens a strict session that was still running when the app was closed / restarted.
Future<void> resumeStrictIfAny(BuildContext c) async {
  try {
    final s = await ch.invokeMethod<Map>('getSession');
    if (s == null || !c.mounted) return;
    final left = (s['left'] as num).toInt();
    if (left <= 0) return;
    await Navigator.push(
        c, MaterialPageRoute(builder: (_) => StrictPage(resumeLeftMs: left, resumeTitle: (s['target'] as String?) ?? '')));
  } catch (_) {}
}

const _presets = [25, 45, 60, 90, 120, 180, 240];

String _dur(int m) {
  if (m < 60) return '$m د';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '$h س' : '$h س $r د';
}

String _mmss(int ms) {
  final s = (ms / 1000).ceil().clamp(0, 359999);
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, x = s % 60;
  final mm = m.toString().padLeft(2, '0'), ss = x.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Strict study session: counts down, and while it runs the phone refuses every other app
/// (except the dialer). The native side has a hard end time, so it can never lock longer than planned.
class StrictPage extends StatefulWidget {
  final Task? task;
  final int? resumeLeftMs;
  final String? resumeTitle;
  const StrictPage({super.key, this.task, this.resumeLeftMs, this.resumeTitle});
  @override
  State<StrictPage> createState() => _StrictPageState();
}

class _StrictPageState extends State<StrictPage> {
  int minutes = 25;
  bool running = false, finished = false;
  late DateTime endAt;
  int totalMs = 1, leftMs = 0, ticks = 0;
  Timer? timer;

  String get title => widget.task?.title ?? widget.resumeTitle ?? 'جلسة دراسة';

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t != null) minutes = ((t.minutes / 5).round() * 5).clamp(5, 360);
    final r = widget.resumeLeftMs;
    if (r != null) {
      totalMs = r;
      leftMs = r;
      endAt = DateTime.now().add(Duration(milliseconds: r));
      running = true;
      _run();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _run() {
    WakelockPlus.enable();
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _start() async {
    if (!await ensureLockReady(context) || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الختم الدراسي'),
        content: Text(
          'سيُغلق هاتفك على «المرشد» لمدة ${_dur(minutes)}، ولن تستطيع الخروج قبل انتهائها. '
          'يبقى الاتصال الهاتفي فقط.\n\nهل أنت متأكد؟',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ابدأ الختم')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final ms = minutes * 60000;
    await ch.invokeMethod('startLock', {'left': ms, 'type': 'study', 'target': title});
    setState(() {
      totalMs = ms;
      leftMs = ms;
      endAt = DateTime.now().add(Duration(milliseconds: ms));
      running = true;
      finished = false;
    });
    _run();
  }

  Future<void> _tick() async {
    final left = endAt.difference(DateTime.now()).inMilliseconds;
    if (left <= 0) return _finish();
    if (!mounted) return;
    setState(() => leftMs = left);
    if (++ticks % 5 == 0) ch.invokeMethod('setLeft', {'left': left}).catchError((_) => null);
  }

  Future<void> _finish() async {
    timer?.cancel();
    try {
      await ch.invokeMethod('stopLock');
    } catch (_) {}
    WakelockPlus.disable();
    HapticFeedback.heavyImpact();
    if (mounted) {
      setState(() {
        running = false;
        finished = true;
        leftMs = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !running,
      child: Scaffold(
        appBar: AppBar(title: const Text('الختم الدراسي'), automaticallyImplyLeading: !running),
        body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: running ? _running() : (finished ? _done() : _intro()))),
      ),
    );
  }

  Widget _intro() {
    final t = widget.task;
    return ListView(children: [
      Container(
        decoration: cardBox(22),
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.4)),
          if (t != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(t.courseTitle, style: const TextStyle(color: kMoss))),
          const SizedBox(height: 20),
          const Text('مدة الختم', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in _presets)
              ChoiceChip(label: Text(_dur(m)), selected: minutes == m, onSelected: (_) => setState(() => minutes = m)),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: minutes > 5 ? () => setState(() => minutes -= 5) : null, icon: const Icon(Icons.remove_circle_outline, size: 32)),
            SizedBox(width: 140, child: Text(_dur(minutes), textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800))),
            IconButton(onPressed: minutes < 360 ? () => setState(() => minutes += 5) : null, icon: const Icon(Icons.add_circle_outline, size: 32)),
          ]),
          const Text('تحدد المدة بنفسك (من 5 دقائق إلى 6 ساعات).', style: TextStyle(fontSize: 12.5, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 14),
      const Text(
        'الختم الدراسي: لا يُسمح إلا بالاتصال الهاتفي. أي تطبيق آخر يُغلق فوراً ويعيدك المرشد إلى هذه الشاشة، '
        'ولا يوجد زر خروج حتى تنتهي المدة التي حددتها. ينتهي تلقائياً بانتهاء الوقت حتى لو أُغلق التطبيق أو أُعيد تشغيل الهاتف.',
        style: TextStyle(height: 1.6, fontSize: 13),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: _start, icon: const Icon(Icons.lock_clock), label: const Text('ابدأ الختم الدراسي')),
    ]);
  }

  Widget _running() {
    final p = totalMs <= 0 ? 0.0 : (1 - leftMs / totalMs).clamp(0.0, 1.0);
    return Column(children: [
      const Spacer(),
      Text(title, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.5)),
      const SizedBox(height: 28),
      SizedBox(
        width: 250,
        height: 250,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(child: CircularProgressIndicator(value: p, strokeWidth: 12, color: kForest, backgroundColor: kSurface2)),
          Text(_mmss(leftMs), style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      ),
      const SizedBox(height: 28),
      const Text('ختم دراسي: ركّز. لا خروج حتى ينتهي الوقت.', style: TextStyle(height: 1.5)),
      const Spacer(),
      OutlinedButton.icon(onPressed: () => ch.invokeMethod('openDialer'), icon: const Icon(Icons.call), label: const Text('اتصال')),
    ]);
  }

  Widget _done() {
    final t = widget.task;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.check_circle, size: 88, color: kForest),
      const SizedBox(height: 12),
      const Text('أحسنت، انتهى الختم الدراسي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 24),
      if (t != null && !t.done)
        FilledButton.icon(
            onPressed: () async {
              await app.toggle(t);
              if (mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.done_all),
            label: const Text('أنجزت المهمة')),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: () => setState(() => finished = false), child: const Text('جلسة أخرى')),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('خروج')),
    ]);
  }
}
