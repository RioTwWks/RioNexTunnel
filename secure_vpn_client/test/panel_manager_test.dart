import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secure_vpn_client/services/panel_manager.dart';
import 'package:secure_vpn_client/services/panel_token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

PanelManager _manager({
  required SharedPreferences prefs,
  http.Client? httpClient,
  InMemoryPanelTokenStorage? tokenStorage,
}) =>
    PanelManager(
      preferences: prefs,
      httpClient: httpClient,
      tokenStorage: tokenStorage ?? InMemoryPanelTokenStorage(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PanelManager', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('is no-op when panel is not configured', () async {
      final manager = _manager(prefs: prefs);
      await manager.load();

      expect(manager.isActive, isFalse);
      expect(await manager.syncConfig(), isNull);
      await manager.flushStats();
      await manager.enqueueStats(
        const PanelStatsPayload(
          sessionId: 's1',
          bytesIn: 1,
          bytesOut: 2,
          status: 'started',
        ),
      );
      expect(prefs.getString('panel_stats_queue_v1'), isNull);
    });

    test('register stores device token in secure storage', () async {
      final tokenStorage = InMemoryPanelTokenStorage();
      final manager = _manager(
        prefs: prefs,
        tokenStorage: tokenStorage,
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/client/register');
          expect(request.headers['X-API-Version'], 'v1');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['pairing_token'], 'pair-123');
          return http.Response(
            jsonEncode({
              'device_token': 'dev-token-abc',
              'subscription_url': 'https://panel.example/sub/token',
              'config_hash': 'hash-1',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await manager.load();
      await manager.updatePanelUrl('https://panel.example');
      await manager.setEnabled(true);

      final result = await manager.register(pairingToken: 'pair-123');

      expect(result.deviceToken, 'dev-token-abc');
      expect(result.subscriptionUrl, 'https://panel.example/sub/token');
      expect(manager.settings.deviceToken, 'dev-token-abc');
      expect(tokenStorage.token, 'dev-token-abc');
      final persisted = jsonDecode(prefs.getString('panel_settings_v1')!) as Map;
      expect(persisted.containsKey('deviceToken'), isFalse);
      expect(manager.settings.subscriptionUrl, 'https://panel.example/sub/token');
      expect(manager.syncStatus.name, 'synced');
    });

    test('syncConfig skips rewrite when config_hash unchanged', () async {
      var configCalls = 0;
      final tokenStorage = InMemoryPanelTokenStorage()..token = 'dev-token';
      final manager = _manager(
        prefs: prefs,
        tokenStorage: tokenStorage,
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/client/config') {
            configCalls++;
            expect(request.headers['Authorization'], 'Bearer dev-token');
            return http.Response(
              jsonEncode({'config_hash': 'same-hash'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('not found', 404);
        }),
      );
      await manager.load();
      prefs.setString(
        'panel_settings_v1',
        jsonEncode({
          'panelUrl': 'https://panel.example',
          'deviceToken': 'dev-token',
          'enabled': true,
          'configHash': 'same-hash',
        }),
      );
      await manager.load();

      final result = await manager.syncConfig();
      expect(result?.configHash, 'same-hash');
      expect(configCalls, 1);
      expect(prefs.containsKey('panel_cached_config_v1'), isFalse);
    });

    test('syncConfig caches config when hash changes', () async {
      final tokenStorage = InMemoryPanelTokenStorage()..token = 'dev-token';
      final manager = _manager(
        prefs: prefs,
        tokenStorage: tokenStorage,
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'config_hash': 'hash-2',
              'config': {'outbounds': []},
              'subscription_url': 'https://panel.example/sub/new',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await manager.load();
      prefs.setString(
        'panel_settings_v1',
        jsonEncode({
          'panelUrl': 'https://panel.example',
          'deviceToken': 'dev-token',
          'enabled': true,
          'configHash': 'hash-1',
        }),
      );
      await manager.load();

      final result = await manager.syncConfig(force: true);
      expect(result?.configHash, 'hash-2');
      expect(await manager.loadCachedConfig(), isNotNull);
      expect(manager.settings.subscriptionUrl, 'https://panel.example/sub/new');
    });

    test('flushStats uploads queued entries', () async {
      String? postedBody;
      final tokenStorage = InMemoryPanelTokenStorage()..token = 'dev-token';
      final manager = _manager(
        prefs: prefs,
        tokenStorage: tokenStorage,
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/client/stats') {
            postedBody = request.body;
            return http.Response('{"ok":true}', 200);
          }
          return http.Response('not found', 404);
        }),
      );
      await manager.load();
      prefs.setString(
        'panel_settings_v1',
        jsonEncode({
          'panelUrl': 'https://panel.example',
          'deviceToken': 'dev-token',
          'enabled': true,
        }),
      );
      await manager.load();
      await manager.enqueueStats(
        const PanelStatsPayload(
          sessionId: 'sess-1',
          bytesIn: 100,
          bytesOut: 200,
          status: 'stopped',
        ),
      );

      await manager.flushStats();

      expect(postedBody, isNotNull);
      final decoded = jsonDecode(postedBody!) as Map<String, dynamic>;
      final entries = decoded['entries'] as List<dynamic>;
      expect(entries, hasLength(1));
      expect(entries.first['session_id'], 'sess-1');
      expect(prefs.getString('panel_stats_queue_v1'), isNull);
    });

    test('normalizePanelUrl adds https and trims slash', () {
      expect(
        PanelManager.normalizePanelUrlForTest('panel.example/'),
        'https://panel.example',
      );
    });
  });
}
