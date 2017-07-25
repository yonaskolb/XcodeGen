# XcodeGen

![Package Managers](https://img.shields.io/badge/package%20managers-SwiftPM-yellow.svg)
[![Build Status](https://img.shields.io/travis/yonaskolb/XcodeGen/master.svg?style=flat)](https://travis-ci.org/yonaskolb/XcodeGen)
[![license](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/yonaskolb/XcodeGen/blob/master/LICENSE)

A command line tool that generates your Xcode project from a YAML project spec and your folder structure. 
This allows for easy configuration which is git friendly, and means your project structure represents exacty what's on disk. The project can be re-generated on demand which means you can remove your xcode project from git and say goodbye to .xcodeproj merge conflicts!

Given a simple project spec file:
```yaml
name: My Project
configs:
  debug:
    type: debug
  release:
    type: release
targets:
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
A project would be created with 2 connected targets, with all the required build settings. See below for the full spec and all the options it provides.

## Install
Make sure Xcode 8 is installed and run the following commands in the same directory as this repo. You can either build via the Swift Package Manager on the command line or Xcode

### 1. Command Line
```
swift build
```
This compiles a build via the Swift Package Manager. You can find the output in the build directory which by default is at `.build/debug/XcodeGen`. You can simply run it with:

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

- **spec** (required): This is the path to the yaml project spec. If none is specified, XcodeGen will look for a `xcodegen.yml` file
- **project**: (optional): This is an optional path the generated xcode project file. If it is left out, the file will be written to the same directory as the spec, and with the same name as the spec file

# XcodeGen project spec

## configs
Configs specify the configurations in your project. 
Each config can specify a `type` of either `debug` or `release` which will then apply the default build settings for those types. A config can also specify its own list of `buildSettings`
```yaml
configs:
  Debug:
    type: debug
    buildSettings:
      MY_COOL_SETTING: value
  Release:
    type: release
```
If no configs are specified, default `Debug` and `Release` configs will be created for you

## targets
This is list of targets
```yaml
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
Specifies the platform for the target. This will provide default build settings for that platform. It can be any of the following:
- iOS
- tvOS
- macOS
- watchOS

#### sources
Specifies the source directories for the target. This can either be a single path or a list of paths. Applicable source files, resources, headers, and lproj files will be parsed appropriately
```yaml
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
```yaml
configs:
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
Species the dependencies for the target. This can be another target, a framework path, or a carthage dependency. 

Carthage dependencies look for frameworks in `Carthage/Build/PLATFORM/FRAMEWORK.framework` where `PLATFORM` is your target's platform, and `FRAMEWORK` is the carthage framework you've specified. 
If any applications contain carthage dependencies within itself or any dependent targets, a carthage copy files script is automatically added to the application containing all the relevant frameworks

```yaml
targets:
  - name: MyTarget
    dependencies:
      - target: MyFramework
      - framework: path/to/framework.framework
      - carthage: Result  
  - name: MyFramework
```

#### configs
Specifies `.xcconfig` files for each configuration for the target.
```yaml
targets:
  - name: MyTarget
    configs:
      Debug: config_files/debug.xcconfig
      Release: config_files/release.xcconfig
```

---

## Attributions

This tool is powered by:

- [xcodeproj](https://github.com/carambalabs/xcodeproj)
- [JSONUtilities](https://github.com/yonaskolb/JSONUtilities)
- [Spectre](https://github.com/kylef/Spectre)
- [PathKit](https://github.com/kylef/PathKit)
- [Commander](https://github.com/kylef/Commander)
- [Yams](https://github.com/jpsim/Yams)

## Contributions
Pull requests and issues are welcome

## License

SwagGen is licensed under the MIT license. See [LICENSE](LICENSE) for more info.
