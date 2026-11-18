import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../theme.dart';
import '../viewer/youtube_page.dart' show youtubeIdOf;
import '../widgets.dart';
import 'downloads.dart';
import 'downloads_page.dart';
import 'files.dart';
import 'numbering.dart';

/// Long-press menu for any course item: download, copy link
Future<void> showItemActions(BuildContext c, {required String url, required String title, String? course}) async {
  await showModalBottomSheet<void>(
    context: c,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: Icon(Icons.download_outlined, color: kMoss),
          title: const Text('تحميل'),
          subtitle: const Text('يُحفظ في «مكتبتي» ويعمل بلا إنترنت'),
          onTap: () {
            Navigator.pop(sheet);
            showDownloadSheet(c, url: url, title: title, course: course);
          },
        ),
        ListTile(
          leading: Icon(Icons.link, color: kMoss),
          title: const Text('نسخ الرابط'),
          onTap: () {
            Navigator.pop(sheet);
            Clipboard.setData(ClipboardData(text: url));
            toast(c, 'تم نسخ الرابط');
          },
        ),
      ]),
    ),
  );
}

/// Starts a download for an item: YouTube asks for the quality first; Moodle / direct files start at once.
Future<void> showDownloadSheet(BuildContext c, {required String url, required String title, String? course}) async {
  final u = Uri.tryParse(url);
  if (u == null || !(u.scheme == 'http' || u.scheme == 'https')) {
    toast(c, 'رابط غير صالح');
    return;
  }
  final dir = await courseDir(course);
  if (!c.mounted) return;
  if (youtubeIdOf(u) == null) {
    var fileName = title;
    int? number;
    final isVid = isVideoLink(url);
    if (isVid) {
      final r = await askNameNumber(c, title: 'اسم الفيديو ورقمه', initialName: title, initialNumber: defaultNumber(dir, course, url));
      if (r == null || !c.mounted) return;
      fileName = r.name.isEmpty ? title : r.name;
      number = r.number;
    }
    final ok = downloads.startFile(url, dir,
        title: fileName, number: number, gallery: isVid && app.settings.saveToGallery, galleryFolder: course);
    toast(c, ok ? 'بدأ التحميل — تابعه من زر التنزيلات' : 'هذا الملف قيد التحميل بالفعل');
    return;
  }

  // YouTube: read the qualities first
  showDialog<void>(context: c, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  YtInfo? info;
  String? err;
  try {
    info = await youtubeInfo(url);
  } catch (e) {
    err = 'تعذّر قراءة الفيديو (قد يكون خاصاً أو غيّر يوتيوب طريقته)';
  }
  if (!c.mounted) return;
  Navigator.of(c, rootNavigator: true).pop();
  if (info == null || info.options.isEmpty) {
    toast(c, err ?? 'لا توجد جودات متاحة');
    return;
  }
  final YtInfo yi = info;
  final name = title.trim().isEmpty ? yi.title : title;
  await showModalBottomSheet<void>(
    context: c,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('اختر الجودة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kInk)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(yi.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        for (final o in yi.options)
          ListTile(
            leading: Icon(o.audio ? Icons.audiotrack_outlined : Icons.videocam_outlined, color: kMoss),
            title: Text(o.text),
            subtitle: Text(fmtSize(o.bytes)),
            onTap: () async {
              Navigator.pop(sheet);
              // like Focus Lock: ask for a name and number; the default number follows the lecture order
              final r = await askNameNumber(c,
                  title: 'اسم الفيديو ورقمه', initialName: name, initialNumber: o.audio ? null : defaultNumber(dir, course, url));
              if (r == null || !c.mounted) return;
              final ok = downloads.startYoutube(url, dir,
                  title: r.name.isEmpty ? name : r.name,
                  option: o,
                  number: r.number,
                  gallery: !o.audio && app.settings.saveToGallery,
                  galleryFolder: course);
              toast(c, ok ? 'بدأ التحميل (${o.text})' : 'هذه الجودة قيد التحميل بالفعل');
            },
          ),
        ListTile(
          leading: Icon(Icons.download_outlined, color: kMoss),
          title: const Text('عرض التنزيلات'),
          onTap: () {
            Navigator.pop(sheet);
            Navigator.push(c, MaterialPageRoute(builder: (_) => const DownloadsPage()));
          },
        ),
      ]),
    ),
  );
}
