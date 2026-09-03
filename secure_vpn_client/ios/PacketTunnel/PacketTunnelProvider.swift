//
//  PacketTunnelProvider.swift
//  PacketTunnel
//

import NetworkExtension
import Libbox

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var commandServer: LibboxCommandServer?
    private var platformInterface: TunnelPlatformInterface?
    private var config: String?
    private var coreEngine: String = "singbox"

    private var uploadTotal: Int64 = 0
    private var downloadTotal: Int64 = 0

    private let appGroupId = "group.com.example.secureVpnClient"

    override func startTunnel(options: [String: NSObject]?) async throws {
        guard let configString = options?["Config"] as? String else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "Config not provided"])
        }

        config = configString
        coreEngine = (options?["CoreEngine"] as? String ?? "singbox").lowercased()
        if coreEngine == "xray" {
            NSLog("[PacketTunnel] Xray requested; falling back to sing-box (libXray not integrated)")
        }

        let disableMemoryLimit = (options?["DisableMemoryLimit"] as? String ?? "NO") == "YES"

        let fileManager = FileManager.default
        let workingDir = getWorkingDirectory()
        let cacheDir = getCacheDirectory()
        let sharedDir = getSharedDirectory()

        try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sharedDir, withIntermediateDirectories: true)

        let setupOptions = LibboxSetupOptions()
        setupOptions.basePath = sharedDir.path
        setupOptions.workingPath = workingDir.path
        setupOptions.tempPath = cacheDir.path
        setupOptions.oomKillerEnabled = !disableMemoryLimit

        var error: NSError?
        LibboxSetup(setupOptions, &error)
        if let error = error {
            throw error
        }

        platformInterface = TunnelPlatformInterface(tunnel: self)

        commandServer = LibboxNewCommandServer(platformInterface, platformInterface, &error)
        if let error = error {
            throw error
        }
        try commandServer?.start()

        try await startService()
    }

    private func startService() async throws {
        guard let config = config else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "Config is nil"])
        }

        let options = LibboxOverrideOptions()
        try commandServer?.startOrReloadService(config, options: options)
    }

    func stopService() {
        do {
            try commandServer?.closeService()
        } catch {
            NSLog("Error closing service: \(error.localizedDescription)")
        }
        platformInterface?.reset()
    }

    func reloadService() async throws {
        reasserting = true
        defer { reasserting = false }
        try await startService()
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        stopService()

        if let server = commandServer {
            try? await Task.sleep(nanoseconds: 100_000_000)
            server.close()
            commandServer = nil
        }
    }

    override func handleAppMessage(_ messageData: Data) async -> Data? {
        guard let message = String(data: messageData, encoding: .utf8) else {
            return nil
        }

        switch message {
        case "stats":
            return "\(uploadTotal),\(downloadTotal)".data(using: .utf8)
        default:
            return nil
        }
    }

    override func sleep() {
        commandServer?.pause()
    }

    override func wake() {
        commandServer?.wake()
    }

    func writeMessage(_ message: String) {
        if let server = commandServer {
            server.writeMessage(2, message: message)
        } else {
            NSLog(message)
        }
    }

    func writeFatalError(_ message: String) {
        NSLog("FATAL: \(message)")
        cancelTunnelWithError(NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
    }

    func updateTraffic(upload: Int64, download: Int64) {
        uploadTotal = upload
        downloadTotal = download
    }

    private func getSharedDirectory() -> URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            fatalError("App group container not found: \(appGroupId)")
        }
        return url
    }

    private func getWorkingDirectory() -> URL {
        getSharedDirectory().appendingPathComponent("working", isDirectory: true)
    }

    private func getCacheDirectory() -> URL {
        getSharedDirectory()
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
    }
}

// MARK: - Platform Interface

class TunnelPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol, LibboxCommandServerHandlerProtocol {

    private weak var tunnel: PacketTunnelProvider?
    private var networkSettings: NEPacketTunnelNetworkSettings?

    init(tunnel: PacketTunnelProvider) {
        self.tunnel = tunnel
    }

    func reset() {
        networkSettings = nil
    }

    func openTun(_ options: (any LibboxTunOptionsProtocol)?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        try runBlocking { [self] in
            try await openTunAsync(options, ret0_)
        }
    }

    private func openTunAsync(_ options: (any LibboxTunOptionsProtocol)?, _ ret0_: UnsafeMutablePointer<Int32>?) async throws {
        guard let options = options else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "nil options"])
        }
        guard let ret0_ = ret0_ else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "nil return pointer"])
        }
        guard let tunnel = tunnel else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "tunnel is nil"])
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())

            var dnsServers = ["8.8.8.8", "8.8.4.4"]
            if let dnsMode = options.getDNSMode(), dnsMode.value != LibboxDNSModeDisabled {
                let dnsIterator = try options.getDNSServerAddress()
                var parsed: [String] = []
                while dnsIterator.hasNext() {
                    parsed.append(dnsIterator.next())
                }
                if !parsed.isEmpty {
                    dnsServers = parsed
                }
            }
            settings.dnsSettings = NEDNSSettings(servers: dnsServers)

            var ipv4Addresses: [String] = []
            var ipv4Masks: [String] = []
            if let iterator = options.getInet4Address() {
                while iterator.hasNext() {
                    if let prefix = iterator.next() {
                        ipv4Addresses.append(prefix.address())
                        ipv4Masks.append(prefix.mask())
                    }
                }
            }

            if !ipv4Addresses.isEmpty {
                let ipv4Settings = NEIPv4Settings(addresses: ipv4Addresses, subnetMasks: ipv4Masks)
                var routes: [NEIPv4Route] = []

                if let routeIterator = options.getInet4RouteAddress(), routeIterator.hasNext() {
                    while routeIterator.hasNext() {
                        if let prefix = routeIterator.next() {
                            routes.append(NEIPv4Route(destinationAddress: prefix.address(), subnetMask: prefix.mask()))
                        }
                    }
                } else {
                    routes.append(NEIPv4Route.default())
                }

                ipv4Settings.includedRoutes = routes
                settings.ipv4Settings = ipv4Settings
            }

            var ipv6Addresses: [String] = []
            var ipv6Prefixes: [NSNumber] = []
            if let iterator = options.getInet6Address() {
                while iterator.hasNext() {
                    if let prefix = iterator.next() {
                        ipv6Addresses.append(prefix.address())
                        ipv6Prefixes.append(NSNumber(value: prefix.prefix()))
                    }
                }
            }

            if !ipv6Addresses.isEmpty {
                let ipv6Settings = NEIPv6Settings(addresses: ipv6Addresses, networkPrefixLengths: ipv6Prefixes)
                ipv6Settings.includedRoutes = [NEIPv6Route.default()]
                settings.ipv6Settings = ipv6Settings
            }
        }

        if options.isHTTPProxyEnabled() {
            let proxySettings = NEProxySettings()
            let proxyServer = NEProxyServer(address: options.getHTTPProxyServer(), port: Int(options.getHTTPProxyServerPort()))
            proxySettings.httpServer = proxyServer
            proxySettings.httpsServer = proxyServer
            proxySettings.httpEnabled = true
            proxySettings.httpsEnabled = true
            settings.proxySettings = proxySettings
        }

        networkSettings = settings
        try await tunnel.setTunnelNetworkSettings(settings)

        if let tunFd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            ret0_.pointee = tunFd
            return
        }

        let tunFdFromLoop = LibboxGetTunnelFileDescriptor()
        if tunFdFromLoop != -1 {
            ret0_.pointee = tunFdFromLoop
        } else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "missing file descriptor"])
        }
    }

    func usePlatformAutoDetectControl() -> Bool { false }
    func autoDetectControl(_ fd: Int32) throws {}

    func findConnectionOwner(_ ipProtocol: Int32, sourceAddress: String?, sourcePort: Int32, destinationAddress: String?, destinationPort: Int32) throws -> LibboxConnectionOwner {
        throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not implemented"])
    }

    func useProcFS() -> Bool { false }

    func writeLog(_ message: String?) {
        guard let message = message else { return }
        tunnel?.writeMessage(message)
    }

    func startDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {}
    func closeDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {}

    func getInterfaces() throws -> any LibboxNetworkInterfaceIteratorProtocol {
        throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not implemented"])
    }

    func underNetworkExtension() -> Bool { true }
    func includeAllNetworks() -> Bool {
        UserDefaults.standard.string(forKey: "flutter.kill_switch_mode") == "strict"
    }

    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }
    func systemCertificates() -> (any LibboxStringIteratorProtocol)? { nil }

    func clearDNSCache() {
        guard let settings = networkSettings, let tunnel = tunnel else { return }
        tunnel.reasserting = true
        tunnel.setTunnelNetworkSettings(nil) { _ in }
        tunnel.setTunnelNetworkSettings(settings) { _ in }
        tunnel.reasserting = false
    }

    func readWIFIState() -> LibboxWIFIState? { nil }

    func send(_ notification: LibboxNotification?) throws {}

    func cancelNotification(_ identifier: String?, typeID: Int32) throws {}

    func startNeighborMonitor(_ listener: (any LibboxNeighborUpdateListenerProtocol)?) throws {}
    func closeNeighborMonitor(_ listener: (any LibboxNeighborUpdateListenerProtocol)?) throws {}
    func registerMyInterface(_ name: String?) {}

    func usePlatformShell() -> Bool { false }
    func checkPlatformShell() throws {
        throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not supported"])
    }

    func openShellSession(_ user: LibboxPlatformUser?, command: String?, environ: (any LibboxStringIteratorProtocol)?, term: String?, rows: Int32, cols: Int32) throws -> any LibboxShellSessionProtocol {
        throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not supported"])
    }

    func readSystemSSHHostKey(_ error: NSErrorPointer) -> String {
        error?.pointee = NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not supported"])
        return ""
    }

    func lookupSFTPServer(_ error: NSErrorPointer) -> String {
        error?.pointee = NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not supported"])
        return ""
    }

    func tailscaleHostname() -> String { "" }

    func usePlatformBridge() -> Bool { false }
    func createBridge(_ options: LibboxBridgeOptions?) throws -> any LibboxBridgeSessionProtocol {
        throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not supported"])
    }

    func usePlatformAutoRedirect() -> Bool { false }
    func createAutoRedirect(_ options: Data?, handler: (any LibboxAutoRedirectHandlerProtocol)?) throws -> any LibboxAutoRedirectSessionProtocol {
        throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not supported"])
    }

    func lookupUser(_ username: String?) throws -> LibboxPlatformUser {
        throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not supported"])
    }

    // MARK: - LibboxCommandServerHandlerProtocol

    func serviceStop() throws {
        tunnel?.stopService()
    }

    func serviceReload() throws {
        try runBlocking { [self] in
            try await tunnel?.reloadService()
        }
    }

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        let status = LibboxSystemProxyStatus()
        guard let settings = networkSettings?.proxySettings else { return status }
        guard settings.httpServer != nil else { return status }
        status.available = true
        status.enabled = settings.httpEnabled
        return status
    }

    func setSystemProxyEnabled(_ isEnabled: Bool) throws {
        guard let settings = networkSettings?.proxySettings else { return }
        guard settings.httpServer != nil else { return }
        guard settings.httpEnabled != isEnabled else { return }

        settings.httpEnabled = isEnabled
        settings.httpsEnabled = isEnabled

        try runBlocking { [self] in
            try await tunnel?.setTunnelNetworkSettings(networkSettings)
        }
    }

    func triggerNativeCrash() throws {}

    func writeDebugMessage(_ message: String?) {
        guard let message = message else { return }
        NSLog(message)
    }

    func connectSSHAgent(_ ret0_: UnsafeMutablePointer<Int32>?) throws {
        throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not supported"])
    }
}

private func runBlocking<T>(_ block: @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<T, Error>!

    Task.detached {
        do {
            let value = try await block()
            result = .success(value)
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }

    semaphore.wait()
    return try result.get()
}

private func runBlocking<T>(_ block: @escaping () async -> T) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var value: T!

    Task.detached {
        value = await block()
        semaphore.signal()
    }

    semaphore.wait()
    return value
}
