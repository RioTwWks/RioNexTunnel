import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/credentials.dart';
import '../models/profile.dart';
import '../models/vpn_engine.dart';
import '../utils/config_parser.dart';
import '../utils/link_config_builder.dart';
import 'app_log.dart';
import 'credential_service.dart';

class VpnService {
  VpnService({
    V2rayBox? v2rayBox,
    CredentialService? credentialService,
    this.applicationId = 'com.example.secure_vpn_client',
    this.socksPort = ConfigParser.defaultSocksPort,
  })  : _v2rayBox = v2rayBox ?? V2rayBox(),
        _credentialService = credentialService ?? CredentialService();

  final V2rayBox _v2rayBox;
  final CredentialService _credentialService;
  final String applicationId;
  final int socksPort;

  static const _connectReadyTimeout = Duration(seconds: 25);

  bool _initialized = false;
  SessionCredentials? _sessionCredentials;
  VpnEngine _engine = VpnEngine.xray;
  VpnStatus _currentStatus = VpnStatus.stopped;
  StreamSubscription<VpnStatus>? _statusSubscription;
  final StreamController<VpnStatus> _statusController =
      StreamController<VpnStatus>.broadcast();

  SessionCredentials? get sessionCredentials => _sessionCredentials;
  VpnEngine get engine => _engine;
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
    final desktopProxy = !kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
    if (desktopProxy) {
      await _v2rayBox.setConfigOptions(
        const ConfigOptions(enableTun: false, setSystemProxy: true),
      );
    }
    await _v2rayBox.setServiceMode(
      desktopProxy ? VpnMode.proxy : VpnMode.vpn,
    );
    await _v2rayBox.setCoreEngine(_engine.coreName);
    await _configurePerAppProxy();
    _statusSubscription ??=
        _v2rayBox.watchStatus().listen(_publishStatus);
    _initialized = true;
  }

  Future<void> setEngine(VpnEngine engine, {bool disconnectIfNeeded = true}) async {
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

  Future<void> connect(Profile profile) async {
    await initialize();
    AppLog.info('Connect requested profile=${profile.name} engine=${_engine.coreName}');

    if (_sessionCredentials != null) {
      await disconnect();
    }

    await _ensureVpnPermission();

    final rawConfig = await resolveProfileConfig(profile);
    AppLog.info('Resolved profile config (${rawConfig.length} bytes)');
    final credentials = _credentialService.generate();
    final desktopProxy = !kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
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
      name: profile.name,
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
    AppLog.info('VPN connected');
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
    await _v2rayBox
        .watchStatus()
        .firstWhere((status) => status == target)
        .timeout(timeout);
  }

  Future<void> _configurePerAppProxy() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    // Full-device VPN: route all apps except this package (OFF excludes self
    // in VPNService). INCLUDE with only our packageName is a no-op on Android
    // (cannot include oneself) and previously left traffic unrouted / confusing.
    await _v2rayBox.setPerAppProxyMode(PerAppProxyMode.off);
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
