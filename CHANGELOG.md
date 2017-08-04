# Change Log

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

