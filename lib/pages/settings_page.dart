import 'package:flutter/material.dart';
import '../ai.dart';
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
  late final TextEditingController baseUrl;
  bool hide = true;

  @override
  void initState() {
    super.initState();
    key = TextEditingController(text: app.settings.apiKey);
    model = TextEditingController(text: app.settings.model);
    baseUrl = TextEditingController(text: app.settings.baseUrl);
  }

  @override
  void dispose() {
    key.dispose();
    model.dispose();
    baseUrl.dispose();
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
              'اختر أي خدمة تريدها. فيه خيارات مجانية (Gemini وGroq وOpenRouter) بمفتاح تأخذه مجاناً من موقع الخدمة، '
              'ولا تحتاج حساب Claude. المفتاح يُحفظ على هاتفك فقط ويُرسل لخدمتك أنت فقط. '
              'يرى الذكاء الاصطناعي عناوين المواد وخطتك، لا كلمة سرك ولا ملفاتك.',
              style: TextStyle(height: 1.6, fontSize: 13),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: providerById(s.provider).id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'الخدمة'),
              items: [for (final p in aiProviders) DropdownMenuItem(value: p.id, child: Text(p.name))],
              onChanged: (v) {
                if (v == null) return;
                s.provider = v;
                s.model = '';
                s.baseUrl = '';
                model.text = '';
                baseUrl.text = '';
                setState(() {});
              },
            ),
            const SizedBox(height: 10),
            Builder(builder: (_) {
              final p = providerById(s.provider);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: key,
                  obscureText: hide,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'مفتاح API',
                    helperText: p.keyHint,
                    suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => hide = !hide)),
                  ),
                  onChanged: (v) => s.apiKey = v.trim(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: model,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: 'النموذج', hintText: p.model, helperText: 'اتركه فارغاً لاستعمال: ${p.model}'),
                  onChanged: (v) => s.model = v.trim(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: baseUrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: 'عنوان الخدمة (اختياري)', hintText: p.baseUrl),
                  onChanged: (v) => s.baseUrl = v.trim(),
                ),
              ]);
            }),
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
