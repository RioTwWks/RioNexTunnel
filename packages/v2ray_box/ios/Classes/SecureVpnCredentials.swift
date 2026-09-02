import Foundation

enum SecureVpnCredentials {
    private(set) static var username: String = ""
    private(set) static var password: String = ""
    private(set) static var socksPort: Int = 1080

    static func setSession(username: String?, password: String?, port: Int) {
        self.username = username ?? ""
        self.password = password ?? ""
        if port > 0 {
            self.socksPort = port
        }
        setenv("SECURE_VPN_SOCKS_USER", self.username, 1)
        setenv("SECURE_VPN_SOCKS_PASS", self.password, 1)
        setenv("SECURE_VPN_SOCKS_PORT", String(self.socksPort), 1)
    }

    static func clearSession() {
        username = ""
        password = ""
        socksPort = 1080
        unsetenv("SECURE_VPN_SOCKS_USER")
        unsetenv("SECURE_VPN_SOCKS_PASS")
        unsetenv("SECURE_VPN_SOCKS_PORT")
    }
}
