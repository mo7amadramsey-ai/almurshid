// Numbered names "003 - Title.mp4" (the Focus Lock idea): every lecture video gets a default number that
// follows the lecture order of its course, and keeps it until the user changes it.
import 'dart:io';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../viewer/youtube_page.dart' show youtubeIdOf;
import 'downloads.dart';
import 'files.dart';
import 'gallery.dart';

/// The lecture videos of a course in course order (the order they appear on Moodle), without repeats.
List<Item> courseVideos(Course c) {
  final seen = <String>{};
  final out = <Item>[];
  for (final s in c.sections) {
    for (final top in s.items) {
      for (final i in top.flatten()) {
        if (i.kind == ItemKind.video && seen.add(i.url)) out.add(i);
      }
    }
  }
  return out;
}

/// "Lecture number" of a video inside its course (1-based), or null when it is not one of the course videos.
int? lectureNumber(Course c, String url) {
  final i = courseVideos(c).indexWhere((v) => v.url == url);
  return i < 0 ? null : i + 1;
}

Course? courseByTitle(String? title) {
  if (title == null) return null;
  for (final c in app.tree?.courses ?? const <Course>[]) {
    if (c.title == title) return c;
  }
  return null;
}

/// Is [url] a video we can show a number for (YouTube link or a direct video file)?
bool isVideoLink(String url) {
  final u = Uri.tryParse(url);
  if (u == null) return false;
  return youtubeIdOf(u) != null || isVideo(Uri.decodeFull(u.path));
}

/// The number a new download gets by default: its lecture number if that number is still free in the
/// folder, otherwise the next free number. Null for things that are not videos (PDFs and so on).
int? defaultNumber(Directory dir, String? courseTitle, String url) {
  if (!isVideoLink(url)) return null;
  final used = <int>{...downloads.pendingNumbers(dir)};
  for (final e in dir.listSync()) {
    if (e is File) {
      final k = numberOf(baseName(e.path));
      if (k != null) used.add(k);
    }
  }
  final c = courseByTitle(courseTitle);
  final n = c == null ? null : lectureNumber(c, url);
  if (n != null && !used.contains(n)) return n;
  return nextNumber(dir, reserved: downloads.pendingNumbers(dir));
}

/// Renames [f] inside the app and keeps its gallery copy in step.
Future<File> renameMedia(File f, String toPath) async {
  final r = await f.rename(toPath);
  await galleryRenamed(f.path, toPath);
  return r;
}

Future<void> insertAtNumber(Directory dir, int n, {String? exceptPath}) async {
  final files = <String, File>{
    for (final e in dir.listSync())
      if (e is File && e.path != exceptPath && !baseName(e.path).startsWith('.')) baseName(e.path): e,
  };
  for (final (from, to) in shiftPlan(files.keys, n)) {
    await renameMedia(files[from]!, '${dir.path}/$to');
  }
}

/// Applies a new name and number to [f] (null number = no number). Other files shift if the number is taken.
Future<File> applyNameNumber(File f, String name, int? number) async {
  final cur = baseName(f.path);
  final ext = extOf(cur).isEmpty ? '' : '.${extOf(cur)}';
  final title = name.trim().isEmpty ? titlePart(cur) : safeName(name);
  if (number != null && number != numberOf(cur)) await insertAtNumber(f.parent, number, exceptPath: f.path);
  var to = '${f.parent.path}/${numberedName(number, title, ext)}';
  for (var k = 2; to != f.path && File(to).existsSync(); k++) {
    to = '${f.parent.path}/${numberedName(number, '$title ($k)', ext)}';
  }
  if (to == f.path) return f;
  return renameMedia(f, to);
}

/// Dialog: name + number (number optional). Returns null on cancel.
Future<({String name, int? number})?> askNameNumber(BuildContext c,
    {required String title, required String initialName, int? initialNumber}) {
  final nameC = TextEditingController(text: initialName);
  final numC = TextEditingController(text: initialNumber?.toString() ?? '');
  return showDialog<({String name, int? number})>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: 80,
            child: TextField(controller: numC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الرقم')),
          ),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: nameC, autofocus: true, decoration: const InputDecoration(labelText: 'الاسم'))),
        ]),
        const SizedBox(height: 12),
        const Text(
          'الرقم المقترح هو ترتيب المحاضرة في المادة، ويبقى كما هو ما لم تغيّره. '
          'إن كان الرقم مستخدماً يُزاح ذلك الفيديو وما بعده خطوة واحدة (001 القديم يصير 002).',
          style: TextStyle(fontSize: 12.5, height: 1.5),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx, (name: nameC.text.trim(), number: int.tryParse(numC.text.trim())));
          },
          child: const Text('موافق'),
        ),
      ],
    ),
  );
}
