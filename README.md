# XcodeGen

![Package Managers](https://img.shields.io/badge/package%20managers-SwiftPM-yellow.svg)
[![license](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/yonaskolb/SwagGen/blob/master/LICENSE)

A command line tool that generates an Xcode project from a YAML project spec

Given the following spec file:
```
targets
  - name: MyApp
    type: application
    platform: iOS
    sources: MyApp
    buildSettings:
      INFOPLIST_FILE: MyApp/Info.plist
      PRODUCT_BUNDLE_IDENTIFIER: com.myapp
    dependencies:
      - target: MyFramework
  - name: MyFramework
    type: framework
    platform: iOS
    sources: MyFramework
```
A project would be created with 2 targets and default `Debug` and `Release` configurations.

## Install
Make sure Xcode 8 is installed and run the following commands in the same directory as this repo. You can either build via the Swift Package Manager on the command line or Xcode

### 1. Command Line
```
swift build
```
This compiles a release build via the Swift Package Manager. You can find the output in the build directory which by default is at `.build/debug/XcodeGen`. You can simply run it with:

```
.build/debug/XcodeGen ..arguments
```

### 2. Xcode
```
swift package generate-xcodeproj
```
will create an `xcodeproj` file that you can open, edit and run in Xcode, which also makes editing any code easier.

If you want to pass the required arguments when running in XCode, you can edit the scheme to include launch arguments.

## Usage
Use `XcodeGen -help` to see the list of options:

- **spec** (required): This is the path to the yaml project spec.
- **project**: (optional): This is an optional path the generated xcode project file. If it is left out, the file will be written to the same directory as the spec, and with the same name as the spec file

# XcodeGen project spec
## configs
Configs specify the configurations in your project. 
Each config can specify a `type` of either `debug` or `release` which will then apply the default build settings for those types. A config can also specify it's own `buildSettings`
```
configs:
  Debug:
    type: debug
    buildSettings:
      MY_COOL_SETTING: value
  Release:
    type: release
```

## targets
This is list of targets
```
targets:
  - name: MyTarget
```
#### type
This specifies the product type of the target. This will provide default build settings for that product type. Type can be any of the following:
- application
- framework
- library.dynamic
- library.static
- bundle
- bundle.unit-test
- bundle.ui-testing
- app-extension
- tool
- application.watchapp
- application.watchapp2
- watchkit-extension
- watchkit2-extension
- tv-app-extension
- application.messages
- app-extension.messages
- app-extension.messages-sticker-pack
- xpc-service

### platform
TSpecifies the platform for the target. This will provide default build settings for that platform. Platform can be any of the following:
- iOS
- tvOS
- macOS
- watchOS

#### sources
Specifies the source directories for the target. This can either be a single path or a list of paths
```
targets:
  - name: MyTarget
    sources: MyTargetSource
  - name: MyOtherTarget
    sources: 
      - MyOtherTargetSource1
      - MyOtherTargetSource2
```

#### buildSettings
Species the build settings for the target. This can either be a simple map of build settings, or they can be broken down into specific configurations. If supplying configuration specific settings, a `$base` configuration may be used to provide default build settings that apply accross all configurations
```
configs
  test:
    type: debug
  staging:
    type: debug
  production:
    type: release
targets:
  - name: MyTarget
    buildSettings:
      INFO_PLIST: Info.plist
  - name: MyOtherTarget
    buildSettings: 
      $base:
        MY_SETTING: default
        MY_OTHER_SETTING: value
      test:
        MY_SETTING: test value
      staging:
        MY_SETTING: staging value
```

#### dependencies
Species the dependencies for the target. This can be another target, a path to a framework, or an sdk framework (INCOMPLETE)
```
targets:
  - name: MyTarget
    dependencies:
      - target: MyFramework
      - framework: path/to/framework.framework
      - sdk: UIKit  
  - name: MyFramework
```

#### configs
Specifies `.xcconfig` files for each configuration for the target.
```
targets:
  - name: MyTarget
    configs:
      Debug: configs/debug.xcconfig
      Release: configs/release.xcconfig
```
