# (iOS) Environments


## Description

Best way to setup Development, Testing and Production environments. 

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
 └── project.yml
```

## project.yml

```diff
 name: MyApp
+configs:
+  Dev Debug: debug
+  Test Debug: debug
+  Prod Debug: debug
+  Dev Release: release
+  Test Release: release
+  Prod Release: release
+settings:
+  configs:
+    Dev Debug:
+      SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG DEV
+    Test Debug:
+      SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG TEST
+    Prod Debug:
+      SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG PROD
+    Dev Release:
+      SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEV
+    Test Release:
+      SWIFT_ACTIVE_COMPILATION_CONDITIONS: TEST
+    Prod Release:
+      SWIFT_ACTIVE_COMPILATION_CONDITIONS: PROD
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
+    scheme:
+      configVariants:
+        - Dev
+        - Test
+        - Prod
```

