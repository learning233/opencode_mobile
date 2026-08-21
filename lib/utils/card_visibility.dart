import 'dart:convert';

import 'package:get/get.dart';

import 'translations.dart';

/// Display-settings keys for message card visibility (excludes markdown/retry/todo UI).
class CardVisibilityKeys {
  CardVisibilityKeys._();

  static const List<String> all = [
    'reasoning',
    'read',
    'bash',
    'edit',
    'batch',
    'glob',
    'grep',
    'web',
    'question',
    'task',
    'subtask',
    'skill',
    'fallback',
    'file',
    'agent',
    'diff',
  ];

  static String labelFor(String key) {
    switch (key) {
      case 'reasoning':
        return LocaleKeys.cardVisReasoning.tr;
      case 'read':
        return LocaleKeys.cardVisRead.tr;
      case 'bash':
        return LocaleKeys.cardVisBash.tr;
      case 'edit':
        return LocaleKeys.cardVisEdit.tr;
      case 'batch':
        return LocaleKeys.cardVisBatch.tr;
      case 'glob':
        return LocaleKeys.cardVisGlob.tr;
      case 'grep':
        return LocaleKeys.cardVisGrep.tr;
      case 'web':
        return LocaleKeys.cardVisWeb.tr;
      case 'question':
        return LocaleKeys.cardVisQuestion.tr;
      case 'task':
        return LocaleKeys.cardVisTask.tr;
      case 'subtask':
        return LocaleKeys.cardVisSubtask.tr;
      case 'skill':
        return LocaleKeys.cardVisSkill.tr;
      case 'fallback':
        return LocaleKeys.cardVisFallback.tr;
      case 'file':
        return LocaleKeys.cardVisFile.tr;
      case 'agent':
        return LocaleKeys.cardVisAgent.tr;
      case 'diff':
        return LocaleKeys.cardVisDiff.tr;
      default:
        return key;
    }
  }
}

/// Maps a tool name to a [CardVisibilityKeys] key (aligned with ToolPartDispatcher).
String cardVisibilityKeyForTool(String toolName) {
  final tool = toolName.toLowerCase();
  switch (tool) {
    case 'read':
      return 'read';
    case 'bash':
    case 'shell':
      return 'bash';
    case 'edit':
    case 'write':
      return 'edit';
    case 'apply_patch':
      return 'batch';
    case 'glob':
    case 'list':
      return 'glob';
    case 'grep':
      return 'grep';
    case 'webfetch':
    case 'websearch':
      return 'web';
    case 'question':
      return 'question';
    case 'task':
      return 'task';
    case 'subtask':
      return 'subtask';
    case 'todo':
    case 'todowrite':
    case 'todo_write':
      return 'todo';
    case 'skill':
      return 'skill';
    default:
      if (tool.contains('todo')) return 'todo';
      if (tool.contains('skill')) return 'skill';
      return 'fallback';
  }
}

/// Missing keys default to visible, except input_session_diff which defaults to false.
bool isCardVisibleInMap(Map<String, bool> map, String key) {
  if (map.containsKey(key)) return map[key]!;
  if (key == 'input_session_diff') return false;
  return true;
}

Map<String, bool> parseCardVisibilityJson(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    final out = <String, bool>{};
    decoded.forEach((k, v) {
      if (k is String && v is bool) out[k] = v;
    });
    return out;
  } catch (_) {
    return {};
  }
}

String encodeCardVisibilityJson(Map<String, bool> map) => jsonEncode(map);
