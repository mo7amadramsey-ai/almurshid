import 'package:flutter/material.dart';
export 'tree_page.dart' show kindIcon;
import 'models.dart';
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
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
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
        decoration: cardBox(20).copyWith(color: color),
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
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: kBrown),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(height: 1.6), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 18), action!],
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
