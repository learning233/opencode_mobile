import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/controllers/settings_controller.dart';
import 'package:opencode_app/models/model_info.dart';

void main() {
  test('permissionFor returns flat actions and custom for path maps', () {
    final map = <String, dynamic>{
      'edit': 'deny',
      'bash': {'*': 'ask', 'src/**': 'allow'},
    };
    expect(SettingsController.permissionFor(map, 'edit'), 'deny');
    expect(
      SettingsController.permissionFor(map, 'bash'),
      SettingsController.permissionCustom,
    );
    expect(SettingsController.permissionFor(map, 'read'), isNotEmpty);
    expect(
      SettingsController.permissionFor(map, 'read'),
      isNot(SettingsController.permissionCustom),
    );
  });

  test('permissionFor does not stringify maps as allow/ask/deny', () {
    final map = <String, dynamic>{
      'read': {'docs/**': 'allow'},
    };
    final value = SettingsController.permissionFor(map, 'read');
    expect(value, SettingsController.permissionCustom);
    expect(const ['ask', 'allow', 'deny'].contains(value), isFalse);
  });

  test('referenceConfigFromEntries builds ConfigV1 map shape', () {
    final map = SettingsController.referenceConfigFromEntries([
      {'name': 'docs', 'type': 'string', 'value': 'https://example.com'},
      {
        'name': 'repo',
        'type': 'git',
        'repository': 'https://github.com/a/b',
        'branch': 'main',
      },
      {'name': 'src', 'type': 'local', 'path': './packages'},
    ]);

    expect(map['docs'], 'https://example.com');
    expect(map['repo'], {
      'repository': 'https://github.com/a/b',
      'branch': 'main',
    });
    expect(map['src'], {'path': './packages'});
  });

  test('referenceEntriesFromConfig round-trips named references', () {
    final cfg = <String, dynamic>{
      'docs': 'https://example.com',
      'repo': {'repository': 'https://github.com/a/b', 'branch': 'dev'},
      'src': {'path': './lib'},
    };
    final entries = SettingsController.referenceEntriesFromConfig(cfg);
    expect(entries.length, 3);
    final rebuilt = SettingsController.referenceConfigFromEntries(entries);
    expect(rebuilt['docs'], 'https://example.com');
    expect(rebuilt['repo']['repository'], 'https://github.com/a/b');
    expect(rebuilt['repo']['branch'], 'dev');
    expect(rebuilt['src']['path'], './lib');
  });

  test('isModelVisible respects local shown and hidden lists', () {
    final controller = SettingsController();
    controller.shownModelsRx
      ..clear()
      ..addAll(['openai:gpt-4']);
    controller.hiddenModelsRx
      ..clear()
      ..addAll(['anthropic:claude']);
    final models = [
      ModelInfo(id: 'gpt-4', name: 'GPT-4', providerId: 'openai'),
      ModelInfo(id: 'claude', name: 'Claude', providerId: 'anthropic'),
      ModelInfo(
        id: 'old',
        name: 'Old',
        providerId: 'openai',
        releaseDate: '2020-01-01',
      ),
    ];
    expect(controller.isModelVisible(models[0], models), isTrue);
    expect(controller.isModelVisible(models[1], models), isFalse);
    expect(controller.isModelVisible(models[2], models), isFalse);
  });
}
