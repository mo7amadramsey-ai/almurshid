import 'package:flutter/material.dart';
export 'tree_page.dart' show kindIcon;
import 'theme.dart';

const weekdayNames = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

String fmtDm(DateTime d) => '${d.day}/${d.month}';

String fmtMin(int m) {
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return '$r د';
  return r == 0 ? '$h س' : '$h س $r د';
}

class Heading extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const Heading(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kInk))),
          if (trailing != null) trailing!,
        ]),
      );
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: cardBox(22).copyWith(color: color),
        child: child,
      );
}

class EmptyNote extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const EmptyNote({super.key, required this.icon, required this.title, required this.body, this.action});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: kMoss),
            SizedBox(height: 14),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            SizedBox(height: 8),
            Text(body, style: TextStyle(height: 1.6), textAlign: TextAlign.center),
            if (action != null) ...[SizedBox(height: 18), action!],
          ]),
        ),
      );
}

void toast(BuildContext c, String msg) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));

Future<DateTime?> pickDate(BuildContext c, DateTime? initial) => showDatePicker(
      context: c,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

/// Small rounded label (counts, statuses). Colour is never the only signal: pass an icon or text.
class Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? bg;
  final Color? fg;
  const Pill(this.text, {super.key, this.icon, this.bg, this.fg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg ?? kTint, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg ?? kForest), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg ?? kForest)),
        ]),
      );
}

/// Soft rounded square with an icon, used at the start of list rows
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? bg;
  const IconBadge(this.icon, {super.key, this.color, this.bg});
  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: bg ?? kTint, borderRadius: BorderRadius.circular(13)),
        child: Icon(icon, size: 22, color: color ?? kForest),
      );
}
