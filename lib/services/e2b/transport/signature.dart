import 'dart:convert';
import 'package:crypto/crypto.dart';

/// E2B 文件访问临时签名生成器 (复制自 packages/js-sdk/src/sandbox/signature.ts)
class E2bSignature {
  /// 生成文件临时 URL 签名
  static ({String signature, int? expiration}) getSignature({
    required String path,
    required String operation, // 'read' | 'write'
    String user = '',
    int? expirationInSeconds,
    required String envdAccessToken,
  }) {
    if (envdAccessToken.isEmpty) {
      throw ArgumentError('Access token is required to generate signature');
    }

    final expiration = expirationInSeconds != null
        ? (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expirationInSeconds
        : null;

    final signatureRaw = expiration == null
        ? '$path:$operation:$user:$envdAccessToken'
        : '$path:$operation:$user:$envdAccessToken:$expiration';

    final bytes = utf8.encode(signatureRaw);
    final digest = sha256.convert(bytes);
    final base64Hash = base64.encode(digest.bytes).replaceAll('=', '');
    final signature = 'v1_$base64Hash';

    return (signature: signature, expiration: expiration);
  }
}
