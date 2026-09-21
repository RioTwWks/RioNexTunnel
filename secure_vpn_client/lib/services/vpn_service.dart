import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../constants/panel_constants.dart';
import '../models/connection_detail.dart';
import '../models/credentials.dart';
import '../models/engine_preference.dart';
import '../models/multihop_chain.dart';
import '../models/panel_socks_inbound.dart';
import '../models/pinning_config.dart';
import '../models/profile.dart';
import '../models/service_mode_preference.dart';
import '../models/socks_auth_mode.dart';
import '../models/subscription_server.dart';
import '../models/transport_stack.dart';
import '../models/vpn_engine.dart';
import '../utils/config_enhancer.dart';
import '../utils/amnezia_wg_config.dart';
import '../utils/config_parser.dart';
import '../utils/core_version_gate.dart';
import '../utils/engine_auto_selector.dart';
import '../utils/link_config_builder.dart';
import '../utils/platform_transport_selector.dart';
import '../utils/skadi_config_builder.dart';
import '../utils/transport_presets.dart';
import '../utils/transport_stack_classifier.dart';
import '../utils/server_latency.dart';
import '../utils/subscription_latency_probe.dart';
import 'app_log.dart';
import 'credential_service.dart';
import 'kill_switch_service.dart';
import 'panel_manager.dart';
import 'routing_rules_service.dart';
import 'subscription_manager.dart';
import 'transport_stack_store.dart';

class ConnectResult {
  const ConnectResult({required this.profile, required this.engine});

  final Profile profile;
  final VpnEngine engine;
}

class VpnService {
  VpnService({
    V2rayBox? v2rayBox,
    CredentialService? credentialService,
    KillSwitchService? killSwitchService,
    PanelManager? panelManager,
    RoutingRulesService? routingRulesService,
    SubscriptionManager? subscriptionManager,
    TransportStackStore? transportStackStore,
    this.applicationId = 'com.example.secure_vpn_client',
    this.socksPort = ConfigParser.defaultSocksPort,
  }) : _v2rayBox = v2rayBox ?? V2rayBox(),
       _credentialService = credentialService ?? CredentialService(),
       _killSwitchService = killSwitchService,
       _panelManager = panelManager,
       _routingRulesService = routingRulesService ?? RoutingRulesService(),
       _subscriptionManager = subscriptionManager ??
           SubscriptionManager(store: transportStackStore);

  final V2rayBox _v2rayBox;
  final CredentialService _credentialService;
  final KillSwitchService? _killSwitchService;
  final PanelManager? _panelManager;
  final RoutingRulesService _routingRulesService;
  final SubscriptionManager _subscriptionManager;
  final String applicationId;
  final int socksPort;

  static const _connectReadyTimeout = Duration(seconds: 25);
  static const _maxReconnectAttempts = 5;
  static const _initialReconnectBackoff = Duration(seconds: 2);
  static const _maxReconnectBackoff = Duration(seconds: 60);

  bool _initialized = false;
  SessionCredentials? _sessionCredentials;
  VpnEngine _engine = EngineAutoSelector.platformDefaultEngine();
  EnginePreference _enginePreference = EnginePreference.auto;
  ServiceModePreference _serviceModePreference = ServiceModePreference.auto;
  SocksAuthMode _socksAuthMode = SocksAuthMode.randomPerSession;
  PinningConfig _pinningConfig = PinningConfig.disabled;
  VpnStatus _currentStatus = VpnStatus.stopped;
  ConnectionDetail _connectionDetail = ConnectionDetail.disconnected();
  Profile? _activeProfile;
  List<TransportStackCandidate> _activeStackCandidates = const [];
  int _activeStackIndex = 0;
  TransportStackCandidate? _activeTransportStack;
  bool _userInitiatedDisconnect = false;
  bool _reconnectEnabled = true;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  DateTime? _connectedAt;
  String _panelSessionId = const Uuid().v4();
  StreamSubscription<VpnStatus>? _statusSubscription;
  final StreamController<VpnStatus> _statusController =
      StreamController<VpnStatus>.broadcast();
  final StreamController<ConnectionDetail> _connectionDetailController =
      StreamController<ConnectionDetail>.broadcast();

  SessionCredentials? get sessionCredentials => _sessionCredentials;
  VpnEngine get engine => _engine;
  EnginePreference get enginePreference => _enginePreference;
  SocksAuthMode get socksAuthMode => _socksAuthMode;
  V2rayBox get v2rayBox => _v2rayBox;
  VpnStatus get currentStatus => _currentStatus;
  ConnectionDetail get connectionDetail => _connectionDetail;
  bool get reconnectEnabled => _reconnectEnabled;
  DateTime? get connectedAt => _connectedAt;
  String get panelSessionId => _panelSessionId;
  TransportStackCandidate? get activeTransportStack => _activeTransportStack;
  SubscriptionManager get subscriptionManager => _subscriptionManager;

  Duration? get connectionUptime {
    if (_connectedAt == null || _currentStatus != VpnStatus.started) {
      return null;
    }
    return DateTime.now().difference(_connectedAt!);
  }

  void setReconnectEnabled(bool enabled) {
    _reconnectEnabled = enabled;
    if (!enabled) {
      _cancelReconnect();
    }
  }

  Stream<VpnStatus> watchStatus() async* {
    yield _currentStatus;
    yield* _statusController.stream;
  }

  Stream<ConnectionDetail> watchConnectionDetail() async* {
    yield _connectionDetail;
    yield* _connectionDetailController.stream;
  }

  void _publishConnectionDetail(ConnectionDetail detail) {
    if (_connectionDetail.phase == detail.phase &&
        _connectionDetail.reason == detail.reason &&
        _connectionDetail.reconnectAttempt == detail.reconnectAttempt &&
        _connectionDetail.vpnStatus == detail.vpnStatus) {
      return;
    }
    _connectionDetail = detail;
    if (!_connectionDetailController.isClosed) {
      _connectionDetailController.add(detail);
    }
  }

  void _publishStatus(VpnStatus status) {
    final previous = _currentStatus;
    if (_currentStatus == status) {
      return;
    }
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
    _syncConnectionDetailFromStatus(previous, status);
  }

  void _syncConnectionDetailFromStatus(VpnStatus previous, VpnStatus status) {
    switch (status) {
      case VpnStatus.starting:
        if (_connectionDetail.phase != ConnectionPhase.reconnecting) {
          _publishConnectionDetail(
            ConnectionDetail.fromVpnStatus(
              status,
              overridePhase: ConnectionPhase.connecting,
            ),
          );
        }
      case VpnStatus.started:
        _connectedAt = DateTime.now();
        _reconnectAttempt = 0;
        _cancelReconnect();
        _publishConnectionDetail(
          ConnectionDetail.fromVpnStatus(
            status,
            overridePhase: ConnectionPhase.connected,
          ),
        );
      case VpnStatus.stopping:
        _publishConnectionDetail(
          ConnectionDetail.fromVpnStatus(
            status,
            overridePhase: ConnectionPhase.disconnecting,
          ),
        );
      case VpnStatus.stopped:
        _connectedAt = null;
        if (_userInitiatedDisconnect) {
          _publishConnectionDetail(ConnectionDetail.disconnected());
          return;
        }
        if (previous == VpnStatus.started &&
            _reconnectEnabled &&
            _activeProfile != null) {
          _scheduleReconnect('Connection dropped unexpectedly');
          return;
        }
        if (_connectionDetail.phase == ConnectionPhase.reconnecting) {
          return;
        }
        _publishConnectionDetail(ConnectionDetail.disconnected());
    }
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _scheduleReconnect(String reason) {
    if (!_reconnectEnabled || _activeProfile == null) {
      _publishConnectionDetail(
        ConnectionDetail(
          phase: ConnectionPhase.error,
          reason: reason,
          vpnStatus: VpnStatus.stopped,
        ),
      );
      return;
    }
    if (_reconnectAttempt >= _maxReconnectAttempts) {
      _publishConnectionDetail(
        ConnectionDetail(
          phase: ConnectionPhase.error,
          reason:
              'Reconnect failed after $_maxReconnectAttempts attempts. $reason',
          reconnectAttempt: _reconnectAttempt,
          maxReconnectAttempts: _maxReconnectAttempts,
          vpnStatus: VpnStatus.stopped,
        ),
      );
      _activeProfile = null;
      return;
    }

    unawaited(_killSwitchService?.onTunnelDown());
    _reconnectAttempt++;
    final delay = _reconnectBackoffDelay(_reconnectAttempt);
    final stackHint = _activeStackCandidates.length > 1
        ? ' — next transport stack after backoff'
        : '';
    _publishConnectionDetail(
      ConnectionDetail(
        phase: ConnectionPhase.reconnecting,
        reason: '$reason — retry in ${delay.inSeconds}s$stackHint',
        reconnectAttempt: _reconnectAttempt,
        maxReconnectAttempts: _maxReconnectAttempts,
        vpnStatus: VpnStatus.stopped,
      ),
    );
    AppLog.info(
      'Scheduling reconnect attempt $_reconnectAttempt/$_maxReconnectAttempts '
      'in ${delay.inSeconds}s',
    );
    _cancelReconnect();
    _reconnectTimer = Timer(delay, () {
      unawaited(_attemptReconnect());
    });
  }

  Duration _reconnectBackoffDelay(int attempt) {
    final seconds = _initialReconnectBackoff.inSeconds * (1 << (attempt - 1));
    final capped = seconds.clamp(
      _initialReconnectBackoff.inSeconds,
      _maxReconnectBackoff.inSeconds,
    );
    return Duration(seconds: capped);
  }

  Future<void> _attemptReconnect() async {
    final profile = _activeProfile;
    if (profile == null || !_reconnectEnabled) {
      return;
    }
    try {
      _publishConnectionDetail(
        ConnectionDetail(
          phase: ConnectionPhase.reconnecting,
          reason: 'Reconnecting…',
          reconnectAttempt: _reconnectAttempt,
          maxReconnectAttempts: _maxReconnectAttempts,
          vpnStatus: VpnStatus.starting,
        ),
      );
      await _connectWithCurrentEngine(profile, isReconnect: true);
    } catch (error) {
      AppLog.error('Reconnect attempt $_reconnectAttempt failed: $error');
      _publishStatus(VpnStatus.stopped);
      _scheduleReconnect(error.toString());
    }
  }

  bool get _isDesktopPlatform =>
      !kIsWeb &&
      (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  bool get _useProxyMode =>
      _serviceModePreference.resolveVpnMode(isDesktop: _isDesktopPlatform) ==
      VpnMode.proxy;

  Future<void> initialize() async {
    if (_initialized) return;
    await _v2rayBox.initialize(notificationStopButtonText: 'Stop');
    await applyServiceMode();
    await _syncEngineWithPlatform();
    _statusSubscription ??= _v2rayBox.watchStatus().listen(_publishStatus);
    _initialized = true;
  }

  /// Align Dart engine with native availability (iOS → sing-box only).
  Future<void> _syncEngineWithPlatform() async {
    final available = await EngineAutoSelector.availableEngines(_v2rayBox);
    if (available.isEmpty) {
      throw StateError('No VPN core engines are available on this device');
    }

    VpnEngine target;
    if (_enginePreference == EnginePreference.singbox ||
        _enginePreference == EnginePreference.xray ||
        _enginePreference == EnginePreference.skadi) {
      target = switch (_enginePreference) {
        EnginePreference.singbox => VpnEngine.singbox,
        EnginePreference.skadi => VpnEngine.skadi,
        _ => VpnEngine.xray,
      };
      if (!available.contains(target)) {
        throw StateError(
          '${target.coreName} is not available on this device. '
          'Install cores or switch engine preference to Auto.',
        );
      }
    } else {
      target = EngineAutoSelector.pickAvailableEngine(
        available,
        preferred: _engine,
      );
    }

    _engine = target;
    final ok = await _v2rayBox.setCoreEngine(target.coreName);
    if (!ok) {
      throw StateError('Failed to activate ${target.coreName} on native side');
    }
  }

  Future<void> applyServiceMode([ServiceModePreference? preference]) async {
    if (preference != null) {
      _serviceModePreference = preference;
    }
    final mode = _serviceModePreference.resolveVpnMode(
      isDesktop: _isDesktopPlatform,
    );
    if (_isDesktopPlatform) {
      final useProxy = mode == VpnMode.proxy;
      await _v2rayBox.setConfigOptions(
        ConfigOptions(
          enableTun: !useProxy,
          setSystemProxy: useProxy,
        ),
      );
    } else if (mode == VpnMode.proxy) {
      await _v2rayBox.setConfigOptions(
        const ConfigOptions(enableTun: false, setSystemProxy: false),
      );
    } else {
      await _v2rayBox.setConfigOptions(
        const ConfigOptions(enableTun: true, setSystemProxy: false),
      );
    }
    await _v2rayBox.setServiceMode(mode);
    AppLog.debug('Work mode applied: ${mode.value}');
  }

  void setEnginePreference(EnginePreference preference) {
    _enginePreference = preference;
  }

  void setSocksAuthMode(SocksAuthMode mode) {
    if (mode == SocksAuthMode.disableInjection) return;
    _socksAuthMode = mode;
  }

  void setPinningConfig(PinningConfig config) {
    _pinningConfig = config;
  }

  PinningConfig get pinningConfig => _pinningConfig;

  Future<void> setEngine(
    VpnEngine engine, {
    bool disconnectIfNeeded = true,
  }) async {
    if (_engine == engine && _initialized) {
      return;
    }

    if (disconnectIfNeeded && _initialized) {
      await disconnect(userInitiated: false);
    }

    if (_initialized) {
      final available = await EngineAutoSelector.availableEngines(_v2rayBox);
      if (!available.contains(engine)) {
        throw StateError(
          '${engine.coreName} is not available on this device',
        );
      }
      final ok = await _v2rayBox.setCoreEngine(engine.coreName);
      if (!ok) {
        throw StateError('Failed to activate ${engine.coreName} on native side');
      }
    }

    _engine = engine;
  }

  Future<String> resolveProfileConfig(
    Profile profile, {
    String? contentOverride,
  }) async {
    if (profile.multihopEnabled && profile.type == ProfileType.subscription && contentOverride == null) {
      return _resolveMultihopProfileConfig(profile);
    }

    if (contentOverride == null && profile.name == kPanelProfileName) {
      final panelJson = await _resolvePanelCachedConfigJson();
      if (panelJson != null) {
        return _rawContentToJsonConfig(profile, panelJson);
      }
    }

    var linkForBuild = profile.configLink.trim();
    if (profile.type == ProfileType.link &&
        profile.censorshipModeEnabled &&
        profile.transportPreset != null &&
        LinkConfigBuilder.isConfigLink(linkForBuild)) {
      linkForBuild = TransportPresets.applyPresetToLink(
        linkForBuild,
        preset: profile.transportPreset!,
        fingerprint: profile.tlsFingerprint,
      );
    }

    final raw = contentOverride ??
        (profile.type == ProfileType.subscription
            ? await ConfigParser.parseFromUrl(
                profile.configLink,
                engine: _engine,
                serverIndex: profile.selectedServerIndex,
                pinning: _pinningConfig,
              )
            : linkForBuild);

    return _rawContentToJsonConfig(profile, raw);
  }

  Future<String?> _resolvePanelCachedConfigJson() async {
    final manager = _panelManager;
    if (manager == null || !manager.isActive) {
      return null;
    }

    var cached = await manager.loadCachedConfig();
    if (cached != null) {
      return jsonEncode(cached);
    }

    try {
      final synced = await manager.syncConfig();
      cached = synced?.configJson ?? await manager.loadCachedConfig();
      if (cached != null) {
        return jsonEncode(cached);
      }
    } catch (_) {
      cached = await manager.loadCachedConfig();
      if (cached != null) {
        return jsonEncode(cached);
      }
    }

    return null;
  }

  Future<String> _resolveMultihopProfileConfig(Profile profile) async {
    final servers = await ConfigParser.listServersFromUrl(profile.configLink, engine: _engine);
    MultihopChain.validateProfile(profile, serverCount: servers.length);
    final chain = MultihopChain.fromProfile(profile);
    final hopConfigs = <Map<String, dynamic>>[];
    for (final index in chain.serverIndices) {
      hopConfigs.add(await _contentToJsonMap(profile.copyWith(multihopEnabled: false), servers[index].content));
    }
    final customRules = (await _routingRulesService.load()).enabledRules;
    return ConfigEnhancer.applyProfileSettings(
      jsonEncode(hopConfigs.last),
      profile,
      _engine,
      multihopHopConfigs: hopConfigs,
      customRules: customRules,
    );
  }

  Future<Map<String, dynamic>> _contentToJsonMap(Profile profile, String raw) async {
    String jsonConfig;
    if (raw.startsWith('{')) { jsonConfig = raw; }
    else if (raw.startsWith('[')) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      if (decoded.isEmpty || decoded.first is! Map) throw StateError('Subscription JSON array is empty');
      jsonConfig = jsonEncode(decoded.first);
    } else if (LinkConfigBuilder.isConfigLink(raw)) {
      jsonConfig = LinkConfigBuilder.buildFromLink(raw, _engine, options: LinkBuildOptions.fromProfile(profile));
    } else {
      try { jsonConfig = await _v2rayBox.generateConfig(raw); }
      on PlatformException { jsonConfig = LinkConfigBuilder.buildFromLink(raw, _engine, options: LinkBuildOptions.fromProfile(profile)); }
    }
    final decoded = jsonDecode(jsonConfig);
    if (decoded is! Map<String, dynamic>) throw StateError('Resolved config must be a JSON object');
    return decoded;
  }

  Future<String> _rawContentToJsonConfig(Profile profile, String raw) async {
    final config = await _contentToJsonMap(profile, raw);
    final customRules = (await _routingRulesService.load()).enabledRules;
    return ConfigEnhancer.applyProfileSettings(
      jsonEncode(config),
      profile,
      _engine,
      customRules: customRules,
    );
  }

  Future<List<SubscriptionServer>> listSubscriptionServers(
    Profile profile, {
    bool logicalServers = true,
  }) async {
    if (profile.type != ProfileType.subscription) {
      return const [];
    }
    final servers = await ConfigParser.listServersFromUrl(
      profile.configLink,
      engine: _engine,
      pinning: _pinningConfig,
    );
    if (!logicalServers) {
      return servers;
    }
    return _subscriptionManager.listLogicalServers(servers);
  }

  SubscriptionLatencyProbe get _latencyProbe =>
      SubscriptionLatencyProbe(_v2rayBox, engine: _engine);

  Future<List<ServerLatencyResult>> probeSubscriptionServers(
    Profile profile, {
    void Function(ServerLatencyResult result)? onResult,
    Duration timeout = ServerLatencyProbe.defaultTimeout,
  }) async {
    final servers = await listSubscriptionServers(
      profile,
      logicalServers: false,
    );
    return _latencyProbe.probeAll(
      servers,
      timeoutMs: timeout.inMilliseconds,
      onResult: onResult,
    );
  }

  Future<ServerLatencyResult> selectBestSubscriptionServer(
    Profile profile, {
    void Function(ServerLatencyResult result)? onResult,
    Duration timeout = ServerLatencyProbe.defaultTimeout,
  }) async {
    final servers = await listSubscriptionServers(
      profile,
      logicalServers: false,
    );
    final results = await _latencyProbe.probeAll(
      servers,
      timeoutMs: timeout.inMilliseconds,
      onResult: onResult,
    );
    final best = _selectBestLogicalServer(servers, results);
    if (best == null) {
      throw ServerLatencyException(
        'No reachable servers in subscription. Check network and try again.',
      );
    }
    final iosNote = PlatformTransportSelector.iosSelectionNote(results, best);
    if (iosNote != null) {
      AppLog.info(iosNote);
    }
    AppLog.info(
      'Best server=${best.server.name} latency=${best.latencyMs}ms '
      'index=${best.server.index}',
    );
    return best;
  }

  Future<ConnectResult> connect(Profile profile) async {
    await initialize();
    _userInitiatedDisconnect = false;
    _reconnectAttempt = 0;
    _activeStackIndex = 0;
    _cancelReconnect();
    _activeProfile = profile;
    _publishConnectionDetail(
      ConnectionDetail.fromVpnStatus(
        VpnStatus.starting,
        overridePhase: ConnectionPhase.connecting,
      ),
    );
    AppLog.info(
      'Connect requested profile=${profile.name} '
      'preference=${_enginePreference.storageName}',
    );

    if (_sessionCredentials != null) {
      await disconnect(userInitiated: false);
    }

    await _ensureVpnPermission();
    await _killSwitchService?.onSessionStart(socksPort: socksPort);

    final resolution = await EngineAutoSelector.resolve(
      profile: profile,
      box: _v2rayBox,
      preference: _enginePreference,
      pinning: _pinningConfig,
      desktopFullTunnel: _isDesktopPlatform && !_useProxyMode,
    );
    AppLog.info(resolution.reason);

    Object? lastError;
    for (var i = 0; i < resolution.attemptOrder.length; i++) {
      final engine = resolution.attemptOrder[i];
      try {
        await setEngine(engine, disconnectIfNeeded: true);
        final connectedProfile = await _connectWithCurrentEngine(
          profile,
          isReconnect: false,
        );
        return ConnectResult(profile: connectedProfile, engine: engine);
      } catch (error) {
        lastError = error;
        AppLog.error('Connect with ${engine.coreName} failed: $error');
        await disconnect(userInitiated: true);
        final hasFallback = i < resolution.attemptOrder.length - 1;
        if (!hasFallback) {
          break;
        }
        AppLog.info(
          'Falling back to ${resolution.attemptOrder[i + 1].coreName}',
        );
      }
    }

    final message = lastError?.toString() ??
        'Failed to connect with any available core engine';
    _publishConnectionDetail(
      ConnectionDetail(
        phase: ConnectionPhase.error,
        reason: message,
        vpnStatus: VpnStatus.stopped,
      ),
    );
    throw lastError ?? StateError(message);
  }

  Future<Profile> _connectWithCurrentEngine(
    Profile profile, {
    required bool isReconnect,
  }) async {
    AppLog.info(
      'Connecting profile=${profile.name} engine=${_engine.coreName} '
      'reconnect=$isReconnect',
    );

    var effectiveProfile = profile;
    if (profile.type == ProfileType.subscription &&
        profile.autoSelectBestServer &&
        !isReconnect) {
      final best = await selectBestSubscriptionServer(profile);
      effectiveProfile = profile.copyWith(
        selectedServerIndex: best.server.index,
        selectedServerName: best.server.name,
        autoSelectBestServer: true,
      );
    }

    final stackCandidates = await _resolveStackCandidates(effectiveProfile);
    _activeStackCandidates = stackCandidates;
    final startIndex = isReconnect && stackCandidates.length > 1
        ? (_activeStackIndex + 1) % stackCandidates.length
        : _activeStackIndex;

    if (stackCandidates.isEmpty) {
      return _connectSingleStack(effectiveProfile, stack: null);
    }

    Object? lastError;
    for (var offset = 0; offset < stackCandidates.length; offset++) {
      final stackIndex = (startIndex + offset) % stackCandidates.length;
      final stack = stackCandidates[stackIndex];
      if (offset > 0) {
        final delay = _reconnectBackoffDelay(offset);
        AppLog.info(
          'Protocol fallback: trying ${stack.tag} in ${delay.inSeconds}s',
        );
        await Future<void>.delayed(delay);
      }
      try {
        final connected = await _connectSingleStack(
          effectiveProfile,
          stack: stack,
        );
        _activeStackIndex = stackIndex;
        _activeTransportStack = stack;
        return connected;
      } catch (error) {
        lastError = error;
        AppLog.error('Connect with stack ${stack.tag} failed: $error');
        await _recordStackAttempt(
          profile: effectiveProfile,
          stack: stack,
          success: false,
        );
        await disconnect(userInitiated: true);
      }
    }

    throw lastError ?? StateError('Failed to connect with any transport stack');
  }

  Future<List<TransportStackCandidate>> _resolveStackCandidates(
    Profile profile,
  ) async {
    if (profile.type != ProfileType.subscription) {
      return const [];
    }
    final servers = await ConfigParser.listServersFromUrl(
      profile.configLink,
      engine: _engine,
      pinning: _pinningConfig,
    );
    return _subscriptionManager.orderedProbeList(
      profileId: profile.id,
      servers: servers,
      selectedIndex: profile.selectedServerIndex,
    );
  }

  Future<Profile> _connectSingleStack(
    Profile effectiveProfile, {
    TransportStackCandidate? stack,
  }) async {
    if (stack != null) {
      AppLog.info(
        'Trying transport stack=${stack.tag} server=${stack.server.name}',
      );
    }

    if (!kIsWeb && Platform.isIOS && _engine == VpnEngine.xray) {
      throw StateError(
        'Xray is not supported on iOS. Open Settings → Engine and choose Auto or sing-box.',
      );
    }
    if (!kIsWeb && Platform.isIOS && _engine == VpnEngine.skadi) {
      throw StateError(
        'SkadiCore is not supported on iOS yet. Open Settings → Engine and choose Auto or sing-box.',
      );
    }

    final rawConfig = await resolveProfileConfig(
      effectiveProfile,
      contentOverride: stack?.content,
    );
    AppLog.info('Resolved profile config (${rawConfig.length} bytes)');

    if (_engine == VpnEngine.xray) {
      await _warnIfXrayTooOldForXhttp(rawConfig);
    }

    _assertOfficialCoreSupportsAwg(rawConfig);

    if (_engine == VpnEngine.skadi) {
      return _connectWithSkadi(
        effectiveProfile: effectiveProfile,
        rawConfig: rawConfig,
        stack: stack,
      );
    }

    if (ConfigParser.configRequiresGeoRules(rawConfig)) {
      if (Platform.isAndroid || Platform.isIOS) {
        // Copies geo assets from the app bundle into the core work dir when packaged.
        await _v2rayBox.getCoreInfo();
      }
      if (!await EngineAutoSelector.geoAssetsPresent(box: _v2rayBox)) {
        throw StateError(
          'Config uses geosite/geoip routing rules but geo assets '
          '(geoip.dat, geosite.dat) are missing on this device. '
          'Run scripts/fetch_cores.sh from the repo root, rebuild the app, '
          'or disable "RU sites direct" / custom geo routing in censorship settings.',
        );
      }
    }

    final credentials = await _resolveSessionCredentials(
      profile: effectiveProfile,
      rawConfig: rawConfig,
    );
    final authMode = _resolveSocksAuthMode(effectiveProfile);
    final panelSocks = authMode == SocksAuthMode.staticFromPanel
        ? await _loadPanelSocksAuth(_engine)
        : null;
    final effectiveSocksPort = panelSocks?.isValid == true
        ? panelSocks!.port
        : socksPort;
    final desktopVpn = _isDesktopPlatform && !_useProxyMode;
    final useDesktopXrayTunBridge =
        desktopVpn && _engine == VpnEngine.xray && Platform.isWindows;
    final xrayTunProfile = desktopVpn && !useDesktopXrayTunBridge
        ? XrayTunRoutingProfile.desktop
        : XrayTunRoutingProfile.mobile;
    final secureConfig = ConfigParser.injectSecureSocksInbound(
      rawConfig,
      credentials,
      _engine,
      socksPort: effectiveSocksPort,
      proxyOnly: _useProxyMode,
      omitXrayTunInbound: useDesktopXrayTunBridge,
      xrayTunProfile: xrayTunProfile,
      authMode: authMode,
      panelSocks: panelSocks,
    );
    AppLog.info(
      'Secure config ready proxyOnly=$_useProxyMode '
      'inbounds=${_inboundSummary(secureConfig)}',
    );

    final validationError = await _v2rayBox.checkConfigJson(secureConfig);
    if (validationError.isNotEmpty) {
      AppLog.error('Config validation failed: $validationError');
      _credentialService.clear(credentials);
      throw StateError('Invalid VPN config: $validationError');
    }

    await _setSessionCredentials(credentials, port: effectiveSocksPort);
    await _v2rayBox.clearLastStartError();
    final started = await _v2rayBox.connectWithJson(
      secureConfig,
      name: effectiveProfile.name,
      socksUsername: credentials.username,
      socksPassword: credentials.password,
      socksPort: effectiveSocksPort,
      desktopXrayTunBridge: useDesktopXrayTunBridge,
    );
    if (!started) {
      final detail = await _describeNativeStartFailure();
      AppLog.error('connectWithJson returned false${detail.isEmpty ? '' : ': $detail'}');
      await _clearSessionCredentials();
      _credentialService.clear(credentials);
      throw StateError(
        detail.isEmpty ? 'Failed to start VPN' : 'Failed to start VPN: $detail',
      );
    }

    try {
      await _waitForStatus(VpnStatus.started, timeout: _connectReadyTimeout);
    } catch (error) {
      final detail = await _describeNativeStartFailure();
      AppLog.error('Did not reach Connected: $error${detail.isEmpty ? '' : ' — $detail'}');
      await disconnect(userInitiated: false);
      _credentialService.clear(credentials);
      throw StateError(_formatConnectFailureMessage(error, detail));
    }

    _sessionCredentials = credentials;
    _activeProfile = effectiveProfile;
    _panelSessionId = const Uuid().v4();
    if (stack != null) {
      await _recordStackAttempt(
        profile: effectiveProfile,
        stack: stack,
        success: true,
      );
    }
    await _killSwitchService?.onTunnelRestored();
    _publishStatus(VpnStatus.started);
    AppLog.info(
      'VPN connected with ${_engine.coreName}'
      '${stack != null ? ' stack=${stack.tag}' : ''}',
    );
    return effectiveProfile;
  }

  /// SkadiCore: TOML client config; native fronts no-auth SOCKS with auth proxy.
  Future<Profile> _connectWithSkadi({
    required Profile effectiveProfile,
    required String rawConfig,
    TransportStackCandidate? stack,
  }) async {
    if (!SkadiConfigBuilder.supportsContent(rawConfig)) {
      throw StateError(
        'SkadiCore supports VLESS (TLS/REALITY/XHTTP) only. '
        'Switch engine to Auto, Xray, or sing-box for this profile.',
      );
    }

    final credentials = await _resolveSessionCredentials(
      profile: effectiveProfile,
      rawConfig: rawConfig,
    );
    final effectiveSocksPort = socksPort;
    final toml = SkadiConfigBuilder.build(
      rawConfig,
      publicSocksPort: effectiveSocksPort,
    );
    AppLog.info(
      'SkadiCore TOML ready backend=127.0.0.1:'
      '${SkadiConfigBuilder.internalSocksPort(effectiveSocksPort)}',
    );

    final validationError = await _v2rayBox.checkConfigJson(toml);
    if (validationError.isNotEmpty) {
      AppLog.error('Skadi config validation failed: $validationError');
      _credentialService.clear(credentials);
      throw StateError('Invalid SkadiCore config: $validationError');
    }

    await _setSessionCredentials(credentials, port: effectiveSocksPort);
    await _v2rayBox.clearLastStartError();
    final started = await _v2rayBox.connectWithJson(
      toml,
      name: effectiveProfile.name,
      socksUsername: credentials.username,
      socksPassword: credentials.password,
      socksPort: effectiveSocksPort,
    );
    if (!started) {
      final detail = await _describeNativeStartFailure();
      AppLog.error(
        'Skadi connectWithJson failed${detail.isEmpty ? '' : ': $detail'}',
      );
      await _clearSessionCredentials();
      _credentialService.clear(credentials);
      throw StateError(
        detail.isEmpty
            ? 'Failed to start SkadiCore'
            : 'Failed to start SkadiCore: $detail',
      );
    }

    try {
      await _waitForStatus(VpnStatus.started, timeout: _connectReadyTimeout);
    } catch (error) {
      final detail = await _describeNativeStartFailure();
      AppLog.error(
        'Skadi did not reach Connected: $error'
        '${detail.isEmpty ? '' : ' — $detail'}',
      );
      await disconnect(userInitiated: false);
      _credentialService.clear(credentials);
      throw StateError(_formatConnectFailureMessage(error, detail));
    }

    _sessionCredentials = credentials;
    _activeProfile = effectiveProfile;
    _panelSessionId = const Uuid().v4();
    if (stack != null) {
      await _recordStackAttempt(
        profile: effectiveProfile,
        stack: stack,
        success: true,
      );
    }
    await _killSwitchService?.onTunnelRestored();
    _publishStatus(VpnStatus.started);
    AppLog.info(
      'VPN connected with ${_engine.coreName}'
      '${stack != null ? ' stack=${stack.tag}' : ''}',
    );
    return effectiveProfile;
  }

  Future<void> _recordStackAttempt({
    required Profile profile,
    required TransportStackCandidate stack,
    required bool success,
    int? latencyMs,
  }) async {
    if (profile.type != ProfileType.subscription) {
      return;
    }
    final serverKey = TransportStackClassifier.serverKey(stack.server);
    await _subscriptionManager.store.recordAttempt(
      profileId: profile.id,
      serverKey: serverKey,
      kind: stack.kind,
      success: success,
      latencyMs: latencyMs,
    );
  }

  ServerLatencyResult? _selectBestLogicalServer(
    List<SubscriptionServer> servers,
    List<ServerLatencyResult> results,
  ) {
    if (results.isEmpty) {
      return null;
    }
    final platformBest = PlatformTransportSelector.selectBest(results);
    if (platformBest != null) {
      final logical = _subscriptionManager.groupServers(servers);
      for (final group in logical) {
        final indices = group.stacks.map((s) => s.server.index).toSet();
        if (indices.contains(platformBest.server.index)) {
          return ServerLatencyResult(
            server: SubscriptionServer(
              index: group.primaryIndex,
              name: group.displayName,
              content: platformBest.server.content,
            ),
            latencyMs: platformBest.latencyMs,
          );
        }
      }
      return platformBest;
    }
    return SubscriptionLatencyProbe.selectBest(results);
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

  Future<void> disconnect({bool userInitiated = true}) async {
    AppLog.info('Disconnect requested userInitiated=$userInitiated');
    if (userInitiated) {
      _userInitiatedDisconnect = true;
      _activeProfile = null;
      _reconnectAttempt = 0;
      _activeStackCandidates = const [];
      _activeStackIndex = 0;
      _activeTransportStack = null;
    }
    _cancelReconnect();
    await _killSwitchService?.onSessionEnd(userInitiated: userInitiated);
    if (_initialized) {
      await _v2rayBox.disconnect();
    }
    if (_sessionCredentials != null) {
      _credentialService.clear(_sessionCredentials!);
      _sessionCredentials = null;
    }
    await _clearSessionCredentials();
    _connectedAt = null;
    _publishStatus(VpnStatus.stopped);
    if (userInitiated) {
      _publishConnectionDetail(ConnectionDetail.disconnected());
    }
    AppLog.info('VPN disconnected');
  }

  Future<void> _ensureVpnPermission() async {
    if (kIsWeb) {
      return;
    }
    if (_isDesktopPlatform && _useProxyMode) {
      return;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      if (await _v2rayBox.checkVpnPermission()) {
        return;
      }
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
    if (_isDesktopPlatform && !_useProxyMode) {
      if (await _v2rayBox.checkVpnPermission()) {
        return;
      }
      throw StateError(
        'Desktop VPN (TUN) needs elevated privileges. On Linux: '
        'sudo setcap cap_net_admin+ep on the sing-box/xray binary in app resources. '
        'On Windows/macOS: run the app as Administrator.',
      );
    }
  }

  Future<void> _waitForStatus(
    VpnStatus target, {
    required Duration timeout,
  }) async {
    if (_currentStatus == target) {
      return;
    }
    final seen = <VpnStatus>{_currentStatus};
    await _statusController.stream.timeout(timeout).firstWhere((status) {
      seen.add(status);
      if (status == target) {
        return true;
      }
      if (status == VpnStatus.stopped && seen.contains(VpnStatus.starting)) {
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

  Future<String> _describeNativeStartFailure() async {
    final native = (await _v2rayBox.getLastStartError()).trim();
    if (native.isNotEmpty) {
      return native;
    }
    final logs = await _v2rayBox.getLogs();
    if (logs.isEmpty) {
      return '';
    }
    final tail = logs.length > 4 ? logs.sublist(logs.length - 4) : logs;
    return tail.join(' | ');
  }

  String _formatConnectFailureMessage(Object error, String nativeDetail) {
    final base = error.toString();
    if (nativeDetail.isEmpty) {
      return 'VPN did not reach Connected state. '
          'Grant VPN and notification permissions, then try again. ($base)';
    }
    if (base.contains(nativeDetail)) {
      return 'VPN did not reach Connected state. $nativeDetail';
    }
    return 'VPN did not reach Connected state. $nativeDetail ($base)';
  }

  SocksAuthMode _resolveSocksAuthMode(Profile profile) {
    if (profile.type == ProfileType.link && profile.disableSocksInjection) {
      return SocksAuthMode.disableInjection;
    }
    return _socksAuthMode;
  }

  Future<PanelSocksInbound?> _loadPanelSocksAuth(VpnEngine engine) async {
    final manager = _panelManager;
    if (manager == null || !manager.isActive) {
      return null;
    }
    final cached = await manager.loadCachedConfig();
    if (cached != null) {
      final fromCache = ConfigParser.extractPanelSocksAuth(cached, engine: engine);
      if (fromCache != null) {
        return fromCache;
      }
    }
    try {
      final synced = await manager.syncConfig();
      final config = synced?.configJson ?? await manager.loadCachedConfig();
      if (config == null) {
        return null;
      }
      return ConfigParser.extractPanelSocksAuth(config, engine: engine);
    } catch (_) {
      return null;
    }
  }

  Future<SessionCredentials> _resolveSessionCredentials({
    required Profile profile,
    required String rawConfig,
  }) async {
    final mode = _resolveSocksAuthMode(profile);
    if (mode == SocksAuthMode.staticFromPanel) {
      final panelSocks = await _loadPanelSocksAuth(_engine);
      if (panelSocks != null && panelSocks.isValid) {
        return SessionCredentials(
          username: panelSocks.username,
          password: panelSocks.password,
        );
      }
      AppLog.warn(
        'Static panel SOCKS unavailable; falling back to per-session creds',
      );
      return _credentialService.generate();
    }
    if (mode == SocksAuthMode.disableInjection) {
      try {
        final decoded = jsonDecode(rawConfig);
        if (decoded is Map<String, dynamic>) {
          final existing = ConfigParser.extractPanelSocksAuth(
            decoded,
            engine: _engine,
          );
          if (existing != null && existing.isValid) {
            return SessionCredentials(
              username: existing.username,
              password: existing.password,
            );
          }
        }
      } catch (_) {}
      return _credentialService.generate();
    }
    return _credentialService.generate();
  }

  void _assertOfficialCoreSupportsAwg(String configOrContent) {
    if (!AmneziaWgConfig.contentUsesAwg(configOrContent)) return;
    throw StateError(AmneziaWgConfig.unsupportedCoreMessage());
  }

  Future<void> _warnIfXrayTooOldForXhttp(String configOrContent) async {
    if (!CoreVersionGate.contentUsesXhttp(configOrContent)) {
      return;
    }
    try {
      final info = await _v2rayBox.getCoreInfo();
      final version = info['version']?.toString();
      final warning = CoreVersionGate.xhttpCompatibilityWarning(
        actualVersion: version,
        content: configOrContent,
      );
      if (warning != null) {
        AppLog.warn(warning);
      }
    } catch (_) {}
  }

  Future<void> _setSessionCredentials(
    SessionCredentials credentials, {
    int? port,
  }) async {
    const channel = MethodChannel('secure_vpn/credentials');
    try {
      await channel.invokeMethod<void>('setSessionCredentials', {
        'username': credentials.username,
        'password': credentials.password,
        'port': port ?? socksPort,
      });
    } catch (_) {}
  }

  Future<void> _clearSessionCredentials() async {
    const channel = MethodChannel('secure_vpn/credentials');
    try {
      await channel.invokeMethod<void>('clearSessionCredentials');
    } catch (_) {}
  }
}
