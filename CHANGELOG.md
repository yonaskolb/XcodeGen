# Change Log

## Master

#### Added

- Added `options.carthageExecutablePath` option [244](https://github.com/yonaskolb/XcodeGen/pull/244) @akkyie
- Added `parallelizeBuild` and `buildImplicitDependencies` to Schemes [241](https://github.com/yonaskolb/XcodeGen/pull/241) @rahul-malik

#### Fixed
- Fixed Mint installation from reading setting presets [248](https://github.com/yonaskolb/XcodeGen/pull/248) @yonaskolb

## 1.6.0

#### Added
- Added scheme pre-actions and post-actions [231](https://github.com/yonaskolb/XcodeGen/pull/231) @kastiglione
- Added `options.disabledValidations` including `missingConfigs` to disable project validation errors [220](https://github.com/yonaskolb/XcodeGen/pull/220) @keith
- Generate UI Test Target Attributes [221](https://github.com/yonaskolb/XcodeGen/pull/221) @anreitersimon

#### Fixed
- Filter out duplicate source files [217](https://github.com/yonaskolb/XcodeGen/pull/217) @allu22
- Fixed how `lastKnownFileType` and `explicitFileType` were generated across platforms [115](https://github.com/yonaskolb/XcodeGen/pull/115) @toshi0383
- Removed a few cases of project diffs when opening the project in Xcode @yonaskolb
- Fixed Swift not being embedded by default in watch apps @yonaskolb

#### Changed
- Change arrays to strings in setting presets [218](https://github.com/yonaskolb/XcodeGen/pull/218) @allu22
- Updated to xcproj 4.0 [227](https://github.com/yonaskolb/XcodeGen/pull/227)

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.5.0...1.6.0)

## 1.5.0

#### Added
- added support for `gatherCoverageData` flag in target schemes [170](https://github.com/yonaskolb/XcodeGen/pull/170) @alexruperez
- added support for `commandLineOptions` in target schemes [172](https://github.com/yonaskolb/XcodeGen/pull/172) @rahul-malik
- added Project spec as a SwiftPM library for reuse in other projects [164](https://github.com/yonaskolb/XcodeGen/pull/164) @soffes
- added `implicit` option for framework dependencies [166](https://github.com/yonaskolb/XcodeGen/pull/166) @sbarow
- added `--quite` option to CLI [167](https://github.com/yonaskolb/XcodeGen/pull/167) @soffes
- can now print version with `-v` in addition to `--version` [174](https://github.com/yonaskolb/XcodeGen/pull/174) @kastiglione
- added support for legacy targets [175](https://github.com/yonaskolb/XcodeGen/pull/175) @bkase
- added support for indentation options [190](https://github.com/yonaskolb/XcodeGen/pull/190) @bkase
- added source excludes [135](https://github.com/yonaskolb/XcodeGen/pull/135) [161](https://github.com/yonaskolb/XcodeGen/pull/161) [190](https://github.com/yonaskolb/XcodeGen/pull/190) @peymankh @
- added `options.xcodeVersion` [197](https://github.com/yonaskolb/XcodeGen/pull/197) @yonaskolb @peymankh
- add test targets to Scheme [195](https://github.com/yonaskolb/XcodeGen/pull/195) @vhbit
- add option to make a source file optional incase it will be generated later [200](https://github.com/yonaskolb/XcodeGen/pull/200) @vhbit
- finalize Scheme spec [201](https://github.com/yonaskolb/XcodeGen/pull/201) @yonaskolb
- added `buildPhase` setting to target source for overriding the guessed build phase of files [206](https://github.com/yonaskolb/XcodeGen/pull/206) @yonaskolb
- added `deploymentTarget` setting to project and target [205](https://github.com/yonaskolb/XcodeGen/pull/205) @yonaskolb

#### Changed
- huge performance improvements when writing the project file due to changes in xcproj
- updated dependencies
- minor logging changes
- updated Project Spec documentation
- scan for `Info.plist` lazely [194](https://github.com/yonaskolb/XcodeGen/pull/194) @kastiglione
- change setting presets so that icon settings only get applied to application targets [204](https://github.com/yonaskolb/XcodeGen/pull/204) @yonaskolb
- changed scheme build targets format [203](https://github.com/yonaskolb/XcodeGen/pull/203) @yonaskolb
- when specifying a `--spec` argument, the default for the `--project` path is now the directory containing the spec [211](https://github.com/yonaskolb/XcodeGen/pull/211) @yonaskolb

#### Fixed
- fixed shell scripts escaping quotes twice [186](https://github.com/yonaskolb/XcodeGen/pull/186) @allu22
- fixed `createIntermediateGroups` when using a relative spec path [184](https://github.com/yonaskolb/XcodeGen/pull/184) @kastiglione
- fixed command line arguments for test and profile from being overridden [199](https://github.com/yonaskolb/XcodeGen/pull/199) @vhbit
- fixed files deep within a hierarchy having the path for a name
- fixed source files from being duplicated if referenced with different casing [212](https://github.com/yonaskolb/XcodeGen/pull/212) @yonaskolb
- fixed target product name not being written. Fixes integration with R.swift [213](https://github.com/yonaskolb/XcodeGen/pull/213) @yonaskolb

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.4.0...1.5.0)

## 1.4.0

#### Added
- added `--version` flag [112](https://github.com/yonaskolb/XcodeGen/pull/112) @mironal
- added support for adding individual file sources [106](https://github.com/yonaskolb/XcodeGen/pull/106) [133](https://github.com/yonaskolb/XcodeGen/pull/133) [142](https://github.com/yonaskolb/XcodeGen/pull/142) [139](https://github.com/yonaskolb/XcodeGen/pull/139) @bkase
- added source compiler flag support [121](https://github.com/yonaskolb/XcodeGen/pull/121) @bkase
- added `ProjectSpec.options.createIntermediateGroups` [108](https://github.com/yonaskolb/XcodeGen/pull/108) @bkase
- added better json loading support [127](https://github.com/yonaskolb/XcodeGen/pull/127) @rahul-malik
- added source `name` for customizing names of source directories and file [146](https://github.com/yonaskolb/XcodeGen/pull/146) @yonaskolb
- added folder reference source support via a new `type` property [151](https://github.com/yonaskolb/XcodeGen/pull/151) @yonaskolb
- added `ProjectSpec.options.developmentLanguage` [155](https://github.com/yonaskolb/XcodeGen/pull/155) @yonaskolb

#### Changed
- updated to xcproj 1.2.0 [113](https://github.com/yonaskolb/XcodeGen/pull/113) @yonaskolb
- build settings from presets will be removed if they are provided in `xcconfig` files [77](https://github.com/yonaskolb/XcodeGen/pull/77) @toshi0383
- all files and groups are sorted by type and then alphabetically [144](https://github.com/yonaskolb/XcodeGen/pull/144) @yonaskolb
- target sources can now have an expanded form [119](https://github.com/yonaskolb/XcodeGen/pull/119) @yonaskolb
- empty build phases are now not generated [149](https://github.com/yonaskolb/XcodeGen/pull/149) @yonaskolb
- make UUIDs more deterministic [154](https://github.com/yonaskolb/XcodeGen/pull/154) @yonaskolb

#### Fixed
- only add headers to frameworks and libraries [118](https://github.com/yonaskolb/XcodeGen/pull/118) @ryohey
- fixed localized files with the same name [126](https://github.com/yonaskolb/XcodeGen/pull/126) @ryohey
- fix intermediate sources [144](https://github.com/yonaskolb/XcodeGen/pull/144) @yonaskolb
- fix cyclical target dependencies not working [147](https://github.com/yonaskolb/XcodeGen/pull/147) @yonaskolb
- fix directory bundles not being added properly when referenced directly [148](https://github.com/yonaskolb/XcodeGen/pull/1478) @yonaskolb
- made `mm`, `c` and `S` file be parsed as source files [120](https://github.com/yonaskolb/XcodeGen/pull/120) [125](https://github.com/yonaskolb/XcodeGen/pull/125) [138](https://github.com/yonaskolb/XcodeGen/pull/138) @bkase @enmiller
- fix the generation of localized variant groups if there is no `Base.lproj` [157](https://github.com/yonaskolb/XcodeGen/pull/157) @ryohey
- all localizations found are added to a projects known regions [157](https://github.com/yonaskolb/XcodeGen/pull/157) @ryohey

#### Internal
- refactoring
- more tests
- added release scripts

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.3.0...1.4.0)

## 1.3.0

#### Added
- generate output files for Carthage copy-frameworks script [84](https://github.com/yonaskolb/XcodeGen/pull/84) @mironal
- added options.settingPreset to choose which setting presets get applied [100](https://github.com/yonaskolb/XcodeGen/pull/101) @yonaskolb
- added `link` option for target dependencies [109](https://github.com/yonaskolb/XcodeGen/pull/109) @keith

#### Changed
- updated to xcproj 0.4.1 [85](https://github.com/yonaskolb/XcodeGen/pull/85) @enmiller
- don't copy base settings if config type has been left out [100](https://github.com/yonaskolb/XcodeGen/pull/100) @yonaskolb
- generate localised files under a single variant group [70](https://github.com/yonaskolb/XcodeGen/pull/70) @ryohey
- don't apply common project settings to configs with no type [100](https://github.com/yonaskolb/XcodeGen/pull/100) @yonaskolb
- config references in settings can now be partially matched and are case insensitive [111](https://github.com/yonaskolb/XcodeGen/pull/111) @yonaskolb
- other small internal changes @yonaskolb

#### Fixed
- embed Carthage frameworks for macOS [82](https://github.com/yonaskolb/XcodeGen/pull/82) @toshi0383
- fixed copying of watchOS app resources [96](https://github.com/yonaskolb/XcodeGen/pull/96) @keith
- automatically ignore more file types for a target's sources (entitlements, gpx, apns) [94](https://github.com/yonaskolb/XcodeGen/pull/94) @keith
- change make build to a PHONY task [98](https://github.com/yonaskolb/XcodeGen/pull/98) @keith
- allow copying of resource files from dependant targets [95](https://github.com/yonaskolb/XcodeGen/pull/95) @keith
- fixed library linking [93](https://github.com/yonaskolb/XcodeGen/pull/93) @keith
- fixed duplicate carthage file references [107](https://github.com/yonaskolb/XcodeGen/pull/107) @yonaskolb
- an error is now shown if you try and generate a target scheme and don't have debug and release builds @yonaskolb

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.2.4...1.3.0)

## 1.2.4

#### Fixed
- setting presets only apply `ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES: YES` to applications
- don't add carthage dependency to `copy-frameworks` script if `embed: false`
- sort group children on APFS

#### Changed
- update to xcproj 0.3.0

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.2.3...1.2.4)

## 1.2.3

#### Fixed
- Fixed wrong carthage directory name reference for macOS [74](https://github.com/yonaskolb/XcodeGen/pull/74) @toshi0383
- Removed unnecessary `carthage copy-frameworks` for macOS app target [76](https://github.com/yonaskolb/XcodeGen/pull/76) @toshi0383
- Added some missing default settings for framework targets. `SKIP_INSTALL: YES` fixes archiving
- Filter out nulls from setting presets if specifying an empty string

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.2.2...1.2.3)

## 1.2.2

#### Added
- automatically set `TEST_TARGET_NAME` on UI test targets if one of the dependencies is an application target

#### Fixed
- set `DYLIB_INSTALL_NAME_BASE` to `@rpath` in framework target presets
- fixed tvOS launch screen setting. `ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME` is now `LaunchImage` not `tvOS LaunchImage`


[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.2.0...1.2.2)

## 1.2.0

#### Added
- `include` now supports a single string as well as a list
- add support setting xcconfig files on a project with `configFiles` [PR#64](https://github.com/yonaskolb/XcodeGen/pull/64)
- add `fileGroups` to project spec for adding groups of files that aren't target source files [PR#64](https://github.com/yonaskolb/XcodeGen/pull/64)
- better output (more info, emoji, colors)
- add `options.bundleIdPrefix` for autogenerating `PRODUCT_BUNDLE_IDENTIFIER` [PR#67](https://github.com/yonaskolb/XcodeGen/pull/67)
- add `:REPLACE` syntax when merging `include` [PR#68](https://github.com/yonaskolb/XcodeGen/pull/68)
- add `mint` installation support

#### Fixed
- fixed homebrew installation
- fixed target xcconfig files not working via `configFiles` [PR#64](https://github.com/yonaskolb/XcodeGen/pull/64)
- look for `INFOPLIST_FILE` setting in project and xcconfig files before adding it automatically. It was just looking in target settings before [PR#64](https://github.com/yonaskolb/XcodeGen/pull/64)
- exit with error on failure

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.1.0...1.2.0)

## 1.1.0

#### Changed
- set project version to Xcode 9 - `LastUpgradeVersion` attribute to `0900`
- set default Swift version to 4.0 - `SWIFT_VERSION` build setting to `4.0`

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.0.1...1.1.0)

### 1.0.1

### Fixed
- fixed incorrect default build script shell path
- fixed install scripts

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.0.0...1.0.1)

## 1.0.0

#### Added
- Swift 4 support [PR#52](https://github.com/yonaskolb/XcodeGen/pull/52)
- Support for C and C++ files [PR#48](https://github.com/yonaskolb/XcodeGen/pull/48) by @antoniocasero
- Xcode 9 default settings

#### Fixed
- fixed empty string in YAML not being parsed properly [PR#50](https://github.com/yonaskolb/XcodeGen/pull/50) by @antoniocasero

#### Changed
- updated to xcodeproj 0.1.2 [PR#56](https://github.com/yonaskolb/XcodeGen/pull/56)
- **BREAKING**: changed target definitions from list to map [PR#54](https://github.com/yonaskolb/XcodeGen/pull/54) See [Project Spec](docs/ProjectSpec.md)


[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.6.1...1.0.0)

## 0.6.1

#### Added
- Ability to set PBXProject attributes [PR#45](https://github.com/yonaskolb/XcodeGen/pull/45)

#### Changed
- Don't bother linking target frameworks for target dependencies.
- Move code signing default settings from all iOS targets to iOS application targets, via Product + Platform setting preset files [PR#46](https://github.com/yonaskolb/XcodeGen/pull/46)

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.6.0...0.6.1)

## 0.6.0

#### Added
- Allow a project spec to include other project specs [PR#44](https://github.com/yonaskolb/XcodeGen/pull/44)

#### Changed
- Changed default spec path to `project.yml`
- Changed default project directory to the current directory instead of the spec file's directory

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.5.1...0.6.0)

## 0.5.1

#### Fixed
- Fix embedded framework dependencies
- Add `CODE_SIGN_IDENTITY[sdk=iphoneos*]` back to iOS targets
- Fix build scripts with "" generating invalid projects [PR#43](https://github.com/yonaskolb/XcodeGen/pull/43)

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.5.0...0.5.1)

## 0.5.0
#### Added
- Added multi platform targets [PR#35](https://github.com/yonaskolb/XcodeGen/pull/35)
- Automatically generate platform specific `FRAMEWORK_SEARCH_PATHS` for Carthage dependencies [PR#38](https://github.com/yonaskolb/XcodeGen/pull/38)
- Automatically find Info.plist and set `INFOPLIST_FILE` build setting if it doesn't exist on a target [PR#40](https://github.com/yonaskolb/XcodeGen/pull/40)
- Add options for controlling embedding of dependencies [PR#37](https://github.com/yonaskolb/XcodeGen/pull/37)

#### Fixed
- Fixed localized files not being added to a target's resources

#### Changed
- Renamed Setting Presets to Setting Groups
- Carthage group is now created under top level Frameworks group

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.4.0...0.5.0)

## 0.4.0

##### Added
- Homebrew support [PR#16](https://github.com/yonaskolb/XcodeGen/pull/16) by @pepibumur
- Added `runOnlyWhenInstalling` to build scripts [PR#32](https://github.com/yonaskolb/XcodeGen/pull/32)
- Added `carthageBuildPath` option [PR#34](https://github.com/yonaskolb/XcodeGen/pull/34)

#### Fixed
- Fixed installations of XcodeGen not applying build setting presets for configs, products, and platforms, due to missing resources

#### Changed
- Upgraded to https://github.com/swift-xcode/xcodeproj 0.1.1 [PR#33](https://github.com/yonaskolb/XcodeGen/pull/33)

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.3.0...0.4.0)

## 0.3.0 - Extensions and Scheme Tests

#### Added
- Support for app extension dependencies, using the same `target: MyExtension` syntax [PR#19](https://github.com/yonaskolb/XcodeGen/pull/19)
- Added test targets to generated target schemes via `Target.scheme.testTargets` [PR#21](https://github.com/yonaskolb/XcodeGen/pull/21)

#### Changed
- Updated xcodeproj to 0.0.9

#### Fixed
- Fixed watch and messages apps not copying carthage dependencies

#### Breaking changes
- Changed `Target.generatedSchemes` to `Target.scheme.configVariants`

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.2...0.3.0)

## 0.2.0 - Build scripts

#### Added
- Added Target build scripts with `Target.prebuildScripts` and `Target.postbuildScripts` [PR#17](https://github.com/yonaskolb/XcodeGen/pull/17)
- Support for absolute paths in target sources, run script files, and config files
- Add validation for incorrect `Target.configFiles`

#### Fixed
- Fixed some project objects sometimes having duplicate ids

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.1...0.2)

## 0.1.0
First official release
