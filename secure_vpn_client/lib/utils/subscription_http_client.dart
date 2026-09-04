import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/pinning_config.dart';

class SubscriptionPinningException implements Exception {
  SubscriptionPinningException(this.message);
  final String message;
  @override
  String toString() => 'SubscriptionPinningException: $message';
}

typedef HttpClientFactory = HttpClient Function();

class SubscriptionHttpClient {
  SubscriptionHttpClient({http.Client? plainClient, HttpClientFactory? pinnedClientFactory})
      : _plainClient = plainClient ?? http.Client(),
        _pinnedClientFactory = pinnedClientFactory ?? _defaultPinnedClient;

  final http.Client _plainClient;
  final HttpClientFactory _pinnedClientFactory;

  static HttpClient _defaultPinnedClient() =>
      HttpClient(context: SecurityContext(withTrustedRoots: false));

  Future<http.Response> get(Uri uri, {required Map<String, String> headers, PinningConfig? pinning}) async {
    if (kIsWeb) {
      if (pinning?.shouldPinHost(uri.host) ?? false) {
        throw SubscriptionPinningException('Certificate pinning is not supported on web');
      }
      return _plainClient.get(uri, headers: headers);
    }
    final allowedPins = pinning?.pinsForHost(uri.host);
    if (!(pinning?.shouldPinHost(uri.host) ?? false) || allowedPins == null || allowedPins.isEmpty) {
      return _plainClient.get(uri, headers: headers);
    }
    return _getWithPinning(uri, headers: headers, allowedPins: allowedPins);
  }

  Future<http.Response> _getWithPinning(Uri uri, {required Map<String, String> headers, required List<String> allowedPins}) async {
    final client = _pinnedClientFactory();
    client.badCertificateCallback = (cert, host, port) => certificateMatchesPins(cert, allowedPins);
    try {
      final request = await client.getUrl(uri);
      headers.forEach(request.headers.set);
      final response = await request.close();
      final bodyBytes = await response.fold<BytesBuilder>(BytesBuilder(copy: false), (b, c) => b..add(c));
      return http.Response(utf8.decode(bodyBytes.takeBytes(), allowMalformed: true), response.statusCode,
          headers: _normalizeHeaders(response.headers), request: http.Request('GET', uri));
    } on HandshakeException {
      throw SubscriptionPinningException('Certificate pin mismatch for ${uri.host}');
    } on TlsException {
      throw SubscriptionPinningException('Certificate pin mismatch for ${uri.host}');
    } finally {
      client.close(force: true);
    }
  }

  static bool certificateMatchesPins(X509Certificate cert, List<String> allowedPins) {
    final spki = spkiSha256Base64(cert);
    return allowedPins.map(SubscriptionSpki.normalizePin).toSet().contains(spki);
  }

  static String spkiSha256Base64(X509Certificate cert) => spkiSha256Base64FromDer(cert.der);

  static String spkiSha256Base64FromDer(Uint8List certDer) {
    final top = ASN1Parser(certDer).nextObject() as ASN1Sequence;
    final tbs = top.elements[0] as ASN1Sequence;
    final spki = (tbs.elements.first.tag == 0xA0 ? tbs.elements[6] : tbs.elements[5]) as ASN1Sequence;
    return base64.encode(sha256.convert(Uint8List.fromList(spki.encodedBytes)).bytes);
  }

  static Map<String, String> _normalizeHeaders(HttpHeaders headers) {
    final out = <String, String>{};
    headers.forEach((n, v) => out[n] = v.join(','));
    return out;
  }

  void close() => _plainClient.close();
}
