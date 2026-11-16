// Plays one YouTube video inside the app with the IFrame player: no YouTube app, no home feed,
// no "up next" list. When the video ends the player is hidden so end-screen suggestions never show.
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme.dart';
import 'guarded_web.dart';
import 'nav_bar.dart';

String? youtubeIdOf(Uri u) {
  final h = u.host.toLowerCase();
  if (h == 'youtu.be' && u.pathSegments.isNotEmpty) return u.pathSegments.first;
  if (h.endsWith('youtube.com') || h.endsWith('youtube-nocookie.com')) {
    final v = u.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;
    final s = u.pathSegments;
    if (s.length >= 2 && (s[0] == 'embed' || s[0] == 'shorts' || s[0] == 'live')) return s[1];
  }
  return null;
}

String _playerHtml(String id) => '''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
html,body{margin:0;height:100%;background:#000;overflow:hidden}
#p{position:absolute;top:0;left:0;width:100%;height:100%}
</style></head><body>
<div id="p"></div>
<script src="https://www.youtube.com/iframe_api"></script>
<script>
var player;
function onYouTubeIframeAPIReady(){
  player=new YT.Player('p',{
    videoId:'$id',
    playerVars:{rel:0,modestbranding:1,playsinline:1,iv_load_policy:3,fs:0,autoplay:0,origin:'https://www.youtube.com'},
    events:{
      onStateChange:function(e){ if(e.data===0){ document.getElementById('p').style.visibility='hidden'; YT_CH.postMessage('ended'); } },
      onError:function(e){ YT_CH.postMessage('error:'+e.data); }
    }
  });
}
function replay(){ document.getElementById('p').style.visibility='visible'; player.seekTo(0); player.playVideo(); }
</script></body></html>
''';

class YoutubePlayerPage extends StatefulWidget {
  final String videoId;
  final String title;
  final String originalUrl;
  const YoutubePlayerPage({super.key, required this.videoId, required this.title, required this.originalUrl});
  @override
  State<YoutubePlayerPage> createState() => _YoutubePlayerPageState();
}

class _YoutubePlayerPageState extends State<YoutubePlayerPage> {
  late final WebViewController c;
  bool ended = false;
  String? error;

  @override
  void initState() {
    super.initState();
    c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(chromeUA)
      ..addJavaScriptChannel('YT_CH', onMessageReceived: (m) {
        if (!mounted) return;
        if (m.message == 'ended') setState(() => ended = true);
        if (m.message.startsWith('error')) setState(() => error = m.message);
      })
      ..setNavigationDelegate(NavigationDelegate(
        // The player must not wander off: only about:blank / the player's own frames are allowed.
        onNavigationRequest: (r) {
          final u = Uri.tryParse(r.url);
          if (u == null) return NavigationDecision.prevent;
          if (!r.isMainFrame) return NavigationDecision.navigate;
          return (u.scheme == 'about' || u.scheme == 'data' || u.host.isEmpty) ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ))
      ..loadHtmlString(_playerHtml(widget.videoId), baseUrl: 'https://www.youtube.com');
  }

  void _replay() {
    setState(() => ended = false);
    c.runJavaScript('replay()');
  }

  // Fallback when the embed refuses the video: the restricted browser (YouTube / Moodle / Drive only).
  void _openInBrowser() => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => GuardedWebPage(url: widget.originalUrl, title: widget.title)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16))),
        body: Column(children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(children: [
              Positioned.fill(child: WebViewWidget(controller: c)),
              if (ended)
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('انتهى الفيديو', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                        onPressed: _replay,
                        icon: const Icon(Icons.replay),
                        label: const Text('إعادة'),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.5, color: kBrownDark)),
                const SizedBox(height: 10),
                const Text('يُشغَّل هنا داخل المرشد فقط، بدون تطبيق يوتيوب ولا صفحة التوصيات.', style: TextStyle(height: 1.6, fontSize: 13)),
                if (error != null) ...[
                  const SizedBox(height: 14),
                  const Text('لم يسمح يوتيوب بتشغيل هذا الفيديو داخل المشغّل المضمَّن.', style: TextStyle(color: Color(0xFFB5602E), height: 1.5)),
                  const SizedBox(height: 8),
                  FilledButton.icon(onPressed: _openInBrowser, icon: const Icon(Icons.public), label: const Text('فتحه في المتصفح المقيّد')),
                ],
              ]),
            ),
          ),
        ]),
        bottomNavigationBar: const AppNavBar(),
      );
}
