import Foundation

enum DesktopVpn {
    static func isVpnServiceMode(_ serviceMode: String) -> Bool {
        serviceMode == "vpn"
    }

    static func configOptionsEnableTun(_ json: String) -> Bool {
        !json.contains("\"enable-tun\":false") && !json.contains("\"enable-tun\": false")
    }

    static func desktopVpnActive(serviceMode: String, configOptions: String) -> Bool {
        isVpnServiceMode(serviceMode) && configOptionsEnableTun(configOptions)
    }

    static func shouldUseSystemProxy(serviceMode: String, configOptions: String) -> Bool {
        if desktopVpnActive(serviceMode: serviceMode, configOptions: configOptions) {
            return false
        }
        return configOptions.contains("\"set-system-proxy\":true") ||
            configOptions.contains("\"set-system-proxy\": true")
    }

    static func validateStart(
        serviceMode: String,
        configOptions: String,
        engine: String,
        binaryPath: String
    ) -> String? {
        guard desktopVpnActive(serviceMode: serviceMode, configOptions: configOptions) else {
            return nil
        }
        if engine == "skadi" {
            return "SkadiCore desktop VPN is not supported. Use sing-box or Xray."
        }
        if binaryPath.isEmpty {
            return "Core binary not found. Run scripts/fetch_cores.sh."
        }
        if geteuid() != 0 {
            return "Desktop VPN (TUN) on macOS requires administrator privileges. "
                + "Launch the app with sudo or use Proxy mode."
        }
        return nil
    }
}
