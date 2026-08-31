import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// 记录请求并返回预设响应的 Dio HttpClientAdapter 假实现(测试用)
class CapturedRequest {
  CapturedRequest(this.options, this.body);

  final RequestOptions options;
  final List<int> body;

  /// 按大小写不敏感取请求头
  String? header(String name) {
    for (final entry in options.headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) {
        return entry.value?.toString();
      }
    }
    return null;
  }
}

class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options, List<int> body)
  handler;

  final List<CapturedRequest> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bodyBytes = <int>[];
    await requestStream?.forEach(bodyBytes.addAll);
    requests.add(CapturedRequest(options, bodyBytes));
    return handler(options, bodyBytes);
  }

  @override
  void close({bool force = false}) {}
}

/// 用 Connect 信封帧编码一串 server-streaming 事件,并追加结束帧
Uint8List framedEvents(List<Map<String, dynamic>> events) {
  final builder = BytesBuilder();
  for (final e in events) {
    builder.add(ConnectTransportFrameHelper.encode(e));
  }
  builder.add(ConnectTransportFrameHelper.encodeEnd());
  return builder.toBytes();
}

/// 避免直接依赖被测实现的便捷封装
class ConnectTransportFrameHelper {
  static Uint8List encode(Map<String, dynamic> data) {
    final payload = utf8.encode(jsonEncode(data));
    final header = Uint8List(5);
    header[0] = 0x00;
    header[1] = (payload.length >> 24) & 0xFF;
    header[2] = (payload.length >> 16) & 0xFF;
    header[3] = (payload.length >> 8) & 0xFF;
    header[4] = payload.length & 0xFF;
    final b = BytesBuilder();
    b.add(header);
    b.add(payload);
    return b.toBytes();
  }

  static Uint8List encodeEnd() {
    final payload = utf8.encode('{}');
    final header = Uint8List(5);
    header[0] = 0x02;
    header[1] = 0;
    header[2] = 0;
    header[3] = 0;
    header[4] = payload.length;
    final b = BytesBuilder();
    b.add(header);
    b.add(payload);
    return b.toBytes();
  }
}
