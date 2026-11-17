// In-app navigation bar: Back / Recent screens / Home, working inside the app only
// (useful when the phone's own navigation is unavailable, e.g. during a study seal).
import 'package:flutter/material.dart';
import '../theme.dart';
import 'open_item.dart';
import 'recents.dart';

class AppNavBar extends StatelessWidget {
  final Future<void> Function()? onBack; // e.g. WebView history; default = close this screen
  const AppNavBar({super.key, this.onBack});

  Future<void> _showRecents(BuildContext context) async {
    await recents.load();
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      builder: (sheet) => SafeArea(
        child: AnimatedBuilder(
          animation: recents,
          builder: (_, __) => recents.items.isEmpty
              ? Padding(padding: EdgeInsets.all(28), child: Text('لا توجد شاشات حديثة بعد.'))
              : ListView(shrinkWrap: true, children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
                    child: Text('الشاشات الأخيرة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kBrownDark)),
                  ),
                  for (final r in recents.items)
                    ListTile(
                      dense: true,
                      leading: Icon(iconForUrl(r.url), color: kBrown),
                      title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(Uri.tryParse(r.url)?.host ?? '', style: TextStyle(fontSize: 11)),
                      onTap: () {
                        Navigator.pop(sheet);
                        openItem(context, url: r.url, title: r.title);
                      },
                    ),
                ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
        color: kSurface,
        elevation: 6,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 54,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _btn(Icons.arrow_forward_rounded, 'رجوع', () async {
                if (onBack != null) {
                  await onBack!();
                } else {
                  if (context.mounted) Navigator.maybePop(context);
                }
              }),
              _btn(Icons.filter_none_rounded, 'الأخيرة', () => _showRecents(context)),
              _btn(Icons.home_rounded, 'البداية', () => Navigator.of(context).popUntil((r) => r.isFirst)),
            ]),
          ),
        ),
      );

  Widget _btn(IconData i, String tip, VoidCallback f) => Expanded(
        child: InkWell(
          onTap: f,
          child: Tooltip(message: tip, child: Center(child: Icon(i, size: 26, color: kBrownDark))),
        ),
      );
}
