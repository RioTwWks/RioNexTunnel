import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_log_level.dart';

class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.redacted = false,
  });

  final String timestamp;
  final String level;
  final String message;
  final bool redacted;

  String get displayLine =>
      '$timestamp [$level] ${redacted ? '[REDACTED] ' : ''}$message';
}

/// Append-only app logs. Never write session credentials.
class AppLog {
  AppLog._();

  static const _maxBytes = 2 * 1024 * 1024;
  static IOSink? _sink;
  static File? _file;
  static Future<void> _chain = Future<void>.value();
  static AppLogLevel _minimumLevel = AppLogLevel.info;

  static AppLogLevel get minimumLevel => _minimumLevel;

  static void setMinimumLevel(AppLogLevel level) => _minimumLevel = level;

  static Future<String?> logDirectoryPath() async {
    try {
      return (await _ensureDir()).path;
    } catch (_) {
      return null;
    }
  }

  static void info(String message) => _write('INFO', message);

  static void warn(String message) => _write('WARN', message);

  static void error(String message) => _write('ERROR', message);

  static void debug(String message) {
    if (_minimumLevel.includesDebug()) {
      _write('DEBUG', message);
    }
  }

  static Future<List<AppLogEntry>> readRecentLines({
    int maxLines = 500,
    bool includeDebug = false,
  }) async {
    try {
      final file = await _ensureFile();
      if (!await file.exists()) {
        return const [];
      }
      final lines = (await file.readAsString())
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
      final tail = lines.length <= maxLines
          ? lines
          : lines.sublist(lines.length - maxLines);
      final entries = <AppLogEntry>[];
      for (final line in tail) {
        final entry = _parseLine(line);
        if (entry == null) {
          continue;
        }
        if (!includeDebug && entry.level == 'DEBUG') {
          continue;
        }
        entries.add(entry);
      }
      return entries;
    } catch (e) {
      debugPrint('[AppLog] read failed: $e');
      return const [];
    }
  }

  static AppLogEntry? _parseLine(String line) {
    final match = RegExp(
      r'^(\S+)\s+\[(\w+)\]\s*(.*)$',
    ).firstMatch(line.trim());
    if (match == null) {
      final scrubbed = scrubMessage(line);
      return AppLogEntry(
        timestamp: '',
        level: 'INFO',
        message: scrubbed.message,
        redacted: scrubbed.redacted,
      );
    }
    final scrubbed = scrubMessage(match.group(3) ?? '');
    return AppLogEntry(
      timestamp: match.group(1) ?? '',
      level: match.group(2) ?? 'INFO',
      message: scrubbed.message,
      redacted: scrubbed.redacted,
    );
  }

  static ({String message, bool redacted}) scrubMessage(String message) {
    if (_looksLikeCredentialLeak(message)) {
      return (message: 'credential field redacted', redacted: true);
    }
    return (message: message, redacted: false);
  }

  static void _write(String level, String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (level == 'DEBUG' && !_minimumLevel.includesDebug()) {
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
        lower.contains('device_token') ||
        (lower.contains('accounts') && lower.contains('user'));
  }
}
