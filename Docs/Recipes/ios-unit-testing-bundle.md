# (iOS) Unit Testing Bundle


## Description

Adds a unit test bundle that uses the XCTest framework.

## File structure

```diff
 .
 ├── MyApp
 │   ├── AppDelegate.swift
 │   ├── Assets.xcassets
 │   │   ├── AppIcon.appiconset
 │   │   │   ├── AppIcon.png
 |   |   |   └── Contents.json
 │   │   └── Contents.json
 │   ├── LaunchScreen.storyboard
 │   └── RootViewController.swift
+├── MyAppTests
+│   └── SomeTests.swift
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
       INFOPLIST_KEY_UILaunchStoryboardName: LaunchScreen.storyboard
       INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
     sources:
       - MyApp
+  MyAppTests:
+    type: bundle.unit-test
+    platform: iOS
+    settings:
+      DEVELOPMENT_TEAM: MYTEAMID
+      PRODUCT_BUNDLE_IDENTIFIER: com.company.myapptests
+      GENERATE_INFOPLIST_FILE: YES
+    sources:
+      - MyAppTests
+    dependencies:
+      - target: MyApp
```
