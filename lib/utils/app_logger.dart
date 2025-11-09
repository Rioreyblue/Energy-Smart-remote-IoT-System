import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Centralized logging utility for the EnergySmart app.
///
/// Automatically disables logs in release mode and provides
/// structured logging with context information.
class AppLogger {
  static final Logger _logger = Logger(
    printer: _AppLogPrinter(),
    level: kDebugMode ? Level.trace : Level.warning,
  );

  /// Log an info message (i)
  static void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message (w)
  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log an error message (e)
  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log a debug message (d)
  static void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log a verbose/trace message (v)
  static void v(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }
}

/// Custom log printer that adds formatting and context
class _AppLogPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final color = _getColorForLevel(event.level);
    final emoji = _getEmojiForLevel(event.level);
    final level = event.level.name.toUpperCase();

    final message = event.message;
    final timestamp = DateTime.now().toString().substring(11, 19);

    final lines = <String>[];
    lines.add('$emoji [$timestamp] [$level] $message');

    if (event.error != null) {
      lines.add('  Error: ${event.error}');
    }

    if (event.stackTrace != null) {
      lines.add('  ${event.stackTrace}');
    }

    return lines
        .map((line) => color != null ? color(line) ?? line : line)
        .toList();
  }

  String? Function(String)? _getColorForLevel(Level level) {
    switch (level) {
      case Level.trace:
      case Level.debug:
        return (message) => '\x1B[36m$message\x1B[0m'; // Cyan
      case Level.info:
        return (message) => '\x1B[32m$message\x1B[0m'; // Green
      case Level.warning:
        return (message) => '\x1B[33m$message\x1B[0m'; // Yellow
      case Level.error:
      case Level.fatal:
        return (message) => '\x1B[31m$message\x1B[0m'; // Red
      default:
        return (message) => message;
    }
  }

  String _getEmojiForLevel(Level level) {
    switch (level) {
      case Level.trace:
      case Level.debug:
        return '🔍';
      case Level.info:
        return 'ℹ️';
      case Level.warning:
        return '⚠️';
      case Level.error:
      case Level.fatal:
        return '❌';
      default:
        return '📝';
    }
  }
}
