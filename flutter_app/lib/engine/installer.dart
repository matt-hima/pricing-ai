import 'dart:io';

import 'package:archive/archive.dart';

import 'catalog.dart';

/// 把引擎壓縮檔解到 [dest]，保留相對路徑與符號連結（macOS 的 dylib 需要），並設定可執行權限。
Future<void> extractEngine(File archiveFile, ArchiveKind kind, Directory dest) async {
  final bytes = await archiveFile.readAsBytes();
  final Archive archive = switch (kind) {
    ArchiveKind.zip => ZipDecoder().decodeBytes(bytes),
    ArchiveKind.tarGz => TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes)),
  };
  await dest.create(recursive: true);
  final root = dest.absolute.path;
  for (final f in archive) {
    final rel = f.name.replaceAll('\\', '/');
    if (rel.isEmpty || rel.startsWith('/') || rel.split('/').contains('..')) continue; // 擋掉路徑穿越
    final target = '$root/$rel';
    if (f.isSymbolicLink) {
      final link = Link(target);
      await link.parent.create(recursive: true);
      if (await link.exists()) await link.delete();
      await link.create(f.symbolicLink ?? '');
    } else if (f.isFile) {
      final out = File(target);
      await out.parent.create(recursive: true);
      await out.writeAsBytes(f.content as List<int>, flush: true);
    } else {
      await Directory(target).create(recursive: true);
    }
  }
}

/// 在 [dir] 底下找 llama-server（或 llama-server.exe）
Future<File?> findServerBinary(Directory dir) async {
  if (!await dir.exists()) return null;
  final name = Platform.isWindows ? 'llama-server.exe' : 'llama-server';
  await for (final e in dir.list(recursive: true, followLinks: false)) {
    if (e is File && e.uri.pathSegments.last == name) return e;
  }
  return null;
}

/// 在 [dir] 底下找 stable-diffusion.cpp 的命令列程式（sd-cli 或舊版名稱 sd）
Future<File?> findSdBinary(Directory dir) async {
  if (!await dir.exists()) return null;
  final names = Platform.isWindows ? ['sd-cli.exe', 'sd.exe'] : ['sd-cli', 'sd'];
  File? found;
  await for (final e in dir.list(recursive: true, followLinks: false)) {
    if (e is File && names.contains(e.uri.pathSegments.last)) {
      if (found == null || names.indexOf(e.uri.pathSegments.last) < names.indexOf(found.uri.pathSegments.last)) found = e;
    }
  }
  return found;
}

Future<void> makeExecutable(File f) async {
  if (Platform.isWindows) return;
  await Process.run('chmod', ['+x', f.path]);
}
