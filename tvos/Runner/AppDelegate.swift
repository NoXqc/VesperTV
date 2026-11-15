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
    VesperMenu.register(engineBridge.pluginRegistry)
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
