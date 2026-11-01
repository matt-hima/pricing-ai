import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../site_model.dart';
import 'zip_export.dart';

const canDeploy = true;

/// 以使用者本機的 Firebase CLI 部署。GUI 程式的 PATH 通常不含 npm 的全域目錄，
/// 所以 macOS 用登入 shell 執行，Windows 用 cmd。
Future<Process> _start(String command, {String? cwd}) {
  if (Platform.isWindows) return Process.start('cmd', ['/c', command], workingDirectory: cwd, runInShell: false);
  return Process.start('/bin/zsh', ['-lc', command], workingDirectory: cwd);
}

Stream<String> _run(String command, {String? cwd}) async* {
  final p = await _start(command, cwd: cwd);
  final out = StreamController<String>();
  var open = 2;
  void pipe(Stream<List<int>> s) => s.transform(utf8.decoder).transform(const LineSplitter()).listen(out.add, onDone: () {
        if (--open == 0) out.close();
      });
  pipe(p.stdout);
  pipe(p.stderr);
  yield* out.stream;
  final code = await p.exitCode;
  if (code != 0) throw Exception('exit code $code');
}

/// 檢查 CLI 是否可用，並開啟瀏覽器登入（Google）
Stream<String> loginFirebase() async* {
  try {
    yield* _run('firebase --version');
  } catch (_) {
    throw Exception('Firebase CLI not found. Install Node.js, then run: npm install -g firebase-tools');
  }
  yield* _run('firebase login');
}

Stream<String> deploySite(String html, {required String project, String hostingSite = '', String url = ''}) async* {
  if (!firebaseIdRe.hasMatch(project)) throw Exception('Invalid Firebase project ID.');
  if (hostingSite.isNotEmpty && !firebaseIdRe.hasMatch(hostingSite)) throw Exception('Invalid Hosting site ID.');
  try {
    await _run('firebase --version').drain<void>();
  } catch (_) {
    throw Exception('Firebase CLI not found. Install Node.js, then run: npm install -g firebase-tools');
  }
  final dir = await Directory.systemTemp.createTemp('site_builder_');
  try {
    yield 'Preparing files…';
    await Directory('${dir.path}/public').create();
    await File('${dir.path}/public/index.html').writeAsString(html);
    for (final e in seoFiles(url.isEmpty ? 'https://${hostingSite.isEmpty ? project : hostingSite}.web.app/' : url).entries) {
      await File('${dir.path}/${e.key}').writeAsString(e.value);
    }
    await File('${dir.path}/firebase.json').writeAsString(firebaseJson(site: hostingSite));
    yield* _run('firebase deploy --only hosting --project $project --non-interactive', cwd: dir.path);
    yield 'Done: https://${hostingSite.isEmpty ? project : hostingSite}.web.app';
  } finally {
    unawaited(dir.delete(recursive: true).catchError((_) => dir));
  }
}
