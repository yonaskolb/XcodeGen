# (iOS) Alternate app icons


## Description

Adds alternate app icons to include in the built product.

## File structure

```diff
 .
 ├── MyApp
 │   ├── AppDelegate.swift
 │   ├── Assets.xcassets
 │   │   ├── AppIcon.appiconset
 │   │   │   ├── AppIcon.png
 |   |   |   └── Contents.json
+│   │   ├── AppIcon2.appiconset
+│   │   │   ├── AppIcon.png
+|   |   |   └── Contents.json
+│   │   ├── AppIcon3.appiconset
+│   │   │   ├── AppIcon.png
+|   |   |   └── Contents.json
 │   │   └── Contents.json
 │   ├── LaunchScreen.storyboard
 │   └── RootViewController.swift
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
+      ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS: YES
+      ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES: AppIcon2 AppIcon3
     sources:
       - MyApp
```
