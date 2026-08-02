import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "ContractLinkPlugin"
    ) else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "lov/contract_link",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getInitialLink" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let key = "lov_initial_contract_link"
      let link = UserDefaults.standard.string(forKey: key)
      UserDefaults.standard.removeObject(forKey: key)
      result(link)
    }
  }
}
