class VpnConfig {
  final String serverIp;
  final String serverPort;
  final String uuid;
  final String dns;

  VpnConfig({required this.serverIp, required this.serverPort, required this.uuid, this.dns = "8.8.8.8"});

  factory VpnConfig.fromVless(String url) {
    try {
      final uri = Uri.parse(url);
      return VpnConfig(serverIp: uri.host, serverPort: uri.port.toString(), uuid: uri.userInfo);
    } catch (e) {
      return VpnConfig(serverIp: "185.22.44.1", serverPort: "443", uuid: "vless-uuid-fallback");
    }
  }

  Map<String, dynamic> toMap() => {'serverIp': serverIp, 'serverPort': serverPort, 'uuid': uuid, 'dns': dns};
}
