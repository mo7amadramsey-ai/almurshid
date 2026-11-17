import 'dart:convert';
import 'dart:io';
import 'package:almurshid/secrets.dart';
import 'package:almurshid/study_models.dart';
import 'package:almurshid/study_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('murshid_test');
    dirOverride = dir;
    secrets = MemorySecretStore();
    resetSecretsCache();
    studyLoadNotice.value = null;
  });
  tearDown(() {
    dirOverride = null;
    dir.deleteSync(recursive: true);
  });

  StudyData sample() {
    final d = StudyData();
    d.settings.apiKey = 'sk-very-secret';
    d.cfg('7').exam = DateTime(2026, 12, 2);
    d.state('7|u').minutes = 45;
    d.state('7|u').done = true;
    return d;
  }

  test('the data file carries a schema version and round-trips', () async {
    await saveStudy(sample());
    final raw = jsonDecode(await File('${dir.path}/study.json').readAsString()) as Map;
    expect(raw['v'], kSchema);
    expect((raw['settings'] as Map).containsKey('apiKey'), false);
    final back = await loadStudy();
    expect(back.courses['7']!.exam, DateTime(2026, 12, 2));
    expect(back.items['7|u']!.minutes, 45);
    expect(back.items['7|u']!.done, true);
    expect(back.settings.apiKey, 'sk-very-secret'); // read back from the secure store
  });

  test('a file from an older version without "v" still loads', () async {
    await File('${dir.path}/study.json').writeAsString(jsonEncode({'courses': {'3': {}}, 'items': {}}));
    final d = await loadStudy();
    expect(d.courses.containsKey('3'), true);
    expect(studyLoadNotice.value, null);
  });

  test('saving keeps the previous version as a backup', () async {
    final d = sample();
    await saveStudy(d);
    d.state('7|u').minutes = 99;
    await saveStudy(d);
    final bak = jsonDecode(await File('${dir.path}/study.json.bak').readAsString()) as Map;
    expect(((bak['items'] as Map)['7|u'] as Map)['minutes'], 45);
  });

  test('a damaged file is moved aside and the internal backup is restored', () async {
    final d = sample();
    await saveStudy(d);
    d.state('7|u').minutes = 60;
    await saveStudy(d); // now .bak holds minutes 45
    await File('${dir.path}/study.json').writeAsString('{ this is not json');
    final back = await loadStudy();
    expect(back.items['7|u']!.minutes, 45);
    expect(studyLoadNotice.value, isNotNull);
    expect(dir.listSync().any((e) => e.path.contains('study.json.corrupt-')), true);
  });

  test('when file and backup are both damaged the app starts empty but keeps the damaged file', () async {
    await File('${dir.path}/study.json').writeAsString('garbage');
    final d = await loadStudy();
    expect(d.items, isEmpty);
    expect(studyLoadNotice.value, isNotNull);
    expect(dir.listSync().any((e) => e.path.contains('study.json.corrupt-')), true);
  });

  test('a backup never contains the AI key and restores the student data', () {
    final text = buildBackup(sample(), [ActivityEntry(DateTime(2026, 11, 16), 'C', 'T', 'pdf')]);
    expect(text.contains('sk-very-secret'), false);
    final r = parseBackup(text);
    expect(r.data.courses['7']!.exam, DateTime(2026, 12, 2));
    expect(r.data.items['7|u']!.done, true);
    expect(r.log.single.title, 'T');
    expect(r.data.settings.apiKey, '');
  });

  test('anything that is not a backup of this app is refused with a clear message', () {
    expect(() => parseBackup('hello'), throwsA(isA<String>()));
    expect(() => parseBackup('{}'), throwsA(isA<String>()));
    expect(() => parseBackup(jsonEncode({'app': 'other', 'kind': 'backup', 'data': {}})), throwsA(isA<String>()));
  });

  test('delete-everything removes every local file and the stored key', () async {
    await saveStudy(sample());
    await saveStudy(sample());
    for (final n in ['news.json', 'log.json', 'tree.json', 'reminders.json']) {
      await File('${dir.path}/$n').writeAsString('[]');
    }
    await File('${dir.path}/study.json.corrupt-1').writeAsString('x');
    expect((secrets as MemorySecretStore).data.containsKey(kAiKey), true);
    await wipeLocalData();
    expect(dir.listSync(), isEmpty);
    expect((secrets as MemorySecretStore).data.containsKey(kAiKey), false);
  });
}
