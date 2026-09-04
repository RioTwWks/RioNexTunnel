import Foundation

enum NativeMessaging {
    private static let fileManager = FileManager.default

    static var nativeHostDirectory: URL {
        baseDirectory.appendingPathComponent("native_host", isDirectory: true)
    }

    static var nativeHostBinaryPath: URL {
        nativeHostDirectory.appendingPathComponent("secure_vpn_native_host", isDirectory: false)
    }

    static var sessionCredentialsPath: URL {
        nativeHostDirectory.appendingPathComponent("session.json", isDirectory: false)
    }

    static var extensionPingPath: URL {
        nativeHostDirectory.appendingPathComponent("extension_ping", isDirectory: false)
    }

    private static var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("V2rayBox/working", isDirectory: true)
    }

    @discardableResult
    static func installHost(sourceBinaryPath: String? = nil) -> Bool {
        let source = sourceBinaryPath ?? findBundledNativeHostBinary()
        guard let source, !source.isEmpty else {
            return false
        }
        guard ensureDirectory(nativeHostDirectory) else {
            return false
        }
        let destination = nativeHostBinaryPath.path
        do {
            if fileManager.fileExists(atPath: destination) {
                try fileManager.removeItem(atPath: destination)
            }
            try fileManager.copyItem(atPath: source, toPath: destination)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: destination)
            return isExecutable(destination)
        } catch {
            return false
        }
    }

    @discardableResult
    static func installManifests() -> Bool {
        let hostPath = nativeHostBinaryPath.path
        guard isExecutable(hostPath) else {
            return false
        }

        var ok = true
        for (path, firefox) in manifestTargets() {
            ok = writeNativeManifest(at: path, hostPath: hostPath, firefox: firefox) && ok
        }
        return ok
    }

    @discardableResult
    static func publishCredentials(host: String, port: Int, username: String, password: String) -> Bool {
        guard ensureDirectory(nativeHostDirectory) else {
            return false
        }
        let json = """
        {
          "type": "credentials",
          "host": "\(jsonEscape(host))",
          "port": \(port),
          "username": "\(jsonEscape(username))",
          "password": "\(jsonEscape(password))"
        }
        """
        return writePrivateFile(path: sessionCredentialsPath.path, content: json + "\n")
    }

    @discardableResult
    static func clearCredentials() -> Bool {
        removeIfExists(sessionCredentialsPath.path)
        removeIfExists(extensionPingPath.path)
        return true
    }

    static func getBrowserHelperStatus() -> [String: Bool] {
        let hostInstalled = isExecutable(nativeHostBinaryPath.path)
        let chromeManifest = fileExists(chromeManifestPath())
        let chromiumManifest = fileExists(chromiumManifestPath())
        let edgeManifest = fileExists(edgeManifestPath())
        let firefoxManifest = fileExists(firefoxManifestPath())
        let manifestInstalled = chromeManifest || chromiumManifest || edgeManifest || firefoxManifest
        let credentialsActive = fileExists(sessionCredentialsPath.path)

        let pingTimestamp = readPingTimestamp()
        let now = Int64(Date().timeIntervalSince1970)
        let extensionConnected = pingTimestamp > 0 &&
            (now - pingTimestamp) <= Int64(NativeMessagingConfig.extensionPingMaxAgeSeconds)

        let ready = hostInstalled && manifestInstalled && extensionConnected && credentialsActive
        return [
            "hostInstalled": hostInstalled,
            "manifestInstalled": manifestInstalled,
            "chromeManifestInstalled": chromeManifest,
            "chromiumManifestInstalled": chromiumManifest || edgeManifest,
            "firefoxManifestInstalled": firefoxManifest,
            "credentialsActive": credentialsActive,
            "extensionConnected": extensionConnected,
            "ready": ready,
        ]
    }

    private static func homeDirectory() -> String {
        NSHomeDirectory()
    }

    private static func chromeManifestPath() -> String {
        "\(homeDirectory())/Library/Application Support/Google/Chrome/NativeMessagingHosts/\(NativeMessagingConfig.hostName).json"
    }

    private static func chromiumManifestPath() -> String {
        "\(homeDirectory())/Library/Application Support/Chromium/NativeMessagingHosts/\(NativeMessagingConfig.hostName).json"
    }

    private static func edgeManifestPath() -> String {
        "\(homeDirectory())/Library/Application Support/Microsoft Edge/NativeMessagingHosts/\(NativeMessagingConfig.hostName).json"
    }

    private static func firefoxManifestPath() -> String {
        "\(homeDirectory())/Library/Application Support/Mozilla/NativeMessagingHosts/\(NativeMessagingConfig.hostName).json"
    }

    private static func manifestTargets() -> [(String, Bool)] {
        [
            (chromeManifestPath(), false),
            (chromiumManifestPath(), false),
            (edgeManifestPath(), false),
            (firefoxManifestPath(), true),
        ]
    }

    private static func findBundledNativeHostBinary() -> String? {
        let bundle = Bundle(for: V2rayBoxPlugin.self)
        let candidates = [
            bundle.path(forResource: "secure_vpn_native_host", ofType: nil),
            Bundle.main.path(forResource: "secure_vpn_native_host", ofType: nil),
            Bundle.main.bundlePath + "/Contents/Resources/secure_vpn_native_host",
            Bundle.main.bundlePath + "/Contents/MacOS/secure_vpn_native_host",
            Bundle.main.bundlePath + "/Contents/Frameworks/secure_vpn_native_host",
        ]
        for candidate in candidates {
            if let path = candidate, isExecutable(path) {
                return path
            }
        }
        return nil
    }

    private static func writeNativeManifest(at path: String, hostPath: String, firefox: Bool) -> Bool {
        guard ensureParentDirectory(for: path) else {
            return false
        }
        let allowed = firefox
            ? "\"allowed_extensions\": [ \"\(NativeMessagingConfig.firefoxExtensionId)\" ]"
            : "\"allowed_origins\": [ \"chrome-extension://\(NativeMessagingConfig.chromeExtensionId)/\" ]"
        let json = """
        {
          "name": "\(NativeMessagingConfig.hostName)",
          "description": "RioNexTunnel proxy auth bridge",
          "path": "\(jsonEscape(hostPath))",
          "type": "stdio",
          \(allowed)
        }
        """
        return writePrivateFile(path: path, content: json + "\n")
    }

    private static func readPingTimestamp() -> Int64 {
        guard let content = try? String(contentsOf: extensionPingPath, encoding: .utf8) else {
            return 0
        }
        return Int64(content.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private static func ensureDirectory(_ url: URL) -> Bool {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }

    private static func ensureParentDirectory(for path: String) -> Bool {
        let url = URL(fileURLWithPath: path).deletingLastPathComponent()
        return ensureDirectory(url)
    }

    private static func writePrivateFile(path: String, content: String) -> Bool {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            return true
        } catch {
            return false
        }
    }

    private static func removeIfExists(_ path: String) {
        if fileManager.fileExists(atPath: path) {
            try? fileManager.removeItem(atPath: path)
        }
    }

    private static func fileExists(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue
    }

    private static func isExecutable(_ path: String) -> Bool {
        fileManager.isExecutableFile(atPath: path)
    }

    private static func jsonEscape(_ value: String) -> String {
        var escaped = ""
        for char in value {
            switch char {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            default: escaped.append(char)
            }
        }
        return escaped
    }
}
