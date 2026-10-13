import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var addressSearchPlugin: AddressSearchPlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TdsLiquidGlassHost") {
      TdsLiquidGlassHost.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AddressSearchPlugin") {
      addressSearchPlugin = AddressSearchPlugin.register(with: registrar)
    }
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    addressSearchPlugin?.dispose()
    addressSearchPlugin = nil
    super.applicationWillTerminate(application)
  }
}
