# Change Log

## 0.5.0
### Added
- Added multi platform targets #35
- Automatically generate platform specific `FRAMEWORK_SEARCH_PATHS` for Carthage dependencies #38
- Automatically find Info.plist and set `INFOPLIST_FILE` build setting if it doesn't exist on a target #40
- Add options for controlling embedding of dependencies #37

### Fixed
- Fixed localized files not being added to a target's resources

### Changed
- Renamed Setting Presets to Setting Groups
- Carthage group is now created under top level Frameworks group

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.4.0...0.5.0)

## 0.4.0
### Added
- Homebrew support #16 by @pepibumur
- Added `runOnlyWhenInstalling` to build scripts #32
- Added `carthageBuildPath` option #34

### Fixed
- Fixed installations of XcodeGen not applying build setting presets for configs, products, and platforms, due to missing resources

### Changed
- Upgraded to https://github.com/swift-xcode/xcodeproj 0.1.1 #33

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.3.0...0.4.0)

## 0.3.0 - Extensions and Scheme Tests

### Added
- Support for app extension dependencies, using the same `target: MyExtension` syntax #19
- Added test targets to generated target schemes via `Target.scheme.testTargets` #21

### Changed
- Updated xcodeproj to 0.0.9

### Fixed
- Fixed watch and messages apps not copying carthage dependencies

### Breaking changes
- Changed `Target.generatedSchemes` to `Target.scheme.configVariants`

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.2...0.3.0)

## 0.2.0 - Build scripts

### Added
- Added Target build scripts with `Target.prebuildScripts` and `Target.postbuildScripts` #17
- Support for absolute paths in target sources, run script files, and config files
- Add validation for incorrect `Target.configFiles`

### Fixed
- Fixed some project objects sometimes having duplicate ids

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.1...0.2)

## 0.1.0
First official release

