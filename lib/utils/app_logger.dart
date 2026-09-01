import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Flutter 端日志工具类
///
/// 与 Rust 端共用同一日志目录，文件名使用 "flutter" 前缀以区分
class AppLogger {
  static AppLogger? _instance;
  static Logger? _logger;
  static AdvancedFileOutput? _fileOutput;

  AppLogger._();

  /// 获取单例实例
  static AppLogger get instance {
    _instance ??= AppLogger._();
    return _instance!;
  }

  /// 获取 Logger 实例 (未显式 init 时默认 fallback 控制台 Logger，保证测试与早期调用安全)
  static Logger get logger {
    _logger ??= Logger(
      filter: ProductionFilter(),
      printer: SimplePrinter(colors: false, printTime: true),
    );
    return _logger!;
  }

  /// 初始化测试环境日志 (单元测试专用)
  static void initForTest({Logger? testLogger}) {
    _logger =
        testLogger ??
        Logger(
          filter: ProductionFilter(),
          printer: SimplePrinter(colors: false),
        );
  }

  /// 获取移动端日志保存目录
  static Future<String> getLogDir() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final logDir = Directory(path.join(appDocDir.path, 'logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    return logDir.path;
  }

  /// 初始化日志系统
  ///
  /// [level] 日志级别，默认自适应：Debug 模式下为 Level.debug，Release 模式下为 Level.info
  /// [logDir] 日志目录，默认使用 getLogDir()（移动端应用文档目录中的 logs 文件夹）
  static Future<void> init({Level? level, String? logDir}) async {
    if (_logger != null) {
      return; // 已初始化，跳过
    }

    final dir = logDir ?? await getLogDir();

    _fileOutput = AdvancedFileOutput(
      path: dir,
      maxFileSizeKB: 128, // 单文件最大 128KB
      maxRotatedFilesCount: 5, // 保留最近 5 个日志文件
      latestFileName: kDebugMode
          ? 'flutter_debug.log'
          : 'flutter.log', // 当前日志文件名
      writeImmediately: [Level.error, Level.fatal], // error 和 fatal 立即写入
    );

    final activeLevel = level ?? (kDebugMode ? Level.debug : Level.info);

    _logger = Logger(
      filter: ProductionFilter(), // 生产环境也输出日志
      printer: SimplePrinter(
        colors: false, // 文件日志不需要颜色
        printTime: true,
      ),
      output: MultiOutput([
        ConsoleOutput(), // 同时输出到控制台
        _fileOutput!,
      ]),
      level: activeLevel,
    );

    _logger!.i('Flutter Logger initialized at: $dir');
  }

  /// 关闭日志系统，确保缓冲区写入
  static Future<void> close() async {
    await _fileOutput?.destroy();
    _fileOutput = null;
    _logger = null;
  }

  // trace
  static void t(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    logger.t(message, error: error, stackTrace: stackTrace);
  }

  // debug
  static void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    logger.d(message, error: error, stackTrace: stackTrace);
  }

  // info
  static void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    logger.i(message, error: error, stackTrace: stackTrace);
  }

  // warning
  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// error
  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    logger.e(message, error: error, stackTrace: stackTrace);
  }

  // fatal
  static void f(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    logger.f(message, error: error, stackTrace: stackTrace);
  }
}
