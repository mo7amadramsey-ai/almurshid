// PDFs, slides and other files are supporting material: they take no study time and are not in the plan.
// They stay one tap away on the course page; a tap downloads the file once and opens it in the app.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'download_sheet.dart';
import 'downloads.dart';
import 'files.dart';
import 'viewers.dart';

bool isSupportKind(ItemKind k) => k == ItemKind.pdf || k == ItemKind.document || k == ItemKind.file;

List<Item> supportItems(Course c) {
  final seen = <String>{};
  final out = <Item>[];
  for (final s in c.sections) {
    for (final top in s.items) {
      for (final i in top.flatten()) {
        if (isSupportKind(i.kind) && seen.add(i.url)) out.add(i);
      }
    }
  }
  return out;
}

/// Opens a supporting file: uses the copy already in the course folder, otherwise downloads it first.
Future<void> openSupportFile(BuildContext c, Item item, String course) async {
  final dir = await courseDir(course);
  final want = safeName(item.title);
  for (final e in dir.listSync()) {
    if (e is File && titlePart(baseName(e.path)) == want && !baseName(e.path).startsWith('.')) {
      if (c.mounted) await openLocalFile(c, e.path);
      return;
    }
  }
  if (!c.mounted) return;
  toast(c, 'جارٍ تحميل الملف…');
  final before = downloads.tasks.length;
  if (!downloads.startFile(item.url, dir, title: item.title)) {
    toast(c, 'هذا الملف قيد التحميل بالفعل');
    return;
  }
  final task = downloads.tasks.length > before ? downloads.tasks.first : null;
  if (task == null) return;
  while (task.active) {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
  if (!c.mounted) return;
  if (task.state == DlState.done && task.resultPath != null) {
    await openLocalFile(c, task.resultPath!);
  } else {
    toast(c, task.error ?? 'تعذّر تحميل الملف');
  }
}

class SupportFiles extends StatelessWidget {
  final Course course;
  const SupportFiles({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    final items = supportItems(course);
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Material(
        color: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: kOutline)),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(Icons.attach_file, color: kMoss),
          title: Text('مواد داعمة (${items.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('لا تأخذ وقتاً في الخطة'),
          children: [
            for (final i in items)
              ListTile(
                dense: true,
                leading: Icon(kindIcon(i.kind), color: kMoss, size: 22),
                title: Text(i.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => openSupportFile(context, i, course.title),
                onLongPress: () => showItemActions(context, url: i.url, title: i.title, course: course.title),
              ),
          ],
        ),
      ),
    );
  }
}
