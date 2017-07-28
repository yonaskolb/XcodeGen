# XcodeGen

![Package Managers](https://img.shields.io/badge/package%20managers-SwiftPM-yellow.svg)
[![Git Version](https://img.shields.io/github/release/yonaskolb/xcodegen.svg)](https://github.com/yonaskolb/XcodeGen/releases)
[![Build Status](https://img.shields.io/travis/yonaskolb/XcodeGen/master.svg?style=flat)](https://travis-ci.org/yonaskolb/XcodeGen)
[![license](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/yonaskolb/XcodeGen/blob/master/LICENSE)

A command line tool that generates your Xcode project from a YAML project spec and your folder structure.
This allows for easy configuration which is git friendly, and means your project structure represents exacty what's on disk. The project can be re-generated on demand which means you can remove your xcode project from git and say goodbye to .xcodeproj merge conflicts!

Given a simple project spec file:

```yaml
name: My Project
targets:
  - name: MyApp
    type: application
    platform: iOS
    sources: MyApp
    settings:
      INFOPLIST_FILE: MyApp/Info.plist
      PRODUCT_BUNDLE_IDENTIFIER: com.myapp
    dependencies:
      - target: MyFramework
  - name: MyFramework
    type: framework
    platform: iOS
    sources: MyFramework
```
A project would be created with 2 connected targets, with all the required configurations and build settings. See below for the full spec and all the options it provides.

## Installing
Make sure Xcode 8.3 is installed first.

**Make**:

```
$ git clone https://github.com/yonaskolb/XcodeGen.git
$ cd XcodeGen
$ make
```

**Swift Package Manager**:

Add the following to your Package.swift file's dependencies:

```
.Package(url: "https://github.com/yonaskolb/XcodeGen.git", majorVersion: 0)
```

And then import wherever needed:

```
import XcodeGenKit
```

## Usage

```
$ xcodegen
```
This will look for a project spec in the current directory called `xcodegen.yml`

Use `xcodegen help` to see the list of options:

- **--spec**: This is an optional path to the yaml project spec
- **--project**: This is an optional path the generated xcode project file. If it is left out, the file will be written to the same directory as the spec, and with the name included in the spec

## Editing
```
$ git clone https://github.com/yonaskolb/XcodeGen.git
$ cd XcodeGen
$ swift package generate-xcodeproj
```
This use Swift Project Manager to create an `xcodeproj` file that you can open, edit and run in Xcode, which makes editing any code easier.

If you want to pass any required arguments when running in XCode, you can edit the scheme to include launch arguments.

# XcodeGen project spec
Each spec must contain a name which is used for the generated project name.

#### configs
Configs specify the build configurations in the project.
Each config maps to a build type of either `debug` or `release` which will then apply default build settings for those types. Any value other than `debug` or `release` (for example "none"), will mean no default build settings will be loaded
```yaml
configs:
  Debug: debug
  Release: release
```
If no configs are specified, default `Debug` and `Release` configs will be created automatically

#### settings
Project settings use the [Settings](#settings-spec) spec. Default base and config type settings will be applied first before any custom settings

#### settingPresets
Setting presets can be used to group build settings together and reuse them elsewhere. Each preset is a Settings schema, so can include other presets

```yaml
settingPresets:
  preset1:
    BUILD_SETTING: value
  preset2:
    base:
      BUILD_SETTING: value
    presets:
      - preset
  preset3:
     configs:
        debug:
        	presets:
            - preset
```

## Settings Spec
Settings can be defined on the project and each target, and the format is the same. Settings can either be a simple list of build settings or can be more advanced with the following properties:

- `presets`: a list of presets to include and merge
- `configs`: a mapping of config name to a new nested settings spec. These settings will only be applied for that config
- `base`: used to specify default settings that apply to any config

```yaml
settings:
  BUILD_SETTING_1: value 1
  BUILD_SETTING_2: value 2
```

```yaml
settings:
  base:
    BUILD_SETTING_1: value 1
  configs:
    my_config:
      BUILD_SETTING_2: value 2
  presets:
    - my_settings
```

Settings are merged in the following order: presets, configs, base.

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

#### platform
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

#### settings
Species the build settings for the target. This uses the same [Settings](#settings-spec) spec as the project. Default platform and product type settings will be applied first before any custom settings

#### dependencies
Species the dependencies for the target. This can be another target, a framework path, or a carthage dependency.

Carthage dependencies look for frameworks in `Carthage/Build/PLATFORM/FRAMEWORK.framework` where `PLATFORM` is the target's platform, and `FRAMEWORK` is the carthage framework you've specified.
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

#### configFiles
Specifies `.xcconfig` files for each configuration for the target.

```yaml
targets:
  - name: MyTarget
    configFiles:
      Debug: config_files/debug.xcconfig
      Release: config_files/release.xcconfig
```

#### generateSchemes
This is a conveniance used to automatically generate schemes for a target based on large amount of configs. A list of names is provided, then for each of these names a scheme is created, using configs that contain the name with debug and release variants. This is useful for having different environment schemes.

For example, the following spec would create 3 schemes called:

- MyApp Test
- MyApp Staging
- MyApp Production

Each scheme would use different build configuration for the different build types, specifically debug configs for `run`, `test`, and `anaylze`, and release configs for `profile` and `archive`

```
configs:
  Test Debug: debug
  Staging Debug: debug
  Production Debug: debug
  Test Release: release
  Staging Release: release
  Production Release: release
targets
  - name: MyApp
    generateSchemes:
      - Test
      - Staging
      - Production
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
