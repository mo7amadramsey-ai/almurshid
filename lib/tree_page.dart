import 'package:flutter/material.dart';
import 'viewer/open_item.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'theme.dart';

IconData kindIcon(ItemKind k) {
  switch (k) {
    case ItemKind.video:
      return Icons.play_circle_outline;
    case ItemKind.pdf:
      return Icons.picture_as_pdf_outlined;
    case ItemKind.document:
      return Icons.description_outlined;
    case ItemKind.file:
      return Icons.insert_drive_file_outlined;
    case ItemKind.link:
      return Icons.link;
    case ItemKind.assignment:
      return Icons.assignment_outlined;
    case ItemKind.quiz:
      return Icons.quiz_outlined;
    case ItemKind.folder:
      return Icons.folder_outlined;
    case ItemKind.page:
      return Icons.article_outlined;
    case ItemKind.book:
      return Icons.menu_book_outlined;
    case ItemKind.forum:
      return Icons.forum_outlined;
    case ItemKind.other:
      return Icons.circle_outlined;
  }
}

class TreePage extends StatelessWidget {
  final Tree tree;
  const TreePage({super.key, required this.tree});

  void _copy(BuildContext context, String text, String msg) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final counts = tree.countByKind().entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      appBar: AppBar(
        title: Text('شجرة المواد'),
        actions: [
          IconButton(
            tooltip: 'نسخ الشجرة كنص',
            icon: Icon(Icons.copy_all_outlined),
            onPressed: () => _copy(context, tree.toText(), 'تم نسخ الشجرة'),
          ),
        ],
      ),
      body: ListView(padding: EdgeInsets.fromLTRB(14, 4, 14, 24), children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in counts)
            Chip(
              avatar: Icon(kindIcon(e.key), size: 18, color: kForest),
              label: Text('${kindLabels[e.key]} ${e.value}'),
              backgroundColor: kSurface2,
              side: BorderSide.none,
            ),
        ]),
        SizedBox(height: 12),
        for (final c in tree.courses) _courseTile(context, c),
        if (tree.errors.isNotEmpty) _errorsTile(context),
      ]),
    );
  }

  Widget _courseTile(BuildContext context, Course c) {
    final n = c.allItems.length;
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: cardBox(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.menu_book, color: kForest),
          title: Text(c.title, style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${c.sections.length} أقسام · $n عنصر'),
          children: [for (final s in c.sections) _sectionTile(context, s)],
        ),
      ),
    );
  }

  Widget _sectionTile(BuildContext context, Section s) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsetsDirectional.only(start: 22, end: 14),
          title: Text(s.title, style: TextStyle(fontSize: 14.5, color: kMoss, fontWeight: FontWeight.w700)),
          children: [for (final i in s.items) _itemTile(context, i, 0)],
        ),
      );

  Widget _itemTile(BuildContext context, Item i, int depth) {
    final pad = EdgeInsetsDirectional.only(start: 34.0 + depth * 18, end: 12);
    final leading = Icon(kindIcon(i.kind), size: 22, color: kForest);
    if (i.children.isEmpty) {
      return ListTile(
        dense: true,
        contentPadding: pad,
        leading: leading,
        title: Text(i.title, style: TextStyle(fontSize: 14)),
        subtitle: Text(kindLabels[i.kind]!, style: TextStyle(fontSize: 11.5)),
        onTap: () => openItem(context, url: i.url, title: i.title, kind: i.kind),
        onLongPress: () => _copy(context, i.url, 'تم نسخ الرابط'),
      );
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: pad,
        leading: leading,
        title: Text(i.title, style: TextStyle(fontSize: 14)),
        subtitle: Text('${kindLabels[i.kind]} · ${i.children.length}', style: TextStyle(fontSize: 11.5)),
        children: [for (final k in i.children) _itemTile(context, k, depth + 1)],
      ),
    );
  }

  Widget _errorsTile(BuildContext context) => Container(
        margin: EdgeInsets.only(top: 6),
        decoration: cardBox(),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(Icons.warning_amber_rounded, color: kMoss),
            title: Text('أخطاء الزحف (${tree.errors.length})'),
            children: [
              for (final e in tree.errors.take(100))
                ListTile(
                  dense: true,
                  title: Text(e.reason, style: TextStyle(fontSize: 13)),
                  subtitle: Text(e.url, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ),
      );
}
