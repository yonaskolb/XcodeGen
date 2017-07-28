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
A project would be created with 2 connected targets, with all the required configurations and build settings. See the [Project Spec](docs/ProjectSpec.md) documentation for all the options you can specify.

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

## Project Spec
See Project Spec documentation [here](docs/ProjectSpec.md)

## Attributions

This tool is powered by:

- [xcodeproj](https://github.com/carambalabs/xcodeproj)
- [JSONUtilities](https://github.com/yonaskolb/JSONUtilities)
- [Spectre](https://github.com/kylef/Spectre)
- [PathKit](https://github.com/kylef/PathKit)
- [Commander](https://github.com/kylef/Commander)
- [Yams](https://github.com/jpsim/Yams)

Inspriration for this tool came from:

- [struct](https://github.com/workshop/struct)
- [xcake](https://github.com/jcampbell05/xcake)
- [Cocoapods Xcodeproj](https://github.com/CocoaPods/Xcodeproj)

## Contributions
Pull requests and issues are welcome

## License

SwagGen is licensed under the MIT license. See [LICENSE](LICENSE) for more info.
