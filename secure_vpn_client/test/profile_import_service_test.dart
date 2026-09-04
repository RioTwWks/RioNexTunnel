import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/profile.dart';
import 'package:secure_vpn_client/services/profile_import_service.dart';

void main() {
  group('ProfileImportService', () {
    final service = ProfileImportService();
    const vless =
        'vless://11111111-2222-3333-4444-555555555555@example.com:443?security=tls';

    test('parses config links and subscriptions', () {
      final candidates = service.parseText('''
$vless
https://panel.example.com/sub/abc
invalid
''');
      expect(candidates, hasLength(2));
      expect(candidates.first.type, ProfileType.link);
      expect(candidates.last.type, ProfileType.subscription);
    });

    test('isSubscriptionUrl accepts http(s) only', () {
      expect(ProfileImportService.isSubscriptionUrl('https://example.com/sub'), isTrue);
      expect(ProfileImportService.isSubscriptionUrl('vless://example.com'), isFalse);
    });

    test('suggestName uses host when available', () {
      expect(
        ProfileImportService.suggestName('https://panel.example.com/sub', ProfileType.subscription),
        'panel.example.com',
      );
    });
  });
}
