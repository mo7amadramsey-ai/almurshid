// A browser that can only reach Moodle, YouTube and Google Drive / Docs. Everything else is refused.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme.dart';
import '../widgets.dart' show toast;
import 'nav_bar.dart';

const _allowed = [
  'ucas.edu.ps', // Moodle
  'youtube.com', 'youtu.be', 'youtube-nocookie.com', 'googlevideo.com', 'ytimg.com', 'ggpht.com', // YouTube
  'google.com', 'gstatic.com', 'googleusercontent.com', 'googleapis.com', // Drive / Docs / Google sign-in
];

bool hostAllowed(String host) {
  final h = host.toLowerCase();
  return _allowed.any((a) => h == a || h.endsWith('.$a'));
}

const chromeUA =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

class GuardedWebPage extends StatefulWidget {
  final String url;
  final String title;
  const GuardedWebPage({super.key, required this.url, required this.title});
  @override
  State<GuardedWebPage> createState() => _GuardedWebPageState();
}

class _GuardedWebPageState extends State<GuardedWebPage> {
  late final WebViewController c;
  int progress = 0;
  String shownTitle = '';

  @override
  void initState() {
    super.initState();
    shownTitle = widget.title;
    c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(chromeUA)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (r) {
          final u = Uri.tryParse(r.url);
          if (u == null) return NavigationDecision.prevent;
          if (u.scheme == 'about' || u.scheme == 'data' || u.scheme == 'blob') return NavigationDecision.navigate;
          if ((u.scheme == 'http' || u.scheme == 'https') && hostAllowed(u.host)) return NavigationDecision.navigate;
          if (mounted && r.isMainFrame) toast(context, 'هذا الموقع غير مسموح داخل المرشد (المسموح: مودل، يوتيوب، درايف)');
          return NavigationDecision.prevent;
        },
        onProgress: (p) {
          if (mounted) setState(() => progress = p);
        },
        onPageFinished: (_) async {
          final t = await c.getTitle();
          if (mounted && t != null && t.trim().isNotEmpty) setState(() => shownTitle = t.trim());
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _back() async {
    if (await c.canGoBack()) {
      await c.goBack();
    } else if (mounted) {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(shownTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
            actions: [
              IconButton(tooltip: 'تحديث', icon: const Icon(Icons.refresh), onPressed: () => c.reload()),
              IconButton(
                tooltip: 'نسخ الرابط',
                icon: const Icon(Icons.link),
                onPressed: () async {
                  final u = await c.currentUrl();
                  await Clipboard.setData(ClipboardData(text: u ?? widget.url));
                  if (context.mounted) toast(context, 'تم نسخ الرابط');
                },
              ),
            ],
          ),
          body: Column(children: [
            if (progress < 100) LinearProgressIndicator(value: progress / 100, color: kBrown, backgroundColor: kBrownLight, minHeight: 3),
            Expanded(child: WebViewWidget(controller: c)),
          ]),
          bottomNavigationBar: AppNavBar(onBack: _back),
        ),
      );
}
