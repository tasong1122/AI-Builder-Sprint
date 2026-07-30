import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let reminderSmsChannel = FlutterMethodChannel(
        name: "yaksok/reminder_sms",
        binaryMessenger: controller.binaryMessenger
      )
      reminderSmsChannel.setMethodCallHandler { call, result in
        guard call.method == "openSmsComposer" else {
          result(FlutterMethodNotImplemented)
          return
        }

        let arguments = call.arguments as? [String: Any]
        let body = arguments?["body"] as? String ?? ""
        let phoneNumber = arguments?["phoneNumber"] as? String ?? ""
        var components = URLComponents()
        components.scheme = "sms"
        components.path = phoneNumber
        components.queryItems = body.isEmpty ? nil : [
          URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url, application.canOpenURL(url) else {
          result(FlutterError(
            code: "NO_SMS_APP",
            message: "No SMS app is available.",
            details: nil
          ))
          return
        }

        application.open(url)
        result(nil)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
