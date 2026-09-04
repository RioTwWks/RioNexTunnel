import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Append-only app logs. Never write session credentials.
class AppLog {
  AppLog._();

  static const _maxBytes = 2 * 1024 * 1024;
  static IOSink? _sink;
  static File? _file;
  static Future<void> _chain = Future<void>.value();

  static Future<String?> logDirectoryPath() async {
    try {
      final dir = await _ensureDir();
      return dir.path;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> logFilePath() async {
    try {
      final file = await _ensureFile();
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static void info(String message) => _write('INFO', message);

  static void warn(String message) => _write('WARN', message);

  static void error(String message) => _write('ERROR', message);

  static void _write(String level, String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (_looksLikeCredentialLeak(trimmed)) {
      debugPrint('[AppLog] skipped possible credential leak');
      return;
    }

    final line =
        '${DateTime.now().toIso8601String()} [$level] $trimmed';
    debugPrint(line);

    _chain = _chain.then((_) => _append(line));
  }

  static Future<void> _append(String line) async {
    try {
      final file = await _ensureFile();
      if (await file.exists() && await file.length() > _maxBytes) {
        final backup = File('${file.path}.1');
        if (await backup.exists()) {
          await backup.delete();
        }
        await file.rename(backup.path);
        _sink?.close();
        _sink = null;
        _file = File(file.path);
      }
      final sink = _sink ??= (await _ensureFile()).openWrite(mode: FileMode.append);
      sink.writeln(line);
      await sink.flush();
    } catch (e) {
      debugPrint('[AppLog] write failed: $e');
    }
  }

  static Future<Directory> _ensureDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/logs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _ensureFile() async {
    if (_file != null) {
      return _file!;
    }
    final dir = await _ensureDir();
    _file = File('${dir.path}/app.log');
    return _file!;
  }

  static bool _looksLikeCredentialLeak(String message) {
    final lower = message.toLowerCase();
    return lower.contains('"pass"') ||
        lower.contains('"password"') ||
        lower.contains('sockspassword') ||
        (lower.contains('accounts') && lower.contains('user'));
  }
}
