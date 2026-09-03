class PanelSocksInbound {
  const PanelSocksInbound({
    required this.username,
    required this.password,
    required this.port,
  });

  final String username;
  final String password;
  final int port;

  bool get isValid =>
      username.isNotEmpty && password.isNotEmpty && port > 0 && port < 65536;
}
