/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Scene delegate required by the scene-based life cycle. The window and the
initial view controller are provided by Main.storyboard through the scene
configuration in Info.plist.
*/

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Nothing to set up: UIKit supplies the window from the storyboard.
    }
}
