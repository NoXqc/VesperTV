import AVFoundation
import AVKit
import CloudKit
import Flutter
import Speech
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pip: VesperPip?
  private var voice: VesperVoice?
  private var backupFolder: VesperBackupFolder?
  private var icloud: VesperICloud?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // A video player: sound plays with the silent switch on and keeps going
    // behind the lock screen (UIBackgroundModes audio), like the Music app.
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VesperPip") {
      pip = VesperPip(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VesperVoice") {
      voice = VesperVoice(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VesperBackupFolder") {
      backupFolder = VesperBackupFolder(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VesperICloud") {
      icloud = VesperICloud(messenger: registrar.messenger())
    }
  }
}

/// Picture-in-picture (`vespertv/pip`, Dart `IosPip`). iOS only floats
/// Apple's own player, and the app plays through mpv (media_kit), so the
/// stream is handed over: Dart stops mpv (freeing the provider's
/// connection), this opens the same link in an AVPlayer on a tiny layer and
/// starts PiP. Back to the app (the PiP window's restore button) or closed
/// (its X): "stopped" tells Dart where it got to, and mpv takes over again.
/// AVPlayer opens HLS and MP4, not MKV or raw MPEG-TS: Dart only offers
/// links it can play.
final class VesperPip: NSObject, AVPictureInPictureControllerDelegate {
  private let channel: FlutterMethodChannel
  private var player: AVPlayer?
  private var layerView: UIView?
  private var playerLayer: AVPlayerLayer?
  private var controller: AVPictureInPictureController?
  private var pendingResult: FlutterResult?
  private var statusObservation: NSKeyValueObservation?
  private var possibleObservation: NSKeyValueObservation?
  private var timeout: DispatchWorkItem?
  private var startPosition: Double = 0
  private var restoring = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "vespertv/pip", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "supported":
      result(AVPictureInPictureController.isPictureInPictureSupported())
    case "start":
      guard let args = call.arguments as? [String: Any],
        let link = args["url"] as? String,
        let url = URL(string: link)
      else {
        result("bad-url")
        return
      }
      start(
        url: url,
        position: args["position"] as? Double ?? 0,
        live: args["live"] as? Bool ?? false,
        headers: args["headers"] as? [String: String] ?? [:],
        result: result)
    case "stop":
      let position = currentPosition()
      teardown()
      result(position)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(
    url: URL, position: Double, live: Bool, headers: [String: String],
    result: @escaping FlutterResult
  ) {
    teardown()
    guard AVPictureInPictureController.isPictureInPictureSupported() else {
      result("unsupported")
      return
    }
    guard let host = hostView() else {
      result("no-view")
      return
    }
    try? AVAudioSession.sharedInstance().setActive(true)
    let asset = AVURLAsset(
      url: url,
      options: headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers])
    let item = AVPlayerItem(asset: asset)
    let player = AVPlayer(playerItem: item)
    // PiP needs the layer in a window; 2 points in a corner is enough and
    // stays out of sight and out of the way of touches.
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
    view.isUserInteractionEnabled = false
    let layer = AVPlayerLayer(player: player)
    layer.frame = view.bounds
    layer.videoGravity = .resizeAspect
    view.layer.addSublayer(layer)
    host.addSubview(view)
    guard let controller = AVPictureInPictureController(playerLayer: layer) else {
      view.removeFromSuperview()
      result("no-controller")
      return
    }
    controller.delegate = self
    // Live: no seek bar or +-15 s in the PiP window.
    controller.requiresLinearPlayback = live
    self.player = player
    self.layerView = view
    self.playerLayer = layer
    self.controller = controller
    self.pendingResult = result
    self.startPosition = position

    statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      DispatchQueue.main.async {
        guard let self = self, self.player?.currentItem === item else { return }
        switch item.status {
        case .readyToPlay:
          if self.startPosition > 0 {
            self.player?.seek(
              to: CMTime(seconds: self.startPosition, preferredTimescale: 600),
              toleranceBefore: .zero, toleranceAfter: .zero)
            self.startPosition = 0
          }
          self.player?.play()
          self.tryStart()
        case .failed:
          self.finishStart(error: "load-failed: \(item.error?.localizedDescription ?? "?")")
        default:
          break
        }
      }
    }
    possibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.new]) {
      [weak self] _, _ in
      DispatchQueue.main.async { self?.tryStart() }
    }
    let timeout = DispatchWorkItem { [weak self] in self?.finishStart(error: "timeout") }
    self.timeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
  }

  private func tryStart() {
    guard pendingResult != nil, let controller = controller,
      player?.currentItem?.status == .readyToPlay,
      controller.isPictureInPicturePossible,
      !controller.isPictureInPictureActive
    else { return }
    controller.startPictureInPicture()
  }

  private func finishStart(error: String?) {
    timeout?.cancel()
    timeout = nil
    guard let result = pendingResult else { return }
    pendingResult = nil
    if let error = error {
      teardown()
      result(error)
    } else {
      result(nil)
    }
  }

  private func currentPosition() -> Double {
    let seconds = player?.currentTime().seconds ?? 0
    return seconds.isFinite ? seconds : 0
  }

  private func teardown() {
    timeout?.cancel()
    timeout = nil
    statusObservation?.invalidate()
    statusObservation = nil
    possibleObservation?.invalidate()
    possibleObservation = nil
    if let controller = controller {
      controller.delegate = nil
      if controller.isPictureInPictureActive { controller.stopPictureInPicture() }
    }
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    playerLayer?.removeFromSuperlayer()
    layerView?.removeFromSuperview()
    player = nil
    playerLayer = nil
    layerView = nil
    controller = nil
    restoring = false
    if let result = pendingResult {
      pendingResult = nil
      result("cancelled")
    }
  }

  private func hostView() -> UIView? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    let window = windows.first { $0.isKeyWindow } ?? windows.first
    return window?.rootViewController?.view
  }

  // MARK: AVPictureInPictureControllerDelegate

  func pictureInPictureControllerDidStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    finishStart(error: nil)
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    finishStart(error: "pip-failed: \(error.localizedDescription)")
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler:
      @escaping (Bool) -> Void
  ) {
    restoring = true
    completionHandler(true)
  }

  func pictureInPictureControllerDidStopPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    let position = currentPosition()
    let restore = restoring
    teardown()
    channel.invokeMethod("stopped", arguments: ["restore": restore, "position": position])
  }
}

/// Voice commands on iPhone / iPad (`vespertv/voice` + `vespertv/voice/events`,
/// the same protocol as Android's VoiceBridge.kt; Dart `VoiceInput`): Apple's
/// speech recognizer on the microphone, and text-to-speech for spoken replies.
/// Android's recognizer stops by itself after a pause; this one stops 1.5 s
/// after the last new words (6 s if nothing is said, 15 s at most).
final class VesperVoice: NSObject, FlutterStreamHandler {
  private let channel: FlutterMethodChannel
  private let events: FlutterEventChannel
  private var sink: FlutterEventSink?
  private let engine = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private var silence: DispatchWorkItem?
  private var limit: DispatchWorkItem?
  private var lastText = ""
  private var finished = true
  private var levelTick = 0
  private let synth = AVSpeechSynthesizer()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "vespertv/voice", binaryMessenger: messenger)
    events = FlutterEventChannel(name: "vespertv/voice/events", binaryMessenger: messenger)
    super.init()
    events.setStreamHandler(self)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func send(_ event: [String: Any]) {
    DispatchQueue.main.async { self.sink?(event) }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "available":
      result(SFSpeechRecognizer() != nil)
    case "hasPermission":
      result(
        SFSpeechRecognizer.authorizationStatus() == .authorized
          && AVAudioSession.sharedInstance().recordPermission == .granted)
    case "requestPermission":
      SFSpeechRecognizer.requestAuthorization { status in
        guard status == .authorized else {
          DispatchQueue.main.async { result(false) }
          return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          DispatchQueue.main.async { result(granted) }
        }
      }
    case "start":
      start(lang: args?["lang"] as? String ?? "en-US")
      result(nil)
    case "stop":
      finish()
      result(nil)
    case "cancel":
      if !finished { endSession(sendEnd: true) }
      result(nil)
    case "speak":
      speak(args?["text"] as? String ?? "", lang: args?["lang"] as? String ?? "en-US")
      result(nil)
    case "stopSpeaking":
      synth.stopSpeaking(at: .immediate)
      result(nil)
    case "takeAssist":
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func fail(_ code: String) {
    send(["type": "error", "code": code])
    endSession(sendEnd: true)
  }

  private func start(lang: String) {
    // A session still running (a second Talk): end it quietly.
    if !finished { endSession(sendEnd: false) }
    synth.stopSpeaking(at: .immediate)
    finished = false
    lastText = ""
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: lang)) ?? SFSpeechRecognizer(),
      recognizer.isAvailable
    else {
      fail("unavailable")
      return
    }
    // Play and record: the video's sound keeps going while listening.
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
      try session.setActive(true)
    } catch {
      fail("audio")
      return
    }
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    self.request = request
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      fail("audio")
      return
    }
    input.removeTap(onBus: 0)
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
      request.append(buffer)
      self?.level(buffer)
    }
    engine.prepare()
    do {
      try engine.start()
    } catch {
      fail("busy")
      return
    }
    task = recognizer.recognitionTask(with: request) { [weak self] result, error in
      DispatchQueue.main.async {
        guard let self = self, !self.finished, self.request === request else { return }
        if let result = result {
          let text = result.bestTranscription.formattedString
          if result.isFinal {
            self.done(text)
            return
          }
          if text != self.lastText {
            self.lastText = text
            self.send(["type": "partial", "text": text])
            self.armSilence(after: 1.5)
          }
        }
        if let error = error {
          if self.lastText.isEmpty {
            self.fail(self.code(for: error))
          } else {
            self.done(self.lastText)
          }
        }
      }
    }
    send(["type": "ready"])
    armSilence(after: 6)
    let limit = DispatchWorkItem { [weak self] in self?.finish() }
    self.limit = limit
    DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: limit)
  }

  private func armSilence(after seconds: Double) {
    silence?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.finish() }
    silence = work
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
  }

  /// Stops the microphone and lets the recognizer give its final text (the
  /// last words heard if it doesn't within 2 s).
  private func finish() {
    guard !finished, let request = request else { return }
    silence?.cancel()
    limit?.cancel()
    stopAudio()
    request.endAudio()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
      guard let self = self, !self.finished, self.request === request else { return }
      self.done(self.lastText)
    }
  }

  private func done(_ text: String) {
    guard !finished else { return }
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      send(["type": "error", "code": "nomatch"])
    } else {
      send(["type": "final", "text": text])
    }
    endSession(sendEnd: true)
  }

  private func endSession(sendEnd: Bool) {
    finished = true
    silence?.cancel()
    limit?.cancel()
    stopAudio()
    task?.cancel()
    task = nil
    request = nil
    // Back to the video player's session.
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .moviePlayback)
    try? session.setActive(true)
    if sendEnd { send(["type": "end"]) }
  }

  private func stopAudio() {
    if engine.isRunning { engine.stop() }
    engine.inputNode.removeTap(onBus: 0)
  }

  /// The mic level for the orb, in Android's range (about -2 to 10).
  private func level(_ buffer: AVAudioPCMBuffer) {
    levelTick += 1
    guard levelTick % 3 == 0, let data = buffer.floatChannelData?[0] else { return }
    let count = Int(buffer.frameLength)
    guard count > 0 else { return }
    var sum: Float = 0
    for i in 0..<count { sum += data[i] * data[i] }
    let db = 20 * log10(max(sqrt(sum / Float(count)), 1e-6))
    send(["type": "level", "value": Double((db + 60) / 60 * 12 - 2)])
  }

  private func code(for error: Error) -> String {
    let ns = error as NSError
    switch ns.code {
    case 1110, 203, 216: return "nomatch"
    case 1700, 1101: return "busy"
    default:
      return ns.domain.lowercased().contains("network") ? "network" : "unavailable"
    }
  }

  private func speak(_ text: String, lang: String) {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    synth.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: lang)
    synth.speak(utterance)
  }
}

/// Settings > Backup & restore > Backup folder (`vespertv/backup_folder`, Dart
/// `BackupFolder`): a folder picked once in Files (iCloud Drive, OneDrive, an SMB
/// server added to Files...) where backups are saved, listed and read instead of
/// On My iPhone. Access is kept as a bookmark in UserDefaults (not a Flutter pref,
/// so it never travels in a backup); each write / read / delete is coordinated with
/// the Files provider, and a coordinated read downloads an iCloud file that is only
/// a placeholder on this device.
final class VesperBackupFolder: NSObject, UIDocumentPickerDelegate {
  private static let key = "vesper_backup_folder_bookmark"
  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "vespertv.backup-folder", qos: .userInitiated)
  private var pending: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "vespertv/backup_folder", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "choose":
      choose(result)
    case "clear":
      UserDefaults.standard.removeObject(forKey: Self.key)
      result(nil)
    case "name":
      guard UserDefaults.standard.data(forKey: Self.key) != nil else {
        result(nil)
        return
      }
      guard let url = Self.folder() else {
        result(Self.unreachable)
        return
      }
      result(url.lastPathComponent)
    case "write":
      guard let name = args["name"] as? String, let content = args["content"] as? String
      else {
        result(Self.badArguments)
        return
      }
      run(result) { dir in
        let target = dir.appendingPathComponent(Self.fileName(name))
        try Self.coordinate(writing: target, options: .forReplacing) { url in
          try content.write(to: url, atomically: true, encoding: .utf8)
        }
        return target.lastPathComponent
      }
    case "list":
      run(result) { dir in try Self.list(dir) }
    case "read":
      guard let id = args["id"] as? String else {
        result(Self.badArguments)
        return
      }
      run(result) { dir in
        let target = dir.appendingPathComponent(Self.fileName(id))
        var text = ""
        var coordinationError: NSError?
        var readError: Error?
        NSFileCoordinator().coordinate(
          readingItemAt: target, options: [], error: &coordinationError
        ) { url in
          do {
            text = try String(contentsOf: url, encoding: .utf8)
          } catch {
            readError = error
          }
        }
        if let error = coordinationError { throw error }
        if let error = readError { throw error }
        return text
      }
    case "delete":
      guard let id = args["id"] as? String else {
        result(Self.badArguments)
        return
      }
      run(result) { dir in
        let target = dir.appendingPathComponent(Self.fileName(id))
        try Self.coordinate(writing: target, options: .forDeleting) { url in
          try FileManager.default.removeItem(at: url)
        }
        return true
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static let badArguments = FlutterError(
    code: "BAD_ARGS", message: "Missing arguments", details: nil)
  private static let unreachable = FlutterError(
    code: "UNREACHABLE",
    message: "The backup folder can't be opened. Choose it again in Backup & restore.",
    details: nil)

  /// A plain file name: never a path out of the folder.
  private static func fileName(_ name: String) -> String {
    (name as NSString).lastPathComponent
  }

  /// The chosen folder, from its bookmark (renewed when iOS says it went stale).
  private static func folder() -> URL? {
    guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
    var stale = false
    guard
      let url = try? URL(
        resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    else { return nil }
    if stale {
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      if let fresh = try? url.bookmarkData(
        options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
      {
        UserDefaults.standard.set(fresh, forKey: key)
      }
    }
    return url
  }

  /// [body] on a background queue with the folder opened; its answer (or the
  /// error) back to Dart on the main thread.
  private func run(_ result: @escaping FlutterResult, _ body: @escaping (URL) throws -> Any?) {
    queue.async {
      guard let dir = Self.folder() else {
        DispatchQueue.main.async { result(Self.unreachable) }
        return
      }
      let scoped = dir.startAccessingSecurityScopedResource()
      defer { if scoped { dir.stopAccessingSecurityScopedResource() } }
      do {
        let value = try body(dir)
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(code: "FOLDER", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private static func coordinate(
    writing url: URL, options: NSFileCoordinator.WritingOptions,
    _ body: (URL) throws -> Void
  ) throws {
    var coordinationError: NSError?
    var bodyError: Error?
    NSFileCoordinator().coordinate(
      writingItemAt: url, options: options, error: &coordinationError
    ) { target in
      do {
        try body(target)
      } catch {
        bodyError = error
      }
    }
    if let error = coordinationError { throw error }
    if let error = bodyError { throw error }
  }

  /// The folder's VesperTV backups. iCloud Drive shows a file that isn't
  /// downloaded on this device as ".name.icloud": listed under its real name
  /// (reading it downloads it).
  private static func list(_ dir: URL) throws -> [[String: Any]] {
    let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
    let items = try FileManager.default.contentsOfDirectory(
      at: dir, includingPropertiesForKeys: keys, options: [])
    var out: [[String: Any]] = []
    for item in items {
      var name = item.lastPathComponent
      var placeholder = false
      if name.hasPrefix("."), name.hasSuffix(".icloud") {
        name = String(name.dropFirst().dropLast(".icloud".count))
        placeholder = true
      }
      guard name.hasPrefix("vespertv-"), name.hasSuffix(".json") else { continue }
      let values = try? item.resourceValues(forKeys: Set(keys))
      let modified = values?.contentModificationDate ?? Date()
      out.append([
        "id": name,
        "name": name,
        "modified": Int64(modified.timeIntervalSince1970 * 1000),
        "size": placeholder ? 0 : (values?.fileSize ?? 0),
      ])
    }
    return out
  }

  private func choose(_ result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "BUSY", message: "The folder picker is already open", details: nil))
      return
    }
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    guard let presenter = top else {
      result(FlutterError(code: "NO_WINDOW", message: "No window to show Files in", details: nil))
      return
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.delegate = self
    picker.allowsMultipleSelection = false
    pending = result
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
  {
    guard let result = pending else { return }
    pending = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let data = try url.bookmarkData(
        options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
      UserDefaults.standard.set(data, forKey: Self.key)
      result(url.lastPathComponent)
    } catch {
      result(FlutterError(code: "FOLDER", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(nil)
    pending = nil
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
