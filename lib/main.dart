import 'package:flutter/material.dart';
import 'app.dart';
import 'init.dart';
import 'utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();
  await Global.init();
  runApp(const OpenCodeApp());
}
