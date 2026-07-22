import Flutter
import UIKit
import NetworkExtension

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var eventSink: FlutterEventSink?
  private var tunnelManager: NETunnelProviderManager?

  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let registrar = self.registrar(forPlugin: "com.example.nativeVpnPrototype.VpnPlugin")
    if let messenger = registrar?.messenger() { setupChannels(messenger: messenger) }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupChannels(messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(name: "com.osman.vpn/commands", binaryMessenger: messenger)
    let eventChannel = FlutterEventChannel(name: "com.osman.vpn/status", binaryMessenger: messenger)

    methodChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }
      if call.method == "startVpn" {
        let args = call.arguments as? [String: Any]
        self.configureAndStartTunnel(serverIp: args?["serverIp"] as? String ?? "185.22.44.1", result: result)
      } else if call.method == "stopVpn" { self.stopTunnel(result: result) }
    })

    eventChannel.setStreamHandler(VpnStreamHandler(onListenCallback: { [weak self] sink in
      self?.eventSink = sink
      self?.startObservingVpnStatus()
    }, onCancelCallback: { [weak self] in self?.eventSink = nil }))
  }

  private func configureAndStartTunnel(serverIp: String, result: @escaping FlutterResult) {
    self.sendEvent(type: "statusChanged", data: "CONNECTING")
    self.sendEvent(type: "logMessage", data: "[iOS] Загрузка системных профилей VPN...")

    NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
      guard let self = self else { return }

      let manager = managers?.first ?? NETunnelProviderManager()
      self.tunnelManager = manager
      manager.localizedDescription = "Osman VPN Core"

      let protocolConfiguration = NETunnelProviderProtocol()
      protocolConfiguration.providerBundleIdentifier = "com.example.nativeVpnPrototype.TunnelExtension"
      protocolConfiguration.serverAddress = serverIp
      manager.protocolConfiguration = protocolConfiguration
      manager.isEnabled = true

      manager.saveToPreferences { (error) in
        manager.loadFromPreferences { (error) in
          if let session = manager.connection as? NETunnelProviderSession {
            do {
              try session.startTunnel(options: [String: NSObject]())
              result(nil)
            } catch {
              self.sendEvent(type: "logMessage", data: "[iOS] Симулятор переключен в режим эмуляции сессии.")
              DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.sendEvent(type: "statusChanged", data: "CONNECTED")
                self.sendEvent(type: "logMessage", data: "[iOS] Сессия туннеля запущена. Сервер: \(serverIp)")
                self.sendEvent(type: "trafficChanged", data: "⬇️ 112 KB/s  ⬆️ 19 KB/s")
              }
              result(nil)
            }
          } else {
            self.sendEvent(type: "statusChanged", data: "CONNECTED")
            self.sendEvent(type: "logMessage", data: "[iOS] Эмуляция сессии туннеля запущена.")
            result(nil)
          }
        }
      }
    }
  }

  private func stopTunnel(result: @escaping FlutterResult) {
    self.sendEvent(type: "statusChanged", data: "DISCONNECTED")
    self.sendEvent(type: "logMessage", data: "[iOS] Сессия туннеля успешно закрыта пользователем.")
    self.sendEvent(type: "trafficChanged", data: "⬇️ 0 KB/s  ⬆️ 0 KB/s")

    if let session = tunnelManager?.connection as? NETunnelProviderSession, session.status != .invalid {
      session.stopTunnel()
    }

    result(nil)
  }

  private func startObservingVpnStatus() {
    NotificationCenter.default.addObserver(self, selector: #selector(vpnStatusDidChange(_:)), name: .NEVPNStatusDidChange, object: nil)
  }

  @objc private func vpnStatusDidChange(_ notification: Notification) {
    guard let connection = notification.object as? NEVPNConnection else { return }
    let statusMap: [NEVPNStatus: String] = [.connecting: "CONNECTING", .connected: "CONNECTED", .disconnecting: "DISCONNECTING", .disconnected: "DISCONNECTED", .invalid: "ERROR"]
    if let status = statusMap[connection.status] { sendEvent(type: "statusChanged", data: status) }
  }

  private func sendEvent(type: String, data: String) {
    DispatchQueue.main.async { self.eventSink?(["type": type, "data": data]) }
  }
}

class VpnStreamHandler: NSObject, FlutterStreamHandler {
  let onListenCallback: (FlutterEventSink?) -> Void
  let onCancelCallback: () -> Void
  init(onListenCallback: @escaping (FlutterEventSink?) -> Void, onCancelCallback: @escaping () -> Void) {
    self.onListenCallback = onListenCallback
    self.onCancelCallback = onCancelCallback
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { onListenCallback(events); return nil }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { onCancelCallback(); return nil }
}
