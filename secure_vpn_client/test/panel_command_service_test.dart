import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secure_vpn_client/models/panel_command.dart';
import 'package:secure_vpn_client/services/panel_command_service.dart';
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

  group('PanelCommandParser', () {
    test('parses single refresh_config command', () {
      final commands = PanelCommandParser.parsePayload({
        'seq': 3,
        'command': 'refresh_config',
      });
      expect(commands, hasLength(1));
      expect(commands.first.seq, 3);
      expect(commands.first.type, PanelCommandType.refreshConfig);
    });

    test('parses commands array with switch_server payload', () {
      final commands = PanelCommandParser.parsePayload({
        'commands': [
          {
            'seq': 2,
            'type': 'switch_server',
            'payload': {'server_index': 4, 'server_name': 'EU-1'},
          },
        ],
      });
      expect(commands, hasLength(1));
      expect(commands.first.type, PanelCommandType.switchServer);
      expect(commands.first.serverIndex, 4);
      expect(commands.first.serverName, 'EU-1');
    });

    test('parses disconnect from list body', () {
      final commands = PanelCommandParser.parsePayload([
        {'seq': 1, 'command': 'disconnect'},
      ]);
      expect(commands.single.type, PanelCommandType.disconnect);
    });
  });

  group('PanelCommandDispatcher', () {
    test('dispatches handlers in seq order and skips duplicates', () async {
      final events = <String>[];
      final dispatcher = PanelCommandDispatcher(
        onRefreshConfig: () async => events.add('refresh'),
        onDisconnect: () async => events.add('disconnect'),
        onSwitchServer: ({serverIndex, serverName}) async =>
            events.add('switch:$serverIndex'),
      );

      await dispatcher.dispatchAll([
        const PanelCommand(seq: 2, type: PanelCommandType.disconnect),
        const PanelCommand(seq: 1, type: PanelCommandType.refreshConfig),
        const PanelCommand(seq: 1, type: PanelCommandType.refreshConfig),
      ]);

      expect(events, ['refresh', 'disconnect']);
      expect(dispatcher.lastSeq, 2);
    });

    test('switch_server forwards payload fields', () async {
      int? index;
      String? name;
      final dispatcher = PanelCommandDispatcher(
        onRefreshConfig: () async {},
        onDisconnect: () async {},
        onSwitchServer: ({serverIndex, serverName}) async {
          index = serverIndex;
          name = serverName;
        },
      );

      await dispatcher.dispatch(
        const PanelCommand(
          seq: 5,
          type: PanelCommandType.switchServer,
          payload: {'server_index': 7, 'server_name': 'US-West'},
        ),
      );

      expect(index, 7);
      expect(name, 'US-West');
    });
  });

  group('PanelCommandService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    PanelManager configuredManager() {
      prefs.setString(
        'panel_settings_v1',
        jsonEncode({
          'panelUrl': 'https://panel.example',
          'deviceToken': 'dev-token',
          'enabled': true,
        }),
      );
      return _manager(
        prefs: prefs,
        tokenStorage: InMemoryPanelTokenStorage()..token = 'dev-token',
      );
    }

    test('start is no-op when panel is not configured', () async {
      final manager = _manager(prefs: prefs);
      await manager.load();
      final service = PanelCommandService(panelManager: manager, preferences: prefs);

      await service.start((
        onRefreshConfig: () async {},
        onDisconnect: () async {},
        onSwitchServer: ({serverIndex, serverName}) async {},
      ));

      expect(service.isStarted, isFalse);
    });

    test('long poll dispatches refresh_config command', () async {
      final manager = configuredManager();
      await manager.load();

      var refreshed = false;
      final service = PanelCommandService(
        panelManager: manager,
        preferences: prefs,
        dispatcher: PanelCommandDispatcher(
          onRefreshConfig: () async => refreshed = true,
          onDisconnect: () async {},
          onSwitchServer: ({serverIndex, serverName}) async {},
        ),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/client/commands');
          expect(request.url.queryParameters['last_seq'], '0');
          expect(request.headers['Authorization'], 'Bearer dev-token');
          return http.Response(
            jsonEncode({
              'commands': [
                {'seq': 1, 'command': 'refresh_config'},
              ],
            }),
            200,
          );
        }),
      );

      await service.longPollOnceForTest();
      expect(refreshed, isTrue);
      expect(prefs.getInt('panel_commands_last_seq_v1'), 1);
    });

    test('websocket payload dispatches disconnect', () async {
      final manager = configuredManager();
      await manager.load();

      var disconnected = false;
      final service = PanelCommandService(
        panelManager: manager,
        preferences: prefs,
        dispatcher: PanelCommandDispatcher(
          onRefreshConfig: () async {},
          onDisconnect: () async => disconnected = true,
          onSwitchServer: ({serverIndex, serverName}) async {},
        ),
      );

      await service.handlePayloadForTest({
        'seq': 9,
        'command': 'disconnect',
      });

      expect(disconnected, isTrue);
      expect(prefs.getInt('panel_commands_last_seq_v1'), 9);
    });
  });
}
