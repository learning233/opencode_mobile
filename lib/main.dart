import 'package:flutter/material.dart';
import 'app.dart';
import 'init.dart';
import 'utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 保持串行（AppLogger 先于 Global）：AppLogger 未完成 init 前任何
  // AppLogger.x 都会抛 StateError（logger getter 的未初始化守卫），而
  // Global.init 里 unawaited 的 Rust 初始化失败兜底与图片缓存清理失败
  // 兜底都会调 AppLogger.e——并行启动会把这两条失败路径变成启动期
  // 未处理异常。省一次 platform-channel 往返不值得冒这个险。
  await AppLogger.init();
  await Global.init();
  runApp(const OpenCodeApp());
}
