import 'package:almurshid/ai.dart';
import 'package:almurshid/secrets.dart';
import 'package:almurshid/study_models.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingStore implements SecretStore {
  @override
  Future<String?> read(String key) async => throw StateError('keystore broken');
  @override
  Future<void> write(String key, String value) async => throw StateError('keystore broken');
  @override
  Future<void> delete(String key) async => throw StateError('keystore broken');
}

void main() {
  setUp(resetSecretsCache);

  test('a new install never writes the API key into the JSON data', () {
    final s = Settings(apiKey: 'sk-secret-123');
    expect(s.toJson().containsKey('apiKey'), false);
    expect(s.toJson().toString().contains('sk-secret-123'), false);
  });

  test('an old plain-text key is moved to the secure store and removed from the file', () async {
    final store = MemorySecretStore();
    final s = Settings.fromJson({'apiKey': 'sk-old-999', 'provider': 'groq'});
    expect(s.keyInFile, true);
    expect(s.toJson()['apiKey'], 'sk-old-999'); // until it is migrated
    final rewrite = await loadApiKey(s, store);
    expect(rewrite, true);
    expect(store.data[kAiKey], 'sk-old-999');
    expect(s.keyInFile, false);
    expect(s.apiKey, 'sk-old-999'); // still usable in memory
    expect(s.toJson().containsKey('apiKey'), false);
  });

  test('if the secure store fails, the old key is kept in the file (nothing is lost)', () async {
    final s = Settings.fromJson({'apiKey': 'sk-old-999'});
    final rewrite = await loadApiKey(s, FailingStore());
    expect(rewrite, false);
    expect(s.keyInFile, true);
    expect(s.toJson()['apiKey'], 'sk-old-999');
    expect(keystoreFailed.value, true);
  });

  test('the key is read back from the secure store on the next launch', () async {
    final store = MemorySecretStore()..data[kAiKey] = 'sk-from-keystore';
    final s = Settings.fromJson({'provider': 'openai'});
    await loadApiKey(s, store);
    expect(s.apiKey, 'sk-from-keystore');
    expect(keystoreFailed.value, false);
  });

  test('saving and deleting the key goes through the secure store', () async {
    final store = MemorySecretStore();
    final s = Settings();
    s.apiKey = '  sk-new-1  ';
    expect(await saveApiKey(s, store), true);
    expect(store.data[kAiKey], 'sk-new-1');
    s.apiKey = '';
    expect(await saveApiKey(s, store), true);
    expect(store.data.containsKey(kAiKey), false);
    expect(await saveApiKey(Settings(apiKey: 'x'), FailingStore()), false);
  });

  test('a key is never sent over plain http; keyless local servers are allowed', () {
    checkEndpoint('https://api.openai.com/v1', hasKey: true);
    expect(() => checkEndpoint('http://api.example.com/v1', hasKey: true), throwsA(isA<String>()));
    expect(() => checkEndpoint('http://192.168.1.10:11434/v1', hasKey: true), throwsA(isA<String>()));
    checkEndpoint('http://192.168.1.10:11434/v1', hasKey: false);
    checkEndpoint('http://localhost:11434/v1', hasKey: false);
    expect(() => checkEndpoint('http://example.com/v1', hasKey: false), throwsA(isA<String>()));
    expect(() => checkEndpoint('ftp://x/y', hasKey: false), throwsA(isA<String>()));
    expect(() => checkEndpoint('not a url', hasKey: false), throwsA(isA<String>()));
  });
}
