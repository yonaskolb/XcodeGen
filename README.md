<p align="center">
<a href="https://github.com/yonaskolb/XcodeGen">
<img src="Assets/Logo_animated.gif" alt="XcodeGen" />
</a>
</p>
<p align="center">
  <img src="https://img.shields.io/badge/package%20managers-SwiftPM-yellow.svg"/>
  <a href="https://github.com/yonaskolb/XcodeGen/releases">
    <img src="https://img.shields.io/github/release/yonaskolb/xcodegen.svg"/>
  </a>
  <a href="https://travis-ci.org/yonaskolb/XcodeGen">
    <img src="https://img.shields.io/travis/yonaskolb/XcodeGen/master.svg?style=flat"/>
  </a>
  <a href="https://github.com/yonaskolb/XcodeGen/blob/master/LICENSE">
    <img src="https://img.shields.io/github/license/mashape/apistatus.svg"/>
  </a>
</p>

# XcodeGen

XcodeGen is a command line tool that generates your Xcode project using your folder structure and a simple project spec.

The project spec is a YAML or JSON file that defines your targets, configurations, schemes and custom build settings. All you source directories are automatically parsed and referenced appropriately while preserving your folder structure. Sensible defaults are used in many places, so you only need to customize what is needed.

- ✅ Easy **configuration** of projects which is human readable and git friendly
- ✅ Groups in Xcode are always **synced** to your directories on disk
- ✅ Create projects on demand and remove your `.xcodeproj` file from git, which means **no merge conflicts**!
- ✅ Easily **copy and paste** files and directories without having to edit anything in xcode
- ✅ Share build settings across multiple targets with **build setting presets**
- ✅ Automatically generate Schemes for **different environments** like test and production
- ✅ Easily **create new projects** with complicated setups on demand without messing around with Xcode
- ✅ Generate from anywhere including **Continuous Delivery** servers


Given a very simple project spec file like this:

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

### Make

```
$ git clone https://github.com/yonaskolb/XcodeGen.git
$ cd XcodeGen
$ make
```
This will install XcodeGen to `usr/local/bin` so it can be used from anywhere

### Swift Package Manager

**Use CI tool**

```
$ git clone https://github.com/yonaskolb/XcodeGen.git
$ cd XcodeGen
$ swift build -c release
$ .build/release/XcodeGen
```

**Use as dependency**

Add the following to your Package.swift file's dependencies:

```
.Package(url: "https://github.com/yonaskolb/XcodeGen.git", majorVersion: 0)
```

And then import wherever needed: `import XcodeGenKit`

## Usage

Simply run:

```
$ xcodegen
```

This will look for a project spec in the current directory called `xcodegen.yml`

Use `xcodegen help` to see the list of options:

- **--spec**: This is an optional path to a `.yml` or `.json` project spec
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

Inspiration for this tool came from:

- [struct](https://github.com/workshop/struct)
- [xcake](https://github.com/jcampbell05/xcake)
- [CocoaPods Xcodeproj](https://github.com/CocoaPods/Xcodeproj)

## Contributions
Pull requests and issues are welcome

## License

XcodeGen is licensed under the MIT license. See [LICENSE](LICENSE) for more info.
