import AVKit
import CoreMedia
import Flutter
import TVServices
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
    VesperMenu.register(engineBridge.pluginRegistry)
    VesperDisplay.register(engineBridge.pluginRegistry)
    VesperTopShelf.register(engineBridge.pluginRegistry)
  }
}

/// Apple TV's Top Shelf (lib/services/launcher_channels.dart `topShelf`, channel
/// `vespertv/launcher`, dev-notes/apple-tv-parity-plan.md point 5): the rows Dart sends are
/// kept as JSON in the App Group's defaults, where the TopShelf extension
/// (tvos/TopShelf/ContentProvider.swift) reads them. An item opens the app on
/// `vespertv://launcher?k=<key>`, which reaches Flutter's scene delegate and, through
/// `addSceneDelegate`, this class: `hasLink` / `takeLink` hand it to Dart like Android's
/// launcher links.
final class VesperTopShelf: NSObject, FlutterSceneLifeCycleDelegate {
  static let shared = VesperTopShelf()
  static let appGroup = "group.app.vespertv.player"
  static let contentKey = "vesper_top_shelf"
  /// Top Shelf shows a few dozen items at most; keeps the stored JSON small.
  private static let maxItems = 40

  private var channel: FlutterMethodChannel?
  private var pendingLink: String?

  static func register(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "VesperTopShelf") else { return }
    let channel = FlutterMethodChannel(
      name: "vespertv/launcher", binaryMessenger: registrar.messenger())
    shared.channel = channel
    registrar.addSceneDelegate(shared)
    channel.setMethodCallHandler { call, result in
      shared.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "publish":
      result(publish(call.arguments as? [String: Any] ?? [:]))
    case "liveAlive":
      result(nil)
    case "hasLink":
      result(pendingLink != nil)
    case "takeLink":
      let link = pendingLink
      pendingLink = nil
      result(link)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Stores the rows and tells tvOS to ask the extension again. The report goes to the
  /// Send log (counts only); `shared` = the App Group exists in this build's signature
  /// (without it the extension never sees the rows).
  private func publish(_ args: [String: Any]) -> [String: Any] {
    var rows: [[String: Any]] = []
    var count = 0
    for row in args["rows"] as? [[String: Any]] ?? [] {
      let room = max(0, Self.maxItems - count)
      let items = Array((row["items"] as? [[String: Any]] ?? []).prefix(room))
      if items.isEmpty { continue }
      count += items.count
      rows.append(["title": row["title"] as? String ?? "", "items": items])
    }
    guard let data = try? JSONSerialization.data(withJSONObject: ["rows": rows]) else {
      return ["error": "encode"]
    }
    let shared =
      FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
      != nil
    UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.contentKey)
    TVTopShelfContentProvider.topShelfContentDidChange()
    return ["rows": rows.count, "items": count, "bytes": data.count, "shared": shared]
  }

  /// A Top Shelf item opened the app (cold start).
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let contexts = connectionOptions?.urlContexts else { return false }
    return take(contexts)
  }

  /// A Top Shelf item while the app was running in the background.
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    take(URLContexts)
  }

  private func take(_ contexts: Set<UIOpenURLContext>) -> Bool {
    guard
      let url = contexts.map({ $0.url }).first(where: {
        $0.scheme == "vespertv" && $0.host == "launcher"
      })
    else { return false }
    pendingLink = url.absoluteString
    channel?.invokeMethod("link", arguments: nil)
    return true
  }
}

/// The TV follows the video's frame rate (lib/services/apple_tv_display.dart, channel
/// `vespertv/display`, dev-notes/apple-tv-parity-plan.md point 1). tvOS switches only when
/// the viewer's Settings > Video and Audio > Match Content > Match Frame Rate is on
/// (`isDisplayCriteriaMatchingEnabled`), and the public `AVDisplayCriteria` initializer is
/// tvOS 17+. Always SDR (BT.709): mpv tone-maps HDR into the 8-bit Flutter texture, so an
/// HDR mode would show wrong colours.
enum VesperDisplay {
  static func register(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "VesperDisplay") else { return }
    let channel = FlutterMethodChannel(
      name: "vespertv/display", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      DispatchQueue.main.async {
        switch call.method {
        case "match":
          let args = call.arguments as? [String: Any] ?? [:]
          let fps = (args["fps"] as? NSNumber)?.doubleValue ?? 0
          let width = (args["width"] as? NSNumber)?.int32Value ?? 1920
          let height = (args["height"] as? NSNumber)?.int32Value ?? 1080
          result(match(fps: fps, width: width, height: height))
        case "reset":
          manager()?.preferredDisplayCriteria = nil
          result(nil)
        case "status":
          let m = manager()
          var supported = false
          if #available(tvOS 17.0, *) { supported = m != nil }
          result([
            "supported": supported,
            "enabled": m?.isDisplayCriteriaMatchingEnabled ?? false,
            "switching": m?.isDisplayModeSwitchInProgress ?? false,
          ])
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  /// The app's window: its display manager is the one tvOS listens to.
  private static func manager() -> AVDisplayManager? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first
    return window?.avDisplayManager
  }

  private static func match(fps: Double, width: Int32, height: Int32) -> String {
    guard fps > 0 else { return "no rate" }
    guard #available(tvOS 17.0, *) else { return "unsupported (tvOS 16 or older)" }
    guard let manager = manager() else { return "unsupported (no window)" }
    guard manager.isDisplayCriteriaMatchingEnabled else {
      return "off in the Apple TV's Settings (Match Content)"
    }
    let extensions: [String: Any] = [
      kCVImageBufferColorPrimariesKey as String: kCVImageBufferColorPrimaries_ITU_R_709_2,
      kCVImageBufferTransferFunctionKey as String: kCVImageBufferTransferFunction_ITU_R_709_2,
      kCVImageBufferYCbCrMatrixKey as String: kCVImageBufferYCbCrMatrix_ITU_R_709_2,
    ]
    var description: CMVideoFormatDescription?
    let status = CMVideoFormatDescriptionCreate(
      allocator: kCFAllocatorDefault, codecType: kCMVideoCodecType_H264,
      width: max(width, 16), height: max(height, 16),
      extensions: extensions as CFDictionary, formatDescriptionOut: &description)
    guard status == noErr, let format = description else { return "no format (\(status))" }
    manager.preferredDisplayCriteria = AVDisplayCriteria(
      refreshRate: Float(fps), formatDescription: format)
    return String(format: "asked %.3f", fps)
  }
}

/// The Siri Remote's Menu button at VesperTV's top screen (lib/services/apple_tv_menu.dart,
/// dev-notes/apple-tv.md). The engine turns every Menu press into Back; at the top screen
/// tvOS expects Menu to leave to the Apple TV Home screen, which the system does when the
/// press goes up the responder chain instead of into Flutter. Dart says ahead when that
/// should happen: `setMenuExits` (the TV home, after each build) and `armMenuExit` (Back
/// reached a top screen: the next Menu press within 10 s).
enum VesperMenu {
  static var exits = false
  static var armedUntil: Date?

  static func register(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "VesperMenu") else { return }
    let channel = FlutterMethodChannel(
      name: "vespertv/tvos", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setMenuExits":
        exits = (call.arguments as? Bool) ?? false
        result(nil)
      case "armMenuExit":
        armedUntil = Date().addingTimeInterval(10)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// True when this press goes to the system (leaves the app). Any other
  /// button disarms [armedUntil].
  static func leaves(_ press: UIPress) -> Bool {
    guard press.type == .menu else {
      armedUntil = nil
      return false
    }
    if exits { return true }
    if let until = armedUntil, Date() < until {
      armedUntil = nil
      return true
    }
    return false
  }
}

/// The app's Flutter view (Main.storyboard). Menu presses [VesperMenu] lets
/// go skip Flutter and go up the responder chain, where tvOS leaves the app.
class VesperViewController: FlutterViewController {
  private var toSystem = Set<UIPress>()

  override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    let leaving = presses.filter { VesperMenu.leaves($0) }
    toSystem.formUnion(leaving)
    if !leaving.isEmpty { next?.pressesBegan(leaving, with: event) }
    let rest = presses.subtracting(leaving)
    if !rest.isEmpty { super.pressesBegan(rest, with: event) }
  }

  override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    let leaving = presses.intersection(toSystem)
    if !leaving.isEmpty { next?.pressesChanged(leaving, with: event) }
    let rest = presses.subtracting(leaving)
    if !rest.isEmpty { super.pressesChanged(rest, with: event) }
  }

  override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    let leaving = presses.intersection(toSystem)
    toSystem.subtract(leaving)
    if !leaving.isEmpty { next?.pressesEnded(leaving, with: event) }
    let rest = presses.subtracting(leaving)
    if !rest.isEmpty { super.pressesEnded(rest, with: event) }
  }

  override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    let leaving = presses.intersection(toSystem)
    toSystem.subtract(leaving)
    if !leaving.isEmpty { next?.pressesCancelled(leaving, with: event) }
    let rest = presses.subtracting(leaving)
    if !rest.isEmpty { super.pressesCancelled(rest, with: event) }
  }
}
