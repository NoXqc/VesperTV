import AVKit
import CloudKit
import CoreMedia
import Flutter
import TVServices
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var icloud: VesperICloud?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    VesperCrashNote.install()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    VesperMenu.register(engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VesperICloud") {
      icloud = VesperICloud(messenger: registrar.messenger())
    }
    VesperDisplay.register(engineBridge.pluginRegistry)
    VesperTopShelf.register(engineBridge.pluginRegistry)
    VesperCrashNote.register(engineBridge.pluginRegistry)
  }
}

/// An Objective-C exception that ends the app (an AVFoundation call refusing its
/// arguments, say) is written to Caches before tvOS ends it; the next session's
/// Send log prints it (`NativeCrash:`, lib/services/app_log.dart). Signals (a bad
/// pointer in the engine or a driver) never get here: `AppLog.step` names what was
/// running then (`LastStep:`). GitHub #20: movies closed the app on 968, no trace.
enum VesperCrashNote {
  static var file: URL? {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
      .appendingPathComponent("vespertv_native_crash.txt")
  }

  static func install() {
    NSSetUncaughtExceptionHandler { exception in
      let frames = exception.callStackSymbols.prefix(24).joined(separator: "\n")
      let note =
        "\(Date()) \(exception.name.rawValue): \(exception.reason ?? "no reason")\n\(frames)"
      if let url = VesperCrashNote.file {
        try? note.write(to: url, atomically: true, encoding: .utf8)
      }
    }
  }

  static func register(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "VesperCrashNote") else { return }
    let channel = FlutterMethodChannel(
      name: "vespertv/crash", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "take" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url = file, let note = try? String(contentsOf: url, encoding: .utf8) else {
        result(nil)
        return
      }
      try? FileManager.default.removeItem(at: url)
      result(note)
    }
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
  private static var observers: [NSObjectProtocol] = []

  static func register(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "VesperDisplay") else { return }
    let channel = FlutterMethodChannel(
      name: "vespertv/display", binaryMessenger: registrar.messenger())
    // The TV's own mode switch, for the Send log and `AppLog.step` (GitHub #20:
    // did the app end while the TV was switching, or after?).
    let center = NotificationCenter.default
    observers = [
      center.addObserver(forName: .AVDisplayManagerModeSwitchStart, object: nil, queue: .main) {
        _ in channel.invokeMethod("modeSwitch", arguments: "start")
      },
      center.addObserver(forName: .AVDisplayManagerModeSwitchEnd, object: nil, queue: .main) {
        _ in channel.invokeMethod("modeSwitch", arguments: "end")
      },
    ]
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

/// Backups in the viewer's own iCloud (`vespertv/icloud`, Dart `ICloudBackups`,
/// dev-notes/icloud-backups.md): CloudKit's private database of the container
/// iCloud.app.vespertv.player, record type `Backup` in the zone `Backups`, one
/// record per device (`device-<identifierForVendor>`) replaced by its next backup.
/// The backup is the record's `file` asset; `device`, `app` and `size` list without
/// downloading it. Nothing to sign in to: the device's own Apple ID.
/// The same class is in ios/Runner/AppDelegate.swift and tvos/Runner/AppDelegate.swift:
/// change both.
final class VesperICloud {
  static let containerId = "iCloud.app.vespertv.player"
  private static let recordType = "Backup"
  private let channel: FlutterMethodChannel
  private let zoneID = CKRecordZone.ID(zoneName: "Backups", ownerName: CKCurrentUserDefaultName)
  private var zoneReady = false
  private lazy var database: CKDatabase? =
    VesperICloud.entitled
    ? CKContainer(identifier: VesperICloud.containerId).privateCloudDatabase : nil

  /// CKContainer stops the app when the build lacks the iCloud entitlement (before
  /// the Apple developer portal step, or an export that dropped it), so look for it
  /// in our own code signature first; without it every call answers NOT_SET_UP. The
  /// key is spelled backwards so this code itself doesn't contain it.
  static let entitled: Bool = {
    guard let path = Bundle.main.executablePath,
      let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
    else { return false }
    let key = String("secivres-duolci.repoleved.elppa.moc".reversed())
    return data.range(of: Data(key.utf8)) != nil
  }()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "vespertv/icloud", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let db = database else {
      result(
        FlutterError(
          code: "NOT_SET_UP", message: "iCloud is not enabled in this build", details: nil))
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    let reply: (Any?) -> Void = { value in DispatchQueue.main.async { result(value) } }
    switch call.method {
    case "status":
      CKContainer(identifier: Self.containerId).accountStatus { status, _ in
        switch status {
        case .available: reply("available")
        case .noAccount: reply("noAccount")
        case .restricted: reply("restricted")
        default: reply("unavailable")
        }
      }
    case "save":
      guard let content = args["content"] as? String else {
        result(Self.badArguments)
        return
      }
      save(db, content: content, app: args["app"] as? String ?? "", reply: reply)
    case "list":
      list(db, reply: reply)
    case "read":
      guard let id = args["id"] as? String else {
        result(Self.badArguments)
        return
      }
      read(db, id: id, reply: reply)
    case "delete":
      guard let id = args["id"] as? String else {
        result(Self.badArguments)
        return
      }
      let op = CKModifyRecordsOperation(
        recordsToSave: nil, recordIDsToDelete: [CKRecord.ID(recordName: id, zoneID: zoneID)])
      op.qualityOfService = .userInitiated
      op.modifyRecordsResultBlock = { outcome in
        switch outcome {
        case .success: reply(nil)
        case .failure(let error): reply(Self.flutterError(error))
        }
      }
      db.add(op)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// What CloudKit's callbacks (other threads, one after another) fill in.
  private final class Box<T> {
    var value: T
    init(_ value: T) { self.value = value }
  }

  private static let badArguments = FlutterError(
    code: "BAD_ARGS", message: "Missing arguments", details: nil)

  /// This device's record: replaced by each of its backups.
  private var deviceRecordID: CKRecord.ID {
    let key = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    return CKRecord.ID(recordName: "device-" + key, zoneID: zoneID)
  }

  /// The `Backups` zone, made once (saving an existing zone changes nothing).
  private func withZone(_ db: CKDatabase, _ next: @escaping (Error?) -> Void) {
    if zoneReady {
      next(nil)
      return
    }
    let op = CKModifyRecordZonesOperation(
      recordZonesToSave: [CKRecordZone(zoneID: zoneID)], recordZoneIDsToDelete: nil)
    op.qualityOfService = .userInitiated
    op.modifyRecordZonesResultBlock = { [weak self] outcome in
      switch outcome {
      case .success:
        self?.zoneReady = true
        next(nil)
      case .failure(let error):
        next(error)
      }
    }
    db.add(op)
  }

  private func save(
    _ db: CKDatabase, content: String, app: String, reply: @escaping (Any?) -> Void
  ) {
    let data = Data(content.utf8)
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("vespertv-icloud-\(UUID().uuidString).json")
    do {
      try data.write(to: file)
    } catch {
      reply(Self.flutterError(error))
      return
    }
    // UIKit on the main thread (this call's), not in CloudKit's callbacks.
    let recordID = deviceRecordID
    let deviceName = UIDevice.current.name
    withZone(db) { error in
      if let error = error {
        try? FileManager.default.removeItem(at: file)
        reply(Self.flutterError(error))
        return
      }
      let record = CKRecord(recordType: Self.recordType, recordID: recordID)
      record["file"] = CKAsset(fileURL: file)
      record["device"] = deviceName
      record["app"] = app
      record["size"] = Int64(data.count)
      let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
      // Replaces whatever this device saved before, without fetching it first.
      op.savePolicy = .allKeys
      op.qualityOfService = .userInitiated
      let failure = Box<Error?>(nil)
      op.perRecordSaveBlock = { _, outcome in
        if case .failure(let error) = outcome { failure.value = error }
      }
      op.modifyRecordsResultBlock = { outcome in
        try? FileManager.default.removeItem(at: file)
        if case .failure(let error) = outcome, failure.value == nil { failure.value = error }
        if let error = failure.value {
          reply(Self.flutterError(error))
        } else {
          reply(nil)
        }
      }
      db.add(op)
    }
  }

  /// Every device's backup (no files downloaded). An account that never saved one
  /// has no zone yet: an empty list.
  private func list(_ db: CKDatabase, reply: @escaping (Any?) -> Void) {
    let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
    config.desiredKeys = ["device", "app", "size"]
    let op = CKFetchRecordZoneChangesOperation(
      recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: config])
    op.qualityOfService = .userInitiated
    let mine = deviceRecordID.recordName
    let out = Box<[[String: Any]]>([])
    op.recordWasChangedBlock = { id, outcome in
      guard case .success(let record) = outcome else { return }
      let modified = record.modificationDate ?? Date()
      out.value.append([
        "id": id.recordName,
        "device": record["device"] as? String ?? "",
        "app": record["app"] as? String ?? "",
        "size": (record["size"] as? NSNumber)?.int64Value ?? 0,
        "modified": Int64(modified.timeIntervalSince1970 * 1000),
        "mine": id.recordName == mine,
      ])
    }
    op.fetchRecordZoneChangesResultBlock = { outcome in
      switch outcome {
      case .success:
        reply(out.value)
      case .failure(let error):
        if Self.missingZone(error) {
          reply(out.value)
        } else {
          reply(Self.flutterError(error))
        }
      }
    }
    db.add(op)
  }

  private func read(_ db: CKDatabase, id: String, reply: @escaping (Any?) -> Void) {
    let op = CKFetchRecordsOperation(recordIDs: [CKRecord.ID(recordName: id, zoneID: zoneID)])
    op.desiredKeys = ["file"]
    op.qualityOfService = .userInitiated
    let text = Box<String?>(nil)
    let failure = Box<Error?>(nil)
    op.perRecordResultBlock = { _, outcome in
      switch outcome {
      case .success(let record):
        // The asset's file is only kept for a while: read it now.
        if let url = (record["file"] as? CKAsset)?.fileURL {
          text.value = try? String(contentsOf: url, encoding: .utf8)
        }
      case .failure(let error):
        failure.value = error
      }
    }
    op.fetchRecordsResultBlock = { outcome in
      if case .failure(let error) = outcome, failure.value == nil { failure.value = error }
      if let value = text.value {
        reply(value)
      } else if let error = failure.value {
        reply(Self.flutterError(error))
      } else {
        reply(FlutterError(code: "CLOUDKIT", message: "This backup has no file", details: nil))
      }
    }
    db.add(op)
  }

  private static func missingZone(_ error: Error) -> Bool {
    guard let ck = error as? CKError else { return false }
    if ck.code == .zoneNotFound || ck.code == .userDeletedZone { return true }
    if ck.code == .partialFailure, let parts = ck.partialErrorsByItemID, !parts.isEmpty {
      return parts.values.allSatisfy {
        let code = ($0 as? CKError)?.code
        return code == .zoneNotFound || code == .userDeletedZone
      }
    }
    return false
  }

  /// Codes Dart turns into words (ICloudBackups.errorMessage).
  private static func flutterError(_ error: Error) -> FlutterError {
    var code = "CLOUDKIT"
    if let ck = error as? CKError {
      switch ck.code {
      case .notAuthenticated: code = "NO_ACCOUNT"
      case .quotaExceeded: code = "QUOTA"
      case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited,
        .zoneBusy:
        code = "NETWORK"
      case .permissionFailure, .managedAccountRestricted: code = "RESTRICTED"
      case .badContainer, .missingEntitlement: code = "NOT_SET_UP"
      default: break
      }
    }
    return FlutterError(code: code, message: error.localizedDescription, details: nil)
  }
}
