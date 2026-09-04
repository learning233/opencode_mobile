import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kterm/kterm.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class PtySession {
  final String id;
  final String title;
  final String directory;
  final Terminal terminal;
  final TerminalController controller;
  final FocusNode focusNode;
  WebSocketChannel? channel;
  final RxBool connected;
  final RxBool error = false.obs;
  final RxString errorMsg = ''.obs;
  Timer? resizeTimer;
  StreamSubscription? streamSub;
  int autoReconnectCount = 0;
  Timer? autoReconnectTimer;
  bool endedByShell = false;

  PtySession({
    required this.id,
    required this.title,
    required this.directory,
    required this.terminal,
    required this.controller,
    required this.focusNode,
    required this.connected,
    this.channel,
  });

  void sendInput(String input) {
    if (connected.value && channel != null) {
      try {
        channel!.sink.add(input);
      } catch (_) {}
    }
  }

  void dispose() {
    autoReconnectTimer?.cancel();
    autoReconnectTimer = null;
    focusNode.dispose();
    controller.dispose();
    resizeTimer?.cancel();
    resizeTimer = null;
    // 取消 WS 订阅，避免 dispose 后在途帧写入已销毁的 Terminal。
    streamSub?.cancel();
    streamSub = null;
    try {
      channel?.sink.close();
    } catch (_) {}
  }
}
