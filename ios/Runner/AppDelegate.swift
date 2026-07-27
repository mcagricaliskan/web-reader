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

    // webread/device_storage: free-space, device capacity, backup exclusion.
    // Kept small on purpose — see lib/core/device_storage.dart (D30).
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
      // Total + available for the Library's device-usage indicator. Returns
      // a map so the two values are read in one call and therefore describe
      // the same moment — a percentage assembled from two round-trips can
      // straddle a write and land outside 0...1.
      case "capacity":
        do {
          let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
          let values = try url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey,
          ])
          var payload: [String: Any] = [:]
          if let free = values.volumeAvailableCapacityForImportantUsage {
            payload["free"] = NSNumber(value: free)
          }
          if let total = values.volumeTotalCapacity {
            payload["total"] = NSNumber(value: total)
          }
          result(payload)
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
