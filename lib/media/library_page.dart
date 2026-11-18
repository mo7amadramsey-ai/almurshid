import 'dart:io';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import 'downloads_page.dart';
import 'files.dart';
import 'gallery.dart';
import 'numbering.dart';
import 'viewers.dart';

/// Folder browser for everything downloaded (one folder per course by default).
class LibraryPage extends StatefulWidget {
  final Directory? dir; // null = library root
  const LibraryPage({super.key, this.dir});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  Directory? dir;
  List<FileSystemEntity> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = widget.dir ?? await mediaRoot();
    final list = listSorted(d);
    if (!mounted) return;
    setState(() {
      dir = d;
      items = list;
      loading = false;
    });
  }

  Future<String?> _ask(String title, {String initial = ''}) async {
    final ctl = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('حفظ')),
        ],
      ),
    );
    final t = r == null ? '' : safeName(r);
    return t.isEmpty || r == null ? null : t;
  }

  Future<void> _newFolder() async {
    final n = await _ask('اسم المجلد');
    if (n == null || dir == null) return;
    await Directory('${dir!.path}/$n').create();
    _load();
  }

  Future<void> _rename(FileSystemEntity e) async {
    final isFile = e is File;
    final cur = baseName(e.path);
    if (e is File && !cur.startsWith('.')) {
      // files: name + number together (the Focus Lock way); a taken number shifts the following ones
      final r = await askNameNumber(context, title: 'الاسم والرقم', initialName: titlePart(cur), initialNumber: numberOf(cur));
      if (r == null) return;
      await applyNameNumber(e, r.name, r.number);
      _load();
      return;
    }
    final n = await _ask('الاسم الجديد', initial: isFile ? titlePart(cur) : cur);
    if (n == null) return;
    final ext = isFile && extOf(cur).isNotEmpty ? '.${extOf(cur)}' : '';
    final to = '${e.parent.path}/${isFile ? numberedName(numberOf(cur), n, ext) : n}';
    if (to == e.path) return;
    if (FileSystemEntity.typeSync(to) != FileSystemEntityType.notFound) {
      if (mounted) toast(context, 'يوجد عنصر بهذا الاسم');
      return;
    }
    await e.rename(to);
    _load();
  }

  Future<void> _delete(FileSystemEntity e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف «${baseName(e.path)}»؟'),
        content: Text(e is Directory ? 'سيُحذف المجلد وكل ما بداخله.' : 'سيُحذف الملف نهائياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    await galleryRemoved(e.path, folder: e is Directory);
    await e.delete(recursive: true);
    _load();
  }

  Future<void> _move(File f) async {
    final root = await mediaRoot();
    final dirs = [root, ...root.listSync(recursive: true).whereType<Directory>()]
      ..removeWhere((d) => d.path == f.parent.path);
    if (!mounted) return;
    final to = await showDialog<Directory>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('نقل إلى'),
        children: [
          for (final d in dirs)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d),
              child: Text(d.path == root.path ? 'المكتبة (الرئيسي)' : d.path.substring(root.path.length + 1)),
            ),
        ],
      ),
    );
    if (to == null) return;
    final target = '${to.path}/${baseName(f.path)}';
    if (File(target).existsSync()) {
      if (mounted) toast(context, 'يوجد ملف بهذا الاسم هناك');
      return;
    }
    await f.rename(target);
    await galleryMoved(f.path, target);
    _load();
  }

  IconData _icon(FileSystemEntity e) {
    if (e is Directory) return Icons.folder_outlined;
    if (isVideo(e.path)) return Icons.play_circle_outline;
    if (isAudio(e.path)) return Icons.audiotrack_outlined;
    if (isPdf(e.path)) return Icons.picture_as_pdf_outlined;
    if (isImage(e.path)) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.dir == null ? 'مكتبتي' : baseName(widget.dir!.path)),
          actions: const [DownloadsButton()],
        ),
        floatingActionButton: FloatingActionButton(onPressed: _newFolder, child: const Icon(Icons.create_new_folder_outlined)),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? const EmptyNote(
                    icon: Icons.video_library_outlined,
                    title: 'المكتبة فارغة',
                    body: 'اضغط مطوّلاً على أي فيديو أو ملف في «المواد» لتنزيله، وسيظهر هنا ويعمل بلا إنترنت.')
                : ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 90), children: [
                    for (final e in items)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: cardBox(14),
                        child: ListTile(
                          leading: Icon(_icon(e), color: kMoss, size: 28),
                          title: Text(e is File ? titlePart(baseName(e.path)) : baseName(e.path), maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: e is File ? Text(fmtSize(e.lengthSync())) : null,
                          onTap: () async {
                            if (e is Directory) {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryPage(dir: e)));
                            } else {
                              await openLocalFile(context, e.path);
                            }
                            _load();
                          },
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'move') _move(e as File);
                              if (v == 'rename') _rename(e);
                              if (v == 'delete') _delete(e);
                            },
                            itemBuilder: (_) => [
                              if (e is File) const PopupMenuItem(value: 'move', child: Text('نقل إلى مجلد')),
                              const PopupMenuItem(value: 'rename', child: Text('إعادة تسمية')),
                              const PopupMenuItem(value: 'delete', child: Text('حذف')),
                            ],
                          ),
                        ),
                      ),
                  ]),
      );
}
