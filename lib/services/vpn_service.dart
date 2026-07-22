import 'dart:async';
import 'package:flutter/services.dart';
import '../models/vpn_config.dart';

enum VpnState { disconnected, connecting, connected, disconnecting, error }

class VpnPlatformService {
  static const _methodChannel = MethodChannel('com.osman.vpn/commands');
  static const _eventChannel = EventChannel('com.osman.vpn/status');

  final _statusController = StreamController<VpnState>.broadcast();
  final _logController = StreamController<String>.broadcast();
  final _trafficController = StreamController<String>.broadcast();

  Stream<VpnState> get statusStream => _statusController.stream;
  Stream<String> get logStream => _logController.stream;
  Stream<String> get trafficStream => _trafficController.stream;

  VpnPlatformService() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final type = event['type'] as String;
        final data = event['data'] as String;
        switch (type) {
          case 'statusChanged': _statusController.add(_parseState(data)); break;
          case 'logMessage': _logController.add(data); break;
          case 'trafficChanged': _trafficController.add(data); break;
          case 'error': _statusController.add(VpnState.error); _logController.add(data); break;
        }
      }
    });
  }

  VpnState _parseState(String state) {
    switch (state) {
      case 'CONNECTING': return VpnState.connecting;
      case 'CONNECTED': return VpnState.connected;
      case 'DISCONNECTING': return VpnState.disconnecting;
      case 'DISCONNECTED': return VpnState.disconnected;
      default: return VpnState.disconnected;
    }
  }

  Future<void> startVpn(VpnConfig config) async => await _methodChannel.invokeMethod('startVpn', config.toMap());
  Future<void> stopVpn() async => await _methodChannel.invokeMethod('stopVpn');
}
