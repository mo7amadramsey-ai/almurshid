// In-app viewers for downloaded files: video / audio (resume, speed, fullscreen), PDF and images.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../widgets.dart';
import 'files.dart';

Future<void> openLocalFile(BuildContext c, String path) async {
  final Widget? page = (isVideo(path) || isAudio(path))
      ? VideoFilePage(path: path)
      : isPdf(path)
          ? PdfFilePage(path: path)
          : isImage(path)
              ? ImageFilePage(path: path)
              : null;
  if (page == null) {
    toast(c, 'لا يوجد عارض داخلي لهذا النوع (.${extOf(path)})');
    return;
  }
  await Navigator.push(c, MaterialPageRoute(builder: (_) => page));
}

// ---- resume position per file (a Focus Lock idea)
Future<File> _posFile() async => File('${(await getApplicationSupportDirectory()).path}/video_positions.json');

Future<Map<String, dynamic>> _readPos() async {
  try {
    final f = await _posFile();
    if (!f.existsSync()) return {};
    return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

Future<void> _savePos(String path, int ms) async {
  try {
    final m = await _readPos();
    if (ms < 3000) {
      m.remove(path);
    } else {
      m[path] = ms;
    }
    await (await _posFile()).writeAsString(jsonEncode(m));
  } catch (_) {}
}

String _fmt(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  return h > 0 ? '$h:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}' : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
}

class VideoFilePage extends StatefulWidget {
  final String path; // file path, or a stable key ("yt:ID") when streaming
  final String? streamUrl;
  final Map<String, String>? headers;
  final String? title;
  const VideoFilePage({super.key, required this.path, this.streamUrl, this.headers, this.title});
  @override
  State<VideoFilePage> createState() => _VideoFilePageState();
}

class _VideoFilePageState extends State<VideoFilePage> {
  late final VideoPlayerController v;
  bool ready = false;
  bool showControls = true;
  bool landscape = false;
  String? error;
  double speed = 1.0;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    final su = widget.streamUrl;
    v = su == null
        ? VideoPlayerController.file(File(widget.path))
        : VideoPlayerController.networkUrl(Uri.parse(su), httpHeaders: widget.headers ?? const {});
    _init();
  }

  Future<void> _init() async {
    try {
      await v.initialize();
      final saved = (await _readPos())[widget.path];
      if (saved is int && Duration(milliseconds: saved) < v.value.duration - const Duration(seconds: 5)) {
        await v.seekTo(Duration(milliseconds: saved));
      }
      await v.play();
      if (!mounted) return;
      setState(() => ready = true);
      _scheduleHide();
    } catch (e) {
      if (mounted) setState(() => error = 'تعذّر تشغيل الملف');
    }
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted && v.value.isPlaying) setState(() => showControls = false);
    });
  }

  void _seekBy(int sec) {
    final p = v.value.position + Duration(seconds: sec);
    final max = v.value.duration;
    v.seekTo(p < Duration.zero ? Duration.zero : (p > max ? max : p));
    _scheduleHide();
  }

  Future<void> _toggleOrientation() async {
    landscape = !landscape;
    if (landscape) {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hide?.cancel();
    if (ready) _savePos(widget.path, v.value.position.inMilliseconds);
    v.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? titlePart(baseName(widget.path));
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: error != null
            ? Center(child: Text(error!, style: const TextStyle(color: Colors.white)))
            : !ready
                ? const Center(child: CircularProgressIndicator())
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() => showControls = !showControls);
                      if (showControls) _scheduleHide();
                    },
                    child: Stack(children: [
                      Center(child: AspectRatio(aspectRatio: v.value.aspectRatio == 0 ? 16 / 9 : v.value.aspectRatio, child: VideoPlayer(v))),
                      if (showControls) _controls(title),
                    ]),
                  ),
      ),
    );
  }

  Widget _controls(String title) => Container(
        color: Colors.black54,
        child: Column(children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white))),
            PopupMenuButton<double>(
              tooltip: 'السرعة',
              icon: const Icon(Icons.speed, color: Colors.white),
              onSelected: (s) {
                setState(() => speed = s);
                v.setPlaybackSpeed(s);
              },
              itemBuilder: (_) => [
                for (final s in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                  CheckedPopupMenuItem(value: s, checked: s == speed, child: Text('${s}x')),
              ],
            ),
            IconButton(
              icon: Icon(landscape ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
              onPressed: _toggleOrientation,
            ),
          ]),
          const Spacer(),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: v,
            builder: (_, val, __) {
              final total = val.duration.inMilliseconds;
              final pos = val.position.inMilliseconds.clamp(0, total == 0 ? 1 : total).toDouble();
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(iconSize: 36, icon: const Icon(Icons.replay_10, color: Colors.white), onPressed: () => _seekBy(-10)),
                  IconButton(
                    iconSize: 56,
                    icon: Icon(val.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
                    onPressed: () {
                      val.isPlaying ? v.pause() : v.play();
                      _scheduleHide();
                    },
                  ),
                  IconButton(iconSize: 36, icon: const Icon(Icons.forward_10, color: Colors.white), onPressed: () => _seekBy(10)),
                ]),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(children: [
                    Padding(padding: const EdgeInsets.only(left: 12), child: Text(_fmt(val.position), style: const TextStyle(color: Colors.white))),
                    Expanded(
                      child: Slider(
                        value: pos,
                        max: total == 0 ? 1 : total.toDouble(),
                        onChanged: (x) => v.seekTo(Duration(milliseconds: x.toInt())),
                        onChangeEnd: (_) => _scheduleHide(),
                      ),
                    ),
                    Padding(padding: const EdgeInsets.only(right: 12), child: Text(_fmt(val.duration), style: const TextStyle(color: Colors.white))),
                  ]),
                ),
              ]);
            },
          ),
        ]),
      );
}

class PdfFilePage extends StatefulWidget {
  final String path;
  const PdfFilePage({super.key, required this.path});
  @override
  State<PdfFilePage> createState() => _PdfFilePageState();
}

class _PdfFilePageState extends State<PdfFilePage> {
  late final PdfControllerPinch c = PdfControllerPinch(document: PdfDocument.openFile(widget.path));

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(titlePart(baseName(widget.path)), overflow: TextOverflow.ellipsis)),
        body: PdfViewPinch(controller: c),
      );
}

class ImageFilePage extends StatelessWidget {
  final String path;
  const ImageFilePage({super.key, required this.path});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(titlePart(baseName(path)), overflow: TextOverflow.ellipsis)),
        body: InteractiveViewer(maxScale: 6, child: Center(child: Image.file(File(path)))),
      );
}
