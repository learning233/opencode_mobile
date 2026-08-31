import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/errors.dart';
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
    final url = await _buildFileUrl(path, user: user, operation: 'read');
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
    final url = await _buildFileUrl(path, user: user, operation: 'write');
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

  /// 构造 /files 请求 URL。仅当存在 envdAccessToken 时生成签名（官方规范：
  /// 无 token 的沙盒直接发无签名请求）；过期参数名必须是
  /// `signature_expiration`，且用 Uri.queryParameters 正确编码 base64 中的 `+`。
  Future<String> _buildFileUrl(
    String path, {
    String? user,
    required String operation,
  }) async {
    final base = transport.config.getSandboxEnvdUrl(sandboxId);
    final uri = Uri.parse('$base/files').replace(
      queryParameters: {
        'path': path,
        if (user != null && user.isNotEmpty) 'username': user,
      },
    );

    final token = transport.config.envdAccessToken;
    if (token == null || token.isEmpty) return uri.toString();

    final sig = E2bSignature.getSignature(
      path: path,
      operation: operation,
      user: user ?? '',
      expirationInSeconds: 300,
      envdAccessToken: token,
    );
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'signature': sig.signature,
        if (sig.expiration != null)
          'signature_expiration': sig.expiration.toString(),
      },
    ).toString();
  }

  /// 列出目录中的文件与子目录
  Future<List<EntryInfo>> list(String path) async {
    final res = await transport.unaryCall(
      sandboxId: sandboxId,
      path: '/filesystem.Filesystem/ListDir',
      request: {'path': path, 'depth': 1},
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

  /// 检查路径是否存在（走 Stat；仅 NotFound 返回 false，其余错误抛出）
  Future<bool> exists(String path) async {
    try {
      await transport.unaryCall(
        sandboxId: sandboxId,
        path: '/filesystem.Filesystem/Stat',
        request: {'path': path},
      );
      return true;
    } on SandboxNotFoundException {
      return false;
    }
  }
}
