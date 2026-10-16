import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var addressSearchPlugin: AddressSearchPlugin?
  private var nativeMediaPicker: NativeMediaPicker?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppRelease") {
      let channel = FlutterMethodChannel(name: "agent_uncle/app_release", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "info" {
          result([
            "platform": "ios",
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            "buildNumber": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
          ])
          return
        }
        guard call.method == "openStore" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let arguments = call.arguments as? [String: Any],
              let rawURL = arguments["url"] as? String,
              let url = URL(string: rawURL), url.scheme == "https", url.host == "apps.apple.com",
              url.user == nil, url.password == nil, url.port == nil, url.fragment == nil,
              url.path.range(of: #"/id[0-9]+$"#, options: .regularExpression) != nil else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LegalDocuments") {
      let channel = FlutterMethodChannel(name: "agent_uncle/legal_documents", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "open" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let arguments = call.arguments as? [String: Any],
              let rawURL = arguments["url"] as? String,
              ["https://www.the-saena.ai/terms", "https://www.the-saena.ai/privacy"].contains(rawURL),
              let url = URL(string: rawURL) else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
          result(opened)
        }
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TdsLiquidGlassHost") {
      TdsLiquidGlassHost.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AddressSearchPlugin") {
      addressSearchPlugin = AddressSearchPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeMediaPicker") {
      nativeMediaPicker = NativeMediaPicker.register(with: registrar)
    }
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    addressSearchPlugin?.dispose()
    addressSearchPlugin = nil
    nativeMediaPicker?.dispose()
    nativeMediaPicker = nil
    super.applicationWillTerminate(application)
  }
}
