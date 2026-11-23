import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // Closed from the app switcher: leave before Flutter tears its engine down
  // under mpv (VesperExit in AppDelegate.swift). One scene only
  // (UIApplicationSupportsMultipleScenes is false), and Flutter ends the
  // engine on a disconnect anyway, so nothing is lost by leaving here.
  override func sceneDidDisconnect(_ scene: UIScene) {
    VesperExit.now()
  }
}
