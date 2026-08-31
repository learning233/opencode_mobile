import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/errors.dart';
import 'connection_config.dart';

/// Connect-RPC 数据帧类型
enum ConnectFrameFlag {
  data(0x00),
  endOfStream(0x02);

  final int value;
  const ConnectFrameFlag(this.value);

  static ConnectFrameFlag fromByte(int byte) {
    if (byte == 0x02) return ConnectFrameFlag.endOfStream;
    return ConnectFrameFlag.data;
  }
}

/// Connect-RPC 数据帧
class ConnectFrame {
  final ConnectFrameFlag flag;
  final Uint8List payload;

  const ConnectFrame({required this.flag, required this.payload});

  Map<String, dynamic>? get jsonMap {
    try {
      final str = utf8.decode(payload);
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}

/// Connect-RPC 通信与流解包传输器
class ConnectTransport {
  final ConnectionConfig config;
  final Dio _dio;

  /// 暴露内部 Dio,供子服务复用同一客户端(测试时可注入 mock adapter)
  Dio get dio => _dio;

  ConnectTransport({required this.config, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
            ),
          );

  /// 编码单条 Unary / Stream 请求 Payload
  static Uint8List encodeFrame(
    Map<String, dynamic> data, {
    ConnectFrameFlag flag = ConnectFrameFlag.data,
  }) {
    final payloadBytes = utf8.encode(jsonEncode(data));
    final len = payloadBytes.length;
    final header = Uint8List(5);
    header[0] = flag.value;
    header[1] = (len >> 24) & 0xFF;
    header[2] = (len >> 16) & 0xFF;
    header[3] = (len >> 8) & 0xFF;
    header[4] = len & 0xFF;

    final result = BytesBuilder();
    result.add(header);
    result.add(payloadBytes);
    return result.toBytes();
  }

  /// 从连续字节流中解包所有 Connect 帧
  static List<ConnectFrame> decodeFrames(List<int> bytes) {
    final frames = <ConnectFrame>[];
    int offset = 0;
    while (offset + 5 <= bytes.length) {
      final flagByte = bytes[offset];
      final len =
          (bytes[offset + 1] << 24) |
          (bytes[offset + 2] << 16) |
          (bytes[offset + 3] << 8) |
          bytes[offset + 4];
      offset += 5;

      if (offset + len <= bytes.length) {
        final chunk = Uint8List.fromList(bytes.sublist(offset, offset + len));
        offset += len;
        frames.add(
          ConnectFrame(
            flag: ConnectFrameFlag.fromByte(flagByte),
            payload: chunk,
          ),
        );
      } else {
        break;
      }
    }
    return frames;
  }

  /// 发起 Unary Connect-RPC 请求(裸 JSON,Content-Type: application/json)
  Future<Map<String, dynamic>> unaryCall({
    required String sandboxId,
    required String path,
    required Map<String, dynamic> request,
  }) async {
    final url = '${config.getSandboxEnvdUrl(sandboxId)}$path';
    final headers = config.getEnvdHeaders(sandboxId: sandboxId);

    try {
      final res = await _dio.post(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.plain,
          validateStatus: (status) => true,
        ),
        data: jsonEncode(request),
      );

      _throwForStatus(res.statusCode, sandboxId, path);

      final rawData = res.data?.toString() ?? '';
      if (rawData.isEmpty) return {};

      // 尝试直接 JSON 解析
      try {
        final directMap = jsonDecode(rawData);
        if (directMap is Map<String, dynamic>) return directMap;
        if (directMap is Map) return Map<String, dynamic>.from(directMap);
      } catch (_) {}

      // 尝试 Connect 帧解包(必须用 UTF-8 字节,UTF-16 codeUnits 会损坏多字节字符)
      final frames = decodeFrames(utf8.encode(rawData));
      for (final f in frames) {
        final map = f.jsonMap;
        if (map != null) return map;
      }
      return {};
    } on DioException catch (e) {
      throw SandboxException('Connect-RPC 请求失败: ${e.message}', cause: e);
    }
  }

  /// 发起 Server Streaming Connect-RPC 请求。
  ///
  /// Connect 协议要求流式方法的请求体必须是信封帧
  /// (1 字节 flags + 4 字节大端长度 + JSON),Content-Type 为 application/connect+json。
  Stream<ConnectFrame> serverStreamCall({
    required String sandboxId,
    required String path,
    required Map<String, dynamic> request,
    CancelToken? cancelToken,
    String? user,
  }) async* {
    final url = '${config.getSandboxEnvdUrl(sandboxId)}$path';
    final headers = config.getEnvdHeaders(
      sandboxId: sandboxId,
      streaming: true,
      user: user,
    );

    try {
      final res = await _dio.post<ResponseBody>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          validateStatus: (status) => status != null && status < 300,
          // 长命令(如安装依赖)可能长时间无输出,放宽帧间隔超时
          receiveTimeout: const Duration(minutes: 10),
        ),
        data: Uint8List.fromList(encodeFrame(request)),
        cancelToken: cancelToken,
      );

      final stream = res.data?.stream;
      if (stream == null) return;

      final buffer = BytesBuilder();
      await for (final chunk in stream) {
        buffer.add(chunk);
        final currentBytes = buffer.toBytes();
        final frames = decodeFrames(currentBytes);

        if (frames.isNotEmpty) {
          // 计算已完全消费的字节偏移
          int consumedLen = 0;
          for (final f in frames) {
            consumedLen += 5 + f.payload.length;
            yield f;
          }
          buffer.clear();
          if (consumedLen < currentBytes.length) {
            buffer.add(currentBytes.sublist(consumedLen));
          }
        }
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      final status = e.response?.statusCode;
      if (status != null) {
        _throwForStatus(status, sandboxId, path);
      }
      throw SandboxException('Connect-RPC 流式请求失败: ${e.message}', cause: e);
    }
  }

  /// 按 HTTP 状态映射 envd 错误。所有非 2xx 都必须进入错误解析，
  /// 不能把 400/409/429 等错误响应当作成功。
  void _throwForStatus(int? statusCode, String sandboxId, String path) {
    if (statusCode == null) return;
    if (statusCode >= 200 && statusCode < 300) return;
    if (statusCode == 401 || statusCode == 403) {
      throw SandboxAuthenticationException(
        'envd 鉴权失败 (HTTP $statusCode), X-Access-Token 无效或缺失: $path',
      );
    }
    if (statusCode == 404) {
      throw SandboxNotFoundException('沙盒 $sandboxId 未找到或已终止 (404): $path');
    }
    if (statusCode == 409) {
      throw SandboxException(
        'envd 请求冲突 (HTTP 409): $path',
        statusCode: statusCode,
      );
    }
    if (statusCode == 429) {
      throw SandboxException(
        'envd 请求被限流 (HTTP 429): $path',
        statusCode: statusCode,
      );
    }
    if (statusCode >= 400 && statusCode < 500) {
      throw SandboxException(
        'envd 请求无效 (HTTP $statusCode): $path',
        statusCode: statusCode,
      );
    }
    if (statusCode >= 500) {
      throw SandboxException(
        'envd 服务异常 (HTTP $statusCode): $path',
        statusCode: statusCode,
      );
    }
  }
}
