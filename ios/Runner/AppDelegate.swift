import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let channelName = "icu.ringona.chordle/platform"
  private var platformChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    platformChannel = channel
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    ChordleFluidSynthEngine.shared.shutdown()
    super.applicationWillTerminate(application)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "prepareAudio":
      let arguments = call.arguments as? [String: Any]
      let program = arguments?["program"] as? Int ?? 0
      ChordleFluidSynthEngine.shared.prepare(program: program) { prepareResult in
        switch prepareResult {
        case .success(let ready):
          result(ready)
        case .failure(let error):
          result(
            FlutterError(
              code: "audio_prepare_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }

    case "playTones":
      guard let arguments = call.arguments as? [String: Any],
            let rawTones = arguments["tones"] as? [[String: Any]] else {
        result(FlutterError(code: "invalid_arguments", message: "缺少音高参数", details: nil))
        return
      }
      let tones = rawTones.compactMap { value -> FluidPlaybackTone? in
        guard let key = (value["key"] as? NSNumber)?.intValue else { return nil }
        let cents = (value["cents"] as? NSNumber)?.doubleValue ?? 0
        return FluidPlaybackTone(key: key, cents: cents)
      }
      ChordleFluidSynthEngine.shared.play(
        tones: tones,
        velocity: (arguments["velocity"] as? NSNumber)?.intValue ?? 104,
        program: (arguments["program"] as? NSNumber)?.intValue ?? 0,
        durationMilliseconds: (arguments["durationMs"] as? NSNumber)?.intValue ?? 1_200
      )
      result(nil)

    case "allSoundOff":
      ChordleFluidSynthEngine.shared.allSoundOff()
      result(nil)

    case "loadSettings":
      result(loadSettings())

    case "saveSettings":
      guard let values = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_arguments", message: "设置参数无效", details: nil))
        return
      }
      saveSettings(values)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func loadSettings() -> [String: Any] {
    let defaults = UserDefaults.standard
    return [
      "normalLow": storedInt(defaults, key: "playableRangeLow", fallback: 48),
      "normalHigh": storedInt(defaults, key: "playableRangeHigh", fallback: 72),
      "normalToneCount": storedInt(defaults, key: "chordToneCount", fallback: 3),
      "extraLow": storedInt(defaults, key: "extraPlayableRangeLow", fallback: 48),
      "extraHigh": storedInt(defaults, key: "extraPlayableRangeHigh", fallback: 72),
      "extraToneCount": storedInt(defaults, key: "extraChordToneCount", fallback: 3),
      "extraEdo": storedInt(defaults, key: "extraEdo", fallback: 24),
      "freeJiEnabled": defaults.object(forKey: "freeJiEnabled") as? Bool ?? false,
      "ratioMcqEdos": defaults.object(forKey: "ratioMcqEdos") ?? "[12]",
      "ratioMcqJiEnabled": defaults.object(forKey: "ratioMcqJiEnabled") as? Bool ?? false,
      "ratioMcqRatios": defaults.object(forKey: "ratioMcqRatios") ?? "[\"3/2\",\"4/3\"]",
      "ratioMcqOptionCount": storedInt(defaults, key: "ratioMcqOptionCount", fallback: 2),
      "ratioMcqConfigured": defaults.object(forKey: "ratioMcqConfigured") as? Bool ?? false,
      "overtoneLow": storedInt(defaults, key: "overtoneLow", fallback: 8),
      "overtoneHigh": storedInt(defaults, key: "overtoneHigh", fallback: 16),
      "overtoneToneCount": storedInt(defaults, key: "overtoneToneCount", fallback: 4),
      "instrumentProgram": storedInt(defaults, key: "instrumentProgram", fallback: 0),
      "keyPitchPreviewEnabled": defaults.object(forKey: "keyPitchPreviewEnabled") as? Bool ?? false,
    ]
  }

  private func saveSettings(_ values: [String: Any]) {
    let defaults = UserDefaults.standard
    let mapping = [
      "normalLow": "playableRangeLow",
      "normalHigh": "playableRangeHigh",
      "normalToneCount": "chordToneCount",
      "extraLow": "extraPlayableRangeLow",
      "extraHigh": "extraPlayableRangeHigh",
      "extraToneCount": "extraChordToneCount",
      "extraEdo": "extraEdo",
      "freeJiEnabled": "freeJiEnabled",
      "ratioMcqEdos": "ratioMcqEdos",
      "ratioMcqJiEnabled": "ratioMcqJiEnabled",
      "ratioMcqRatios": "ratioMcqRatios",
      "ratioMcqOptionCount": "ratioMcqOptionCount",
      "ratioMcqConfigured": "ratioMcqConfigured",
      "overtoneLow": "overtoneLow",
      "overtoneHigh": "overtoneHigh",
      "overtoneToneCount": "overtoneToneCount",
      "instrumentProgram": "instrumentProgram",
      "keyPitchPreviewEnabled": "keyPitchPreviewEnabled",
    ]
    let stableListKeys: Set<String> = ["ratioMcqEdos", "ratioMcqRatios"]
    for (flutterKey, nativeKey) in mapping {
      if let value = values[flutterKey] {
        defaults.set(
          stableListKeys.contains(flutterKey) ? stableListString(value) : value,
          forKey: nativeKey
        )
      }
    }
  }

  private func stableListString(_ value: Any) -> String {
    if let string = value as? String { return string }
    guard JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value),
          let encoded = String(data: data, encoding: .utf8) else {
      return String(describing: value)
    }
    return encoded
  }

  private func storedInt(_ defaults: UserDefaults, key: String, fallback: Int) -> Int {
    guard defaults.object(forKey: key) != nil else { return fallback }
    return defaults.integer(forKey: key)
  }
}
