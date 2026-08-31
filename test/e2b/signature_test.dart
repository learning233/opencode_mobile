import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/e2b/e2b.dart';

void main() {
  group('Signature Engine Tests (Replicated from signing.test.ts)', () {
    test('generate signature with expiration', () {
      final res = E2bSignature.getSignature(
        path: '/home/user/workspace/app.py',
        operation: 'read',
        user: 'user',
        expirationInSeconds: 600,
        envdAccessToken: 'access_token_12345',
      );

      expect(res.signature.startsWith('v1_'), isTrue);
      expect(res.signature.contains('='), isFalse); // Base64 unpadded
      expect(res.expiration, isNotNull);
      expect(res.expiration! > 0, isTrue);
    });

    test('generate signature without expiration', () {
      final res = E2bSignature.getSignature(
        path: 'data.json',
        operation: 'write',
        envdAccessToken: 'token_xyz',
      );

      expect(res.signature.startsWith('v1_'), isTrue);
      expect(res.expiration, isNull);
    });

    test('deterministic signature for identical inputs and no expiration', () {
      final res1 = E2bSignature.getSignature(
        path: 'test.txt',
        operation: 'read',
        user: 'user',
        envdAccessToken: 'fixed_token',
      );

      final res2 = E2bSignature.getSignature(
        path: 'test.txt',
        operation: 'read',
        user: 'user',
        envdAccessToken: 'fixed_token',
      );

      expect(res1.signature, equals(res2.signature));
    });

    test('different operation produces distinct signature', () {
      final readSig = E2bSignature.getSignature(
        path: 'test.txt',
        operation: 'read',
        user: 'user',
        envdAccessToken: 'fixed_token',
      );

      final writeSig = E2bSignature.getSignature(
        path: 'test.txt',
        operation: 'write',
        user: 'user',
        envdAccessToken: 'fixed_token',
      );

      expect(readSig.signature, isNot(equals(writeSig.signature)));
    });

    test('throws ArgumentError if envdAccessToken is empty', () {
      expect(
        () => E2bSignature.getSignature(
          path: '/path',
          operation: 'read',
          envdAccessToken: '',
        ),
        throwsArgumentError,
      );
    });
  });
}
