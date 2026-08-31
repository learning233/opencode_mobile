import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/filesystem_models.dart';
import '../transport/connect_transport.dart';
import '../transport/signature.dart';

/// E2B 文件系统服务 (对应 JS SDK Filesystem)
class Filesystem {
  final String sandboxId;
  final ConnectTransport transport;
  final Dio _dio;

  Filesystem({
    required this.sandboxId,
    required this.transport,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// 读取文本文件内容
  Future<String> read(String path, {String? user}) async {
    final bytes = await readBytes(path, user: user);
    return utf8.decode(bytes);
  }

  /// 读取二进制文件内容
  Future<Uint8List> readBytes(String path, {String? user}) async {
    final token = transport.config.envdAccessToken ?? transport.config.apiKey;
    final sig = E2bSignature.getSignature(
      path: path,
      operation: 'read',
      user: user ?? '',
      expirationInSeconds: 300,
      envdAccessToken: token,
    );

    final url =
        '${transport.config.getSandboxEnvdUrl(sandboxId)}/files?path=${Uri.encodeComponent(path)}&signature=${sig.signature}&expiration=${sig.expiration ?? ''}&username=${Uri.encodeComponent(user ?? '')}';

    final res = await _dio.get<List<int>>(
      url,
      options: Options(
        headers: transport.config.getEnvdHeaders(sandboxId: sandboxId),
        responseType: ResponseType.bytes,
      ),
    );

    return Uint8List.fromList(res.data ?? []);
  }

  /// 写入文本文件内容
  Future<void> write(String path, String data, {String? user}) async {
    await writeBytes(path, Uint8List.fromList(utf8.encode(data)), user: user);
  }

  /// 写入二进制文件内容
  Future<void> writeBytes(String path, Uint8List data, {String? user}) async {
    final token = transport.config.envdAccessToken ?? transport.config.apiKey;
    final sig = E2bSignature.getSignature(
      path: path,
      operation: 'write',
      user: user ?? '',
      expirationInSeconds: 300,
      envdAccessToken: token,
    );

    final url =
        '${transport.config.getSandboxEnvdUrl(sandboxId)}/files?path=${Uri.encodeComponent(path)}&signature=${sig.signature}&expiration=${sig.expiration ?? ''}&username=${Uri.encodeComponent(user ?? '')}';

    await _dio.post(
      url,
      options: Options(
        headers: {
          ...transport.config.getEnvdHeaders(sandboxId: sandboxId),
          'Content-Type': 'application/octet-stream',
        },
      ),
      data: Stream.fromIterable([data]),
    );
  }

  /// 列出目录中的文件与子目录
  Future<List<EntryInfo>> list(String path) async {
    final res = await transport.unaryCall(
      sandboxId: sandboxId,
      path: '/filesystem.Filesystem/List',
      request: {'path': path},
    );

    final rawEntries = res['entries'] as List?;
    if (rawEntries == null) return [];

    return rawEntries
        .whereType<Map>()
        .map((e) => EntryInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 创建目录
  Future<void> makeDir(String path) async {
    await transport.unaryCall(
      sandboxId: sandboxId,
      path: '/filesystem.Filesystem/MakeDir',
      request: {'path': path},
    );
  }

  /// 删除文件或目录
  Future<void> remove(String path) async {
    await transport.unaryCall(
      sandboxId: sandboxId,
      path: '/filesystem.Filesystem/Remove',
      request: {'path': path},
    );
  }

  /// 检查路径是否存在
  Future<bool> exists(String path) async {
    try {
      final entries = await list(path);
      return entries.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
