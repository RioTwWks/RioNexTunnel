import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/credentials.dart';
import '../models/engine_preference.dart';
import '../models/profile.dart';
import '../models/subscription_server.dart';
import '../models/vpn_engine.dart';
import '../utils/config_parser.dart';
import '../utils/engine_auto_selector.dart';
import '../utils/link_config_builder.dart';
import '../utils/server_latency.dart';
import 'app_log.dart';
import 'credential_service.dart';

class ConnectResult {
  const ConnectResult({required this.profile, required this.engine});

  final Profile profile;
  final VpnEngine engine;
}

class VpnService {
  VpnService({
    V2rayBox? v2rayBox,
    CredentialService? credentialService,
    this.applicationId = 'com.example.secure_vpn_client',
    this.socksPort = ConfigParser.defaultSocksPort,
  }) : _v2rayBox = v2rayBox ?? V2rayBox(),
       _credentialService = credentialService ?? CredentialService();

  final V2rayBox _v2rayBox;
  final CredentialService _credentialService;
  final String applicationId;
  final int socksPort;

  static const _connectReadyTimeout = Duration(seconds: 25);

  bool _initialized = false;
  SessionCredentials? _sessionCredentials;
  VpnEngine _engine = VpnEngine.xray;
  EnginePreference _enginePreference = EnginePreference.auto;
  VpnStatus _currentStatus = VpnStatus.stopped;
  StreamSubscription<VpnStatus>? _statusSubscription;
  final StreamController<VpnStatus> _statusController =
      StreamController<VpnStatus>.broadcast();

  SessionCredentials? get sessionCredentials => _sessionCredentials;
  VpnEngine get engine => _engine;
  EnginePreference get enginePreference => _enginePreference;
  V2rayBox get v2rayBox => _v2rayBox;
  VpnStatus get currentStatus => _currentStatus;

  /// Latest status first, then live updates. Prefer this over calling
  /// [V2rayBox.watchStatus] directly so UI and connect() share one source.
  Stream<VpnStatus> watchStatus() async* {
    yield _currentStatus;
    yield* _statusController.stream;
  }

  void _publishStatus(VpnStatus status) {
    if (_currentStatus == status) {
      return;
    }
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await _v2rayBox.initialize(notificationStopButtonText: 'Stop');
    final desktopProxy =
        !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
    if (desktopProxy) {
      await _v2rayBox.setConfigOptions(
        const ConfigOptions(enableTun: false, setSystemProxy: true),
      );
    }
    await _v2rayBox.setServiceMode(desktopProxy ? VpnMode.proxy : VpnMode.vpn);
    await _v2rayBox.setCoreEngine(_engine.coreName);
    _statusSubscription ??= _v2rayBox.watchStatus().listen(_publishStatus);
    _initialized = true;
  }

  void setEnginePreference(EnginePreference preference) {
    _enginePreference = preference;
  }

  Future<void> setEngine(
    VpnEngine engine, {
    bool disconnectIfNeeded = true,
  }) async {
    if (_engine == engine) {
      return;
    }

    if (disconnectIfNeeded && _initialized) {
      await disconnect();
    }

    _engine = engine;
    if (_initialized) {
      await _v2rayBox.setCoreEngine(engine.coreName);
    }
  }

  Future<String> resolveProfileConfig(Profile profile) async {
    final raw = profile.type == ProfileType.subscription
        ? await ConfigParser.parseFromUrl(
            profile.configLink,
            engine: _engine,
            serverIndex: profile.selectedServerIndex,
          )
        : profile.configLink.trim();

    if (raw.startsWith('{')) {
      return raw;
    }
    if (raw.startsWith('[')) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      if (decoded.isEmpty || decoded.first is! Map) {
        throw StateError('Subscription JSON array is empty');
      }
      return jsonEncode(decoded.first);
    }

    if (LinkConfigBuilder.isConfigLink(raw)) {
      return LinkConfigBuilder.buildFromLink(raw, _engine);
    }

    try {
      return await _v2rayBox.generateConfig(raw);
    } on PlatformException {
      return LinkConfigBuilder.buildFromLink(raw, _engine);
    }
  }

  /// Fetches subscription and returns selectable non-decoy servers.
  Future<List<SubscriptionServer>> listSubscriptionServers(
    Profile profile,
  ) async {
    if (profile.type != ProfileType.subscription) {
      return const [];
    }
    return ConfigParser.listServersFromUrl(profile.configLink, engine: _engine);
  }

  /// Probes TCP latency for all servers in [profile]'s subscription.
  Future<List<ServerLatencyResult>> probeSubscriptionServers(
    Profile profile, {
    void Function(ServerLatencyResult result)? onResult,
    Duration timeout = ServerLatencyProbe.defaultTimeout,
  }) async {
    final servers = await listSubscriptionServers(profile);
    return ServerLatencyProbe.probeAll(
      servers,
      timeout: timeout,
      onResult: onResult,
    );
  }

  /// Returns the lowest-latency reachable server, or throws if none respond.
  Future<ServerLatencyResult> selectBestSubscriptionServer(
    Profile profile, {
    void Function(ServerLatencyResult result)? onResult,
    Duration timeout = ServerLatencyProbe.defaultTimeout,
  }) async {
    final results = await probeSubscriptionServers(
      profile,
      onResult: onResult,
      timeout: timeout,
    );
    final best = ServerLatencyProbe.selectBest(results);
    if (best == null) {
      throw ServerLatencyException(
        'No reachable servers in subscription. Check network and try again.',
      );
    }
    AppLog.info(
      'Best server=${best.server.name} latency=${best.latencyMs}ms '
      'index=${best.server.index}',
    );
    return best;
  }

  Future<ConnectResult> connect(Profile profile) async {
    await initialize();
    AppLog.info(
      'Connect requested profile=${profile.name} '
      'preference=${_enginePreference.storageName}',
    );

    if (_sessionCredentials != null) {
      await disconnect();
    }

    await _ensureVpnPermission();

    final resolution = await EngineAutoSelector.resolve(
      profile: profile,
      box: _v2rayBox,
      preference: _enginePreference,
    );
    AppLog.info(resolution.reason);

    Object? lastError;
    for (var i = 0; i < resolution.attemptOrder.length; i++) {
      final engine = resolution.attemptOrder[i];
      try {
        await setEngine(engine, disconnectIfNeeded: true);
        final connectedProfile = await _connectWithCurrentEngine(profile);
        return ConnectResult(profile: connectedProfile, engine: engine);
      } catch (error) {
        lastError = error;
        AppLog.error('Connect with ${engine.coreName} failed: $error');
        await disconnect();
        final hasFallback = i < resolution.attemptOrder.length - 1;
        if (!hasFallback) {
          break;
        }
        AppLog.info(
          'Falling back to ${resolution.attemptOrder[i + 1].coreName}',
        );
      }
    }

    throw lastError ??
        StateError('Failed to connect with any available core engine');
  }

  Future<Profile> _connectWithCurrentEngine(Profile profile) async {
    AppLog.info(
      'Connecting profile=${profile.name} engine=${_engine.coreName}',
    );

    var effectiveProfile = profile;
    if (profile.type == ProfileType.subscription &&
        profile.autoSelectBestServer) {
      final best = await selectBestSubscriptionServer(profile);
      effectiveProfile = profile.copyWith(
        selectedServerIndex: best.server.index,
        selectedServerName: best.server.name,
        autoSelectBestServer: true,
      );
    }

    final rawConfig = await resolveProfileConfig(effectiveProfile);
    AppLog.info('Resolved profile config (${rawConfig.length} bytes)');
    final credentials = _credentialService.generate();
    final desktopProxy =
        !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
    final secureConfig = ConfigParser.injectSecureSocksInbound(
      rawConfig,
      credentials,
      _engine,
      socksPort: socksPort,
      proxyOnly: desktopProxy,
    );
    AppLog.info(
      'Secure config ready proxyOnly=$desktopProxy '
      'inbounds=${_inboundSummary(secureConfig)}',
    );

    final validationError = await _v2rayBox.checkConfigJson(secureConfig);
    if (validationError.isNotEmpty) {
      AppLog.error('Config validation failed: $validationError');
      _credentialService.clear(credentials);
      throw StateError('Invalid VPN config: $validationError');
    }

    await _setSessionCredentials(credentials);
    final started = await _v2rayBox.connectWithJson(
      secureConfig,
      name: effectiveProfile.name,
      socksUsername: credentials.username,
      socksPassword: credentials.password,
      socksPort: socksPort,
    );
    if (!started) {
      AppLog.error('connectWithJson returned false');
      await _clearSessionCredentials();
      _credentialService.clear(credentials);
      throw StateError('Failed to start VPN');
    }

    try {
      await _waitForStatus(VpnStatus.started, timeout: _connectReadyTimeout);
    } catch (error) {
      AppLog.error('Did not reach Connected: $error');
      await disconnect();
      _credentialService.clear(credentials);
      throw StateError(
        'VPN did not reach Connected state. '
        'Grant VPN and notification permissions, then try again. ($error)',
      );
    }

    _sessionCredentials = credentials;
    // Ensure UI flips to Disconnect even if a status event was raced/missed.
    _publishStatus(VpnStatus.started);
    AppLog.info('VPN connected with ${_engine.coreName}');
    return effectiveProfile;
  }

  String _inboundSummary(String configJson) {
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map) {
        return 'invalid';
      }
      final inbounds = decoded['inbounds'];
      if (inbounds is! List) {
        return 'none';
      }
      return inbounds
          .whereType<Map>()
          .map((inbound) {
            final tag = inbound['tag'] ?? '?';
            final protocol = inbound['protocol'] ?? inbound['type'] ?? '?';
            return '$tag:$protocol';
          })
          .join(',');
    } catch (_) {
      return 'parse-error';
    }
  }

  Future<void> disconnect() async {
    AppLog.info('Disconnect requested');
    if (_initialized) {
      await _v2rayBox.disconnect();
    }
    if (_sessionCredentials != null) {
      _credentialService.clear(_sessionCredentials!);
      _sessionCredentials = null;
    }
    await _clearSessionCredentials();
    _publishStatus(VpnStatus.stopped);
    AppLog.info('VPN disconnected');
  }

  Future<void> _ensureVpnPermission() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    if (await _v2rayBox.checkVpnPermission()) {
      return;
    }
    // Shows the system VPN consent dialog and returns immediately.
    await _v2rayBox.requestVpnPermission();
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      if (await _v2rayBox.checkVpnPermission()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    throw StateError(
      'VPN permission is required. Allow the VPN connection prompt and try again.',
    );
  }

  Future<void> _waitForStatus(
    VpnStatus target, {
    required Duration timeout,
  }) async {
    if (_currentStatus == target) {
      return;
    }
    final seen = <VpnStatus>{_currentStatus};
    await _statusController.stream
        .timeout(timeout)
        .firstWhere((status) {
          seen.add(status);
          if (status == target) {
            return true;
          }
          // Core often returns started=true then fails → Starting → Stopped.
          // Fail fast so Auto engine fallback can run.
          if (status == VpnStatus.stopped &&
              seen.contains(VpnStatus.starting)) {
            return true;
          }
          return false;
        });
    if (_currentStatus != target) {
      throw StateError(
        'VPN failed to reach Connected (status=${_currentStatus.name})',
      );
    }
  }

  Future<void> _setSessionCredentials(SessionCredentials credentials) async {
    const channel = MethodChannel('secure_vpn/credentials');
    try {
      await channel.invokeMethod<void>('setSessionCredentials', {
        'username': credentials.username,
        'password': credentials.password,
        'port': socksPort,
      });
    } catch (_) {
      // Native channel may be unavailable on some platforms during tests.
    }
  }

  Future<void> _clearSessionCredentials() async {
    const channel = MethodChannel('secure_vpn/credentials');
    try {
      await channel.invokeMethod<void>('clearSessionCredentials');
    } catch (_) {
      // Ignore when channel is not registered.
    }
  }
}
