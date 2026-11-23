import CloudKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var icloud: VesperICloud?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    VesperMenu.register(engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VesperICloud") {
      icloud = VesperICloud(messenger: registrar.messenger())
    }
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
