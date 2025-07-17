import Framework
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // file from a framework
        _ = FrameworkStruct()

        // Standalone files added to project by path-to-file.
        _ = standaloneHello()

        // file in a synced folder
        _ = SyncedStruct()

        return true
    }
}
