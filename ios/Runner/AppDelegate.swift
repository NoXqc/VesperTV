import AVFoundation
import AVKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pip: VesperPip?

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
