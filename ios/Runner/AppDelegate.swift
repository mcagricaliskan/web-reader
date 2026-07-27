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

    // webread/device_storage: free-space + backup exclusion. Kept to two
    // calls on purpose — see lib/core/device_storage.dart (D30).
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "webread.device_storage")!
    let channel = FlutterMethodChannel(
      name: "webread/device_storage",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "freeBytes":
        do {
          let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
          let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
          if let capacity = values.volumeAvailableCapacityForImportantUsage {
            result(NSNumber(value: capacity))
          } else {
            result(nil)
          }
        } catch {
          result(nil)
        }
      case "excludeFromBackup":
        guard
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String
        else {
          result(false)
          return
        }
        var url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
          result(false)
          return
        }
        do {
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try url.setResourceValues(values)
          result(true)
        } catch {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
