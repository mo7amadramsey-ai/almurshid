import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import 'downloads.dart';
import 'files.dart';
import 'viewers.dart';

/// App-bar button with a badge showing how many downloads are running
class DownloadsButton extends StatelessWidget {
  const DownloadsButton({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: downloads,
        builder: (_, __) => IconButton(
          tooltip: 'التنزيلات',
          icon: Badge(
            isLabelVisible: downloads.activeCount > 0,
            label: Text('${downloads.activeCount}'),
            child: const Icon(Icons.download_outlined),
          ),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsPage())),
        ),
      );
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  String _status(DlTask t) {
    switch (t.state) {
      case DlState.preparing:
        return 'جارٍ التحضير…';
      case DlState.running:
        return t.total > 0 ? '${fmtSize(t.got)} من ${fmtSize(t.total)}' : fmtSize(t.got);
      case DlState.done:
        return 'اكتمل';
      case DlState.failed:
        return 'فشل: ${t.error ?? ''}';
      case DlState.cancelled:
        return 'أُلغي';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('التنزيلات'),
          actions: [TextButton(onPressed: downloads.clearFinished, child: const Text('مسح المنتهية'))],
        ),
        body: ListenableBuilder(
          listenable: downloads,
          builder: (_, __) {
            if (downloads.tasks.isEmpty) return const EmptyNote(
                icon: Icons.download_outlined, title: 'لا توجد تنزيلات', body: 'اضغط مطوّلاً على أي فيديو أو ملف في «المواد» لتنزيله.');
            return ListView(padding: const EdgeInsets.all(14), children: [
              for (final t in downloads.tasks)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: cardBox(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      Pill(t.label),
                    ]),
                    if (t.active) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: t.progress, color: kForest, backgroundColor: kSurface2),
                    ],
                    const SizedBox(height: 6),
                    Text(_status(t), style: TextStyle(fontSize: 12.5, color: t.state == DlState.failed ? kWarnText : kInk)),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (t.active) TextButton(onPressed: () => downloads.cancel(t), child: const Text('إلغاء')),
                      if (t.state == DlState.failed || t.state == DlState.cancelled)
                        TextButton(onPressed: () => downloads.retry(t), child: const Text('إعادة المحاولة')),
                      if (t.state == DlState.done && t.resultPath != null)
                        TextButton(onPressed: () => openLocalFile(context, t.resultPath!), child: const Text('فتح')),
                      if (!t.active) TextButton(onPressed: () => downloads.remove(t), child: const Text('إزالة')),
                    ]),
                  ]),
                ),
            ]);
          },
        ),
      );
}
