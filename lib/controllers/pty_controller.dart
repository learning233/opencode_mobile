import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kterm/kterm.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api/endpoints.dart';
import '../api/opencode_client.dart';
import '../api/sidecar_manager.dart';
import '../controllers/project_controller.dart';
import '../init.dart';
import '../utils/app_logger.dart';
import '../utils/translations.dart';
import '../utils/url_utils.dart';

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
  String lastCursor = '';
  Timer? resizeTimer;
  StreamSubscription? _streamSub;
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
    _streamSub?.cancel();
    _streamSub = null;
    try {
      channel?.sink.close();
    } catch (_) {}
  }
}

class PtyController extends GetxController with WidgetsBindingObserver {
  final _client = OpenCodeClient();

  final RxList<PtySession> sessions = <PtySession>[].obs;
  final RxString activePtyId = ''.obs;
  late final RxBool filterCurrentProjectOnly =
      Global.ptyFilterCurrentProjectOnly.obs;
  final RxBool isCreating = false.obs;
  final RxBool isLoading = false.obs;
  // 正在重连的 pty id 集合：按 id 串行，不同会话可并发重连，同一 id 防重。
  final Set<String> _reconnectingIds = <String>{};

  int _fetchSeq = 0;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    try {
      if (Get.isRegistered<ProjectController>()) {
        ever(Get.find<ProjectController>().activeProject, (project) {
          if (project != null) {
            _onProjectChanged(project.worktree);
          }
        });
      }
    } catch (e) {
      AppLogger.w('Listen active project error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      for (final session in sessions) {
        if (!session.connected.value &&
            session.error.value &&
            !session.endedByShell) {
          session.autoReconnectCount = 0;
          session.autoReconnectTimer?.cancel();
          reconnectPty(session);
        }
      }
    }
  }

  void _onProjectChanged(String worktree) {
    final normWorktree = normalizeDirectory(worktree);
    if (normWorktree.isEmpty) return;

    final matchingSession = sessions.firstWhereOrNull(
      (s) => normalizeDirectory(s.directory) == normWorktree,
    );

    if (matchingSession != null) {
      activePtyId.value = matchingSession.id;
    } else {
      fetchSessions(customDirectory: worktree);
    }
  }

  void setFilterCurrentProjectOnly(bool val) {
    filterCurrentProjectOnly.value = val;
    Global.ptyFilterCurrentProjectOnly = val;
  }

  static String normalizeDirectory(String dir) {
    if (dir.isEmpty) return '';
    return dir.replaceAll('\\', '/').replaceAll(RegExp(r'/$'), '');
  }

  List<PtySession> get filteredSessions {
    if (!filterCurrentProjectOnly.value) {
      return sessions.toList();
    }
    final activeDir =
        Get.find<ProjectController>().activeProject.value?.worktree ?? '';
    if (activeDir.isEmpty) return sessions.toList();

    final activeNorm = normalizeDirectory(activeDir);
    return sessions.where((s) {
      final sessionNorm = normalizeDirectory(s.directory);
      return sessionNorm == activeNorm || sessionNorm.isEmpty;
    }).toList();
  }

  PtySession? get activeSession {
    final list = filteredSessions;
    if (list.isEmpty) return null;
    return list.firstWhereOrNull((s) => s.id == activePtyId.value) ??
        list.first;
  }

  void selectPty(String id) {
    activePtyId.value = id;
  }

  Future<void> fetchSessions({String? customDirectory}) async {
    // 请求序号：新请求会接管，旧请求的写回一律丢弃，避免项目切换时
    // 旧目录的结果覆盖新目录的会话状态。
    final seq = ++_fetchSeq;
    isLoading.value = true;
    try {
      final activeProject = Get.find<ProjectController>().activeProject.value;
      final rawDir = customDirectory ?? activeProject?.worktree ?? '';
      final directory = normalizeDirectory(rawDir);

      final resp = await _client.get(ApiEndpoints.ptyV2, directory: directory);

      if (seq != _fetchSeq) return;

      if (resp.statusCode == 200 && resp.data != null) {
        final rawData = resp.data;
        final List list = (rawData is Map && rawData['data'] is List)
            ? rawData['data'] as List
            : (rawData is List)
            ? rawData
            : [];

        // 收集本次目录下服务端仍存活的会话 id。
        final liveIds = <String>{};
        for (final item in list) {
          if (item is Map) {
            final id =
                item['id']?.toString() ?? item['ptyID']?.toString() ?? '';
            final status = item['status']?.toString();
            if (id.isNotEmpty && status != 'exited') {
              liveIds.add(id);
            }
          }
        }

        // 清理已 stale 的本地会话（服务端已退出/被删）。只清理与本次请求
        // 同目录的会话，避免误删其它目录的终端。
        if (directory.isNotEmpty) {
          final stale = sessions
              .where(
                (s) =>
                    normalizeDirectory(s.directory) == directory &&
                    !liveIds.contains(s.id),
              )
              .toList();
          for (final s in stale) {
            s.dispose();
            sessions.remove(s);
          }
        }

        for (final item in list) {
          if (seq != _fetchSeq) return;
          if (item is Map) {
            final id =
                item['id']?.toString() ?? item['ptyID']?.toString() ?? '';
            final status = item['status']?.toString();
            if (id.isNotEmpty && status != 'exited') {
              if (!sessions.any((s) => s.id == id)) {
                // 后端 list 按请求目录返回，会话 cwd 即该目录，直接复用。
                final added = await _attachToSession(
                  id,
                  directory: directory,
                  activate: false,
                );
                // attach 在 await 期间可能已被更新的 fetch 接管（seq 变化），
                // 若此时才完成，需移除刚追加的会话，避免旧目录幽灵终端残留
                // （更新的 fetch 只清理其同目录会话，覆盖不到这里）。
                // 只移除本次 add 的会话对象，避免并发 attach 同一 id 时
                // 按 id 查询误删新 fetch 刚加入的会话。
                if (seq != _fetchSeq && added != null) {
                  added.dispose();
                  sessions.remove(added);
                  return;
                }
              }
            }
          }
        }
      }

      if (seq != _fetchSeq) return;
      // 修正 activePtyId：首次加载为空、或清理 stale 后悬空时，指到首个存活会话。
      if (activePtyId.value.isEmpty ||
          !sessions.any((s) => s.id == activePtyId.value)) {
        final first = filteredSessions.firstOrNull;
        activePtyId.value = first?.id ?? '';
      }

      if (filteredSessions.isEmpty) {
        await createTerminal(customDirectory: customDirectory);
      }
    } catch (e) {
      AppLogger.w('Fetch PTY sessions error: $e');
    } finally {
      if (seq == _fetchSeq) {
        isLoading.value = false;
      }
    }
  }

  Future<PtySession?> _attachToSession(
    String ptyId, {
    required String directory,
    String? customTitle,
    String? initialCursor,
    // fetchSessions 批量 attach 时置 false，由 fetch 自身的 seq 保护逻辑
    // 统一决定 activePtyId，避免过期请求的 attach 覆盖当前激活项。
    bool activate = true,
  }) async {
    // 1. Fetch PTY ticket for connection
    String ticket = '';
    try {
      final ticketHeader = <String, String>{'x-opencode-ticket': '1'};
      final tokenResp = await _client.post(
        ApiEndpoints.ptyConnectTokenV2(ptyId),
        headers: ticketHeader,
        directory: directory,
      );

      if (tokenResp.statusCode == 200 || tokenResp.statusCode == 201) {
        final tokenData = tokenResp.data;
        ticket = (tokenData is Map && tokenData['data'] is Map)
            ? ((tokenData['data'] as Map)['ticket']?.toString() ?? '')
            : (tokenData is Map && tokenData.containsKey('ticket'))
            ? (tokenData['ticket']?.toString() ?? '')
            : '';
      }
    } catch (e) {
      AppLogger.w('Fetch ticket error ($ptyId): ${maskIpsInText('$e')}');
    }

    // 2. Connect WebSocket using normalized Uri & v2 endpoints
    final manager = SidecarManager.instance;
    final baseUri = Uri.parse(manager.baseUrl);
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';

    final basePath = baseUri.path.replaceAll(RegExp(r'/$'), '');
    final ptyPath = ApiEndpoints.ptyConnectV2(ptyId);
    final fullPath = '$basePath$ptyPath';

    final queryParams = <String, String>{
      if (directory.isNotEmpty) 'directory': directory,
      if (directory.isNotEmpty) 'location[directory]': directory,
      if (ticket.isNotEmpty) 'ticket': ticket,
      if (initialCursor != null && initialCursor.isNotEmpty)
        'cursor': initialCursor,
    };

    final wsUri = Uri(
      scheme: wsScheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: fullPath,
      queryParameters: queryParams,
    );

    final wsHeaders = <String, String>{};
    if (manager.password.isNotEmpty) {
      final token = base64Encode(
        utf8.encode('${manager.username}:${manager.password}'),
      );
      // 后端 authorization.ts 的 ticket 免鉴权正则只匹配 v1 路径
      // (/^\/pty\/[^/]+\/connect$/)，v2 /api/pty/{id}/connect 仍需 Basic Auth，
      // 因此这里必须显式携带 Authorization header。
      wsHeaders['Authorization'] = 'Basic $token';
    }

    final channel = IOWebSocketChannel.connect(
      wsUri,
      headers: wsHeaders.isNotEmpty ? wsHeaders : null,
    );

    final focusNode = FocusNode();
    // 连接状态唯一来源：onOutput/onResize 与 PtySession.connected 共用，
    // 由 channel.ready / onError / onDone 驱动，不再硬编码为 true。
    final connected = false.obs;
    final controller = TerminalController();

    // 会话对象稍后创建，先声明以便 resize 闭包引用。
    PtySession? session;

    // resize 事件高频触发，做 150ms 节流，避免拖动窗口时轰炸服务端。
    // timer 直接挂在 session.resizeTimer 上（session 稍后创建），
    // dispose 时统一取消，避免在途 timer 泄漏。
    final terminal = Terminal(
      maxLines: 3000,
      onOutput: (data) {
        if (connected.value) {
          try {
            channel.sink.add(data);
          } catch (_) {}
        }
      },
      onResize: (w, h, pw, ph) {
        session?.resizeTimer?.cancel();
        session?.resizeTimer = Timer(
          const Duration(milliseconds: 150),
          () async {
            if (!connected.value) return;
            try {
              await _client.put(
                ApiEndpoints.ptyDetailV2(ptyId),
                data: {
                  'size': {'rows': h, 'cols': w},
                },
                directory: directory,
              );
            } catch (e) {
              AppLogger.w('PTY resize error ($ptyId): $e');
            }
          },
        );
      },
    );

    controller.onGetText = () => terminal.buffer.getText();
    controller.onCreateAnchor = (offset) {
      return terminal.buffer.createAnchorFromOffset(offset);
    };

    String title = customTitle ?? '';
    if (title.isEmpty) {
      String projectName = LocaleKeys.terminalTitle.tr;
      try {
        final activeProject = Get.find<ProjectController>().activeProject.value;
        if (activeProject != null && activeProject.displayName.isNotEmpty) {
          projectName = activeProject.displayName;
        }
      } catch (_) {}

      if (projectName == LocaleKeys.terminalTitle.tr && directory.isNotEmpty) {
        final segs = directory.split('/').where((s) => s.isNotEmpty).toList();
        if (segs.isNotEmpty) {
          projectName = segs.last;
        }
      }
      final sameProjectCount = sessions.where((s) {
        final sNorm = normalizeDirectory(s.directory);
        if (directory.isNotEmpty && sNorm.isNotEmpty) {
          return sNorm == normalizeDirectory(directory);
        }
        return s.title.startsWith('$projectName ');
      }).length;
      final titleNum = sameProjectCount + 1;
      title = '$projectName $titleNum';
    }

    session = PtySession(
      id: ptyId,
      title: title,
      directory: directory,
      terminal: terminal,
      controller: controller,
      focusNode: focusNode,
      channel: channel,
      connected: connected,
    );

    // 握手成功后才标记已连接（避免 UI 短暂假连），失败则直接报错。
    // 握手超时兜底：服务端一直不响应 upgrade 时停留在连接中，UI 会无限转圈，
    // 超时后进入错误视图（带重试入口）。
    channel.ready
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            AppLogger.w('PTY WebSocket ready timeout ($ptyId)');
            connected.value = false;
            final s = session;
            if (s != null) {
              s.error.value = true;
              s.errorMsg.value = 'Connection timeout';
              _scheduleAutoReconnect(s);
            }
          },
        )
        .then((_) {
          // onTimeout 之后才完成的情况忽略，避免把已置错的会话翻回连接态。
          final s = session;
          if (s != null && !s.error.value) {
            connected.value = true;
            s.autoReconnectCount = 0;
            s.autoReconnectTimer?.cancel();
          }
        })
        .catchError((e) {
          AppLogger.w(
            'PTY WebSocket ready error ($ptyId): ${maskIpsInText('$e')}',
          );
          connected.value = false;
          final s = session;
          if (s != null) {
            s.error.value = true;
            s.errorMsg.value = 'Connection lost';
            _scheduleAutoReconnect(s);
          }
        });

    session._streamSub = channel.stream.listen(
      (data) {
        if (data != null) {
          if (data is List<int>) {
            final bytes = data;
            if (bytes.isNotEmpty && bytes[0] == 0) {
              // 0x00 prefix indicates a WS Control Frame (matches opencode-mobile)
              try {
                final text = utf8.decode(bytes.sublist(1));
                final map = jsonDecode(text);
                if (map is Map) {
                  final c = map['cursor'];
                  if (c != null) {
                    // 后端 metaFrame 为 { cursor: <number> }，保存用于重连续传。
                    session?.lastCursor = c.toString();
                  }
                }
              } catch (_) {}
              return; // Do NOT render control frame to terminal output
            } else {
              final text = utf8.decode(bytes);
              if (text.isNotEmpty) {
                session?.terminal.write(text);
              }
              return;
            }
          }

          if (data is String) {
            // 后端 v2 协议：String 帧是纯终端输出（replay 分块 / 实时数据），
            // 控制帧只以二进制 0x00 前缀发出（见 core/src/pty/protocol.ts）。
            // 不要在此做 JSON 探测，否则 `{"cursor":1}` 之类的合法终端输出会被吞掉。
            if (data.isNotEmpty) {
              session?.terminal.write(data);
            }
          }
        }
      },
      onError: (e) {
        AppLogger.e('PTY WebSocket error ($ptyId): ${maskIpsInText('$e')}');
        connected.value = false;
        final s = session;
        if (s != null) {
          s.error.value = true;
          s.errorMsg.value = 'Connection lost';
          _scheduleAutoReconnect(s);
        }
      },
      onDone: () {
        AppLogger.i('PTY WebSocket closed ($ptyId)');
        connected.value = false;
        // 优雅关闭（如进程 exit 后服务端发 CloseEvent）也要进入错误视图，
        // 否则 UI 停在无限转圈、无重试入口。但若此前已因网络错误置 error，
        // 保留"连接失败"文案，避免被"会话已结束"覆盖误导用户。
        final s = session;
        if (s != null) {
          if (!s.error.value) {
            s.endedByShell = true;
            s.error.value = true;
            s.errorMsg.value = LocaleKeys.terminalSessionEnded.tr;
          } else {
            _scheduleAutoReconnect(s);
          }
        }
      },
    );

    sessions.add(session);
    if (activate) {
      activePtyId.value = ptyId;
    }
    return session;
  }

  Future<void> createTerminal({String? customDirectory}) async {
    if (isCreating.value) return;
    isCreating.value = true;
    try {
      final activeProject = Get.find<ProjectController>().activeProject.value;
      final rawDir = customDirectory ?? activeProject?.worktree ?? '';
      final directory = normalizeDirectory(rawDir);

      // 后端 Pty.CreateInput schema 是 {command, args, cwd, title, env}，
      // 没有 directory 字段（目录靠 x-opencode-directory header 解析）。
      final createBody = <String, dynamic>{
        if (directory.isNotEmpty) 'cwd': directory,
      };

      // 1. Create PTY via v2 (/api/pty)
      dynamic createResp;
      try {
        createResp = await _client.post(
          ApiEndpoints.ptyV2,
          data: createBody,
          directory: directory,
        );
      } catch (e) {
        AppLogger.e(
          'POST ${ApiEndpoints.ptyV2} failed: ${maskIpsInText('$e')}',
        );
        return;
      }

      if (createResp == null ||
          (createResp.statusCode != 200 && createResp.statusCode != 201)) {
        AppLogger.e('Failed to create PTY (${createResp?.statusCode})');
        return;
      }
      final createData = createResp.data;
      final ptyInfo = (createData is Map && createData['data'] is Map)
          ? createData['data'] as Map
          : createData is Map
          ? createData
          : <String, dynamic>{};
      final ptyId =
          ptyInfo['id']?.toString() ?? ptyInfo['ptyID']?.toString() ?? '';
      if (ptyId.isEmpty) {
        AppLogger.e('No PTY ID returned');
        return;
      }

      await _attachToSession(ptyId, directory: directory);
    } catch (e) {
      AppLogger.e('Create PTY failed: ${maskIpsInText('$e')}');
    } finally {
      isCreating.value = false;
    }
  }

  Future<void> closeTerminal(String ptyId) async {
    final idx = sessions.indexWhere((s) => s.id == ptyId);
    if (idx == -1) return;

    final session = sessions[idx];
    // 计算在过滤列表中的位置，作为下一个激活项的依据（过滤开启时
    // filteredSessions 与 sessions 的索引/顺序不一致）。
    final filteredIdx = filteredSessions.indexWhere((s) => s.id == ptyId);
    session.dispose();
    sessions.removeAt(idx);

    try {
      await _client.delete(
        ApiEndpoints.ptyDetailV2(ptyId),
        directory: session.directory,
      );
    } catch (_) {}

    final list = filteredSessions;
    if (list.isNotEmpty) {
      final newIdx = (filteredIdx - 1).clamp(0, list.length - 1);
      activePtyId.value = list[newIdx].id;
    } else {
      activePtyId.value = '';
    }
  }

  void _scheduleAutoReconnect(PtySession session) {
    // 同一会话已有在途 timer 时不再叠加调度，避免 onError 与 onDone
    // 双触发导致计数虚增、重试次数少于预期。
    if (session.autoReconnectTimer?.isActive ?? false) return;
    if (session.endedByShell) return;
    if (session.autoReconnectCount >= 3) {
      AppLogger.w('PTY auto-reconnect max attempts reached (${session.id})');
      return;
    }
    session.autoReconnectCount++;
    final delaySeconds = 1 << (session.autoReconnectCount - 1);
    AppLogger.i(
      'Scheduling PTY auto-reconnect attempt ${session.autoReconnectCount} in ${delaySeconds}s (${session.id})',
    );

    session.autoReconnectTimer?.cancel();
    session.autoReconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!session.connected.value && sessions.contains(session)) {
        reconnectPty(session);
      }
    });
  }

  Future<void> reconnectPty(PtySession session) async {
    // 按 id 防重：同一会话快速连点/自动重试时避免并发 attach 产生重复会话；
    // 不同会话可以并发重连，互不阻塞。
    final id = session.id;
    if (_reconnectingIds.contains(id)) return;
    _reconnectingIds.add(id);
    session.autoReconnectTimer?.cancel();
    try {
      final directory = session.directory;
      final oldTitle = session.title;
      // 先不清空列表，避免重连期间（ticket POST 等网络往返）sessions 为空，
      // UI 闪现出"新建终端"空态页。旧会话保持显示错误视图，直到新会话入列后
      // 同一帧内再清理同 id 旧项（含重连失败残留的重复项），同时透传 oldTitle 避免标题编号自增。
      // 注意：重连时 _attachToSession 会创建全新的 Terminal 实例（缓冲区初始为空），
      // 故不能传 initialCursor/lastCursor，需要后端全量回放历史输出以还原终端画面。
      final newSession = await _attachToSession(
        id,
        directory: directory,
        customTitle: oldTitle,
      );
      // 携带旧会话的重试计数，让 autoReconnectCount>=3 的上限跨会话生效，
      // 避免每次重连新建 count=0 会话导致无限重试。
      newSession?.autoReconnectCount = session.autoReconnectCount;
      for (final old in sessions.where((s) => s.id == id).toList()) {
        if (!identical(old, newSession)) {
          old.dispose();
          sessions.remove(old);
        }
      }
    } finally {
      _reconnectingIds.remove(id);
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in sessions) {
      s.dispose();
    }
    super.onClose();
  }
}
