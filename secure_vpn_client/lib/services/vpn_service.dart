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

  SessionCredentials? get sessionCredentials => _sessionCredentials;
  VpnEngine get engine => _engine;
  V2rayBox get v2rayBox => _v2rayBox;

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

    if (_sessionCredentials != null) {
      await disconnect();
    }

    await _ensureVpnPermission();

    final rawConfig = await resolveProfileConfig(profile);
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

    final validationError = await _v2rayBox.checkConfigJson(secureConfig);
    if (validationError.isNotEmpty) {
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
      await _clearSessionCredentials();
      _credentialService.clear(credentials);
      throw StateError('Failed to start VPN');
    }

    try {
      await _waitForStatus(VpnStatus.started, timeout: _connectReadyTimeout);
    } catch (error) {
      await disconnect();
      _credentialService.clear(credentials);
      throw StateError(
        'VPN did not reach Connected state. '
        'Grant VPN and notification permissions, then try again. ($error)',
      );
    }

    _sessionCredentials = credentials;
  }

  Future<void> disconnect() async {
    if (_initialized) {
      await _v2rayBox.disconnect();
    }
    if (_sessionCredentials != null) {
      _credentialService.clear(_sessionCredentials!);
      _sessionCredentials = null;
    }
    await _clearSessionCredentials();
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
    if (kIsWeb) {
      return;
    }
    await _v2rayBox.setPerAppProxyMode(PerAppProxyMode.include);
    await _v2rayBox.setPerAppProxyList(
      [applicationId],
      PerAppProxyMode.include,
    );
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
