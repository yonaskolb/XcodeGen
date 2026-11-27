# (iOS) Playground


## Description

An alternative to XCode Playground.

Example of Source.swift:

```swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        var greeting = "Hello, playground"
        print(greeting)
        
        return true
    }
}
```

Another example with UI:

```swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow()
        self.window = window
        
        let rootViewController = RootViewController(nibName: nil, bundle: nil)
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        
        return true
    }
}

class RootViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
}
```


## File structure

```diff
.
├── Source.swift
└── project.yml
```

## project.yml

```diff
 name: MyApp
 targets:
   MyApp:
     type: application
     platform: iOS
     deploymentTarget: 12.0
     settings:
       TARGETED_DEVICE_FAMILY: 1
       MARKETING_VERSION: 1.0
       CURRENT_PROJECT_VERSION: 1
       DEVELOPMENT_TEAM: MYTEAMID
       PRODUCT_BUNDLE_IDENTIFIER: com.mycompany.myapp
       GENERATE_INFOPLIST_FILE: YES
       INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: YES
-      INFOPLIST_KEY_UILaunchStoryboardName: LaunchScreen.storyboard
+      INFOPLIST_KEY_UILaunchScreen_Generation: YES
       INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
     sources:
       - Source.swift
```
