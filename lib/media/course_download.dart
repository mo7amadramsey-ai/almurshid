// "Download the whole course": every lecture video of a course, in lecture order, numbered 001, 002, ...,
// in one tap. Files go to the library (folder = course name) and, if wanted, also to the phone's gallery.
import 'dart:io';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../viewer/youtube_page.dart' show youtubeIdOf;
import '../widgets.dart';
import 'downloads.dart';
import 'downloads_page.dart';
import 'files.dart';
import 'numbering.dart';

/// Which lecture videos of [c] can be downloaded, and which are already in the course folder.
class CoursePlan {
  final List<(Item, int)> todo; // item + its lecture number
  final int youtube, direct, skippedOther, alreadyHave;
  CoursePlan(this.todo, this.youtube, this.direct, this.skippedOther, this.alreadyHave);
}

CoursePlan planCourseDownload(Course c, Directory dir) {
  final have = <String>{};
  for (final e in dir.listSync()) {
    if (e is File) have.add(titlePart(baseName(e.path)));
  }
  final todo = <(Item, int)>[];
  var yt = 0, direct = 0, other = 0, already = 0;
  final vids = courseVideos(c);
  for (var k = 0; k < vids.length; k++) {
    final i = vids[k];
    final u = Uri.tryParse(i.url);
    final isYt = u != null && youtubeIdOf(u) != null;
    final isDirect = u != null && !isYt && isVideo(Uri.decodeFull(u.path));
    if (!isYt && !isDirect) {
      other++;
      continue;
    }
    if (have.contains(safeName(i.title))) {
      already++;
      continue;
    }
    todo.add((i, k + 1));
    if (isYt) {
      yt++;
    } else {
      direct++;
    }
  }
  return CoursePlan(todo, yt, direct, other, already);
}

const _heights = <(String, int?)>[('أعلى جودة متاحة', null), ('720p', 720), ('480p', 480), ('360p', 360)];

Future<void> showCourseDownload(BuildContext c, Course course) async {
  final dir = await courseDir(course.title);
  final plan = planCourseDownload(course, dir);
  if (!c.mounted) return;
  var height = 0; // index in _heights
  var gallery = app.settings.saveToGallery;
  await showModalBottomSheet<void>(
    context: c,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (ctx, setS) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('تحميل فيديوهات المادة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kInk)),
            const SizedBox(height: 4),
            Text(course.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            Text(
              plan.todo.isEmpty
                  ? 'لا يوجد ما يُحمَّل: ${plan.alreadyHave > 0 ? 'كل الفيديوهات موجودة عندك' : 'لم أجد فيديوهات قابلة للتحميل'}.'
                  : '${plan.todo.length} فيديو سيُحمَّل بترتيب المحاضرات ويُرقَّم 001، 002، ... '
                      '${plan.alreadyHave > 0 ? '(${plan.alreadyHave} موجود مسبقاً فيُتخطّى) ' : ''}'
                      '${plan.skippedOther > 0 ? '(${plan.skippedOther} غير قابل للتحميل) ' : ''}',
              style: const TextStyle(height: 1.6),
            ),
            if (plan.todo.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('الجودة', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                for (var i = 0; i < _heights.length; i++)
                  ChoiceChip(label: Text(_heights[i].$1), selected: height == i, onSelected: (_) => setS(() => height = i)),
              ]),
              const SizedBox(height: 4),
              const Text('تُختار أعلى جودة لا تتجاوز ما طلبته (يوتيوب يقدّم صورة وصوتاً معاً حتى 720p عادة).',
                  style: TextStyle(fontSize: 12.5, height: 1.5)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: gallery,
                onChanged: (v) => setS(() => gallery = v),
                title: const Text('نسخة في معرض الهاتف'),
                subtitle: const Text('تظهر في المعرض داخل Movies/المرشد، وتستهلك مساحة مضاعفة.'),
              ),
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(sheet);
                  app.settings.saveToGallery = gallery;
                  await app.commit();
                  if (!c.mounted) return;
                  toast(c, 'بدأ تحميل ${plan.todo.length} فيديو بالتتابع، اثنان في وقت واحد');
                  Navigator.push(c, MaterialPageRoute(builder: (_) => const DownloadsPage()));
                  await _feed(plan, dir, course.title, _heights[height].$2, gallery);
                },
                icon: const Icon(Icons.download_for_offline_outlined),
                label: Text('ابدأ تحميل الكل (${plan.todo.length})'),
              ),
            ],
          ]),
        ),
      ),
    ),
  );
}

/// Feeds the download manager in lecture order, keeping at most two running (gentle on the phone and the network).
Future<void> _feed(CoursePlan plan, Directory dir, String course, int? maxHeight, bool gallery) async {
  for (final (item, n) in plan.todo) {
    while (downloads.activeCount >= 2) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    final u = Uri.parse(item.url);
    if (youtubeIdOf(u) != null) {
      downloads.startYoutubeAuto(item.url, dir, title: item.title, maxHeight: maxHeight, number: n, gallery: gallery, galleryFolder: course);
    } else {
      downloads.startFile(item.url, dir, title: item.title, number: n, gallery: gallery, galleryFolder: course);
    }
  }
}
