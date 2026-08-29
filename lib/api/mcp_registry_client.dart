import 'package:dio/dio.dart';
import 'models/registry_server.dart';

/// HTTP client for the MCP (Model Context Protocol) server registry at
/// https://registry.modelcontextprotocol.io.
///
/// Lists and queries available MCP servers from the official registry.
class McpRegistryClient {
  static const String _baseUrl = 'https://registry.modelcontextprotocol.io';
  static const Duration _timeout = Duration(seconds: 60);

  final Dio _dio;

  /// 短期内存缓存：列表缓存 3 分钟，详情缓存 10 分钟。
  final Map<String, ({RegistrySearchResult data, DateTime timestamp})>
  _listCache = {};
  final Map<String, ({RegistryServerInfo data, DateTime timestamp})>
  _detailCache = {};

  static const Duration _listCacheTtl = Duration(minutes: 3);
  static const Duration _detailCacheTtl = Duration(minutes: 10);

  /// Creates an [McpRegistryClient] with an optional custom [Dio] instance.
  McpRegistryClient({Dio? dio}) : _dio = dio ?? _createBaseDio();

  static Dio _createBaseDio() => Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      headers: {'Accept': 'application/json'},
    ),
  );

  void dispose() {
    _listCache.clear();
    _detailCache.clear();
    _dio.close(force: true);
  }

  /// Fetches a paginated list of MCP servers from the registry.
  /// [search] filters by name, [limit] controls page size (default 30),
  /// and [cursor] enables cursor-based pagination.
  /// Throws [McpRegistryException] on non-200 responses.
  Future<RegistrySearchResult> listServers({
    String? search,
    int limit = 30,
    String? cursor,
    bool force = false,
  }) async {
    final cacheKey = '${search ?? ''}\u0000$limit\u0000${cursor ?? ''}';
    final cached = _listCache[cacheKey];
    final now = DateTime.now();
    if (!force &&
        cached != null &&
        now.difference(cached.timestamp) < _listCacheTtl) {
      return cached.data;
    }

    final params = <String, dynamic>{'limit': limit, 'version': 'latest'};
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    if (cursor != null && cursor.isNotEmpty) {
      params['cursor'] = cursor;
    }

    try {
      final response = await _dio.get('/v0.1/servers', queryParameters: params);

      if (response.statusCode != 200) {
        throw McpRegistryException(
          'Failed to list servers: HTTP ${response.statusCode}'
          '${_bodySuffix(response.data)}',
        );
      }

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw McpRegistryException('Invalid server list response format');
      }
      final result = _parseServerList(body);
      _listCache[cacheKey] = (data: result, timestamp: now);
      return result;
    } on DioException catch (e) {
      throw McpRegistryException(
        'Failed to list servers: HTTP ${e.response?.statusCode ?? e.message}'
        '${_bodySuffix(e.response?.data)}',
      );
    }
  }

  /// Fetches detailed information about a specific MCP server.
  /// [name] is the server name, [version] specifies the version (default 'latest').
  /// Throws [McpRegistryException] if the server is not found or the request fails.
  Future<RegistryServerInfo> getServerDetail(
    String name, {
    String version = 'latest',
    bool force = false,
  }) async {
    final cacheKey = '$name\u0000$version';
    final cached = _detailCache[cacheKey];
    final now = DateTime.now();
    if (!force &&
        cached != null &&
        now.difference(cached.timestamp) < _detailCacheTtl) {
      return cached.data;
    }

    final encodedName = Uri.encodeComponent(name);
    final encodedVersion = Uri.encodeComponent(version);

    try {
      final response = await _dio.get(
        '/v0.1/servers/$encodedName/versions/$encodedVersion',
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw McpRegistryException('Invalid server detail response format');
      }
      final serverJson = data['server'];
      if (serverJson is! Map<String, dynamic>) {
        throw McpRegistryException('Invalid server detail payload format');
      }
      final result = RegistryServerInfo.fromJson(serverJson);
      _detailCache[cacheKey] = (data: result, timestamp: now);
      return result;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw McpRegistryException('Server "$name" not found in registry');
      }
      throw McpRegistryException(
        'Failed to get server detail: HTTP ${e.response?.statusCode ?? e.message}'
        '${_bodySuffix(e.response?.data)}',
      );
    }
  }

  /// Extracts a short, human-readable message from a JSON error body.
  static String _bodySuffix(Object? data) {
    if (data is Map) {
      final msg = data['error'] ?? data['message'] ?? data['detail'];
      if (msg is String && msg.isNotEmpty) return ': $msg';
    }
    return '';
  }

  RegistrySearchResult _parseServerList(Map<String, dynamic> body) {
    final serversRaw = body['servers'];
    final metadataRaw = body['metadata'];

    final servers = <RegistryServerInfo>[];
    if (serversRaw is List) {
      for (final item in serversRaw) {
        if (item is! Map) continue;
        final serverRaw = item['server'];
        if (serverRaw is Map) {
          servers.add(
            RegistryServerInfo.fromJson(Map<String, dynamic>.from(serverRaw)),
          );
        }
      }
    }

    final count = metadataRaw is Map ? metadataRaw['count'] : null;
    final nextCursor = metadataRaw is Map ? metadataRaw['nextCursor'] : null;
    return RegistrySearchResult(
      servers: servers,
      count: count is int ? count : servers.length,
      nextCursor: nextCursor is String ? nextCursor : null,
    );
  }
}

/// Exception thrown by [McpRegistryClient] when registry API calls fail.
class McpRegistryException implements Exception {
  /// Human-readable error message describing what went wrong.
  final String message;

  /// Creates an [McpRegistryException] with the given error [message].
  McpRegistryException(this.message);

  @override
  String toString() => 'McpRegistryException: $message';
}
