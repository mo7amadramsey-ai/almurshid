// File helpers for the downloads library (numbering "003 - Title.mp4" is the Focus Lock idea).
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<Directory> mediaRoot() async {
  final d = Directory('${(await getApplicationDocumentsDirectory()).path}/library');
  if (!d.existsSync()) await d.create(recursive: true);
  return d;
}

/// Folder for a course (created on demand)
Future<Directory> courseDir(String? course) async {
  final root = await mediaRoot();
  if (course == null || course.trim().isEmpty) return root;
  final d = Directory('${root.path}/${safeName(course)}');
  if (!d.existsSync()) await d.create(recursive: true);
  return d;
}

String safeName(String s) {
  final t = s.replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '_').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return 'ملف';
  return t.length > 90 ? t.substring(0, 90).trim() : t;
}

String baseName(String path) => path.split('/').where((p) => p.isNotEmpty).last;

String extOf(String path) {
  final n = baseName(path);
  final i = n.lastIndexOf('.');
  if (i <= 0 || i == n.length - 1) return '';
  final e = n.substring(i + 1).toLowerCase();
  return e.length > 6 ? '' : e;
}

const _video = {'mp4', 'm4v', 'mov', 'mkv', 'webm', 'avi', '3gp'};
const _audio = {'mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus'};
const _image = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

bool isVideo(String p) => _video.contains(extOf(p));
bool isAudio(String p) => _audio.contains(extOf(p));
bool isImage(String p) => _image.contains(extOf(p));
bool isPdf(String p) => extOf(p) == 'pdf';

/// "3" + "Limits" + ".mp4" -> "003 - Limits.mp4"
String numberedName(int? n, String title, String ext) =>
    n == null ? '$title$ext' : '${n.toString().padLeft(3, '0')} - $title$ext';

int? numberOf(String name) {
  final m = RegExp(r'^(\d{1,4}) - ').firstMatch(name);
  return m == null ? null : int.parse(m.group(1)!);
}

/// File name without number prefix and extension
String titlePart(String name) {
  var t = name.replaceFirst(RegExp(r'^\d{1,4} - '), '');
  final i = t.lastIndexOf('.');
  if (i > 0 && t.length - i <= 7) t = t.substring(0, i);
  return t;
}

/// Next free number in a folder (max + 1), also skipping numbers [reserved] by running downloads
int nextNumber(Directory dir, {Iterable<int> reserved = const []}) {
  var m = 0;
  for (final e in dir.listSync()) {
    if (e is File) {
      final n = numberOf(baseName(e.path));
      if (n != null && n > m) m = n;
    }
  }
  for (final r in reserved) {
    if (r > m) m = r;
  }
  return m + 1;
}

/// Compares "Lecture 2" before "Lecture 10"
int naturalCompare(String a, String b) {
  final ra = RegExp(r'\d+|\D+');
  final pa = ra.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
  final pb = ra.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final x = pa[i], y = pb[i];
    final nx = int.tryParse(x), ny = int.tryParse(y);
    final c = (nx != null && ny != null) ? nx.compareTo(ny) : x.compareTo(y);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}

/// Folders first, then files; both in natural name order (numbered files follow their number)
List<FileSystemEntity> listSorted(Directory d) {
  final all = d.listSync().where((e) => !baseName(e.path).endsWith('.part') && !baseName(e.path).startsWith('.')).toList();
  final dirs = all.whereType<Directory>().toList()..sort((a, b) => naturalCompare(baseName(a.path), baseName(b.path)));
  final files = all.whereType<File>().toList()..sort((a, b) => naturalCompare(baseName(a.path), baseName(b.path)));
  return [...dirs, ...files];
}

String fmtSize(int bytes) {
  if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}
