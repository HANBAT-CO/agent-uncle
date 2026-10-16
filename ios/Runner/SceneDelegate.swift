import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let response = connectionOptions.notificationResponse {
      PushNotifications.shared.capture(response.notification.request.content.userInfo)
    }
    for item in connectionOptions.urlContexts { _ = PushNotifications.shared.capture(item.url) }
  }
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let others = Set(URLContexts.filter { !PushNotifications.shared.capture($0.url) })
    if !others.isEmpty { super.scene(scene, openURLContexts: others) }
  }
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    PushNotifications.shared.changed()
  }
}
