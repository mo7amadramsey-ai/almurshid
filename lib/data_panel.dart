// "Data and privacy" panel: backup, restore and delete-everything. Theme-neutral on purpose, so the settings
// screen can place it anywhere:  `const DataPrivacyPanel()`.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'study_store.dart';

class DataPrivacyPanel extends StatelessWidget {
  const DataPrivacyPanel({super.key});

  void _say(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

  Future<bool> _confirm(BuildContext c, String title, String body, String action) async =>
      (await showDialog<bool>(
        context: c,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(body, style: const TextStyle(height: 1.6)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
          ],
        ),
      )) ==
      true;

  Future<void> _backup(BuildContext c) async {
    final text = await app.makeBackup();
    await Clipboard.setData(ClipboardData(text: text));
    if (c.mounted) _say(c, 'نُسخت النسخة الاحتياطية إلى الحافظة. الصقها في ملاحظة أو رسالة تحفظها عندك.');
  }

  Future<void> _restore(BuildContext c) async {
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (!c.mounted) return;
    try {
      parseBackup(clip); // validate before asking
    } catch (e) {
      _say(c, e is String ? '$e (انسخ النسخة الاحتياطية أولاً ثم أعد المحاولة)' : 'تعذّرت القراءة');
      return;
    }
    if (!await _confirm(c, 'استعادة النسخة الاحتياطية؟', 'ستحل بيانات النسخة (المواعيد والإنجاز والإعدادات) محل بياناتك الحالية على هذا الهاتف. مفتاح الذكاء الاصطناعي لا يتأثر.', 'استعادة') || !c.mounted) return;
    final err = await app.restoreBackup(clip);
    if (c.mounted) _say(c, err ?? 'تمت الاستعادة');
  }

  Future<void> _wipe(BuildContext c) async {
    if (!await _confirm(c, 'حذف كل بياناتك من هذا الهاتف؟', 'سيُحذف كل ما يحفظه المرشد: المواد المستوردة، الإنجاز، المواعيد، الإعدادات، مفتاح الذكاء الاصطناعي، وجلسة مودل، وتُلغى كل التذكيرات. لا يمكن التراجع. (حسابك على مودل نفسه لا يتأثر.)', 'حذف كل شيء') || !c.mounted) return;
    await app.resetAll();
    if (c.mounted) _say(c, 'حُذفت كل البيانات المحلية');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        ValueListenableBuilder<String?>(
          valueListenable: studyLoadNotice,
          builder: (_, n, __) => n == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(n, style: const TextStyle(height: 1.5))),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.copy_all_outlined),
          title: const Text('نسخ نسخة احتياطية'),
          subtitle: const Text('بياناتك فقط، بدون مفتاح الذكاء الاصطناعي ولا جلسة مودل'),
          onTap: () => _backup(context),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.restore_outlined),
          title: const Text('استعادة من الحافظة'),
          onTap: () => _restore(context),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_forever_outlined),
          title: const Text('حذف كل بياناتي من هذا الهاتف'),
          onTap: () => _wipe(context),
        ),
      ]);
}
