import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'models/vpn_config.dart';
import 'services/vpn_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp(theme: ThemeData.dark(), home: const VpnControlScreen());
}

class VpnControlScreen extends StatefulWidget {
  const VpnControlScreen({super.key});

  @override
  State<VpnControlScreen> createState() => _VpnControlScreenState();
}

class _VpnControlScreenState extends State<VpnControlScreen> {
  final VpnPlatformService _vpnService = VpnPlatformService();
  VpnState _currentState = VpnState.disconnected;
  String _traffic = "⬇️ 0 KB/s  ⬆️ 0 KB/s";
  final List<String> _logs = [];
  Timer? _ticker;
  int _connectionDuration = 0;
  final String _vlessUrl =
      "vless://93b6e8f1-c4d3-4a11-b22e@185.22.44.1:443?encryption=none";

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _requestNotificationPermission();
    }
    _vpnService.statusStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _currentState = state;
        if (state == VpnState.connected)
          _startTimer();
        else if (state == VpnState.disconnected || state == VpnState.error)
          _stopTimer();
      });
    });
    _vpnService.logStream.listen(
      (log) => setState(
        () => _logs.insert(
          0,
          "[${DateTime.now().toString().split(' ').last.substring(0, 8)}] $log",
        ),
      ),
    );
    _vpnService.trafficStream.listen(
      (traffic) => setState(() => _traffic = traffic),
    );
  }

  Future<void> _requestNotificationPermission() async {
    var status = await Permission.notification.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      final result = await Permission.notification.request();
      if (result.isGranted) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  void _startTimer() {
    _connectionDuration = 0;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _connectionDuration++);
    });
  }

  void _stopTimer() {
    _ticker?.cancel();
    if (mounted) setState(() => _connectionDuration = 0);
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    return "${duration.inHours.toString().padLeft(2, '0')}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsedConfig = VpnConfig.fromVless(_vlessUrl);
    return Scaffold(
      appBar: AppBar(title: const Text('Osman VPN Core Prototype')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _currentState.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _currentState == VpnState.connected
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Сервер: ${parsedConfig.serverIp}:${parsedConfig.serverPort}",
                    ),
                    Text(
                      "Время сессии: ${_formatDuration(_connectionDuration)}",
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _traffic,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _currentState == VpnState.disconnected
                        ? () => _vpnService.startVpn(parsedConfig)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('CONNECT'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _currentState == VpnState.connected
                        ? () async {
                            setState(() {
                              _currentState = VpnState.disconnecting;
                            });
                            await _vpnService.stopVpn();
                            if (mounted) {
                              setState(() {
                                _currentState = VpnState.disconnected;
                                _traffic = "⬇️ 0 KB/s  ⬆️ 0 KB/s";
                              });
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('DISCONNECT'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Системные логи (Native Bridge Logs):",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black,
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => Text(
                    _logs[index],
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
