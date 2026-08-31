import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart' show DioException;
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
import '../utils/snackbar_utils.dart';
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

  Worker? _projectWorker;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    try {
      if (Get.isRegistered<ProjectController>()) {
        _projectWorker = ever(Get.find<ProjectController>().activeProject, (
          project,
        ) {
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
          unawaited(
            reconnectPty(session).catchError((Object e) {
              AppLogger.w('PTY resume-reconnect failed (${session.id}): $e');
            }),
          );
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

        // 收集需要新 attach 的会话 id（保持服务端返回顺序并去重）。
        final attachIds = <String>[];
        for (final item in list) {
          if (item is Map) {
            final id =
                item['id']?.toString() ?? item['ptyID']?.toString() ?? '';
            final status = item['status']?.toString();
            if (id.isNotEmpty &&
                status != 'exited' &&
                !attachIds.contains(id) &&
                !sessions.any((s) => s.id == id)) {
              attachIds.add(id);
            }
          }
        }
        if (seq != _fetchSeq) return;

        // 并行 attach：每个终端的恢复 = 1 次 ticket POST + WS 握手，串行时
        // N 个终端总时长线性叠加。并行发起、完成后按 seq 统一清理 —— 保持
        // 与原串行实现相同的代际语义：attach 期间被更新的 fetch 接管（seq
        // 变化）时，移除本次新增的会话对象，避免旧目录幽灵终端残留（更新的
        // fetch 只清理其同目录会话，覆盖不到这里）。只移除本次返回的实例，
        // 避免按 id 查询误删新 fetch 刚加入的会话。
        // 标题编号先经 _ptyTitleBase 串行预留，避免并行计数撞号。
        final addedList = <PtySession?>[];
        if (attachIds.isNotEmpty) {
          final titleBase = _ptyTitleBase(directory);
          addedList.addAll(
            await Future.wait(
              attachIds.asMap().entries.map((entry) async {
                try {
                  return await _attachToSession(
                    entry.value,
                    directory: directory,
                    activate: false,
                    customTitle:
                        '${titleBase.projectName} '
                        '${titleBase.existingCount + entry.key + 1}',
                  );
                } catch (e) {
                  AppLogger.w(
                    'PTY parallel attach failed (${entry.value}): '
                    '${maskIpsInText('$e')}',
                  );
                  return null;
                }
              }),
            ),
          );
        }
        if (seq != _fetchSeq) {
          for (final added in addedList) {
            if (added != null) {
              added.dispose();
              sessions.remove(added);
            }
          }
          return;
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

  /// 终端标题基础名与现有同目录会话数（用于编号）。提取为独立方法以便并行
  /// attach 前先串行统一预留编号：sessions.add 发生在握手之后，若各 attach
  /// 各自计数，并行时会拿到相同编号导致标题重复。
  ({String projectName, int existingCount}) _ptyTitleBase(String directory) {
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
    return (projectName: projectName, existingCount: sameProjectCount);
  }

  Future<PtySession?> _attachToSession(
    String ptyId, {
    required String directory,
    String? customTitle,
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
      // 凭据失败（401/403）：全局 unauthorized 提示已由 dio 拦截器触发
      // （OpenCodeApp 消费），这里终止 attach，不再对错误凭据盲目建连重试。
      final code = e is DioException ? e.response?.statusCode : null;
      if (code == 401 || code == 403) {
        AppLogger.w('PTY ticket auth failed ($ptyId): $code');
        return null;
      }
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
      // 心跳：移动网络下 NAT/防火墙会静默回收空闲 TCP，无 ping 的死连接上
      // 输入会静默丢失且 UI 毫无感知（connected 仍为 true）。pong 超时后库
      // 会以 goingAway 关闭连接，触发 onError/onDone 走错误视图 + 自动重连。
      // （web_socket_channel 默认 pingInterval 为 null，即禁用心跳。）
      pingInterval: const Duration(seconds: 20),
      // 握手超时由库内直接中止整个连接（含 TCP），避免仅靠外层 ready.timeout
      // 时底层握手仍挂在后台。
      connectTimeout: const Duration(seconds: 10),
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
      final base = _ptyTitleBase(directory);
      title = '${base.projectName} ${base.existingCount + 1}';
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
            // 中止被超时抛弃的连接：不取消订阅的话，晚到完成的握手会让服务端
            // 回放数据继续写入错误视图下的 Terminal，socket 与远端 PTY 也长期悬挂。
            unawaited(session?._streamSub?.cancel());
            session?._streamSub = null;
            try {
              channel.sink.close();
            } catch (_) {}
            final s = session;
            if (s != null) {
              s.error.value = true;
              s.errorMsg.value = LocaleKeys.terminalConnectionTimeout.tr;
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
            s.errorMsg.value = LocaleKeys.terminalConnectionLost.tr;
            _scheduleAutoReconnect(s);
          }
        });

    session._streamSub = channel.stream.listen(
      (data) {
        if (data != null) {
          if (data is List<int>) {
            final bytes = data;
            if (bytes.isNotEmpty && bytes[0] == 0) {
              // 0x00 前缀为 WS 控制帧（协议保留通道，见 core/src/pty/protocol.ts），
              // 不渲染到终端输出。
              return;
            }
            // allowMalformed：防御性兜底，避免个别字节损坏抛 FormatException
            // 打断整帧输出（onData 内异常不会进入本订阅的 onError）。
            final text = utf8.decode(bytes, allowMalformed: true);
            if (text.isNotEmpty) {
              session?.terminal.write(text);
            }
            return;
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
          s.errorMsg.value = LocaleKeys.terminalConnectionLost.tr;
          _scheduleAutoReconnect(s);
        }
      },
      onDone: () {
        AppLogger.i(
          'PTY WebSocket closed ($ptyId, closeCode: ${channel.closeCode})',
        );
        connected.value = false;
        // 关闭也要进入错误视图，否则 UI 停在无限转圈、无重试入口。
        // 后端关闭语义（已对照源码 packages/opencode/src/server/routes/instance/
        // httpapi/handlers/pty.ts + websocket-tracker.ts）：
        //   1000 = shell 进程退出（onEnd）；4404 = 会话不存在/已退出
        //     （Pty.NotFoundError / Pty.ExitedError）—— 两者均判定"会话已结束"，
        //     重连无意义，不调度自动重连；
        //   1001 = server closing（服务端关闭/连接数上限）；其余 code 与无
        //     close frame（null，TCP 异常断开）—— 网络问题，走自动重连，
        //     避免被误判"会话已结束"并永久熔断重连。
        // 若此前已因网络错误置 error，保留"连接失败"文案并继续重连调度。
        final code = channel.closeCode;
        final terminalClose = code == 1000 || code == 4404;
        final s = session;
        if (s != null) {
          if (!s.error.value && terminalClose) {
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
    // 计算激活项回退目标：按对象引用捕获原过滤列表中被关闭项的前一个
    // 存活会话（首项则取后一个，与原 (filteredIdx - 1).clamp 语义一致）。
    // 不能记索引——下面的 DELETE await（最长 5s）期间列表可能被
    // fetchSessions 的 stale 清理 / 并行 attach 代际清理并发修改。
    final filteredList = filteredSessions;
    final filteredIdx = filteredList.indexWhere((s) => s.id == ptyId);
    PtySession? fallbackTab;
    if (filteredIdx != -1) {
      final prevIdx = filteredIdx - 1;
      fallbackTab = prevIdx >= 0
          ? filteredList[prevIdx]
          : (filteredIdx + 1 < filteredList.length
                ? filteredList[filteredIdx + 1]
                : null);
    }

    // 先删远端再移除本地：DELETE 失败时远端 PTY 仍在运行，若先删本地，
    // 下次 fetchSessions 会把它当存活项重新 attach，已关闭的终端"复活"。
    // 超时兜底 5s：dio 默认 receiveTimeout 60s，会拖住关闭动作。
    var deleted = false;
    try {
      await _client
          .delete(ApiEndpoints.ptyDetailV2(ptyId), directory: session.directory)
          .timeout(const Duration(seconds: 5));
      deleted = true;
    } catch (e) {
      AppLogger.w('PTY delete failed ($ptyId): ${maskIpsInText('$e')}');
    }

    if (!deleted) {
      Snack.error(LocaleKeys.terminalDeleteFailed.tr, title: session.title);
      return;
    }

    // await 期间本会话可能已被 fetchSessions 的 stale 清理 dispose+移除
    // （DELETE 成功会让下一次列表刷新把它判为已删）：以对象身份复查，
    // 避免二次 dispose 与按过期索引误删相邻会话。
    if (!sessions.contains(session)) return;
    session.dispose();
    sessions.remove(session);

    final list = filteredSessions;
    final candidate = (fallbackTab != null && list.contains(fallbackTab))
        ? fallbackTab
        : list.firstOrNull;
    activePtyId.value = candidate?.id ?? '';
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
        unawaited(
          reconnectPty(session).catchError((Object e) {
            AppLogger.w('PTY auto-reconnect failed (${session.id}): $e');
          }),
        );
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
      // 需要后端全量回放历史输出以还原终端画面。
      // activate: false——后台终端自动重连成功时不得把用户正在查看的其他页签
      // 切走；重连自身会话时 activePtyId 本就指向它，无需置位。
      final newSession = await _attachToSession(
        id,
        directory: directory,
        customTitle: oldTitle,
        activate: false,
      );
      if (newSession == null) {
        // attach 被终止（如凭据失败 401/403）：保留旧会话的错误视图供手动重试。
        return;
      }
      // 携带旧会话的重试计数，让 autoReconnectCount>=3 的上限跨会话生效，
      // 避免每次重连新建 count=0 会话导致无限重试。
      newSession.autoReconnectCount = session.autoReconnectCount;
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
    _projectWorker?.dispose();
    for (final s in sessions) {
      s.dispose();
    }
    super.onClose();
  }
}
