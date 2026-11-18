// Download manager: YouTube videos in the quality you pick (or audio only) and any Moodle / direct file.
// Moodle files use the WebView login session (cookies are read natively, HttpOnly ones included).
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../channel.dart';
import '../crawler/classify.dart' show isMoodleHost;
import 'files.dart';

enum DlState { preparing, running, done, failed, cancelled }

class DlTask {
  final int id;
  final String url;
  final Directory dir;
  String title;
  final String label; // quality shown in the list ("720p", "صوت فقط", "ملف")
  final String? quality; // YouTube quality label to fetch (null = direct file)
  final bool audio;
  final int? number;
  DlState state = DlState.preparing;
  int got = 0, total = 0;
  String? error;
  String? resultPath;
  bool cancelRequested = false;
  DlTask(this.id, this.url, this.dir, this.title, this.label, {this.quality, this.audio = false, this.number});

  bool get active => state == DlState.preparing || state == DlState.running;
  double? get progress => total > 0 ? (got / total).clamp(0.0, 1.0).toDouble() : null;
}

class _Cancelled implements Exception {}

/// One quality offered for a YouTube video
class YtOption {
  final String label; // "720p" or "audio"
  final bool audio;
  final int bytes;
  final String ext;
  YtOption(this.label, this.audio, this.bytes, this.ext);
  String get text => audio ? 'صوت فقط ($ext)' : label;
}

class YtInfo {
  final String title;
  final List<YtOption> options;
  YtInfo(this.title, this.options);
}

/// Reads the qualities of a YouTube video (video+audio in one file; no merging is needed).
Future<YtInfo> youtubeInfo(String url) async {
  final yt = YoutubeExplode();
  try {
    final id = VideoId(url);
    final video = await yt.videos.get(id);
    final m = await yt.videos.streamsClient.getManifest(id);
    final best = <String, MuxedStreamInfo>{};
    for (final s in m.muxed) {
      final cur = best[s.videoQualityLabel];
      if (cur == null || s.bitrate.bitsPerSecond > cur.bitrate.bitsPerSecond) best[s.videoQualityLabel] = s;
    }
    final opts = best.values
        .map((s) => YtOption(s.videoQualityLabel, false, s.size.totalBytes, s.container.name))
        .toList()
      ..sort((a, b) => qualityRank(b.label).compareTo(qualityRank(a.label)));
    if (m.audioOnly.isNotEmpty) {
      final a = m.audioOnly.withHighestBitrate();
      opts.add(YtOption('audio', true, a.size.totalBytes, a.container.name == 'mp4' ? 'm4a' : a.container.name));
    }
    return YtInfo(video.title, opts);
  } finally {
    yt.close();
  }
}

/// "1080p60" -> 1080 (for sorting)
int qualityRank(String label) => int.tryParse(RegExp(r'^\d+').stringMatch(label) ?? '') ?? 0;

Future<String> cookiesFor(String url) async {
  try {
    return (await ch.invokeMethod<String>('getCookies', {'url': url})) ?? '';
  } catch (_) {
    return '';
  }
}

const _ua = 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';

class DownloadManager extends ChangeNotifier {
  final tasks = <DlTask>[];
  int _next = 1;

  int get activeCount => tasks.where((t) => t.active).length;

  List<int> pendingNumbers(Directory dir) =>
      [for (final t in tasks) if (t.active && t.dir.path == dir.path && t.number != null) t.number!];

  bool _dup(String url, Directory dir, String? quality, bool audio) => tasks.any((t) =>
      t.active && t.url == url && t.dir.path == dir.path && t.quality == quality && t.audio == audio);

  /// false when the same download is already running
  bool startYoutube(String url, Directory dir, {required String title, required YtOption option, int? number}) {
    final q = option.audio ? null : option.label;
    if (_dup(url, dir, q, option.audio)) return false;
    final t = DlTask(_next++, url, dir, title, option.audio ? 'صوت فقط' : option.label,
        quality: q, audio: option.audio, number: number);
    tasks.insert(0, t);
    notifyListeners();
    _runYoutube(t);
    return true;
  }

  bool startFile(String url, Directory dir, {required String title, int? number}) {
    if (_dup(url, dir, null, false)) return false;
    final t = DlTask(_next++, url, dir, title, 'ملف', number: number);
    tasks.insert(0, t);
    notifyListeners();
    _runFile(t);
    return true;
  }

  void cancel(DlTask t) {
    if (t.active) t.cancelRequested = true;
  }

  void retry(DlTask t) {
    tasks.remove(t);
    if (t.quality != null || t.audio) {
      _retryYoutube(t);
    } else {
      startFile(t.url, t.dir, title: t.title, number: t.number);
    }
  }

  void _retryYoutube(DlTask t) {
    final nt = DlTask(_next++, t.url, t.dir, t.title, t.label, quality: t.quality, audio: t.audio, number: t.number);
    tasks.insert(0, nt);
    notifyListeners();
    _runYoutube(nt);
  }

  void remove(DlTask t) {
    if (t.active) return;
    tasks.remove(t);
    notifyListeners();
  }

  void clearFinished() {
    tasks.removeWhere((t) => !t.active);
    notifyListeners();
  }

  File _finalTarget(DlTask t, String title, String ext) {
    final safe = safeName(title);
    var f = File('${t.dir.path}/${numberedName(t.number, safe, ext)}');
    for (var n = 2; f.existsSync(); n++) {
      f = File('${t.dir.path}/${numberedName(t.number, '$safe ($n)', ext)}');
    }
    return f;
  }

  Future<void> _runYoutube(DlTask t) async {
    final yt = YoutubeExplode();
    IOSink? sink;
    File? part;
    try {
      final id = VideoId(t.url);
      final m = await yt.videos.streamsClient.getManifest(id);
      if (t.cancelRequested) throw _Cancelled();
      StreamInfo info;
      String ext;
      if (t.audio) {
        final a = m.audioOnly.withHighestBitrate();
        info = a;
        ext = a.container.name == 'mp4' ? '.m4a' : '.${a.container.name}';
      } else {
        final cands = m.muxed.where((s) => s.videoQualityLabel == t.quality).toList();
        if (cands.isEmpty) throw Exception('الجودة ${t.quality} لم تعد متاحة');
        cands.sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
        info = cands.first;
        ext = '.${info.container.name}';
      }
      t.total = info.size.totalBytes;
      t.state = DlState.running;
      notifyListeners();
      part = File('${t.dir.path}/.${t.id}.part');
      sink = part.openWrite();
      final clock = Stopwatch()..start();
      await for (final chunk in yt.videos.streamsClient.get(info)) {
        if (t.cancelRequested) throw _Cancelled();
        sink.add(chunk);
        t.got += chunk.length;
        if (clock.elapsedMilliseconds > 250) {
          clock.reset();
          notifyListeners();
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      final target = _finalTarget(t, t.title, ext);
      await part.rename(target.path);
      t.resultPath = target.path;
      t.state = DlState.done;
    } on _Cancelled {
      t.state = DlState.cancelled;
      await _cleanup(sink, part);
    } catch (e) {
      t.state = DlState.failed;
      t.error = _msg(e);
      await _cleanup(sink, part);
    } finally {
      yt.close();
      notifyListeners();
    }
  }

  Future<void> _runFile(DlTask t) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    IOSink? sink;
    File? part;
    try {
      var u = Uri.parse(t.url);
      HttpClientResponse? res;
      for (var hop = 0; hop < 6; hop++) {
        final req = await client.getUrl(u);
        req.followRedirects = false;
        req.headers.set('User-Agent', _ua);
        if (isMoodleHost(u.host)) {
          final ck = await cookiesFor(u.toString());
          if (ck.isNotEmpty) req.headers.set('Cookie', ck);
        }
        res = await req.close();
        if (res.isRedirect) {
          final loc = res.headers.value('location');
          await res.drain<void>();
          if (loc == null) throw Exception('توجيه بلا عنوان');
          u = u.resolve(loc);
          continue;
        }
        break;
      }
      if (res == null || res.statusCode != 200) {
        throw Exception('HTTP ${res?.statusCode}');
      }
      final ct = res.headers.contentType?.mimeType ?? '';
      if (ct == 'text/html') {
        throw Exception('الرابط يفتح صفحة وليس ملفاً (سجّل الدخول إلى مودل من «استيراد» ثم أعد المحاولة)');
      }
      if (t.cancelRequested) throw _Cancelled();
      // Name: the item title, extension from the server name or the link
      var ext = extOf(Uri.decodeComponent(u.path));
      final cd = res.headers.value('content-disposition') ?? '';
      final fn = RegExp(r'filename\*?=(?:UTF-8\x27\x27)?"?([^";]+)"?', caseSensitive: false).firstMatch(cd)?.group(1);
      if (fn != null && extOf(Uri.decodeComponent(fn)).isNotEmpty) ext = extOf(Uri.decodeComponent(fn));
      if (ext.isEmpty) ext = _extFromMime(ct);
      t.total = res.contentLength > 0 ? res.contentLength : 0;
      t.state = DlState.running;
      notifyListeners();
      part = File('${t.dir.path}/.${t.id}.part');
      sink = part.openWrite();
      final clock = Stopwatch()..start();
      await for (final chunk in res) {
        if (t.cancelRequested) throw _Cancelled();
        sink.add(chunk);
        t.got += chunk.length;
        if (clock.elapsedMilliseconds > 250) {
          clock.reset();
          notifyListeners();
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      final target = _finalTarget(t, t.title, ext.isEmpty ? '' : '.$ext');
      await part.rename(target.path);
      t.resultPath = target.path;
      t.state = DlState.done;
    } on _Cancelled {
      t.state = DlState.cancelled;
      await _cleanup(sink, part);
    } catch (e) {
      t.state = DlState.failed;
      t.error = _msg(e);
      await _cleanup(sink, part);
    } finally {
      client.close(force: true);
      notifyListeners();
    }
  }

  Future<void> _cleanup(IOSink? sink, File? part) async {
    try {
      await sink?.close();
    } catch (_) {}
    try {
      if (part != null && part.existsSync()) await part.delete();
    } catch (_) {}
  }

  String _msg(Object e) {
    final s = '$e'.replaceFirst('Exception: ', '');
    return s.length > 160 ? s.substring(0, 160) : s;
  }
}

String _extFromMime(String m) {
  switch (m) {
    case 'application/pdf':
      return 'pdf';
    case 'video/mp4':
      return 'mp4';
    case 'video/webm':
      return 'webm';
    case 'application/zip':
      return 'zip';
    case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      return 'pptx';
    case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      return 'docx';
    case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
      return 'xlsx';
    default:
      return '';
  }
}

final downloads = DownloadManager();
