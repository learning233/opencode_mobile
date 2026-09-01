import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/models/e2b_sandbox_info.dart';
import 'package:opencode_app/services/e2b_workspace_service.dart';
import 'package:opencode_app/utils/translations.dart';

void main() {
  group('Drawer Multi-Backend Grouping & Route Resolution Tests', () {
    test(
      'isCloudUrl correctly identifies E2B cloud endpoints vs self-hosted',
      () {
        // E2B cloud URLs
        expect(
          E2bWorkspaceService.isCloudUrl('https://4096-sbx123.e2b.app'),
          isTrue,
        );
        expect(
          E2bWorkspaceService.isCloudUrl('http://4096-abcxyz.e2b.dev'),
          isTrue,
        );

        // Self-hosted URLs
        expect(
          E2bWorkspaceService.isCloudUrl('http://192.168.1.100:4096'),
          isFalse,
        );
        expect(
          E2bWorkspaceService.isCloudUrl('http://localhost:4096'),
          isFalse,
        );
        expect(
          E2bWorkspaceService.isCloudUrl('https://my-opencode-server.com:4096'),
          isFalse,
        );
        expect(E2bWorkspaceService.isCloudUrl(''), isFalse);
      },
    );

    test('E2bSandboxInfo model parses running and paused states correctly', () {
      final runningJson = {
        'sandboxID': 'sbx_live_001',
        'templateID': 'opencode-v1',
        'status': 'running',
        'metadata': {'repo': 'my_awesome_project'},
        'startedAt': '2026-09-01T10:00:00Z',
        'endAt': '2026-09-01T14:00:00Z',
      };

      final runningSb = E2bSandboxInfo.fromJson(runningJson);
      expect(runningSb.sandboxId, equals('sbx_live_001'));
      expect(runningSb.templateId, equals('opencode-v1'));
      expect(runningSb.state, equals('running'));
      expect(runningSb.isPaused, isFalse);
      expect(runningSb.metadata['repo'], equals('my_awesome_project'));
      expect(
        runningSb.endpointUrl,
        equals('https://4096-sbx_live_001.e2b.app'),
      );

      final pausedJson = {
        'sandboxID': 'sbx_paused_002',
        'templateID': 'base',
        'status': 'paused',
        'metadata': {},
      };

      final pausedSb = E2bSandboxInfo.fromJson(pausedJson);
      expect(pausedSb.sandboxId, equals('sbx_paused_002'));
      expect(pausedSb.isPaused, isTrue);
    });

    test(
      'LocaleKeys contains all required Drawer grouping keys in zh and en maps',
      () {
        final translations = Messages();
        final zhMap = translations.keys['zh_CN'];
        final enMap = translations.keys['en_US'];

        expect(zhMap, isNotNull);
        expect(enMap, isNotNull);

        // Verify Drawer Section Keys exist in both dictionaries
        expect(zhMap!.containsKey(LocaleKeys.drawerSelfHostedSection), isTrue);
        expect(zhMap.containsKey(LocaleKeys.drawerCloudSection), isTrue);
        expect(zhMap.containsKey(LocaleKeys.drawerClickToConnect), isTrue);
        expect(zhMap.containsKey(LocaleKeys.drawerSwitchingBackend), isTrue);
        expect(zhMap.containsKey(LocaleKeys.drawerConnected), isTrue);

        expect(enMap!.containsKey(LocaleKeys.drawerSelfHostedSection), isTrue);
        expect(enMap.containsKey(LocaleKeys.drawerCloudSection), isTrue);
        expect(enMap.containsKey(LocaleKeys.drawerClickToConnect), isTrue);
        expect(enMap.containsKey(LocaleKeys.drawerSwitchingBackend), isTrue);
        expect(enMap.containsKey(LocaleKeys.drawerConnected), isTrue);

        expect(zhMap[LocaleKeys.drawerSelfHostedSection], equals('自建服务器'));
        expect(zhMap[LocaleKeys.drawerCloudSection], equals('E2B 云端沙盒'));
        expect(
          enMap[LocaleKeys.drawerSelfHostedSection],
          equals('Self-Hosted Server'),
        );
        expect(
          enMap[LocaleKeys.drawerCloudSection],
          equals('E2B Cloud Sandboxes'),
        );
      },
    );
  });
}
