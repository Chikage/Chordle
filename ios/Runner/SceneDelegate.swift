import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidEnterBackground(_ scene: UIScene) {
    ChordleFluidSynthEngine.shared.enterBackground()
    super.sceneDidEnterBackground(scene)
  }
}
