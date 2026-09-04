import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/panel_settings.dart';
import '../models/panel_sync_interval.dart';
import '../models/panel_sync_status.dart';
import 'app_log.dart';
import 'panel_token_storage.dart';

class PanelRegisterResult {
  const PanelRegisterResult({
    required this.deviceToken,
    this.subscriptionUrl,
    this.configHash,
  });

  final String deviceToken;
  final String? subscriptionUrl;
  final String? configHash;
}

class PanelConfigResult {
  const PanelConfigResult({
    required this.configHash,
    this.configJson,
    this.subscriptionUrl,
  });

  final String configHash;
  final Map<String, dynamic>? configJson;
  final String? subscriptionUrl;
}

class PanelStatsPayload {
  const PanelStatsPayload({
    required this.sessionId,
    required this.bytesIn,
    required this.bytesOut,
    required this.status,
    this.sessions = 1,
  });

  final String sessionId;
  final int bytesIn;
  final int bytesOut;
  final String status;
  final int sessions;

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'bytes_in': bytesIn,
    'bytes_out': bytesOut,
    'status': status,
    'sessions': sessions,
  };
}

class PanelApiException implements Exception {
  PanelApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'PanelApiException($statusCode): $message';
}

class PanelManager {
  PanelManager({
    http.Client? httpClient,
    SharedPreferences? preferences,
    Future<SharedPreferences> Function()? preferencesFactory,
    PanelTokenStorage? tokenStorage,
  }) : _http = httpClient ?? http.Client(),
       _preferences = preferences,
       _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance,
       _tokenStorage = tokenStorage ?? SecurePanelTokenStorage();

  static const _settingsKey = 'panel_settings_v1';
  static const _cachedConfigKey = 'panel_cached_config_v1';
  static const _statsQueueKey = 'panel_stats_queue_v1';
  static const _deviceIdKey = 'panel_device_id_v1';
  static const _apiVersionHeader = 'v1';
  static const _maxRetries = 4;
  static const _requestTimeout = Duration(seconds: 20);

  final http.Client _http;
  final SharedPreferences? _preferences;
  final Future<SharedPreferences> Function() _preferencesFactory;
  final PanelTokenStorage _tokenStorage;

  PanelSettings _settings = const PanelSettings();
  PanelSyncStatus _syncStatus = PanelSyncStatus.disabled;
  String? _deviceIdHash;

  PanelSettings get settings => _settings;
  PanelSyncStatus get syncStatus => _syncStatus;

  Future<void> load() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_settingsKey);
    if (raw != null) {
      try {
        _settings = PanelSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (error) {
        AppLog.warn('Panel settings corrupt; resetting ($error)');
        _settings = const PanelSettings();
      }
    }
    await _loadDeviceToken();
    _deviceIdHash = await _loadDeviceIdHash(prefs);
    _syncStatus = _deriveStatus();
  }
  Future<void> _loadDeviceToken() async { final t=await _tokenStorage.readToken(); if(t!=null&&t.isNotEmpty){_settings=_settings.copyWith(deviceToken:t);return;} final l=_settings.deviceToken; if(l!=null&&l.isNotEmpty){await _tokenStorage.writeToken(l);await _persistSettings(_settings,persistToken:false);} }
  Future<void> _persistDeviceToken(String? t) async { if(t==null||t.isEmpty){await _tokenStorage.deleteToken();return;} await _tokenStorage.writeToken(t); }
  Future<SharedPreferences> _prefs() async =>
      _preferences ?? await _preferencesFactory();

  Future<String> _loadDeviceIdHash(SharedPreferences prefs) async {
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    return id.substring(0, 8);
  }

  String get deviceIdHash => _deviceIdHash ?? 'unknown';
  bool get isActive => _settings.isConfigured;

  PanelSyncStatus _deriveStatus() {
    if (!_settings.enabled || !_settings.isConfigured) {
      return PanelSyncStatus.disabled;
    }
    if (_settings.lastError != null) {
      return PanelSyncStatus.error;
    }
    if (_settings.lastSyncAt != null) {
      return PanelSyncStatus.synced;
    }
    return PanelSyncStatus.stale;
  }

  Future<void> _persistSettings(PanelSettings next,{PanelSyncStatus? syncStatus,bool persistToken=true}) async { if(persistToken) await _persistDeviceToken(next.deviceToken); _settings=next; final prefs=await _prefs(); await prefs.setString(_settingsKey,jsonEncode(_settings.toJson(includeDeviceToken:false))); _syncStatus=syncStatus??_deriveStatus(); }

  Future<void> setEnabled(bool enabled) async {
    if (!enabled) {
      await _persistSettings(
        _settings.copyWith(enabled: false, clearLastError: true),
      );
      _syncStatus = PanelSyncStatus.disabled;
      return;
    }
    await _persistSettings(_settings.copyWith(enabled: true, clearLastError: true));
  }

  Future<void> updatePanelUrl(String panelUrl) async {
    final normalized = _normalizePanelUrl(panelUrl);
    await _persistSettings(
      _settings.copyWith(
        panelUrl: normalized,
        clearDeviceToken: normalized != _settings.panelUrl,
        clearSubscriptionUrl: normalized != _settings.panelUrl,
        clearConfigHash: normalized != _settings.panelUrl,
        clearLastSyncAt: normalized != _settings.panelUrl,
        clearLastError: true,
      ),
    );
  }

  Future<void> clearRegistration() async {
    final prefs = await _prefs();
    await prefs.remove(_cachedConfigKey);
    await prefs.remove(_statsQueueKey);
    await _tokenStorage.deleteToken();
    await _persistSettings(
      _settings.copyWith(
        clearDeviceToken: true,
        clearSubscriptionUrl: true,
        clearConfigHash: true,
        clearLastSyncAt: true,
        clearLastError: true,
      ), persistToken: false,
    );
    _syncStatus = PanelSyncStatus.disabled;
  }
  Future<void> setSyncInterval(PanelSyncInterval interval) async { await _persistSettings(_settings.copyWith(syncInterval: interval)); }

  Future<PanelRegisterResult> register({required String pairingToken}) async {
    final panelUrl = _settings.panelUrl;
    if (panelUrl == null || panelUrl.isEmpty) {
      throw PanelApiException('Panel URL is required');
    }
    final token = pairingToken.trim();
    if (token.isEmpty) {
      throw PanelApiException('Pairing token is required');
    }

    AppLog.info('Panel register start (device=$deviceIdHash)');

    final response = await _request(
      method: 'POST',
      path: '/api/client/register',
      body: jsonEncode({
        'pairing_token': token,
        'device_name': _defaultDeviceName(),
        'platform': _platformName(),
        'client': 'RioNexTunnel',
      }),
      authenticated: false,
    );

    final decoded = _decodeJson(response.body);
    final deviceToken = decoded['device_token'] as String?;
    if (deviceToken == null || deviceToken.isEmpty) {
      throw PanelApiException('Register response missing device_token');
    }

    final subscriptionUrl = decoded['subscription_url'] as String?;
    final configHash = decoded['config_hash'] as String?;

    await _persistSettings(
      _settings.copyWith(
        enabled: true,
        deviceToken: deviceToken,
        subscriptionUrl: subscriptionUrl,
        configHash: configHash,
        lastSyncAt: DateTime.now().toUtc(),
        clearLastError: true,
      ),
    );
    _syncStatus = PanelSyncStatus.synced;

    AppLog.info('Panel register ok (device=$deviceIdHash)');
    return PanelRegisterResult(
      deviceToken: deviceToken,
      subscriptionUrl: subscriptionUrl,
      configHash: configHash,
    );
  }

  Future<PanelConfigResult?> syncConfig({bool force = false}) async {
    if (!isActive) {
      return null;
    }

    AppLog.info('Panel config sync (device=$deviceIdHash)');

    try {
      final response = await _request(
        method: 'GET',
        path: '/api/client/config',
        authenticated: true,
      );
      final decoded = _decodeJson(response.body);
      final configHash = decoded['config_hash'] as String? ?? '';
      if (!force &&
          configHash.isNotEmpty &&
          configHash == _settings.configHash) {
        await _persistSettings(
          _settings.copyWith(
            lastSyncAt: DateTime.now().toUtc(),
            clearLastError: true,
          ),
        );
        _syncStatus = PanelSyncStatus.synced;
        return PanelConfigResult(
          configHash: configHash,
          subscriptionUrl: _settings.subscriptionUrl,
        );
      }

      Map<String, dynamic>? configJson;
      final configRaw = decoded['config'];
      if (configRaw is Map) {
        configJson = Map<String, dynamic>.from(configRaw);
      } else if (configRaw is String && configRaw.trim().isNotEmpty) {
        try {
          configJson = Map<String, dynamic>.from(jsonDecode(configRaw) as Map);
        } catch (_) {
          AppLog.warn('Panel config JSON invalid (device=$deviceIdHash)');
          await _persistSettings(
            _settings.copyWith(lastError: 'Invalid config JSON from panel'),
            syncStatus: await _hasCachedConfig()
                ? PanelSyncStatus.stale
                : PanelSyncStatus.error,
          );
          return PanelConfigResult(
            configHash: _settings.configHash ?? configHash,
            configJson: await loadCachedConfig(),
            subscriptionUrl: _settings.subscriptionUrl,
          );
        }
      } else if (configRaw != null) {
        AppLog.warn('Panel config has unexpected type (device=$deviceIdHash)');
        await _persistSettings(
          _settings.copyWith(lastError: 'Invalid config JSON from panel'),
          syncStatus: await _hasCachedConfig()
              ? PanelSyncStatus.stale
              : PanelSyncStatus.error,
        );
        return PanelConfigResult(
          configHash: _settings.configHash ?? configHash,
          configJson: await loadCachedConfig(),
          subscriptionUrl: _settings.subscriptionUrl,
        );
      }

      if (configJson != null) {
        final prefs = await _prefs();
        await prefs.setString(_cachedConfigKey, jsonEncode(configJson));
      }

      final subscriptionUrl =
          decoded['subscription_url'] as String? ?? _settings.subscriptionUrl;

      await _persistSettings(
        _settings.copyWith(
          configHash: configHash.isEmpty ? _settings.configHash : configHash,
          subscriptionUrl: subscriptionUrl,
          lastSyncAt: DateTime.now().toUtc(),
          clearLastError: true,
        ),
      );
      _syncStatus = PanelSyncStatus.synced;

      return PanelConfigResult(
        configHash: configHash,
        configJson: configJson,
        subscriptionUrl: subscriptionUrl,
      );
    } on PanelApiException catch (error) {
      final hasCache = await _hasCachedConfig();
      await _persistSettings(
        _settings.copyWith(lastError: hasCache ? null : error.message),
        syncStatus: hasCache ? PanelSyncStatus.stale : PanelSyncStatus.error,
      );
      rethrow;
    } on SocketException {
      final hasCache = await _hasCachedConfig();
      await _persistSettings(
        _settings.copyWith(
          lastError: hasCache ? null : 'Panel unreachable',
        ),
        syncStatus:
            hasCache ? PanelSyncStatus.stale : PanelSyncStatus.offline,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> loadCachedConfig() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_cachedConfigKey);
    if (raw == null) {
      return null;
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _hasCachedConfig() async {
    final prefs = await _prefs();
    return prefs.containsKey(_cachedConfigKey);
  }

  Future<void> enqueueStats(PanelStatsPayload payload) async {
    if (!isActive) {
      return;
    }
    final prefs = await _prefs();
    final queue = _readStatsQueue(prefs);
    queue.add(payload.toJson());
    await prefs.setString(_statsQueueKey, jsonEncode(queue));
  }

  Future<void> flushStats() async {
    if (!isActive) {
      return;
    }
    final prefs = await _prefs();
    final queue = _readStatsQueue(prefs);
    if (queue.isEmpty) {
      return;
    }

    try {
      await _request(
        method: 'POST',
        path: '/api/client/stats',
        body: jsonEncode({'entries': queue}),
        authenticated: true,
      );
      await prefs.remove(_statsQueueKey);
    } on PanelApiException catch (error) {
      AppLog.warn('Panel stats upload failed: ${error.message}');
    } on SocketException {
      AppLog.warn('Panel stats upload offline (queued=${queue.length})');
    }
  }

  List<Map<String, dynamic>> _readStatsQueue(SharedPreferences prefs) {
    final raw = prefs.getString(_statsQueueKey);
    if (raw == null) {
      return [];
    }
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<http.Response> _request({
    required String method,
    required String path,
    String? body,
    bool authenticated = false,
  }) async {
    final panelUrl = _settings.panelUrl;
    if (panelUrl == null || panelUrl.isEmpty) {
      throw PanelApiException('Panel URL is not configured');
    }

    final uri = Uri.parse('$panelUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-API-Version': _apiVersionHeader,
    };
    if (authenticated) {
      final token = _settings.deviceToken;
      if (token == null || token.isEmpty) {
        throw PanelApiException('Device token missing');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    Object? lastError;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await _send(method, uri, headers, body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
        if (response.statusCode >= 500 && attempt < _maxRetries - 1) {
          await Future<void>.delayed(_backoff(attempt));
          continue;
        }
        throw PanelApiException(
          _safeErrorMessage(response),
          statusCode: response.statusCode,
        );
      } on SocketException catch (error) {
        lastError = error;
        if (attempt < _maxRetries - 1) {
          await Future<void>.delayed(_backoff(attempt));
          continue;
        }
        rethrow;
      } on http.ClientException catch (error) {
        lastError = error;
        if (attempt < _maxRetries - 1) {
          await Future<void>.delayed(_backoff(attempt));
          continue;
        }
        throw PanelApiException('Network error');
      }
    }
    throw PanelApiException('Request failed: $lastError');
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    switch (method) {
      case 'GET':
        return _http.get(uri, headers: headers).timeout(_requestTimeout);
      case 'POST':
        return _http
            .post(uri, headers: headers, body: body)
            .timeout(_requestTimeout);
      default:
        throw ArgumentError('Unsupported method: $method');
    }
  }

  Duration _backoff(int attempt) =>
      Duration(milliseconds: 400 * (1 << attempt.clamp(0, 4)));

  Map<String, dynamic> _decodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      throw PanelApiException('Unexpected JSON shape from panel');
    } catch (error) {
      if (error is PanelApiException) {
        rethrow;
      }
      throw PanelApiException('Invalid JSON from panel');
    }
  }

  String _safeErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return 'Panel request failed (${response.statusCode})';
  }

  @visibleForTesting
  static String normalizePanelUrlForTest(String raw) => _normalizePanelUrl(raw);

  static String _normalizePanelUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      return '';
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static String _defaultDeviceName() {
    if (kIsWeb) {
      return 'RioNexTunnel Web';
    }
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'RioNexTunnel';
    }
  }

  static String _platformName() {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    if (Platform.isLinux) {
      return 'linux';
    }
    if (Platform.isWindows) {
      return 'windows';
    }
    if (Platform.isMacOS) {
      return 'macos';
    }
    return 'unknown';
  }

  void dispose() {
    _http.close();
  }
}
