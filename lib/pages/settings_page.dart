import 'package:flutter/material.dart';
import '../secrets.dart';
import '../ai.dart';
import '../data_panel.dart';
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

  String _fmtMin(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  Future<void> _pickWindow({required bool start}) async {
    final s = app.settings;
    final cur = start ? s.windowStart : s.windowEnd;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (t == null || !mounted) return;
    final m = t.hour * 60 + t.minute;
    final ok = start ? s.windowEnd - m >= 60 : m - s.windowStart >= 60;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('يجب أن تكون النافذة ساعة على الأقل')));
      return;
    }
    if (start) {
      s.windowStart = m;
    } else {
      s.windowEnd = m;
    }
    app.commit();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = app.settings;
    return Scaffold(
      appBar: AppBar(title: Text('الإعدادات')),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        const Heading('المظهر'),
        Panel(
          child: SegmentedButton<String>(
            style: SegmentedButton.styleFrom(selectedBackgroundColor: kTint, selectedForegroundColor: kForest),
            segments: const <ButtonSegment<String>>[
              ButtonSegment(value: 'system', label: Text('تلقائي'), icon: Icon(Icons.brightness_auto)),
              ButtonSegment(value: 'light', label: Text('فاتح'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: 'dark', label: Text('داكن'), icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) {
              s.themeMode = v.first;
              app.commit();
              setState(() {});
            },
          ),
        ),
        const Heading('وقت الدراسة'),
        Panel(
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: kForest,
              title: Text('أنا متعب هذه الفترة'),
              subtitle: Text('يخفض ساعات كل يوم 25% حتى لا تُحمَّل أكثر من طاقتك'),
              value: s.tired,
              onChanged: (v) {
                s.tired = v;
                app.commit();
                setState(() {});
              },
            ),
            Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: kForest,
              title: Text('التطبيق يحدد ساعات الدراسة'),
              subtitle: Text(
                s.autoHours
                    ? 'يحسب التطبيق أقل عدد ساعات يومياً يُنهي موادك في موعدها ويفرضه عليك. اجعل يوماً 0 ليكون راحة.'
                    : 'أنت تحدد ساعات كل يوم بنفسك من الأشرطة أدناه.',
              ),
              value: s.autoHours,
              onChanged: (v) {
                s.autoHours = v;
                app.commit();
                setState(() {});
              },
            ),
            if (s.autoHours && (app.plan?.report.autoMinutes ?? 0) > 0)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'الهدف اليومي المفروض الآن: ${fmtMin(app.plan!.report.autoMinutes)}',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            for (var i = 0; i < 7; i++)
              Row(children: [
                SizedBox(width: 70, child: Text(weekdayNames[i])),
                Expanded(
                  child: Slider(
                    value: s.hours[i],
                    min: 0,
                    max: 10,
                    divisions: 20,
                    activeColor: kForest,
                    onChanged: (v) {
                      s.hours[i] = v;
                      setState(() {});
                    },
                    onChangeEnd: (_) => app.commit(),
                  ),
                ),
                SizedBox(width: 44, child: Text('${s.hours[i].toStringAsFixed(1)} س', textAlign: TextAlign.end)),
              ]),
            Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('بداية وقت الدراسة المسموح'),
              subtitle: Text('لا تُرسَل تذكيرات قبلها، ولا تتجاوز الخطة طول النافذة'),
              trailing: Text(_fmtMin(s.windowStart), style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => _pickWindow(start: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('نهاية وقت الدراسة المسموح'),
              trailing: Text(_fmtMin(s.windowEnd), style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => _pickWindow(start: false),
            ),
            Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('أيام الأمان قبل كل امتحان'),
              subtitle: Text('أيام تُترك فارغة للمراجعة، ولا تُستخدم إلا إذا ضاق الوقت'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    icon: Icon(Icons.remove_circle_outline),
                    onPressed: s.bufferDays > 0
                        ? () {
                            s.bufferDays--;
                            app.commit();
                            setState(() {});
                          }
                        : null),
                Text('${s.bufferDays}', style: TextStyle(fontWeight: FontWeight.w800)),
                IconButton(
                    icon: Icon(Icons.add_circle_outline),
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
              title: Text('آخر يوم دراسة (تحدده أنت)'),
              subtitle: Text('${fmtDm(s.deadline)}/${s.deadline.year}  •  المواد التي لها موعد امتحان تتوقف قبله بيوم'),
              trailing: Icon(Icons.event_outlined),
              onTap: () async {
                final d = await pickDate(context, s.deadline);
                if (d != null) {
                  s.deadline = d;
                  app.commit();
                  setState(() {});
                }
              },
            ),
            Text('معامل وقت الفيديو: ${s.videoFactor.toStringAsFixed(2)}×  (للإيقاف والتدوين)', style: TextStyle(height: 1.5)),
            Slider(
              value: s.videoFactor,
              min: 1,
              max: 2.5,
              divisions: 15,
              activeColor: kForest,
              onChanged: (v) {
                s.videoFactor = v;
                setState(() {});
              },
              onChangeEnd: (_) => app.commit(),
            ),
          ]),
        ),
        Heading('الذكاء الاصطناعي'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'اختر أي خدمة تريدها. فيه خيارات مجانية (Gemini وGroq وOpenRouter) بمفتاح تأخذه مجاناً من موقع الخدمة، '
              'ولا تحتاج حساب Claude. المفتاح يُحفظ على هاتفك فقط ويُرسل لخدمتك أنت فقط. '
              'يرى الذكاء الاصطناعي عناوين المواد وخطتك، لا كلمة سرك ولا ملفاتك.',
              style: TextStyle(height: 1.6, fontSize: 13),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: providerById(s.provider).id,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'الخدمة'),
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
            SizedBox(height: 10),
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
                ValueListenableBuilder<bool>(
                  valueListenable: keystoreFailed,
                  builder: (_, failed, __) => Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          failed
                              ? 'تعذّر الحفظ الآمن للمفتاح على هذا الجهاز؛ لن يُحفظ بنص عادي. أعد إدخاله عند الحاجة.'
                              : 'يُحفظ المفتاح مشفّراً داخل مخزن الأمان في الهاتف، ولا يدخل في ملفات الدراسة.',
                          style: TextStyle(fontSize: 12, height: 1.5, color: failed ? kWarn : null),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          key.clear();
                          s.apiKey = '';
                          app.commit();
                          setState(() {});
                        },
                        child: Text('حذف المفتاح'),
                      ),
                    ]),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: model,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: 'النموذج', hintText: p.model, helperText: 'اتركه فارغاً لاستعمال: ${p.model}'),
                  onChanged: (v) => s.model = v.trim(),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: baseUrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: 'عنوان الخدمة (اختياري)', hintText: p.baseUrl),
                  onChanged: (v) => s.baseUrl = v.trim(),
                ),
              ]);
            }),
            SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await app.commit();
                if (context.mounted) toast(context, 'تم الحفظ');
              },
              child: Text('حفظ'),
            ),
          ]),
        ),
        const Heading('الأمان والخصوصية'),
        const DataPrivacyPanel(),
        Heading('أدوات'),
        Panel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.account_tree_outlined, color: kMoss),
            title: Text('شجرة المواد الخام'),
            subtitle: Text('للفحص ونسخ الشجرة كنص'),
            onTap: app.tree == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TreePage(tree: app.tree!))),
          ),
        ),
      ]),
    );
  }
}
