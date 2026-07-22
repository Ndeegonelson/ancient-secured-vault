import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var screenSecurityChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VaultScreenSecurity")
    let channel = FlutterMethodChannel(
      name: "ancient_secure_docs/screen_security",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      DispatchQueue.main.async {
        switch call.method {
        case "enableReaderStayAwake":
          UIApplication.shared.isIdleTimerDisabled = true
          result(nil)
        case "disableReaderStayAwake":
          UIApplication.shared.isIdleTimerDisabled = false
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    screenSecurityChannel = channel
  }
}
