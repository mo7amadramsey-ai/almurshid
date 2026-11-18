// Copies finished downloads into the phone's gallery (Movies/المرشد/<course>) and keeps the copy in step
// when a file is renamed, renumbered or deleted inside the app. Android 10+ only (MediaStore, no permission).
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../channel.dart';
import 'files.dart';

Future<File> _indexFile() async => File('${(await getApplicationSupportDirectory()).path}/gallery.json');

Future<Map<String, String>> _read() async {
  try {
    final f = await _indexFile();
    if (!f.existsSync()) return {};
    return (jsonDecode(await f.readAsString()) as Map).map((k, v) => MapEntry(k as String, v as String));
  } catch (_) {
    return {};
  }
}

Future<void> _write(Map<String, String> m) async {
  try {
    await (await _indexFile()).writeAsString(jsonEncode(m));
  } catch (_) {}
}

/// Adds [f] to the gallery under Movies/المرشد/[folder]. False when it is not possible (old Android, odd type).
Future<bool> galleryExport(File f, {required String folder}) async {
  try {
    final uri = await ch.invokeMethod<String>('saveToGallery', {
      'path': f.path,
      'name': baseName(f.path),
      'folder': safeName(folder),
    });
    if (uri == null || uri.isEmpty) return false;
    final m = await _read();
    m[f.path] = uri;
    await _write(m);
    return true;
  } catch (_) {
    return false;
  }
}

/// The file was renamed inside the app: rename its gallery copy too (if it has one).
Future<void> galleryRenamed(String from, String to) async {
  try {
    final m = await _read();
    final uri = m.remove(from);
    if (uri == null) return;
    try {
      await ch.invokeMethod('galleryRename', {'uri': uri, 'name': baseName(to)});
    } catch (_) {}
    m[to] = uri;
    await _write(m);
  } catch (_) {}
}

/// The file moved to another library folder: only the bookkeeping key changes.
Future<void> galleryMoved(String from, String to) async {
  try {
    final m = await _read();
    final uri = m.remove(from);
    if (uri == null) return;
    m[to] = uri;
    await _write(m);
  } catch (_) {}
}

/// A file (or a whole folder when [folder] is true) was deleted: remove the gallery copies too.
Future<void> galleryRemoved(String path, {bool folder = false}) async {
  try {
    final m = await _read();
    final keys = m.keys.where((k) => k == path || (folder && k.startsWith('$path/'))).toList();
    for (final k in keys) {
      try {
        await ch.invokeMethod('galleryDelete', {'uri': m[k]});
      } catch (_) {}
      m.remove(k);
    }
    await _write(m);
  } catch (_) {}
}
