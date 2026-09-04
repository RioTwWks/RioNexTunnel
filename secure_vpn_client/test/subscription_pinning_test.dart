import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:secure_vpn_client/models/pinning_config.dart';
import 'package:secure_vpn_client/utils/subscription_http_client.dart';

void main() {
  group('SubscriptionSpki', () {
    test('normalizePin strips sha256/ prefix', () {
      expect(
        SubscriptionSpki.normalizePin('sha256/abc123='),
        'abc123=',
      );
    });

    test('isValidPinFormat accepts 32-byte base64 digest', () {
      final pin = base64.encode(List<int>.filled(32, 7));
      expect(SubscriptionSpki.isValidPinFormat(pin), isTrue);
      expect(SubscriptionSpki.isValidPinFormat('too-short'), isFalse);
    });
  });

  group('PinningConfig', () {
    test('disabled by default and round-trips storage JSON', () {
      expect(PinningConfig.disabled.enabled, isFalse);
      const config = PinningConfig(
        enabled: true,
        pinsByHost: {
          'panel.example.com': ['abc123=='],
        },
      );
      final restored = PinningConfig.fromStorage(config.toStorageJson());
      expect(restored.enabled, isTrue);
      expect(restored.pinsByHost['panel.example.com'], ['abc123==']);
    });

    test('shouldPinHost only when enabled and pins exist', () {
      const config = PinningConfig(
        enabled: true,
        pinsByHost: {'panel.example.com': ['abc123==']},
      );
      expect(config.shouldPinHost('panel.example.com'), isTrue);
      expect(config.shouldPinHost('other.example.com'), isFalse);
      expect(
        const PinningConfig(enabled: true).shouldPinHost('panel.example.com'),
        isFalse,
      );
    });
  });

  group('SubscriptionHttpClient SPKI', () {
    late Uint8List certDer;
    late String expectedSpkiPin;

    setUpAll(() async {
      final certPem = await File('test/fixtures/pinning/test_cert.pem')
          .readAsString();
      certDer = _decodePemCertificateDer(certPem);
      expectedSpkiPin =
          (await File('test/fixtures/pinning/test_spki_sha256.base64')
                  .readAsString())
              .trim();
    });

    test('computes SPKI SHA-256 base64 from certificate DER', () {
      expect(
        SubscriptionHttpClient.spkiSha256Base64FromDer(certDer),
        expectedSpkiPin,
      );
    });

    test('certificateMatchesPins accepts normalized pins', () {
      final cert = _FakeX509Certificate(certDer);
      expect(
        SubscriptionHttpClient.certificateMatchesPins(cert, [
          expectedSpkiPin,
          'sha256/$expectedSpkiPin',
        ]),
        isTrue,
      );
      expect(
        SubscriptionHttpClient.certificateMatchesPins(cert, [
          base64.encode(List<int>.filled(32, 1)),
        ]),
        isFalse,
      );
    });
  });

  group('SubscriptionHttpClient fetch', () {
    late SecurityContext serverContext;
    late String spkiPin;
    late HttpServer server;
    late int port;

    setUpAll(() async {
      final certBytes =
          await File('test/fixtures/pinning/test_cert.pem').readAsBytes();
      final keyBytes =
          await File('test/fixtures/pinning/test_key.pem').readAsBytes();
      serverContext = SecurityContext()
        ..useCertificateChainBytes(certBytes)
        ..usePrivateKeyBytes(keyBytes);
      spkiPin = (await File('test/fixtures/pinning/test_spki_sha256.base64')
              .readAsString())
          .trim();
    });

    setUp(() async {
      server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        serverContext,
      );
      server.listen((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..write(
            'vless://00000000-0000-0000-0000-000000000001@127.0.0.1:443?security=none#test',
          )
          ..close();
      });
      port = server.port;
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('succeeds when SPKI pin matches self-signed cert', () async {
      final client = SubscriptionHttpClient(plainClient: http.Client());
      final uri = Uri.parse('https://127.0.0.1:$port/sub');
      final response = await client.get(
        uri,
        headers: const {'Accept-Encoding': 'identity'},
        pinning: PinningConfig(
          enabled: true,
          pinsByHost: {'127.0.0.1': [spkiPin]},
        ),
      );
      expect(response.statusCode, 200);
      expect(response.body, contains('vless://'));
      client.close();
    });

    test('fails when SPKI pin does not match', () async {
      final client = SubscriptionHttpClient(plainClient: http.Client());
      final uri = Uri.parse('https://127.0.0.1:$port/sub');
      expect(
        () => client.get(
          uri,
          headers: const {'Accept-Encoding': 'identity'},
          pinning: PinningConfig(
            enabled: true,
            pinsByHost: {
              '127.0.0.1': [base64.encode(List<int>.filled(32, 9))],
            },
          ),
        ),
        throwsA(isA<SubscriptionPinningException>()),
      );
      client.close();
    });

    test('uses plain client when pinning disabled', () async {
      final mock = MockClient((request) async {
        return http.Response('vless://plain-client', 200);
      });
      final client = SubscriptionHttpClient(plainClient: mock);
      final response = await client.get(
        Uri.parse('https://example.com/sub'),
        headers: const {'Accept-Encoding': 'identity'},
        pinning: PinningConfig.disabled,
      );
      expect(response.statusCode, 200);
      expect(response.body, contains('vless://'));
      client.close();
    });
  });
}

Uint8List _decodePemCertificateDer(String pem) {
  final base64Body = pem
      .replaceAll('-----BEGIN CERTIFICATE-----', '')
      .replaceAll('-----END CERTIFICATE-----', '')
      .replaceAll('\n', '')
      .trim();
  return Uint8List.fromList(base64.decode(base64Body));
}

class _FakeX509Certificate implements X509Certificate {
  _FakeX509Certificate(this.derBytes);

  final Uint8List derBytes;

  @override
  Uint8List get der => derBytes;

  @override
  String get pem => throw UnimplementedError();

  @override
  Uint8List get sha1 => throw UnimplementedError();

  @override
  String get subject => 'CN=localhost';

  @override
  String get issuer => 'CN=localhost';

  @override
  DateTime get startValidity => DateTime(2025);

  @override
  DateTime get endValidity => DateTime(2027);
}
