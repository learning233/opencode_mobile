import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/e2b/e2b.dart';
import 'package:opencode_app/init.dart';
import 'package:opencode_app/models/cloud_workspace_config.dart';
import 'package:opencode_app/models/e2b_sandbox_info.dart';
import 'package:opencode_app/services/e2b_workspace_service.dart';
import 'package:opencode_app/services/git_repo_service.dart';
import 'package:opencode_app/utils/app_logger.dart';
import 'package:opencode_app/utils/app_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  setUpAll(() async {
    await AppLogger.init(logDir: './build/test_logs');
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudWorkspaceConfig Tests', () {
    test('default values are set correctly', () {
      final config = CloudWorkspaceConfig();
      expect(config.e2bApiKey, '');
      expect(config.templateId, 'opencode');
      expect(config.toolchains, containsAll(['dart', 'rust']));
      expect(config.ttlHours, 2);
      expect(config.autoPause, true);
      expect(config.hasActiveSandbox, false);
    });

    test('serialization and deserialization roundtrip', () {
      final original = CloudWorkspaceConfig(
        e2bApiKey: 'test-api-key-123',
        templateId: 'custom-opencode',
        toolchains: ['dart', 'rust', 'c_cpp'],
        gitProvider: 'github',
        gitRepoUrl: 'https://github.com/test/repo.git',
        gitRepoFullName: 'test/repo',
        gitBranch: 'develop',
        gitToken: 'ghp_secret',
        gitUsername: 'dev_user',
        gitEmail: 'dev@test.com',
        ttlHours: 4,
        autoPause: false,
        activeSandboxId: 'sbx-998877',
        activeSandboxUrl: 'https://4096-sbx-998877.e2b.app',
        activeSandboxPassword: 'pass_secret_123',
        activeSandboxEnvdToken: 'envd_tok_abc',
        activeSandboxStatus: 'running',
        lastConnectedAt: DateTime(2026, 8, 31, 12, 0),
      );

      final serialized = original.serialize();
      final deserialized = CloudWorkspaceConfig.deserialize(serialized);

      expect(deserialized.e2bApiKey, original.e2bApiKey);
      expect(deserialized.templateId, original.templateId);
      expect(deserialized.toolchains, original.toolchains);
      expect(deserialized.gitProvider, original.gitProvider);
      expect(deserialized.gitRepoUrl, original.gitRepoUrl);
      expect(deserialized.gitRepoFullName, original.gitRepoFullName);
      expect(deserialized.gitBranch, original.gitBranch);
      expect(deserialized.gitToken, original.gitToken);
      expect(deserialized.gitUsername, original.gitUsername);
      expect(deserialized.gitEmail, original.gitEmail);
      expect(deserialized.ttlHours, original.ttlHours);
      expect(deserialized.autoPause, original.autoPause);
      expect(deserialized.activeSandboxId, original.activeSandboxId);
      expect(deserialized.activeSandboxUrl, original.activeSandboxUrl);
      expect(deserialized.activeSandboxPassword, original.activeSandboxPassword);
      expect(
        deserialized.activeSandboxEnvdToken,
        original.activeSandboxEnvdToken,
      );
      expect(deserialized.activeSandboxStatus, original.activeSandboxStatus);
      expect(deserialized.hasActiveSandbox, true);
    });

    test('copyWith works correctly with clearActiveSandbox', () {
      final config = CloudWorkspaceConfig(
        activeSandboxId: 'sbx-1',
        activeSandboxUrl: 'https://4096-sbx-1.e2b.app',
        activeSandboxPassword: 'pwd',
        activeSandboxEnvdToken: 'tok-1',
        activeSandboxStatus: 'running',
      );
      expect(config.hasActiveSandbox, true);

      final cleared = config.copyWith(clearActiveSandbox: true);
      expect(cleared.activeSandboxId, isNull);
      expect(cleared.activeSandboxUrl, isNull);
      expect(cleared.activeSandboxPassword, isNull);
      expect(cleared.activeSandboxEnvdToken, isNull);
      expect(cleared.activeSandboxStatus, isNull);
      expect(cleared.hasActiveSandbox, false);
    });
  });

  group('E2bWorkspaceService Tests', () {
    test('generateSecurePassword generates distinct string of requested length', () {
      final service = E2bWorkspaceService.instance;
      final pwd1 = service.generateSecurePassword(16);
      final pwd2 = service.generateSecurePassword(16);

      expect(pwd1.length, 16);
      expect(pwd2.length, 16);
      expect(pwd1, isNot(equals(pwd2)));
    });

    test('launchWorkspace fails fast when apiKey is empty', () async {
      final service = E2bWorkspaceService.instance;
      final result = await service.launchWorkspace(CloudWorkspaceConfig(e2bApiKey: ''));
      expect(result.success, false);
      expect(result.error, contains('E2B API Key 不能为空'));
    });
  });

  group('AppSettingsStore CloudWorkspace Integration', () {
    test('persists and retrieves cloudWorkspaceConfig', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AppSettingsStore(prefs);

      expect(store.cloudWorkspaceConfig.e2bApiKey, '');

      final newConfig = CloudWorkspaceConfig(
        e2bApiKey: 'test-key-456',
        toolchains: ['dart', 'rust', 'python'],
      );
      await store.setCloudWorkspaceConfig(newConfig);

      final loaded = store.cloudWorkspaceConfig;
      expect(loaded.e2bApiKey, 'test-key-456');
      expect(loaded.toolchains, containsAll(['dart', 'rust', 'python']));
    });

    test('persists selfHostedServer settings and preserves them when connecting to cloud',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Global.settings = AppSettingsStore(prefs);

      // 1. 用户连接自建服务器
      await Global.persistServerConnection(
        url: 'http://192.168.1.100:4096',
        username: 'my_user',
        password: 'my_password',
      );

      expect(Global.serverUrl, 'http://192.168.1.100:4096');
      expect(Global.selfHostedServerUrl, 'http://192.168.1.100:4096');
      expect(Global.selfHostedServerUsername, 'my_user');
      expect(Global.selfHostedServerPassword, 'my_password');

      // 2. 用户切换连接 E2B 云端沙盒
      await Global.persistServerConnection(
        url: 'https://4096-sbx-9988.e2b.app',
        username: 'opencode',
        password: 'temporary_sandbox_secret',
      );

      // 当前运行时连接变为沙盒
      expect(Global.serverUrl, 'https://4096-sbx-9988.e2b.app');
      expect(Global.serverPassword, 'temporary_sandbox_secret');

      // 但自建服务器表单配置依然完整保留！
      expect(Global.selfHostedServerUrl, 'http://192.168.1.100:4096');
      expect(Global.selfHostedServerUsername, 'my_user');
      expect(Global.selfHostedServerPassword, 'my_password');
    });
  });

  group('GitRepoService Tests', () {
    test('buildAuthenticatedCloneUrl adds token to GitHub URL', () {
      final service = GitRepoService.instance;
      final authUrl = service.buildAuthenticatedCloneUrl(
        repoUrl: 'https://github.com/my-org/my-project.git',
        token: 'ghp_secret_token_123',
      );

      expect(
        authUrl,
        'https://oauth2:ghp_secret_token_123@github.com/my-org/my-project.git',
      );
    });

    test('GitRepoItem fromGitHubJson parses correctly', () {
      final json = {
        'name': 'test-repo',
        'full_name': 'owner/test-repo',
        'clone_url': 'https://github.com/owner/test-repo.git',
        'default_branch': 'main',
        'private': true,
        'description': 'A test repository',
        'owner': {'login': 'owner'},
      };

      final item = GitRepoItem.fromGitHubJson(json);
      expect(item.name, 'test-repo');
      expect(item.fullName, 'owner/test-repo');
      expect(item.cloneUrl, 'https://github.com/owner/test-repo.git');
      expect(item.defaultBranch, 'main');
      expect(item.isPrivate, true);
      expect(item.description, 'A test repository');
      expect(item.owner, 'owner');
    });
    test('buildAuthenticatedCloneUrl retains custom port and handles other platforms', () {
      final service = GitRepoService.instance;
      final gitlabUrl = service.buildAuthenticatedCloneUrl(
        repoUrl: 'https://gitlab.company.com:8443/team/repo.git',
        token: 'glpat_secret',
      );
      expect(
        gitlabUrl,
        'https://oauth2:glpat_secret@gitlab.company.com:8443/team/repo.git',
      );

      final giteeUrl = service.buildAuthenticatedCloneUrl(
        repoUrl: 'https://gitee.com/user/project.git',
        token: 'gitee_token',
      );
      expect(
        giteeUrl,
        'https://gitee_token@gitee.com/user/project.git',
      );
    });
  });

  group('E2bSandboxInfo Tests', () {
    test('E2bSandboxInfo fromJson parses standard E2B listed sandbox correctly', () {
      final json = {
        'sandboxID': 'sbx_abc123',
        'templateID': 'opencode',
        'alias': 'opencode-v1',
        'state': 'running',
        'startedAt': '2026-08-31T04:24:09.425Z',
        'endAt': '2026-08-31T06:24:09.425Z',
        'cpuCount': 4,
        'memoryMB': 4096,
        'metadata': {
          'repo': 'my-user/my-flutter-repo',
          'source': 'opencode_mobile',
        },
      };

      final info = E2bSandboxInfo.fromJson(json);
      expect(info.sandboxId, 'sbx_abc123');
      expect(info.templateId, 'opencode');
      expect(info.alias, 'opencode-v1');
      expect(info.state, 'running');
      expect(info.isRunning, true);
      expect(info.isPaused, false);
      expect(info.cpuCount, 4);
      expect(info.memoryMB, 4096);
      expect(info.repoName, 'my-user/my-flutter-repo');
      expect(info.endpointUrl, 'https://4096-sbx_abc123.e2b.app');
    });

    test('E2bSandboxInfo handles status fallback key', () {
      final json = {
        'id': 'sbx_status_123',
        'template': 'opencode',
        'status': 'paused',
      };
      final info = E2bSandboxInfo.fromJson(json);
      expect(info.sandboxId, 'sbx_status_123');
      expect(info.isPaused, true);
      expect(info.isRunning, false);
    });

    test('E2bSandboxInfo handles paused state and serialization', () {
      final info = E2bSandboxInfo(
        sandboxId: 'sbx_paused_99',
        templateId: 'opencode',
        state: 'paused',
      );
      expect(info.isRunning, false);
      expect(info.isPaused, true);
      expect(info.endpointUrl, 'https://4096-sbx_paused_99.e2b.app');

      final serialized = info.toJson();
      expect(serialized['sandboxID'], 'sbx_paused_99');
      expect(serialized['state'], 'paused');
    });
  });

  group('E2bWorkspaceService bootstrap script', () {
    test('avoids pgrep self-match and probes port via curl', () {
      final script = E2bWorkspaceService.bootstrapScript;
      // 守护:bash -l -c 的进程 cmdline 含脚本文本,
      // 若裸写 "opencode serve" 会被 pgrep -f 匹配到脚本自身,
      // 误判"已在运行"直接 exit 0,导致服务从未启动(历史 502 根因)
      expect(script.contains('pgrep -f "opencode serve"'), isFalse);
      expect(script.contains("pgrep -f 'opencode serve'"), isFalse);
      expect(script.contains('[o]pencode serve'), isTrue);
      // 就绪判定必须 curl 探测本机端口,不能只看进程名/固定 sleep
      expect(script.contains('127.0.0.1:4096'), isTrue);
      expect(script.contains('setsid nohup'), isTrue);
      // 克隆目录用 GitHub 项目名(basename 去除 .git),并防御 ".." 等危险值
      expect(script.contains('basename "\$GIT_CLONE_URL" .git'), isTrue);
      expect(script.contains('REPO_DIR="\$HOME/\$REPO_NAME"'), isTrue);
    });
  });

  group('E2bWorkspaceService health polling (mock HTTP)', () {
    final service = E2bWorkspaceService.instance;

    tearDown(service.stopKeepAlive);

    test('waitForHealthy fails fast on 401 (password mismatch)', () async {
      service.healthDioForTest = Dio()
        ..httpClientAdapter = FakeHttpAdapter((options, body) async {
          return ResponseBody.fromString('unauthorized', 401);
        });

      final res = await service.waitForHealthy(
        endpointUrl: 'https://4096-sbx-auth.e2b.app',
        password: 'wrong-password',
        maxRetries: 100,
        retryDelay: const Duration(milliseconds: 1),
      );

      expect(res.healthy, isFalse);
      expect(res.failReason, contains('密码不匹配'));
    });

    test('waitForHealthy retries 502 then succeeds on 200', () async {
      int calls = 0;
      service.healthDioForTest = Dio()
        ..httpClientAdapter = FakeHttpAdapter((options, body) async {
          calls++;
          if (calls <= 2) {
            return ResponseBody.fromString(
              '{"code":502,"message":"The sandbox is running but port is not open"}',
              502,
            );
          }
          return ResponseBody.fromString('{"healthy":true}', 200);
        });

      final res = await service.waitForHealthy(
        endpointUrl: 'https://4096-sbx-boot.e2b.app',
        password: 'pw',
        maxRetries: 5,
        retryDelay: const Duration(milliseconds: 1),
      );

      expect(res.healthy, isTrue);
      expect(res.failReason, isNull);
      // /api/health 与 /global/health 在第 1 轮各打一次(502),第 2 轮 /api/health 直接 200
      expect(calls, 3);
    });

    test('waitForHealthy reports timeout reason after exhausting retries',
        () async {
      service.healthDioForTest = Dio()
        ..httpClientAdapter = FakeHttpAdapter((options, body) async {
          return ResponseBody.fromString('port not open', 502);
        });

      final res = await service.waitForHealthy(
        endpointUrl: 'https://4096-sbx-slow.e2b.app',
        password: 'pw',
        maxRetries: 3,
        retryDelay: const Duration(milliseconds: 1),
      );

      expect(res.healthy, isFalse);
      expect(res.failReason, contains('超时'));
    });
  });

  group('E2bWorkspaceService bootstrap (mock envd)', () {
    test('ensureOpenCodeRunning maps exit code 42 to install failure',
        () async {
      final adapter = FakeHttpAdapter((options, body) async {
        if (options.uri.path.endsWith('/connect')) {
          return ResponseBody.fromString(
            jsonEncode({
              'sandboxID': 'sbx-b',
              'envdAccessToken': 'tok',
              'domain': 'e2b.app',
            }),
            200,
            headers: {
              'content-type': ['application/json'],
            },
          );
        }
        if (options.uri.path.contains('process.Process/Start')) {
          return ResponseBody(
            Stream.fromIterable([
              framedEvents([
                {
                  'event': {'start': {'pid': 1}},
                },
                {
                  'event': {'end': {'exit_code': 42}},
                },
              ]),
            ]),
            200,
          );
        }
        // 其他请求(如读取 /tmp/opencode.log)返回 404,由调用方静默处理
        return ResponseBody.fromString('not found', 404);
      });
      final dio = Dio()..httpClientAdapter = adapter;

      final sandbox = await Sandbox.connect(
        SandboxConnectOpts(sandboxId: 'sbx-b', apiKey: 'k'),
        dio: dio,
      );

      final result = await E2bWorkspaceService.instance.ensureOpenCodeRunning(
        sandboxId: 'sbx-b',
        apiKey: 'k',
        password: 'pw',
        config: CloudWorkspaceConfig(),
        sandbox: sandbox,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('安装失败'));
    });

    test('ensureOpenCodeRunning succeeds when script exits 0', () async {
      final adapter = FakeHttpAdapter((options, body) async {
        if (options.uri.path.endsWith('/connect')) {
          return ResponseBody.fromString(
            jsonEncode({
              'sandboxID': 'sbx-ok',
              'envdAccessToken': 'tok',
              'domain': 'e2b.app',
            }),
            200,
            headers: {
              'content-type': ['application/json'],
            },
          );
        }
        if (options.uri.path.contains('process.Process/Start')) {
          return ResponseBody(
            Stream.fromIterable([
              framedEvents([
                {
                  'event': {'start': {'pid': 2}},
                },
                {
                  'event': {
                    'data': {
                      'stdout': base64Encode(utf8.encode('Bootstrap done')),
                    },
                  },
                },
                {
                  'event': {'end': {'exit_code': 0}},
                },
              ]),
            ]),
            200,
          );
        }
        return ResponseBody.fromString('not found', 404);
      });
      final dio = Dio()..httpClientAdapter = adapter;

      final sandbox = await Sandbox.connect(
        SandboxConnectOpts(sandboxId: 'sbx-ok', apiKey: 'k'),
        dio: dio,
      );

      final result = await E2bWorkspaceService.instance.ensureOpenCodeRunning(
        sandboxId: 'sbx-ok',
        apiKey: 'k',
        password: 'pw',
        config: CloudWorkspaceConfig(),
        sandbox: sandbox,
      );

      expect(result.success, isTrue);
    });

    test('recoverPassword reads password from sandbox', () async {
      final adapter = FakeHttpAdapter((options, body) async {
        if (options.uri.path.endsWith('/connect')) {
          return ResponseBody.fromString(
            jsonEncode({
              'sandboxID': 'sbx-pw',
              'envdAccessToken': 'tok',
              'domain': 'e2b.app',
            }),
            200,
            headers: {
              'content-type': ['application/json'],
            },
          );
        }
        if (options.uri.path.contains('process.Process/Start')) {
          return ResponseBody(
            Stream.fromIterable([
              framedEvents([
                {
                  'event': {'start': {'pid': 3}},
                },
                {
                  'event': {
                    'data': {
                      'stdout': base64Encode(utf8.encode('recovered-pw\n')),
                    },
                  },
                },
                {
                  'event': {'end': {'exit_code': 0}},
                },
              ]),
            ]),
            200,
          );
        }
        return ResponseBody.fromString('not found', 404);
      });
      final dio = Dio()..httpClientAdapter = adapter;

      final sandbox = await Sandbox.connect(
        SandboxConnectOpts(sandboxId: 'sbx-pw', apiKey: 'k'),
        dio: dio,
      );

      final pw = await E2bWorkspaceService.instance.recoverPassword(sandbox);
      expect(pw, 'recovered-pw');
    });
  });

  group('E2bWorkspaceService isCloudUrl tests', () {
    test('identifies cloud and self-hosted URLs correctly', () {
      expect(E2bWorkspaceService.isCloudUrl('https://4096-sbx123.e2b.app'), isTrue);
      expect(E2bWorkspaceService.isCloudUrl('https://49983-sbx-abc.e2b.app'), isTrue);
      expect(E2bWorkspaceService.isCloudUrl('http://e2b.app:4096'), isTrue);
      expect(E2bWorkspaceService.isCloudUrl('http://192.168.1.100:4096'), isFalse);
      expect(E2bWorkspaceService.isCloudUrl('http://localhost:4096'), isFalse);
      expect(E2bWorkspaceService.isCloudUrl(''), isFalse);
      expect(E2bWorkspaceService.isCloudUrl(null), isFalse);
    });
  });

  group('E2bWorkspaceService connectSandbox tests', () {
    final service = E2bWorkspaceService.instance;
    tearDown(service.stopKeepAlive);

    test('connectSandbox fails fast when apiKey is empty', () async {
      final res = await service.connectSandbox(
        config: CloudWorkspaceConfig(e2bApiKey: ''),
        sandboxId: 'sbx-1',
        endpointUrl: 'https://4096-sbx-1.e2b.app',
      );
      expect(res.success, isFalse);
      expect(res.error, contains('E2B API Key 不能为空'));
    });

    test('connectSandbox happy path with existing sandbox and mock healthy server',
        () async {
      service.healthDioForTest = Dio()
        ..httpClientAdapter = FakeHttpAdapter((options, body) async {
          return ResponseBody.fromString('{"healthy":true}', 200);
        });

      final adapter = FakeHttpAdapter((options, body) async {
        if (options.uri.path.endsWith('/connect')) {
          return ResponseBody.fromString(
            jsonEncode({
              'sandboxID': 'sbx-connect-ok',
              'envdAccessToken': 'tok_envd_123',
              'domain': 'e2b.app',
            }),
            200,
            headers: {'content-type': ['application/json']},
          );
        }
        return ResponseBody.fromString('not found', 404);
      });

      final sandbox = await Sandbox.connect(
        SandboxConnectOpts(sandboxId: 'sbx-connect-ok', apiKey: 'test-key'),
        dio: Dio()..httpClientAdapter = adapter,
      );

      final config = CloudWorkspaceConfig(
        e2bApiKey: 'test-key',
        activeSandboxId: 'sbx-connect-ok',
        activeSandboxPassword: 'my-stored-password',
      );

      final result = await service.connectSandbox(
        config: config,
        sandboxId: 'sbx-connect-ok',
        endpointUrl: 'https://4096-sbx-connect-ok.e2b.app',
        sandbox: sandbox,
      );

      expect(result.success, isTrue);
      expect(result.password, 'my-stored-password');
      expect(result.envdAccessToken, 'tok_envd_123');
      expect(result.domain, 'e2b.app');
    });

    test('connectSandbox recovers password from sandbox when missing in config',
        () async {
      service.healthDioForTest = Dio()
        ..httpClientAdapter = FakeHttpAdapter((options, body) async {
          return ResponseBody.fromString('{"healthy":true}', 200);
        });

      final adapter = FakeHttpAdapter((options, body) async {
        if (options.uri.path.endsWith('/connect')) {
          return ResponseBody.fromString(
            jsonEncode({
              'sandboxID': 'sbx-recover-ok',
              'envdAccessToken': 'tok_recover',
              'domain': 'e2b.app',
            }),
            200,
            headers: {'content-type': ['application/json']},
          );
        }
        if (options.uri.path.contains('process.Process/Start')) {
          return ResponseBody(
            Stream.fromIterable([
              framedEvents([
                {
                  'event': {'start': {'pid': 10}},
                },
                {
                  'event': {
                    'data': {
                      'stdout': base64Encode(utf8.encode('recovered-secret\n')),
                    },
                  },
                },
                {
                  'event': {'end': {'exit_code': 0}},
                },
              ]),
            ]),
            200,
          );
        }
        return ResponseBody.fromString('not found', 404);
      });

      final sandbox = await Sandbox.connect(
        SandboxConnectOpts(sandboxId: 'sbx-recover-ok', apiKey: 'test-key'),
        dio: Dio()..httpClientAdapter = adapter,
      );

      final config = CloudWorkspaceConfig(
        e2bApiKey: 'test-key',
        activeSandboxId: 'sbx-recover-ok',
        activeSandboxPassword: '', // 没有密码，触发恢复
      );

      final result = await service.connectSandbox(
        config: config,
        sandboxId: 'sbx-recover-ok',
        endpointUrl: 'https://4096-sbx-recover-ok.e2b.app',
        sandbox: sandbox,
      );

      expect(result.success, isTrue);
      expect(result.password, 'recovered-secret');
      expect(result.envdAccessToken, 'tok_recover');
    });
  });
}

