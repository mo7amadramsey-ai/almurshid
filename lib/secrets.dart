// Secrets (the AI API key) live in Android Keystore, never in the plain JSON data files.
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'study_models.dart';

const kAiKey = 'ai_api_key';

abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Real store: Android Keystore through flutter_secure_storage.
class KeystoreSecretStore implements SecretStore {
  static const _s = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

/// In-memory store for tests.
class MemorySecretStore implements SecretStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}

SecretStore secrets = KeystoreSecretStore();

/// True when the Keystore could not be used (the UI shows a clear warning).
final keystoreFailed = ValueNotifier<bool>(false);

String? _lastSaved;

/// Called after study.json is read. Brings the key into [s.apiKey] from the Keystore, and moves an old
/// plain-text key out of the file. Returns true when study.json must be rewritten WITHOUT the key.
/// If the Keystore fails the old key stays in the file (nothing is lost) and we try again next launch.
Future<bool> loadApiKey(Settings s, SecretStore store) async {
  try {
    if (s.keyInFile && s.apiKey.isNotEmpty) {
      await store.write(kAiKey, s.apiKey);
      if (await store.read(kAiKey) != s.apiKey) throw StateError('verify failed');
      _lastSaved = s.apiKey;
      s.keyInFile = false;
      keystoreFailed.value = false;
      return true;
    }
    final stored = await store.read(kAiKey);
    if (stored != null && stored.isNotEmpty) {
      s.apiKey = stored;
      _lastSaved = stored;
    }
    keystoreFailed.value = false;
  } catch (_) {
    keystoreFailed.value = true;
  }
  return false;
}

/// Called before study.json is written: keeps the Keystore copy in step with [s.apiKey].
/// Returns false when the Keystore failed; the key is never written to the JSON file by this path.
Future<bool> saveApiKey(Settings s, SecretStore store) async {
  final key = s.apiKey.trim();
  if (key == (_lastSaved ?? '') && !s.keyInFile) return true; // nothing changed
  try {
    if (key.isEmpty) {
      await store.delete(kAiKey);
    } else {
      await store.write(kAiKey, key);
    }
    _lastSaved = key;
    s.keyInFile = false;
    keystoreFailed.value = false;
    return true;
  } catch (_) {
    keystoreFailed.value = true;
    return false;
  }
}

/// Forget cached state (used by tests).
void resetSecretsCache() => _lastSaved = null;
