import AVFoundation
import AVKit
import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pip: VesperPip?
  private var voice: VesperVoice?

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
