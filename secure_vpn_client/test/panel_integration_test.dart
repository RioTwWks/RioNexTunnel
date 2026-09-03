import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secure_vpn_client/models/panel_sync_status.dart';
import 'package:secure_vpn_client/models/profile.dart';
import 'package:secure_vpn_client/providers/panel_providers.dart';
import 'package:secure_vpn_client/providers/vpn_providers.dart';
import 'package:secure_vpn_client/services/panel_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory RioNexGate panel simulator for integration-style Dart tests.
class FakePanelServer {
  FakePanelServer({
    this.configHash = 'hash-v1',
    this.subscriptionUrl = 'https://panel.test/sub/v1',
    Map<String, dynamic>? config,
    this.pairingToken = 'pair-test',
  }) : config = config ?? {'outbounds': <Map<String, dynamic>>[]};

  static const panelBase = 'https://panel.test';

  String configHash;
  String subscriptionUrl;
  Map<String, dynamic> config;
  String pairingToken;
  String? deviceToken;
  bool online = true;

  final List<List<Map<String, dynamic>>> statsUploads = [];
  int configFetchCount = 0;
  int registerCount = 0;

  http.Client get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    if (!online) {
      throw const SocketException('panel offline');
    }

    switch (request.url.path) {
      case '/api/client/register':
        registerCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['pairing_token'] != pairingToken) {
          return http.Response('{"error":"invalid pairing"}', 401);
        }
        deviceToken = 'device-$registerCount';
        return _json({
          'device_token': deviceToken,
          'subscription_url': subscriptionUrl,
        });
      case '/api/client/config':
        configFetchCount++;
        if (deviceToken == null ||
            request.headers['Authorization'] != 'Bearer $deviceToken') {
          return http.Response('{"error":"unauthorized"}', 401);
        }
        return _json({
          'config_hash': configHash,
          'subscription_url': subscriptionUrl,
          'config': config,
        });
      case '/api/client/stats':
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        statsUploads.add(
          (decoded['entries'] as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
        return _json({'ok': true});
      default:
        return http.Response('not found', 404);
    }
  }

  http.Response _json(Map<String, dynamic> body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );
}

Future<PanelManager> _managerWithPrefs(
  SharedPreferences prefs,
  FakePanelServer server,
) async {
  final manager = PanelManager(preferences: prefs, httpClient: server.client);
  await manager.load();
  await manager.updatePanelUrl(FakePanelServer.panelBase);
  await manager.setEnabled(true);
  return manager;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Panel integration lifecycle', () {
    late SharedPreferences prefs;
    late FakePanelServer server;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      server = FakePanelServer();
    });

    test('register → config fetch → mock connect → stats queue → disconnect', () async {
      final manager = await _managerWithPrefs(prefs, server);

      final registered = await manager.register(pairingToken: server.pairingToken);
      expect(registered.deviceToken, isNotEmpty);
      expect(manager.settings.subscriptionUrl, server.subscriptionUrl);

      final synced = await manager.syncConfig();
      expect(synced?.configHash, server.configHash);
      expect(await manager.loadCachedConfig(), isNotNull);
      expect(server.configFetchCount, greaterThanOrEqualTo(1));

      const sessionId = 'sess-integration-1';
      await manager.enqueueStats(
        const PanelStatsPayload(
          sessionId: sessionId,
          bytesIn: 0,
          bytesOut: 0,
          status: 'started',
        ),
      );

      await manager.enqueueStats(
        const PanelStatsPayload(
          sessionId: sessionId,
          bytesIn: 4096,
          bytesOut: 8192,
          status: 'stopped',
        ),
      );

      await manager.flushStats();

      expect(server.statsUploads, hasLength(1));
      final uploaded = server.statsUploads.single;
      expect(uploaded, hasLength(2));
      expect(uploaded.first['session_id'], sessionId);
      expect(uploaded.first['status'], 'started');
      expect(uploaded.last['status'], 'stopped');
      expect(prefs.getString('panel_stats_queue_v1'), isNull);
      expect(manager.syncStatus, PanelSyncStatus.synced);
    });

    test('new config_hash refreshes cache without app restart', () async {
      final manager = await _managerWithPrefs(prefs, server);
      await manager.register(pairingToken: server.pairingToken);
      await manager.syncConfig();

      final cachedBefore = await manager.loadCachedConfig();
      expect(cachedBefore, isNotNull);
      expect(manager.settings.configHash, 'hash-v1');

      server.configHash = 'hash-v2';
      server.subscriptionUrl = 'https://panel.test/sub/v2';
      server.config = {
        'outbounds': [
          {'tag': 'proxy-v2'},
        ],
      };

      final refreshed = await manager.syncConfig();
      expect(refreshed?.configHash, 'hash-v2');
      expect(manager.settings.configHash, 'hash-v2');
      expect(manager.settings.subscriptionUrl, 'https://panel.test/sub/v2');

      final cachedAfter = await manager.loadCachedConfig();
      expect(cachedAfter?['outbounds'], isNotEmpty);
      expect(
        (cachedAfter!['outbounds'] as List).first['tag'],
        'proxy-v2',
      );
      expect(cachedAfter, isNot(equals(cachedBefore)));
      expect(manager.syncStatus, PanelSyncStatus.synced);
    });

    test('offline uses cached config and replays queued stats after restore', () async {
      final manager = await _managerWithPrefs(prefs, server);
      await manager.register(pairingToken: server.pairingToken);
      await manager.syncConfig();
      final cached = await manager.loadCachedConfig();
      expect(cached, isNotNull);

      server.online = false;
      await expectLater(manager.syncConfig(), throwsA(isA<SocketException>()));
      expect(manager.syncStatus, PanelSyncStatus.stale);
      expect(await manager.loadCachedConfig(), cached);

      await manager.enqueueStats(
        const PanelStatsPayload(
          sessionId: 'offline-sess',
          bytesIn: 100,
          bytesOut: 200,
          status: 'stopped',
        ),
      );
      await manager.flushStats();
      expect(server.statsUploads, isEmpty);
      expect(prefs.getString('panel_stats_queue_v1'), isNotNull);

      server.online = true;
      await manager.flushStats();
      expect(server.statsUploads, hasLength(1));
      expect(server.statsUploads.single.single['session_id'], 'offline-sess');
      expect(prefs.getString('panel_stats_queue_v1'), isNull);
      expect(manager.syncStatus, PanelSyncStatus.stale);
    });

    test('malformed config JSON keeps previous cache and does not throw', () async {
      final manager = await _managerWithPrefs(prefs, server);
      await manager.register(pairingToken: server.pairingToken);
      await manager.syncConfig();
      final goodCache = await manager.loadCachedConfig();
      expect(goodCache, isNotNull);
      final previousHash = manager.settings.configHash;

      final brokenClient = MockClient((request) async {
        if (request.url.path == '/api/client/config') {
          return http.Response(
            jsonEncode({
              'config_hash': 'hash-bad',
              'config': '{broken-json',
              'subscription_url': 'https://panel.test/sub/broken',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });
      final brokenManager = PanelManager(
        preferences: prefs,
        httpClient: brokenClient,
      );
      await brokenManager.load();

      PanelConfigResult? result;
      Object? caught;
      try {
        result = await brokenManager.syncConfig(force: true);
      } catch (error) {
        caught = error;
      }

      expect(caught, isNull);
      expect(result, isNotNull);
      expect(result!.configHash, previousHash);
      expect(await brokenManager.loadCachedConfig(), goodCache);
      expect(brokenManager.settings.configHash, previousHash);
      expect(brokenManager.settings.lastError, contains('Invalid config'));
      expect(brokenManager.syncStatus, PanelSyncStatus.stale);
    });

    test('unexpected config type keeps previous profile data', () async {
      final manager = await _managerWithPrefs(prefs, server);
      await manager.register(pairingToken: server.pairingToken);
      await manager.syncConfig();
      final previousUrl = manager.settings.subscriptionUrl;

      final brokenClient = MockClient((request) async {
        if (request.url.path == '/api/client/config') {
          return http.Response(
            jsonEncode({
              'config_hash': 'hash-bad-type',
              'config': ['not', 'a', 'map'],
              'subscription_url': 'https://panel.test/sub/broken',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });
      final brokenManager = PanelManager(
        preferences: prefs,
        httpClient: brokenClient,
      );
      await brokenManager.load();

      final result = await brokenManager.syncConfig(force: true);
      expect(result?.subscriptionUrl, previousUrl);
      expect(brokenManager.settings.configHash, 'hash-v1');
      expect(brokenManager.syncStatus, PanelSyncStatus.stale);
    });
  });

  group('Panel Riverpod integration', () {
    late SharedPreferences prefs;
    late FakePanelServer server;
    late PanelManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      server = FakePanelServer();
      manager = PanelManager(preferences: prefs, httpClient: server.client);
      await manager.load();
      await manager.updatePanelUrl(FakePanelServer.panelBase);
      await manager.setEnabled(true);
    });

    test('refreshConfig updates RioNexGate profile when hash changes', () async {
      final container = ProviderContainer(
        overrides: [
          panelManagerProvider.overrideWithValue(manager),
        ],
      );
      addTearDown(container.dispose);

      await container.read(panelBootstrapProvider.future);
      await container.read(panelStateProvider.notifier).register(
        server.pairingToken,
      );

      var profiles = container.read(profilesProvider);
      final panelProfile = profiles.singleWhere((p) => p.name == 'RioNexGate');
      expect(panelProfile.configLink, server.subscriptionUrl);

      server.configHash = 'hash-v3';
      server.subscriptionUrl = 'https://panel.test/sub/v3';

      await container.read(panelStateProvider.notifier).refreshConfig();

      profiles = container.read(profilesProvider);
      final updated = profiles.singleWhere((p) => p.name == 'RioNexGate');
      expect(updated.configLink, 'https://panel.test/sub/v3');
      expect(updated.type, ProfileType.subscription);
      expect(container.read(panelStateProvider).syncStatus, PanelSyncStatus.synced);
    });
  });
}
