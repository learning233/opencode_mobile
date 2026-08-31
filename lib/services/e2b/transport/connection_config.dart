import 'dart:convert';

class ConnectionConfig {
  final String apiKey;
  final String domain;
  final String apiUrl;

  /// JS SDK 风格的稳定代理域(https://sandbox.{domain})。
  /// 仅当显式传入时作为 envd Base URL 覆盖默认的直连域名路由。
  final String? sandboxUrl;
  final String? envdAccessToken;
  final String? sandboxId;

  const ConnectionConfig({
    required this.apiKey,
    this.domain = 'e2b.app',
    String? apiUrl,
    this.sandboxUrl,
    this.envdAccessToken,
    this.sandboxId,
  }) : apiUrl = apiUrl ?? 'https://api.$domain';

  /// 获取指定沙盒内部 envd 数据面网关的 Base URL。
  ///
  /// 默认走与业务端口同机制的直连域名路由 https://{port}-{sandboxId}.{domain}
  /// (边缘网关按主机名路由,与 4096-{sandboxId} 一致)。
  /// 显式传入 sandboxUrl 时以自定义地址为准。
  String getSandboxEnvdUrl(String sandboxId, {int port = 49983}) {
    final override = sandboxUrl;
    if (override != null && override.isNotEmpty) {
      return override.endsWith('/')
          ? override.substring(0, override.length - 1)
          : override;
    }
    return 'https://$port-$sandboxId.$domain';
  }

  /// 获取沙盒公开暴露的端口的主机名
  String getHost(String sandboxId, int port) {
    return '$port-$sandboxId.$domain';
  }

  /// 获取沙盒公开暴露的端口完整 HTTPS URL
  String getHostUrl(String sandboxId, int port) {
    return 'https://${getHost(sandboxId, port)}';
  }

  /// 构造向 envd 数据面发起请求的基础 Header。
  ///
  /// Connect 协议要求 unary 与 streaming 的 Content-Type 不同:
  /// unary 走 application/json(裸 JSON),streaming 走 application/connect+json(信封帧)。
  /// [streaming] 为 true 时额外携带 Keepalive-Ping-Interval 长流心跳。
  Map<String, String> getEnvdHeaders({
    required String sandboxId,
    int port = 49983,
    bool streaming = false,
    String? user,
  }) {
    return {
      'Connect-Protocol-Version': '1',
      'Content-Type': streaming
          ? 'application/connect+json'
          : 'application/json',
      'E2b-Sandbox-Id': sandboxId,
      'E2b-Sandbox-Port': port.toString(),
      if (envdAccessToken != null && envdAccessToken!.isNotEmpty)
        'X-Access-Token': envdAccessToken!
      else if (apiKey.isNotEmpty)
        'X-API-Key': apiKey,
      // 官方用 Basic header 传递执行用户(process 请求体里没有 user 字段)
      if (user != null && user.isNotEmpty)
        'Authorization': 'Basic ${base64Encode(utf8.encode('$user:'))}',
      if (streaming) 'Keepalive-Ping-Interval': '50',
    };
  }

  /// 构造控制面 REST API 请求的基础 Header
  Map<String, String> getApiHeaders() {
    return {
      'Content-Type': 'application/json',
      'X-API-Key': apiKey,
    };
  }
}
