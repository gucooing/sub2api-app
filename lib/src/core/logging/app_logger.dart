import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 一条日志记录。
@immutable
class LogEntry {
  const LogEntry({required this.time, required this.level, required this.message});

  final DateTime time;
  final String level; // error / warn / info
  final String message;

  Map<String, dynamic> toJson() => {
        't': time.toIso8601String(),
        'l': level,
        'm': message,
      };

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        time: DateTime.tryParse(j['t'] as String? ?? '') ?? DateTime(1970),
        level: j['l'] as String? ?? 'info',
        message: j['m'] as String? ?? '',
      );
}

/// 应用日志:记录异常/错误,写入前对敏感数据脱敏;内存环形缓冲 + 文件持久化。
///
/// - 单例,经 [init] 在启动期装配(读回历史 + 准备文件)。
/// - [FlutterError]/[PlatformDispatcher] 与网络层错误统一汇入此处。
/// - 支持导出(读全部文本)与清空。
class AppLogger extends ChangeNotifier {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int _maxEntries = 500;
  final List<LogEntry> _entries = [];
  File? _file;
  bool _ready = false;

  /// 最新在前的只读视图。
  List<LogEntry> get entries => _entries.reversed.toList(growable: false);

  Future<void> init() async {
    if (_ready) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/sub2api/logs');
      await logDir.create(recursive: true);
      _file = File('${logDir.path}/app.log');
      if (await _file!.exists()) {
        final lines = await _file!.readAsLines();
        for (final l in lines) {
          if (l.trim().isEmpty) continue;
          try {
            _entries.add(LogEntry.fromJson(
                jsonDecode(l) as Map<String, dynamic>));
          } catch (_) {}
        }
        if (_entries.length > _maxEntries) {
          _entries.removeRange(0, _entries.length - _maxEntries);
        }
      }
    } catch (_) {
      // 文件不可用时退化为纯内存日志。
    }
    _ready = true;
  }

  void error(String message, {Object? error, StackTrace? stack}) =>
      _add('error', _compose(message, error, stack));

  void warn(String message, {Object? error}) =>
      _add('warn', _compose(message, error, null));

  void info(String message) => _add('info', _compose(message, null, null));

  /// 捕获 Flutter 框架渲染等异常。
  void flutterError(FlutterErrorDetails details) =>
      _add('error', _compose(details.exceptionAsString(), null, details.stack));

  static String _compose(String message, Object? error, StackTrace? stack) {
    final b = StringBuffer(message);
    if (error != null) b.write('\n$error');
    if (stack != null) {
      // 仅保留前若干帧,避免日志膨胀。
      final frames = stack.toString().split('\n').take(12).join('\n');
      b.write('\n$frames');
    }
    return redact(b.toString());
  }

  void _add(String level, String message) {
    final entry = LogEntry(time: DateTime.now(), level: level, message: message);
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    // 异步追加,失败忽略(不阻塞调用方)。
    final f = _file;
    if (f != null) {
      f
          .writeAsString('${jsonEncode(entry.toJson())}\n',
              mode: FileMode.append, flush: false)
          .ignore();
    }
    notifyListeners();
  }

  Future<void> clear() async {
    _entries.clear();
    try {
      if (_file != null && await _file!.exists()) {
        await _file!.writeAsString('');
      }
    } catch (_) {}
    notifyListeners();
  }

  /// 导出为可粘贴的纯文本(最新在前)。
  String exportText() {
    final b = StringBuffer();
    for (final e in entries) {
      b.writeln('[${e.time.toIso8601String()}] ${e.level.toUpperCase()}');
      b.writeln(e.message);
      b.writeln('');
    }
    return b.toString();
  }

  /// 对常见敏感数据脱敏:Bearer 令牌、Authorization、各类 token/密码/密钥字段、
  /// sk- 形式密钥、邮箱本地部分。写入前调用。
  static String redact(String input) {
    var s = input;
    // Authorization: Bearer xxx / Bearer xxx
    s = s.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9._\-]+', caseSensitive: false),
      'Bearer ***',
    );
    // JSON / kv 形式的敏感字段值(Authorization 头交由上面的 Bearer 规则处理)
    s = s.replaceAll(
      RegExp(
        r'("?(?:access_token|refresh_token|password|api_key|apikey|token|secret|client_secret|turnstile_token)"?\s*[:=]\s*"?)([^",\s}]+)',
        caseSensitive: false,
      ),
      r'$1***',
    );
    // sk-... 形式的 API key
    s = s.replaceAll(RegExp(r'sk-[A-Za-z0-9._\-]{6,}'), 'sk-***');
    // 邮箱:保留首字符与域名
    s = s.replaceAllMapped(
      RegExp(r'([A-Za-z0-9])[A-Za-z0-9._%+\-]*(@[A-Za-z0-9.\-]+)'),
      (m) => '${m[1]}***${m[2]}',
    );
    return s;
  }
}
