import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    saveInitialContractLink(connectionOptions.urlContexts.first?.url)
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    saveInitialContractLink(URLContexts.first?.url)
    super.scene(scene, openURLContexts: URLContexts)
  }

  // Flutter 준비 전에 전달된 최초 돈 약속 링크를 임시 보관한다.
  private func saveInitialContractLink(_ url: URL?) {
    guard let url, url.scheme?.hasPrefix("kakao") == true, url.host == "kakaolink" else {
      return
    }
    UserDefaults.standard.set(url.absoluteString, forKey: "lov_initial_contract_link")
  }
}
