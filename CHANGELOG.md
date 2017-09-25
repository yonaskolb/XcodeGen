# Change Log

## Master

### Added
- `include` now supports a single string as well as a list
- add support setting xcconfig files on a project with `configFiles` [PR#64](https://github.com/yonaskolb/XcodeGen/pull/64)
- add `fileGroups` to project spec for adding groups of files that aren't target source files [PR#64](https://github.com/yonaskolb/XcodeGen/pull/64)
- print errors in red

### Fixed
- fixed install scripts
- fixed target xcconfig files not working via `configFiles` [PR#64](https://github.com/yonaskolb/XcodeGen/pull/64)
- look for `INFOPLIST_FILE` setting in project and xcconfig files before adding it automatically. It was just looking in target settings before [PR#64](https://github.com/yonaskolb/XcodeGen/pull/64)

## 1.1.0

### Changed
- set project version to Xcode 9 - `LastUpgradeVersion` attribute to `0900`
- set default Swift version to 4.0 - `SWIFT_VERSION` build setting to `4.0`

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.0.1...1.1.0)

## 1.0.1

### Fixed
- fixed incorrect default build script shell path
- fixed install scripts 

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.0.0...1.0.1)

## 1.0.0

### Added
- Swift 4 support [PR#52](https://github.com/yonaskolb/XcodeGen/pull/52)
- Support for C and C++ files [PR#48](https://github.com/yonaskolb/XcodeGen/pull/48) by @antoniocasero
- Xcode 9 default settings

### Fixed
- fixed empty string in YAML not being parsed properly [PR#50](https://github.com/yonaskolb/XcodeGen/pull/50) by @antoniocasero

### Changed
- updated to xcodeproj 0.1.2 [PR#56](https://github.com/yonaskolb/XcodeGen/pull/56)
- **BREAKING**: changed target definitions from list to map [PR#54](https://github.com/yonaskolb/XcodeGen/pull/54) See [Project Spec](docs/ProjectSpec.md) 


[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.6.1...1.0.0)

## 0.6.1

### Added
- Ability to set PBXProject attributes [PR#45](https://github.com/yonaskolb/XcodeGen/pull/45)

### Changed
- Don't bother linking target frameworks for target dependencies.
- Move code signing default settings from all iOS targets to iOS application targets, via Product + Platform setting preset files [PR#46](https://github.com/yonaskolb/XcodeGen/pull/46)

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.6.0...0.6.1)

## 0.6.0

### Added
- Allow a project spec to include other project specs [PR#44](https://github.com/yonaskolb/XcodeGen/pull/44)

### Changed
- Changed default spec path to `project.yml`
- Changed default project directory to the current directory instead of the spec file's directory

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.5.1...0.6.0)

## 0.5.1

### Fixed
- Fix embedded framework dependencies
- Add `CODE_SIGN_IDENTITY[sdk=iphoneos*]` back to iOS targets
- Fix build scripts with "" generating invalid projects [PR#43](https://github.com/yonaskolb/XcodeGen/pull/43)

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.5.0...0.5.1)

## 0.5.0
### Added
- Added multi platform targets [PR#35](https://github.com/yonaskolb/XcodeGen/pull/35)
- Automatically generate platform specific `FRAMEWORK_SEARCH_PATHS` for Carthage dependencies [PR#38](https://github.com/yonaskolb/XcodeGen/pull/38)
- Automatically find Info.plist and set `INFOPLIST_FILE` build setting if it doesn't exist on a target [PR#40](https://github.com/yonaskolb/XcodeGen/pull/40)
- Add options for controlling embedding of dependencies [PR#37](https://github.com/yonaskolb/XcodeGen/pull/37)

### Fixed
- Fixed localized files not being added to a target's resources

### Changed
- Renamed Setting Presets to Setting Groups
- Carthage group is now created under top level Frameworks group

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.4.0...0.5.0)

## 0.4.0
### Added
- Homebrew support [PR#16](https://github.com/yonaskolb/XcodeGen/pull/16) by @pepibumur
- Added `runOnlyWhenInstalling` to build scripts [PR#32](https://github.com/yonaskolb/XcodeGen/pull/32)
- Added `carthageBuildPath` option [PR#34](https://github.com/yonaskolb/XcodeGen/pull/34)

### Fixed
- Fixed installations of XcodeGen not applying build setting presets for configs, products, and platforms, due to missing resources

### Changed
- Upgraded to https://github.com/swift-xcode/xcodeproj 0.1.1 [PR#33](https://github.com/yonaskolb/XcodeGen/pull/33)

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.3.0...0.4.0)

## 0.3.0 - Extensions and Scheme Tests

### Added
- Support for app extension dependencies, using the same `target: MyExtension` syntax [PR#19](https://github.com/yonaskolb/XcodeGen/pull/19)
- Added test targets to generated target schemes via `Target.scheme.testTargets` [PR#21](https://github.com/yonaskolb/XcodeGen/pull/21)

### Changed
- Updated xcodeproj to 0.0.9

### Fixed
- Fixed watch and messages apps not copying carthage dependencies

### Breaking changes
- Changed `Target.generatedSchemes` to `Target.scheme.configVariants`

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.2...0.3.0)

## 0.2.0 - Build scripts

### Added
- Added Target build scripts with `Target.prebuildScripts` and `Target.postbuildScripts` [PR#17](https://github.com/yonaskolb/XcodeGen/pull/17)
- Support for absolute paths in target sources, run script files, and config files
- Add validation for incorrect `Target.configFiles`

### Fixed
- Fixed some project objects sometimes having duplicate ids

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.1...0.2)

## 0.1.0
First official release
