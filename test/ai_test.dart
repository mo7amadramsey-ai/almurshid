import 'package:flutter_test/flutter_test.dart';
import 'package:almurshid/ai.dart';
import 'package:almurshid/study_models.dart';

void main() {
  test('every provider has a model and base url', () {
    for (final p in aiProviders) {
      expect(p.model, isNotEmpty);
      expect(p.baseUrl, startsWith('http'));
    }
  });
  test('unknown provider falls back to the first', () {
    expect(providerById('nope').id, aiProviders.first.id);
  });
  test('settings round-trip keeps provider and base url', () {
    final s = Settings(provider: 'custom', baseUrl: 'http://x/v1', model: 'm', apiKey: 'k');
    final r = Settings.fromJson(s.toJson());
    expect(r.provider, 'custom');
    expect(r.baseUrl, 'http://x/v1');
    expect(r.model, 'm');
  });
  test('ai readiness: key required except custom/local', () {
    expect(aiReady(Settings(provider: 'groq')), isFalse);
    expect(aiReady(Settings(provider: 'groq', apiKey: 'k')), isTrue);
    expect(aiReady(Settings(provider: 'custom')), isTrue);
  });
}
