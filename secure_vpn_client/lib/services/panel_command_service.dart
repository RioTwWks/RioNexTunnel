import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/panel_command.dart';
import '../models/panel_settings.dart';
import 'app_log.dart';
import 'panel_manager.dart';

typedef PanelWebSocketConnector =
    Future<WebSocketChannel> Function(Uri uri, Map<String, String> headers);

typedef PanelCommandHandlers = ({
  Future<void> Function() onRefreshConfig,
  Future<void> Function() onDisconnect,
  Future<void> Function({int? serverIndex, String? serverName}) onSwitchServer,
});

/// Dispatches parsed panel commands to app callbacks.
class PanelCommandDispatcher {
  PanelCommandDispatcher({
    required Future<void> Function() onRefreshConfig,
    required Future<void> Function() onDisconnect,
    required Future<void> Function({int? serverIndex, String? serverName})
    onSwitchServer,
  }) : _handlers = (
         onRefreshConfig: onRefreshConfig,
         onDisconnect: onDisconnect,
         onSwitchServer: onSwitchServer,
       );

  final PanelCommandHandlers _handlers;
  int _lastSeq = 0;
  bool _busy = false;

  int get lastSeq => _lastSeq;

  @visibleForTesting
  void setLastSeqForTest(int value) => _lastSeq = value;

  Future<void> dispatchAll(List<PanelCommand> commands) async {
    if (commands.isEmpty) {
      return;
    }
    final sorted = [...commands]..sort((a, b) => a.seq.compareTo(b.seq));
    for (final command in sorted) {
      if (command.seq > 0 && command.seq <= _lastSeq) {
        continue;
      }
      await dispatch(command);
      if (command.seq > _lastSeq) {
        _lastSeq = command.seq;
      }
    }
  }

  Future<void> dispatch(PanelCommand command) async {
    if (_busy) {
      AppLog.warn('Panel command ignored while another command runs');
      return;
    }
    _busy = true;
    try {
      AppLog.info('Panel command received type=${command.type.name}');
      switch (command.type) {
        case PanelCommandType.refreshConfig:
          await _handlers.onRefreshConfig();
        case PanelCommandType.disconnect:
          await _handlers.onDisconnect();
        case PanelCommandType.switchServer:
          await _handlers.onSwitchServer(
            serverIndex: command.serverIndex,
            serverName: command.serverName,
          );
        case PanelCommandType.unknown:
          AppLog.warn('Panel command ignored: unknown type');
      }
      if (command.seq > _lastSeq) {
        _lastSeq = command.seq;
      }
    } catch (error) {
      AppLog.warn('Panel command handler failed: $error');
    } finally {
      _busy = false;
    }
  }
}

/// Listens for RioNexGate remote commands via WebSocket with long-poll fallback.
class PanelCommandService {
  PanelCommandService({
    required PanelManager panelManager,
    http.Client? httpClient,
    PanelWebSocketConnector? webSocketConnector,
    SharedPreferences? preferences,
    Future<SharedPreferences> Function()? preferencesFactory,
    PanelCommandDispatcher? dispatcher,
    Duration longPollInterval = const Duration(minutes: 5),
    Duration webSocketReconnectDelay = const Duration(seconds: 30),
  }) : _panelManager = panelManager,
       _http = httpClient ?? http.Client(),
       _webSocketConnector = webSocketConnector ?? _defaultWebSocketConnector,
       _preferences = preferences,
       _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance,
       _dispatcher = dispatcher,
       _longPollInterval = longPollInterval,
       _webSocketReconnectDelay = webSocketReconnectDelay;

  static const _lastSeqKey = 'panel_commands_last_seq_v1';
  static const _apiVersionHeader = 'v1';
  static const _requestTimeout = Duration(seconds: 90);

  final PanelManager _panelManager;
  final http.Client _http;
  final PanelWebSocketConnector _webSocketConnector;
  final SharedPreferences? _preferences;
  final Future<SharedPreferences> Function() _preferencesFactory;
  final Duration _longPollInterval;
  final Duration _webSocketReconnectDelay;

  PanelCommandDispatcher? _dispatcher;
  WebSocketChannel? _webSocketChannel;
  StreamSubscription<dynamic>? _webSocketSubscription;
  Timer? _longPollTimer;
  Timer? _webSocketReconnectTimer;
  bool _started = false;
  bool _webSocketConnected = false;
  bool _stopRequested = false;
  int _lastSeq = 0;

  bool get isStarted => _started;

  Future<SharedPreferences> _prefs() async =>
      _preferences ?? await _preferencesFactory();

  Future<void> start(PanelCommandHandlers handlers) async {
    if (_started) {
      return;
    }
    if (!_panelManager.isActive) {
      return;
    }

    _dispatcher ??= PanelCommandDispatcher(
      onRefreshConfig: handlers.onRefreshConfig,
      onDisconnect: handlers.onDisconnect,
      onSwitchServer: handlers.onSwitchServer,
    );

    final prefs = await _prefs();
    _lastSeq = prefs.getInt(_lastSeqKey) ?? 0;
    _dispatcher!.setLastSeqForTest(_lastSeq);

    _started = true;
    _stopRequested = false;
    AppLog.info('Panel command listener starting (device=${_panelManager.deviceIdHash})');
    unawaited(_connectWebSocket());
    _scheduleLongPoll(immediate: true);
  }

  Future<void> stop() async {
    if (!_started) {
      return;
    }
    _stopRequested = true;
    _started = false;
    _longPollTimer?.cancel();
    _longPollTimer = null;
    _webSocketReconnectTimer?.cancel();
    _webSocketReconnectTimer = null;
    await _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    await _webSocketChannel?.sink.close();
    _webSocketChannel = null;
    _webSocketConnected = false;
    AppLog.info('Panel command listener stopped');
  }

  void dispose() {
    unawaited(stop());
    _http.close();
  }

  @visibleForTesting
  Future<void> handlePayloadForTest(dynamic decoded) async {
    final commands = PanelCommandParser.parsePayload(decoded);
    await _dispatcher?.dispatchAll(commands);
    await _persistLastSeq();
  }

  @visibleForTesting
  Future<void> longPollOnceForTest() => _longPoll();

  Future<void> _connectWebSocket() async {
    if (_stopRequested || !_started || !_panelManager.isActive) {
      return;
    }

    final settings = _panelManager.settings;
    final uri = _webSocketUri(settings);
    if (uri == null) {
      _scheduleWebSocketReconnect();
      return;
    }

    try {
      final channel = await _webSocketConnector(uri, _authHeaders(settings));
      if (_stopRequested) {
        await channel.sink.close();
        return;
      }

      _webSocketChannel = channel;
      _webSocketConnected = true;
      AppLog.info('Panel command WebSocket connected');

      _webSocketSubscription = channel.stream.listen(
        _onWebSocketMessage,
        onError: (Object error) {
          AppLog.warn('Panel command WebSocket error: $error');
          _onWebSocketClosed();
        },
        onDone: _onWebSocketClosed,
        cancelOnError: true,
      );
    } catch (error) {
      AppLog.warn('Panel command WebSocket connect failed: $error');
      _webSocketConnected = false;
      _scheduleWebSocketReconnect();
    }
  }

  void _onWebSocketClosed() {
    if (!_started || _stopRequested) {
      return;
    }
    _webSocketConnected = false;
    _webSocketSubscription = null;
    _webSocketChannel = null;
    _scheduleWebSocketReconnect();
  }

  void _scheduleWebSocketReconnect() {
    if (_stopRequested || !_started) {
      return;
    }
    _webSocketReconnectTimer?.cancel();
    _webSocketReconnectTimer = Timer(_webSocketReconnectDelay, () {
      unawaited(_connectWebSocket());
    });
  }

  Future<void> _onWebSocketMessage(dynamic message) async {
    if (message is! String) {
      return;
    }
    try {
      final decoded = jsonDecode(message);
      await handlePayloadForTest(decoded);
    } catch (error) {
      AppLog.warn('Panel command WebSocket message parse failed: $error');
    }
  }

  void _scheduleLongPoll({required bool immediate}) {
    if (_stopRequested || !_started) {
      return;
    }
    _longPollTimer?.cancel();
    final delay = immediate ? Duration.zero : _longPollInterval;
    _longPollTimer = Timer(delay, () async {
      if (_stopRequested || !_started) {
        return;
      }
      if (!_webSocketConnected) {
        await _longPoll();
      }
      _scheduleLongPoll(immediate: false);
    });
  }

  Future<void> _longPoll() async {
    if (!_panelManager.isActive) {
      return;
    }

    final settings = _panelManager.settings;
    final panelUrl = settings.panelUrl;
    final token = settings.deviceToken;
    if (panelUrl == null || token == null || token.isEmpty) {
      return;
    }

    final uri = Uri.parse('$panelUrl/api/client/commands').replace(
      queryParameters: {'last_seq': '$_lastSeq'},
    );
    final headers = _authHeaders(settings);

    try {
      final response = await _http
          .get(uri, headers: headers)
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        AppLog.warn(
          'Panel command long-poll failed (${response.statusCode})',
        );
        return;
      }
      if (response.body.trim().isEmpty) {
        return;
      }
      final decoded = jsonDecode(response.body);
      await handlePayloadForTest(decoded);

      final lastSeqRaw = decoded is Map
          ? (decoded['last_seq'] ?? decoded['next_seq'])
          : null;
      if (lastSeqRaw is int && lastSeqRaw > _lastSeq) {
        _lastSeq = lastSeqRaw;
        _dispatcher?.setLastSeqForTest(_lastSeq);
        await _persistLastSeq();
      }
    } on SocketException {
      AppLog.warn('Panel command long-poll offline');
    } on FormatException {
      AppLog.warn('Panel command long-poll returned invalid JSON');
    } catch (error) {
      AppLog.warn('Panel command long-poll failed: $error');
    }
  }

  Future<void> _persistLastSeq() async {
    final seq = _dispatcher?.lastSeq ?? _lastSeq;
    _lastSeq = seq;
    final prefs = await _prefs();
    await prefs.setInt(_lastSeqKey, seq);
  }

  Uri? _webSocketUri(PanelSettings settings) {
    final panelUrl = settings.panelUrl;
    final token = settings.deviceToken;
    if (panelUrl == null || token == null || token.isEmpty) {
      return null;
    }
    final base = Uri.parse(panelUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/api/client/commands',
      queryParameters: {'device_token': token},
    );
  }

  Map<String, String> _authHeaders(PanelSettings settings) {
    final token = settings.deviceToken ?? '';
    return {
      'Accept': 'application/json',
      'X-API-Version': _apiVersionHeader,
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<WebSocketChannel> _defaultWebSocketConnector(
    Uri uri,
    Map<String, String> headers,
  ) async {
    final channel = IOWebSocketChannel.connect(uri, headers: headers);
    return channel;
  }
}
