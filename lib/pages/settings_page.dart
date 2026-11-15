import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../tree_page.dart';
import '../widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController key;
  late final TextEditingController model;
  bool hide = true;

  @override
  void initState() {
    super.initState();
    key = TextEditingController(text: app.settings.apiKey);
    model = TextEditingController(text: app.settings.model);
  }

  @override
  void dispose() {
    key.dispose();
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = app.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        const Heading('وقت الدراسة'),
        Panel(
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: kOlive,
              title: const Text('أنا متعب هذه الفترة'),
              subtitle: const Text('يخفض ساعات كل يوم 25% حتى لا تُحمَّل أكثر من طاقتك'),
              value: s.tired,
              onChanged: (v) {
                s.tired = v;
                app.commit();
                setState(() {});
              },
            ),
            const Divider(),
            for (var i = 0; i < 7; i++)
              Row(children: [
                SizedBox(width: 70, child: Text(weekdayNames[i])),
                Expanded(
                  child: Slider(
                    value: s.hours[i],
                    min: 0,
                    max: 10,
                    divisions: 20,
                    activeColor: kOlive,
                    onChanged: (v) {
                      s.hours[i] = v;
                      setState(() {});
                    },
                    onChangeEnd: (_) => app.commit(),
                  ),
                ),
                SizedBox(width: 44, child: Text('${s.hours[i].toStringAsFixed(1)} س', textAlign: TextAlign.end)),
              ]),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('أيام الأمان قبل كل امتحان'),
              subtitle: const Text('أيام تُترك فارغة للمراجعة، ولا تُستخدم إلا إذا ضاق الوقت'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: s.bufferDays > 0
                        ? () {
                            s.bufferDays--;
                            app.commit();
                            setState(() {});
                          }
                        : null),
                Text('${s.bufferDays}', style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: s.bufferDays < 7
                        ? () {
                            s.bufferDays++;
                            app.commit();
                            setState(() {});
                          }
                        : null),
              ]),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('موعد افتراضي للمواد التي بلا امتحان محدد'),
              subtitle: Text('${fmtDm(s.deadline)}/${s.deadline.year}'),
              trailing: const Icon(Icons.event_outlined),
              onTap: () async {
                final d = await pickDate(context, s.deadline);
                if (d != null) {
                  s.deadline = d;
                  app.commit();
                  setState(() {});
                }
              },
            ),
            Text('معامل وقت الفيديو: ${s.videoFactor.toStringAsFixed(2)}×  (للإيقاف والتدوين)', style: const TextStyle(height: 1.5)),
            Slider(
              value: s.videoFactor,
              min: 1,
              max: 2.5,
              divisions: 15,
              activeColor: kOlive,
              onChanged: (v) {
                s.videoFactor = v;
                setState(() {});
              },
              onChangeEnd: (_) => app.commit(),
            ),
          ]),
        ),
        const Heading('الذكاء الاصطناعي'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'يتصل التطبيق بـ Claude مباشرة من هاتفك بمفتاحك الخاص. المفتاح يُحفظ في ذاكرة التطبيق على الهاتف فقط، ولا يُرسل إلا إلى Anthropic. '
              'يرى الذكاء الاصطناعي عناوين المواد وخطتك فقط، لا كلمة سرك ولا ملفاتك.',
              style: TextStyle(height: 1.6, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: key,
              obscureText: hide,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'مفتاح Claude API',
                suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => hide = !hide)),
              ),
              onChanged: (v) => s.apiKey = v.trim(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: model,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'النموذج'),
              onChanged: (v) => s.model = v.trim(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await app.commit();
                if (context.mounted) toast(context, 'تم الحفظ');
              },
              child: const Text('حفظ'),
            ),
          ]),
        ),
        const Heading('أدوات'),
        Panel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_tree_outlined, color: kBrown),
            title: const Text('شجرة المواد الخام'),
            subtitle: const Text('للفحص ونسخ الشجرة كنص'),
            onTap: app.tree == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TreePage(tree: app.tree!))),
          ),
        ),
      ]),
    );
  }
}
