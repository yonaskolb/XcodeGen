<p align="center">
<a href="https://github.com/yonaskolb/XcodeGen">
<img src="Assets/Logo_animated.gif" alt="XcodeGen" />
</a>
</p>
<p align="center">
  <a href="https://swift.org/package-manager">
    <img src="https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat" alt="Swift Package Manager" />
  </a>
  <a href="https://github.com/yonaskolb/XcodeGen/releases">
    <img src="https://img.shields.io/github/release/yonaskolb/xcodegen.svg"/>
  </a>
  <a href="https://circleci.com/gh/yonaskolb/XcodeGen">
    <img src="https://img.shields.io/circleci/project/github/yonaskolb/Beak.svg?style=flat"/>
  </a>
  <a href="https://github.com/yonaskolb/XcodeGen/blob/master/LICENSE">
    <img src="https://img.shields.io/github/license/mashape/apistatus.svg"/>
  </a>
  <a href="http://xcodeswift.herokuapp.com/">
    <img src="https://xcodeswift.herokuapp.com/badge.svg">
  </a>
</p>

# XcodeGen

XcodeGen is a command line tool that generates your Xcode project using your folder structure and a simple project spec.

The project spec is a YAML or JSON file that defines your targets, configurations, schemes and custom build settings. All you source directories are automatically parsed and referenced appropriately while preserving your folder structure. Sensible defaults are used in many places, so you only need to customize what is needed.

- ✅ Easy **configuration** of projects which is human readable and git friendly
- ✅ Groups in Xcode are always **synced** to your directories on disk
- ✅ Create projects on demand and remove your `.xcodeproj` file from git, which means **no merge conflicts**!
- ✅ Easily **copy and paste** files and directories without having to edit anything in xcode
- ✅ Share build settings across multiple targets with **build setting groups**
- ✅ Automatically generate Schemes for **different environments** like test and production
- ✅ Easily **create new projects** with complicated setups on demand without messing around with Xcode
- ✅ Generate from anywhere including **Continuous Delivery** servers
- ✅ Distribute your spec amongst multiple files for easy **sharing** and overriding
- ✅ Easily create **multi-platform** frameworks

Given a very simple project spec file like this:

```yaml
name: MyProject
options:
  bundleIdPrefix: com.myapp
targets:
  MyApp:
    type: application
    platform: iOS
    deploymentTarget: 10.0
    sources: [MyApp]
    settings:
      CUSTOM_BUILD_SETTING: my_value
    dependencies:
      - target: MyFramework
  MyFramework:
    type: framework
    platform: iOS
    sources: [MyFramework]
```
A project would be created with 2 connected targets, with all the required configurations and build settings. See the [Project Spec](Docs/ProjectSpec.md) documentation for all the options you can specify.

## Installing
Make sure Xcode 9 is installed first.

### [Mint](https://github.com/yonaskolb/mint)
```sh
$ mint run yonaskolb/xcodegen
```

### Make

```
$ git clone https://github.com/yonaskolb/XcodeGen.git
$ cd XcodeGen
$ make
```

### Homebrew

```
$ brew tap yonaskolb/XcodeGen https://github.com/yonaskolb/XcodeGen.git
$ brew install XcodeGen
```

### Swift Package Manager

**Use as CLI**

```
$ git clone https://github.com/yonaskolb/XcodeGen.git
$ cd XcodeGen
$ swift run xcodegen
```

**Use as dependency**

Add the following to your Package.swift file's dependencies:

```
.package(url: "https://github.com/yonaskolb/XcodeGen.git", from: "1.0.0"),
```

And then import wherever needed: `import XcodeGenKit`

## Usage

Simply run:

```
$ xcodegen
```

This will look for a project spec in the current directory called `project.yml`

Use `xcodegen --help` to see the list of options:

- **--spec**: An optional path to a `.yml` or `.json` project spec.
- **--project**: An optional path to a directory where the project will be generated. By default this is the directory the spec lives in.
- **--quiet**: Suppress informational and success messages. By default this is disabled.

## Editing
```
$ git clone https://github.com/yonaskolb/XcodeGen.git
$ cd XcodeGen
$ swift package generate-xcodeproj
```
This use Swift Project Manager to create an `xcodeproj` file that you can open, edit and run in Xcode, which makes editing any code easier.

If you want to pass any required arguments when running in XCode, you can edit the scheme to include launch arguments.

## Project Spec
See Project Spec documentation [here](Docs/ProjectSpec.md)

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
