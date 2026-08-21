import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'url_utils.dart';

class ErrorFormatter {
  /// Main entry point to format any error.
  /// Handles Maps, JSON strings, DioExceptions, and raw Dart Map.toString() representations.
  static String format(dynamic error) {
    final formatted = _format(error);
    return formatted.isEmpty ? formatted : maskIpsInText(formatted);
  }

  static String _format(dynamic error) {
    if (error == null) return '';

    final isZh = Get.locale?.languageCode.startsWith('zh') ?? true;

    if (error is DioException) {
      try {
        final resp = error.response;
        if (resp != null && resp.data is Map) {
          final errData = resp.data as Map<String, dynamic>;
          final innerError = errData['error'];
          if (innerError != null) {
            return _format(innerError);
          }
          final message = errData['message'];
          if (message != null) return message.toString();
        }
        if (resp != null &&
            resp.statusMessage != null &&
            resp.statusMessage!.isNotEmpty) {
          return '${resp.statusCode}: ${resp.statusMessage}';
        }
        if (error.type == DioExceptionType.connectionTimeout) {
          return isZh ? '连接超时' : 'Connection timeout';
        }
        if (error.type == DioExceptionType.receiveTimeout) {
          return isZh ? '接收超时' : 'Receive timeout';
        }
        if (error.message != null && error.message!.isNotEmpty) {
          return error.message!;
        }
      } catch (_) {}
      return error.toString();
    }

    if (error is Map) {
      return _formatMap(Map<String, dynamic>.from(error));
    }

    if (error is String) {
      final trimmed = error.trim();
      if (trimmed.isEmpty) return '';

      // Try to parse as JSON first
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            return _formatMap(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // Fall through to Dart Map.toString() parsing
        }
      }

      // Try to parse as Dart Map.toString() representation
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final parsed = parseDartMapString(trimmed);
          if (parsed != null) {
            return _formatMap(parsed);
          }
        } catch (_) {}
      }

      return error;
    }

    return error.toString();
  }

  /// Parses a raw Dart Map.toString() representation recursively.
  /// Example: {name: APIError, data: {message: Not supported model, statusCode: 400}}
  static Map<String, dynamic>? parseDartMapString(String s) {
    s = s.trim();
    if (!s.startsWith('{') || !s.endsWith('}')) return null;
    int index = 0;

    dynamic parseValue() {
      // skip whitespace
      while (index < s.length && _isWhitespace(s[index])) {
        index++;
      }
      if (index >= s.length) return null;

      if (s[index] == '{') {
        index++; // skip '{'
        final map = <String, dynamic>{};
        while (index < s.length) {
          while (index < s.length && _isWhitespace(s[index])) {
            index++;
          }
          if (index >= s.length || s[index] == '}') {
            if (index < s.length) index++; // skip '}'
            break;
          }

          // Parse key: read until ':'
          final keyStart = index;
          while (index < s.length && s[index] != ':') {
            index++;
          }
          if (index >= s.length) break;
          final key = s.substring(keyStart, index).trim();
          index++; // skip ':'

          // Parse value
          final val = parseValue();
          map[key] = val;

          // skip whitespace and comma
          while (index < s.length && _isWhitespace(s[index])) {
            index++;
          }
          if (index < s.length && s[index] == ',') {
            index++; // skip ','
          }
        }
        return map;
      } else if (s[index] == '[') {
        index++; // skip '['
        final start = index;
        var bracketCount = 1;
        while (index < s.length && bracketCount > 0) {
          if (s[index] == '[') bracketCount++;
          if (s[index] == ']') bracketCount--;
          index++;
        }
        return s.substring(start, index - 1);
      } else {
        // Primitive value (string, number, bool, null)
        // If it starts with quotes, parse properly
        if (s[index] == '"' || s[index] == "'") {
          final quote = s[index];
          index++;
          final start = index;
          var escaped = false;
          while (index < s.length) {
            if (escaped) {
              escaped = false;
              index++;
              continue;
            }
            if (s[index] == '\\') {
              escaped = true;
              index++;
              continue;
            }
            if (s[index] == quote) {
              final val = s.substring(start, index);
              index++; // skip quote
              return val;
            }
            index++;
          }
          return s.substring(start);
        }

        // Unquoted string: read until next sibling key separator or closing brace
        final start = index;
        while (index < s.length) {
          if (s[index] == '}') {
            break;
          }
          if (s[index] == ',') {
            if (_isFollowedByKey(s, index + 1)) {
              break;
            }
          }
          index++;
        }
        final valStr = s.substring(start, index).trim();
        if (valStr == 'true') return true;
        if (valStr == 'false') return false;
        if (valStr == 'null') return null;
        final numVal = num.tryParse(valStr);
        if (numVal != null) return numVal;
        return valStr;
      }
    }

    final parsed = parseValue();
    if (parsed is Map) {
      return Map<String, dynamic>.from(parsed);
    }
    return null;
  }

  static bool _isWhitespace(String char) {
    return char == ' ' || char == '\n' || char == '\r' || char == '\t';
  }

  static bool _isFollowedByKey(String s, int startIdx) {
    var i = startIdx;
    while (i < s.length && _isWhitespace(s[i])) {
      i++;
    }
    if (i >= s.length) return false;
    final startId = i;
    while (i < s.length && _isIdentifierChar(s[i])) {
      i++;
    }
    if (i == startId) return false;
    while (i < s.length && _isWhitespace(s[i])) {
      i++;
    }
    if (i >= s.length) return false;
    return s[i] == ':';
  }

  static bool _isIdentifierChar(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 97 && code <= 122) || // a-z
        (code >= 65 && code <= 90) || // A-Z
        (code >= 48 && code <= 57) || // 0-9
        char == '_' ||
        char == '-';
  }

  static String _formatMap(Map<String, dynamic> map) {
    final isZh = Get.locale?.languageCode.startsWith('zh') ?? true;

    final name = map['name'] as String? ?? '';
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : <String, dynamic>{};

    if (name.isEmpty) {
      // Fallback for direct api errors
      final error = map['error'];
      if (error is Map) {
        return _formatMap({
          'name': 'APIError',
          'data': Map<String, dynamic>.from(error),
        });
      }
      final message = map['message'] as String? ?? '';
      if (message.isNotEmpty) return message;
      return map.toString();
    }

    switch (name) {
      case 'APIError':
        final message =
            data['message'] as String? ?? (isZh ? 'API 错误' : 'API Error');
        final lines = <String>[message];

        final statusCode = data['statusCode'];
        if (statusCode != null) {
          lines.add(isZh ? '状态码：$statusCode' : 'Status Code: $statusCode');
        }

        final responseBody = data['responseBody'];
        if (responseBody is String && responseBody.trim().isNotEmpty) {
          final parsedBody = (_parseResponseBody(responseBody) ?? responseBody)
              .trim();
          final msgLower = message.toLowerCase();
          final bodyLower = parsedBody.toLowerCase();
          if (!msgLower.contains(bodyLower) && !bodyLower.contains(msgLower)) {
            if (parsedBody.contains('\n')) {
              lines.add(isZh ? '详情：\n$parsedBody' : 'Detail:\n$parsedBody');
            } else {
              lines.add(isZh ? '详情：$parsedBody' : 'Detail: $parsedBody');
            }
          }
        }

        return lines.join('\n');

      case 'ProviderAuthError':
        final provider =
            data['providerID'] as String? ?? (isZh ? '未知' : 'Unknown');
        final message = data['message'] as String? ?? '';
        return isZh
            ? '提供商认证失败（$provider）：$message'
            : 'Provider authentication failed ($provider): $message';

      case 'ProviderModelNotFoundError':
        final provider = data['providerID'] as String? ?? '';
        final model = data['modelID'] as String? ?? '';
        final suggestions = data['suggestions'];
        final lines = <String>[
          isZh
              ? '未找到模型：在 $provider 中未找到模型 $model'
              : 'Model not found: $model in $provider',
        ];
        if (suggestions is List && suggestions.isNotEmpty) {
          lines.add(
            isZh
                ? '您是不是要找：${suggestions.join(", ")}'
                : 'Did you mean: ${suggestions.join(", ")}',
          );
        } else if (suggestions is String && suggestions.isNotEmpty) {
          lines.add(
            isZh ? '您是不是要找：$suggestions' : 'Did you mean: $suggestions',
          );
        }
        lines.add(
          isZh
              ? '请检查你的配置 (opencode.json) 中的 provider/model 名称。'
              : 'Check your config (opencode.json) provider/model names.',
        );
        return lines.join('\n');

      case 'ProviderInitError':
        final provider = data['providerID'] as String? ?? '';
        return isZh
            ? '无法初始化提供商 "$provider"。请检查凭据和配置。'
            : 'Failed to initialize provider "$provider". Please check credentials and configuration.';

      case 'MCPFailed':
        final mcpName = data['name'] as String? ?? '';
        return isZh
            ? 'MCP 服务器 "$mcpName" 启动失败。注意：OpenCode 暂不支持 MCP 认证。'
            : 'MCP server "$mcpName" failed. Note: OpenCode does not support MCP authentication yet.';

      case 'ConfigJsonError':
        final path = data['path'] as String? ?? '';
        final message = data['message'] as String? ?? '';
        if (message.isNotEmpty) {
          return isZh
              ? '配置文件 $path 不是有效的 JSON(C)：$message'
              : 'Config file at $path is not valid JSON(C): $message';
        }
        return isZh
            ? '配置文件 $path 不是有效的 JSON(C)'
            : 'Config file at $path is not valid JSON(C)';

      case 'ConfigFrontmatterError':
        final path = data['path'] as String? ?? '';
        final message = data['message'] as String? ?? '';
        return isZh
            ? '无法解析 $path 中的 frontmatter：\n$message'
            : 'Failed to parse frontmatter in $path:\n$message';

      case 'ConfigInvalidError':
        final path = data['path'] as String? ?? '';
        final message = data['message'] as String? ?? '';
        final issues = data['issues'];
        final lines = <String>[];
        if (message.isNotEmpty) {
          lines.add(
            isZh
                ? '配置文件 $path 无效：$message'
                : 'Config file at $path is invalid: $message',
          );
        } else {
          lines.add(isZh ? '配置文件 $path 无效' : 'Config file at $path is invalid');
        }
        if (issues is List) {
          for (final issue in issues) {
            lines.add('↳ $issue');
          }
        }
        return lines.join('\n');

      case 'ContextOverflowError':
        final message = data['message'] as String? ?? '';
        return isZh ? '上下文溢出：$message' : 'Context Overflow: $message';

      case 'ContentFilterError':
        final message = data['message'] as String? ?? '';
        return isZh ? '内容被过滤：$message' : 'Content Filter: $message';

      case 'MessageOutputLengthError':
      case 'OutputLengthError':
        return isZh ? '输出长度超出限制' : 'Output length exceeded limit';

      case 'MessageAbortedError':
      case 'AbortedError':
        return isZh ? '消息已被用户或系统中断。' : 'Message was aborted by user or system.';

      case 'StructuredOutputError':
        final message = data['message'] as String? ?? '';
        final retries = data['retries'] ?? 0;
        return isZh
            ? '结构化输出生成失败：$message (重试次数: $retries)'
            : 'Structured output generation failed: $message (Retries: $retries)';

      case 'UnknownError':
        final message = data['message'] as String? ?? '';
        final ref = data['ref'] as String? ?? '';
        if (ref.isNotEmpty) {
          return '$message (Ref: $ref)';
        }
        return message.isNotEmpty ? message : (isZh ? '未知错误' : 'Unknown error');

      default:
        final message = data['message'] as String? ?? '';
        if (message.isNotEmpty) return message;
        return map.toString();
    }
  }

  static String? _parseResponseBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          final message = error['message'] as String? ?? '';
          if (message.isNotEmpty) return message;
        }
        final message = decoded['message'] as String? ?? '';
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}
    return null;
  }
}
