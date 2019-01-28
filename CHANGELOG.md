# Change Log

## Master

## 2.2.0

#### Added
- Added ability to generate empty directories via `options.generateEmptyDirectories` [#480](https://github.com/yonaskolb/XcodeGen/pull/480) @Beniamiiin
- Added support for the `instrumentsPackage` product type [#482](https://github.com/yonaskolb/XcodeGen/pull/482) @ksulliva
- Added support for `inputFileLists` and `outputFileLists` within project build scripts [#500](https://github.com/yonaskolb/XcodeGen/pull/500) @lukewakeford
- Added support for a `$target_name` replacement string within target templates [#504](https://github.com/yonaskolb/XcodeGen/pull/504) @yonaskolb
- Added `createIntermediateGroups` to individual Target Sources which overrides the top level option [#505](https://github.com/yonaskolb/XcodeGen/pull/505) @yonaskolb

#### Changed
- **BREAKING**: All the paths within `include` files are now relative to that file and not the root spec. This can be disabled with a `relativePaths: false` on the include. See the [documentation](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#include) for more details [#489](https://github.com/yonaskolb/XcodeGen/pull/489) @ellneal
- Updated the Xcode compatibility version from 3.2 to 9.3 [#497](https://github.com/yonaskolb/XcodeGen/pull/497) @yonaskolb
- Exact matches to config names in build settings won't partial apply to other configs [#503](https://github.com/yonaskolb/XcodeGen/pull/503) @yonaskolb
- UUIDs in the project are standard and don't contain any type prefixes anymore

#### Fixed
- Fixed `--project` argument not taking effect [#487](https://github.com/yonaskolb/XcodeGen/pull/487) @monowerker
- Fixed Sticker Packs from generating an empty Source file phase which caused in error in the new build system [#492](https://github.com/yonaskolb/XcodeGen/pull/492) @rpassis
- Fixed generated schemes for tool targets not setting the executable [#496](https://github.com/yonaskolb/XcodeGen/pull/496) @yonaskolb
- Fixed resolving Carthage dependencies for iOS app with watchOS target. [465](https://github.com/yonaskolb/XcodeGen/pull/465) @raptorxcz

[Commits](https://github.com/yonaskolb/XcodeGen/compare/2.1.0...2.2.0)

## 2.1.0

#### Added
- Added an experiment new caching feature. Pass `--use-cache` to opt in. This will read and write from a cache file to prevent unnecessarily generating the project. Give it a try as it may become the default in a future release [#412](https://github.com/yonaskolb/XcodeGen/pull/412) @yonaskolb

#### Changed
- Changed spelling of build phases to **preBuildPhase** and **postBuildPhase**. The older names are deprecated but still work [402](https://github.com/yonaskolb/XcodeGen/pull/402) @brentleyjones
- Moved generation to a specific subcommand `xcodegen generate`. Simple `xcodegen` will continue to work for now [#437](https://github.com/yonaskolb/XcodeGen/pull/437) @yonaskolb
- If `INFOPLIST_FILE` has been set on a target, then an `info` path won't ovewrite it [#443](https://github.com/yonaskolb/XcodeGen/pull/443) @feischl97

#### Fixed
- Fixed XPC Service package type in generated `Info.plist` [#435](https://github.com/yonaskolb/XcodeGen/pull/435) @alvarhansen
- Fixed phase ordering for modulemap and static libary header Copy File phases. [402](https://github.com/yonaskolb/XcodeGen/pull/402) @brentleyjones
- Fixed intermittent errors when running multiple `xcodegen`s concurrently [#450](https://github.com/yonaskolb/XcodeGen/pull/450) @bryansum
- Fixed `--project` argument not working [#437](https://github.com/yonaskolb/XcodeGen/pull/437) @yonaskolb
- Fixed unit tests not hooking up to host applications properly by default. They now generate a `TEST_HOST` and a `TestTargetID` [#452](https://github.com/yonaskolb/XcodeGen/pull/452) @yonaskolb
- Fixed static libraries not including external frameworks in their search paths [#454](https://github.com/yonaskolb/XcodeGen/pull/454) @brentleyjones
- Add `.intentdefinition` files to sources build phase instead of resources [#442](https://github.com/yonaskolb/XcodeGen/pull/442) @yonaskolb
- Add `mlmodel` files to sources build phase instead of resources [#457](https://github.com/yonaskolb/XcodeGen/pull/457) @dwb357

[Commits](https://github.com/yonaskolb/XcodeGen/compare/2.0.0...2.1.0)

## 2.0.0

#### Added
- Added `weak` linking setting for dependencies [#411](https://github.com/yonaskolb/XcodeGen/pull/411) @alvarhansen
- Added `info` to targets for generating an `Info.plist` [#415](https://github.com/yonaskolb/XcodeGen/pull/415) @yonaskolb
- Added `entitlements` to targets for generating an `.entitlement` file [#415](https://github.com/yonaskolb/XcodeGen/pull/415) @yonaskolb
- Added `sdk` dependency type for linking system frameworks and libs [#430](https://github.com/yonaskolb/XcodeGen/pull/430) @yonaskolb
- Added `parallelizable` and `randomExecutionOrder` to `Scheme` test targets in an expanded form [#434](https://github.com/yonaskolb/XcodeGen/pull/434) @yonaskolb
- Validate incorrect config setting definitions [#431](https://github.com/yonaskolb/XcodeGen/pull/431) @yonaskolb
- Automatically set project `SDKROOT` if there is only a single platform within the project [#433](https://github.com/yonaskolb/XcodeGen/pull/433) @yonaskolb

#### Changed
- Performance improvements for large projects [#388](https://github.com/yonaskolb/XcodeGen/pull/388) [#417](https://github.com/yonaskolb/XcodeGen/pull/417) [#416](https://github.com/yonaskolb/XcodeGen/pull/416) @yonaskolb @kastiglione
- Upgraded to xcodeproj 6 [#388](https://github.com/yonaskolb/XcodeGen/pull/388) @yonaskolb
- Upgraded to Swift 4.2 [#388](https://github.com/yonaskolb/XcodeGen/pull/388) @yonaskolb
- Remove iOS codesigning sdk restriction in setting preset [#414](https://github.com/yonaskolb/XcodeGen/pull/414) @yonaskolb
- Changed default project version to Xcode 10.0 and default Swift version to 4.2 [#423](https://github.com/yonaskolb/XcodeGen/pull/423) @yonaskolb
- Added ability to not link Carthage frameworks [#432](https://github.com/yonaskolb/XcodeGen/pull/432) @yonaskolb

#### Fixed
- Fixed code signing issues [#414](https://github.com/yonaskolb/XcodeGen/pull/414) @yonaskolb
- Fixed `TargetSource.headerVisibility` not being set in initializer [#419](https://github.com/yonaskolb/XcodeGen/pull/419) @jerrymarino
- Fixed crash when using Xcode Legacy targets as dependencies [#427](https://github.com/yonaskolb/XcodeGen/pull/427) @dflems

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.11.2...2.0.0)

## 1.11.2

If XcodeGen is compiled with Swift 4.2, then UUID's in the generated project will not be deterministic. This will be fixed in an upcoming release with an update to xcodeproj 6.0

#### Fixed
- Fixed release builds in Swift 4.2 [#404](https://github.com/yonaskolb/XcodeGen/pull/404) @pepibumur
- Fixed default settings for macOS unit-tests [#387](https://github.com/yonaskolb/XcodeGen/pull/387) @frankdilo
- Fixed Copy Headers phase ordering for Xcode 10 [#401](https://github.com/yonaskolb/XcodeGen/pull/401) @brentleyjones
- Fixed generated schemes on aggregate targets [#394](https://github.com/yonaskolb/XcodeGen/pull/394) @vgorloff

#### Changed
- Added `en` as default value for knownRegions [#390](https://github.com/yonaskolb/XcodeGen/pull/390) @Saik0s
- Update `PathKit`, `Spectre`, `Yams` and `xcodeproj` dependencies

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.11.1...1.11.2)

## 1.11.1

#### Fixed
- Fixed `FRAMEWORK_SEARCH_PATHS` for `framework` dependency paths with spaces [#382](https://github.com/yonaskolb/XcodeGen/pull/382) @brentleyjones
- Fixed aggregate targets not being found with `transitivelyLinkDependencies` [#383](https://github.com/yonaskolb/XcodeGen/pull/383) @brentleyjones

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.11.0...1.11.1)

## 1.11.0

#### Added
- Added `showEnvVars` to build scripts to disable printing the environment [#351](https://github.com/yonaskolb/XcodeGen/pull/351) @keith
- Added `requiresObjCLinking` to `target` [#354](https://github.com/yonaskolb/XcodeGen/pull/354) @brentleyjones
- Added `targetTemplates` [#355](https://github.com/yonaskolb/XcodeGen/pull/355) @yonaskolb
- Added `aggregateTargets` [#353](https://github.com/yonaskolb/XcodeGen/pull/353) [#381](https://github.com/yonaskolb/XcodeGen/pull/381) @yonaskolb
- Added `options.groupSortPosition` [#356](https://github.com/yonaskolb/XcodeGen/pull/356) @yonaskolb
- Added ability to specify `copyFiles` build phase for sources [#345](https://github.com/yonaskolb/XcodeGen/pull/345) @brentleyjones
- Added ability to specify a `minimumXcodeGenVersion` [#349](https://github.com/yonaskolb/XcodeGen/pull/349) @brentleyjones
- Added `customArchiveName` and `revealArchiveInOrganizer` to `archive`  [#367](https://github.com/yonaskolb/XcodeGen/pull/367) @sxua

#### Fixed
- Sort files using localizedStandardCompare [#341](https://github.com/yonaskolb/XcodeGen/pull/341) @rohitpal440
- Use the latest `xcdatamodel` when sorted by version [#341](https://github.com/yonaskolb/XcodeGen/pull/341) @rohitpal440
- Fixed compiler flags being set on non source files in mixed build phase target sources [#347](https://github.com/yonaskolb/XcodeGen/pull/347) @brentleyjones
- Fixed `options.xcodeVersion` not being parsed [#348](https://github.com/yonaskolb/XcodeGen/pull/348) @brentleyjones
- Fixed non-application targets using `carthage copy-frameworks` [#361](https://github.com/yonaskolb/XcodeGen/pull/361) @brentleyjones
- Set `xcdatamodel` based on `xccurrentversion` if available [#364](https://github.com/yonaskolb/XcodeGen/pull/364) @rpassis
- XPC Services are now correctly copied [#368](https://github.com/yonaskolb/XcodeGen/pull/368) @brentley
- Fixed `.metal` files being added to resources [#380](https://github.com/yonaskolb/XcodeGen/pull/380) @vgorloff

#### Changed
- Improved linking for `static.library` targets [#352](https://github.com/yonaskolb/XcodeGen/pull/352) @brentleyjones
- Changed default group sorting to be after files [#356](https://github.com/yonaskolb/XcodeGen/pull/356) @yonaskolb
- Moved `Frameworks` and `Products` top level groups to bottom [#356](https://github.com/yonaskolb/XcodeGen/pull/356) @yonaskolb
- `modulemap` files are automatically copied to the products directory for static library targets [#346](https://github.com/yonaskolb/XcodeGen/pull/346) @brentleyjones
- Public header files are automatically copied to the products directory for static library targets [#365](https://github.com/yonaskolb/XcodeGen/pull/365) @brentleyjones
- Swift Objective-C Interface Header files are automatically copied to the products directory for static library targets [#366](https://github.com/yonaskolb/XcodeGen/pull/366) @brentleyjones
- `FRAMEWORK_SEARCH_PATHS` are adjusted for `framework` dependencies [#373](https://github.com/yonaskolb/XcodeGen/pull/373) @brentley
- `library.static` targets have `SKIP_INSTALL` set to `YES` [#358](https://github.com/yonaskolb/XcodeGen/pull/358) @brentley
- Copy files phases have descriptive names [#360](https://github.com/yonaskolb/XcodeGen/pull/360) @brentley

#### Internal
- Moved brew formula to homebrew core
- Added `CONTRIBUTING.md`

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.10.3...1.11.0)

## 1.10.3

#### Fixed
- Fixed Mint installations finding `SettingPresets` [#338](https://github.com/yonaskolb/XcodeGen/pull/338) @yonaskolb

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.10.2...1.10.3)

## 1.10.2

#### Changed
- Set `transitivelyLinkDependencies` to false by default

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.10.1...1.10.2)

## 1.10.1

#### Fixed
- Fixed `transitivelyLinkDependencies` typo [#332](https://github.com/yonaskolb/XcodeGen/pull/332) @brentleyjones
- Fixed framework target dependencies not being code signed by default [#332](https://github.com/yonaskolb/XcodeGen/pull/332) @yonaskolb

#### Changed
- Code sign all dependencies by default except target executables [#332](https://github.com/yonaskolb/XcodeGen/pull/332) @yonaskolb

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.10.0...1.10.1)

## 1.10.0

#### Added
- Added build rule support [#306](https://github.com/yonaskolb/XcodeGen/pull/306) @yonaskolb
- Added support for frameworks in sources [#308](https://github.com/yonaskolb/XcodeGen/pull/308) @keith
- Added ability to automatically embed transient dependencies. Controlled with `transitivelyLinkDependencies` [#327](https://github.com/yonaskolb/XcodeGen/pull/327) @brentleyjones

#### Changed
- Upgraded to Swift 4.1
- Improved Carthage dependency lookup performance with many targets [#298](https://github.com/yonaskolb/XcodeGen/pull/298) @keith
- By default don't CodeSignOnCopy `target` dependencies. This can still be controlled with `Dependency.codeSign` [#324](https://github.com/yonaskolb/XcodeGen/pull/324) @yonaskolb

#### Fixed
- Fixed PBXBuildFile and PBXFileReference being incorrectly generated for Legacy targets [#296](https://github.com/yonaskolb/XcodeGen/pull/296) @sascha
- Fixed required sources build phase not being generated if there are no sources [#307](https://github.com/yonaskolb/XcodeGen/pull/307) @yonaskolb
- Fixed install script in binary release [#303](https://github.com/yonaskolb/XcodeGen/pull/303) @alvarhansen
- Removed `ENABLE_TESTABILITY` from framework setting presets [#299](https://github.com/yonaskolb/XcodeGen/pull/299) @allu22
- Fixed homebrew installation [#297](https://github.com/yonaskolb/XcodeGen/pull/297) @vhbit
- `cc` files are now automatically recognized as source files [#317](https://github.com/yonaskolb/XcodeGen/pull/317) @maicki
- Fixed `commandLineArguments` not parsing when they had dots in them [#323](https://github.com/yonaskolb/XcodeGen/pull/323) @yonaskolb
- Fixed excluding directories that only have sub directories [#326](https://github.com/yonaskolb/XcodeGen/pull/326) @brentleyjones
- Made `PBXContainerItemProxy` ID more deterministic
- Fixed generated framework schemes from being executable [#328](https://github.com/yonaskolb/XcodeGen/pull/328) @brentleyjones

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.9.0...1.10.0)

## 1.9.0

#### Added
- Scheme pre and post actions can now be added to `target.scheme` [#280](https://github.com/yonaskolb/XcodeGen/pull/280) @yonaskolb
- Individual files can now be added to `fileGroups` [#293](https://github.com/yonaskolb/XcodeGen/pull/293) @yonaskolb

#### Changed
- Updated to `xcproj` 4.3.0 for Xcode 9.3 updates
- Update default Xcode version to 9.3 including new settings [#284](https://github.com/yonaskolb/XcodeGen/pull/284) @LinusU
- **Breaking for ProjectSpec library users** Changed `ProjectSpec` to `Project` and `ProjectSpec.Options` to `SpecOptions`  [#281](https://github.com/yonaskolb/XcodeGen/pull/281) @jerrymarino

#### Fixed
- Fixed manual build phase of `none` not being applied to folders [#288](https://github.com/yonaskolb/XcodeGen/pull/288) @yonaskolb
- Quoted values now correctly get parsed as strings [#282](https://github.com/yonaskolb/XcodeGen/pull/282) @yonaskolb
- Fixed adding a root source folder when `createIntermediateGroups` is on [#291](https://github.com/yonaskolb/XcodeGen/pull/291) @yonaskolb
- Fixed Homebrew installations issues on some machines [#289](https://github.com/yonaskolb/XcodeGen/pull/289) @vhbit
- Fixed files that are added as root sources from having invalid parent groups outside the project directory [#293](https://github.com/yonaskolb/XcodeGen/pull/293) @yonaskolb

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.8.0...1.9.0)

## 1.8.0

#### Added
- Added Project `defaultConfig` [#269](https://github.com/yonaskolb/XcodeGen/pull/269) @keith
- Added Target `attributes` [#276](https://github.com/yonaskolb/XcodeGen/pull/276) @yonaskolb
- Automatically set `DevelopmentTeam` and `ProvisioningStyle` within `TargetAttributes` if relevant build settings are defined [#277](https://github.com/yonaskolb/XcodeGen/pull/277) @yonaskolb

#### Fixed
- Fixed default `LD_RUNPATH_SEARCH_PATHS` for app extensions [#272](https://github.com/yonaskolb/XcodeGen/pull/272) @LinusU

#### Internal
- Make `LegacyTarget` init public [#264](https://github.com/yonaskolb/XcodeGen/pull/264) @jerrymarino
- Upgrade to *xcproj* to 4.2.0, *Yams* to 0.6.0 and *PathKit* to 0.9.1 @yonaskolb

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.7.0...1.8.0)

## 1.7.0

#### Added

- Added support for scheme environment variables [#239](https://github.com/yonaskolb/XcodeGen/pull/239) [#254](https://github.com/yonaskolb/XcodeGen/pull/254) [#259](https://github.com/yonaskolb/XcodeGen/pull/259) @turekj @toshi0383
- Added `carthageExecutablePath` option [#244](https://github.com/yonaskolb/XcodeGen/pull/244) @akkyie
- Added `parallelizeBuild` and `buildImplicitDependencies` to Schemes [#241](https://github.com/yonaskolb/XcodeGen/pull/241) @rahul-malik
 @yonaskolb
- Added support for Core Data `xcdatamodeld` files [#249](https://github.com/yonaskolb/XcodeGen/pull/249) @yonaskolb
- Projects are now generated atomically by writing to a temporary directory first [#250](https://github.com/yonaskolb/XcodeGen/pull/250) @yonaskolb
- Added script for adding precompiled binary to releases [#246](https://github.com/yonaskolb/XcodeGen/pull/246) @toshi0383
- Added optional `headerVisibilty` to target source. This still defaults to public [#252](https://github.com/yonaskolb/XcodeGen/pull/252) @yonaskolb
- Releases now include a pre-compiled binary and setting presets, including an install script

#### Fixed
- Fixed Mint installation from reading setting presets [#248](https://github.com/yonaskolb/XcodeGen/pull/248) @yonaskolb
- Fixed setting `buildPhase` on a `folder` source. This allows for a folder of header files [#254](https://github.com/yonaskolb/XcodeGen/pull/254) @toshi0383
- Carthage dependencies are not automatically embedded into test targets [#256](https://github.com/yonaskolb/XcodeGen/pull/256) @yonaskolb
- Carthage dependencies now respect the `embed` property [#256](https://github.com/yonaskolb/XcodeGen/pull/256) @yonaskolb
- iMessage extensions now have proper setting presets in regards to app icon and runtime search paths [#255](https://github.com/yonaskolb/XcodeGen/pull/255) @yonaskolb
- Excluded files are not added within .lproj directories [#238](https://github.com/yonaskolb/XcodeGen/pull/238) @toshi0383

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.6.0...1.7.0)

## 1.6.0

#### Added
- Added scheme pre-actions and post-actions [#231](https://github.com/yonaskolb/XcodeGen/pull/231) @kastiglione
- Added `options.disabledValidations` including `missingConfigs` to disable project validation errors [#220](https://github.com/yonaskolb/XcodeGen/pull/220) @keith
- Generate UI Test Target Attributes [#221](https://github.com/yonaskolb/XcodeGen/pull/221) @anreitersimon

#### Fixed
- Filter out duplicate source files [#217](https://github.com/yonaskolb/XcodeGen/pull/217) @allu22
- Fixed how `lastKnownFileType` and `explicitFileType` were generated across platforms [#115](https://github.com/yonaskolb/XcodeGen/pull/115) @toshi0383
- Removed a few cases of project diffs when opening the project in Xcode @yonaskolb
- Fixed Swift not being embedded by default in watch apps @yonaskolb

#### Changed
- Change arrays to strings in setting presets [#218](https://github.com/yonaskolb/XcodeGen/pull/218) @allu22
- Updated to xcproj 4.0 [#227](https://github.com/yonaskolb/XcodeGen/pull/227)

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.5.0...1.6.0)

## 1.5.0

#### Added
- added support for `gatherCoverageData` flag in target schemes [#170](https://github.com/yonaskolb/XcodeGen/pull/170) @alexruperez
- added support for `commandLineOptions` in target schemes [#172](https://github.com/yonaskolb/XcodeGen/pull/172) @rahul-malik
- added Project spec as a SwiftPM library for reuse in other projects [#164](https://github.com/yonaskolb/XcodeGen/pull/164) @soffes
- added `implicit` option for framework dependencies [#166](https://github.com/yonaskolb/XcodeGen/pull/166) @sbarow
- added `--quite` option to CLI [#167](https://github.com/yonaskolb/XcodeGen/pull/167) @soffes
- can now print version with `-v` in addition to `--version` [#174](https://github.com/yonaskolb/XcodeGen/pull/174) @kastiglione
- added support for legacy targets [#175](https://github.com/yonaskolb/XcodeGen/pull/175) @bkase
- added support for indentation options [#190](https://github.com/yonaskolb/XcodeGen/pull/190) @bkase
- added source excludes [#135](https://github.com/yonaskolb/XcodeGen/pull/135) [#161](https://github.com/yonaskolb/XcodeGen/pull/161) [#190](https://github.com/yonaskolb/XcodeGen/pull/190) @peymankh @
- added `options.xcodeVersion` [#197](https://github.com/yonaskolb/XcodeGen/pull/197) @yonaskolb @peymankh
- add test targets to Scheme [#195](https://github.com/yonaskolb/XcodeGen/pull/195) @vhbit
- add option to make a source file optional incase it will be generated later [#200](https://github.com/yonaskolb/XcodeGen/pull/200) @vhbit
- finalize Scheme spec [#201](https://github.com/yonaskolb/XcodeGen/pull/201) @yonaskolb
- added `buildPhase` setting to target source for overriding the guessed build phase of files [#206](https://github.com/yonaskolb/XcodeGen/pull/206) @yonaskolb
- added `deploymentTarget` setting to project and target [#205](https://github.com/yonaskolb/XcodeGen/pull/205) @yonaskolb

#### Changed
- huge performance improvements when writing the project file due to changes in xcproj
- updated dependencies
- minor logging changes
- updated Project Spec documentation
- scan for `Info.plist` lazely [#194](https://github.com/yonaskolb/XcodeGen/pull/194) @kastiglione
- change setting presets so that icon settings only get applied to application targets [#204](https://github.com/yonaskolb/XcodeGen/pull/204) @yonaskolb
- changed scheme build targets format [#203](https://github.com/yonaskolb/XcodeGen/pull/203) @yonaskolb
- when specifying a `--spec` argument, the default for the `--project` path is now the directory containing the spec [#211](https://github.com/yonaskolb/XcodeGen/pull/211) @yonaskolb

#### Fixed
- fixed shell scripts escaping quotes twice [#186](https://github.com/yonaskolb/XcodeGen/pull/186) @allu22
- fixed `createIntermediateGroups` when using a relative spec path [#184](https://github.com/yonaskolb/XcodeGen/pull/184) @kastiglione
- fixed command line arguments for test and profile from being overridden [#199](https://github.com/yonaskolb/XcodeGen/pull/199) @vhbit
- fixed files deep within a hierarchy having the path for a name
- fixed source files from being duplicated if referenced with different casing [#212](https://github.com/yonaskolb/XcodeGen/pull/212) @yonaskolb
- fixed target product name not being written. Fixes integration with R.swift [#213](https://github.com/yonaskolb/XcodeGen/pull/213) @yonaskolb

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.4.0...1.5.0)

## 1.4.0

#### Added
- added `--version` flag [#112](https://github.com/yonaskolb/XcodeGen/pull/112) @mironal
- added support for adding individual file sources [#106](https://github.com/yonaskolb/XcodeGen/pull/106) [#133](https://github.com/yonaskolb/XcodeGen/pull/133) [#142](https://github.com/yonaskolb/XcodeGen/pull/142) [#139](https://github.com/yonaskolb/XcodeGen/pull/139) @bkase
- added source compiler flag support [#121](https://github.com/yonaskolb/XcodeGen/pull/121) @bkase
- added `ProjectSpec.options.createIntermediateGroups` [#108](https://github.com/yonaskolb/XcodeGen/pull/108) @bkase
- added better json loading support [#127](https://github.com/yonaskolb/XcodeGen/pull/127) @rahul-malik
- added source `name` for customizing names of source directories and file [#146](https://github.com/yonaskolb/XcodeGen/pull/146) @yonaskolb
- added folder reference source support via a new `type` property [#151](https://github.com/yonaskolb/XcodeGen/pull/151) @yonaskolb
- added `ProjectSpec.options.developmentLanguage` [#155](https://github.com/yonaskolb/XcodeGen/pull/155) @yonaskolb

#### Changed
- updated to xcproj 1.2.0 [#113](https://github.com/yonaskolb/XcodeGen/pull/113) @yonaskolb
- build settings from presets will be removed if they are provided in `xcconfig` files [#77](https://github.com/yonaskolb/XcodeGen/pull/77) @toshi0383
- all files and groups are sorted by type and then alphabetically [#144](https://github.com/yonaskolb/XcodeGen/pull/144) @yonaskolb
- target sources can now have an expanded form [#119](https://github.com/yonaskolb/XcodeGen/pull/119) @yonaskolb
- empty build phases are now not generated [#149](https://github.com/yonaskolb/XcodeGen/pull/149) @yonaskolb
- make UUIDs more deterministic [#154](https://github.com/yonaskolb/XcodeGen/pull/154) @yonaskolb

#### Fixed
- only add headers to frameworks and libraries [#118](https://github.com/yonaskolb/XcodeGen/pull/118) @ryohey
- fixed localized files with the same name [#126](https://github.com/yonaskolb/XcodeGen/pull/126) @ryohey
- fix intermediate sources [#144](https://github.com/yonaskolb/XcodeGen/pull/144) @yonaskolb
- fix cyclical target dependencies not working [#147](https://github.com/yonaskolb/XcodeGen/pull/147) @yonaskolb
- fix directory bundles not being added properly when referenced directly [#148](https://github.com/yonaskolb/XcodeGen/pull/1478) @yonaskolb
- made `mm`, `c` and `S` file be parsed as source files [#120](https://github.com/yonaskolb/XcodeGen/pull/120) [#125](https://github.com/yonaskolb/XcodeGen/pull/125) [#138](https://github.com/yonaskolb/XcodeGen/pull/138) @bkase @enmiller
- fix the generation of localized variant groups if there is no `Base.lproj` [#157](https://github.com/yonaskolb/XcodeGen/pull/157) @ryohey
- all localizations found are added to a projects known regions [#157](https://github.com/yonaskolb/XcodeGen/pull/157) @ryohey

#### Internal
- refactoring
- more tests
- added release scripts

[Commits](https://github.com/yonaskolb/XcodeGen/compare/1.3.0...1.4.0)

## 1.3.0

#### Added
- generate output files for Carthage copy-frameworks script [#84](https://github.com/yonaskolb/XcodeGen/pull/84) @mironal
- added options.settingPreset to choose which setting presets get applied [#100](https://github.com/yonaskolb/XcodeGen/pull/101) @yonaskolb
- added `link` option for target dependencies [#109](https://github.com/yonaskolb/XcodeGen/pull/109) @keith

#### Changed
- updated to xcproj 0.4.1 [#85](https://github.com/yonaskolb/XcodeGen/pull/85) @enmiller
- don't copy base settings if config type has been left out [#100](https://github.com/yonaskolb/XcodeGen/pull/100) @yonaskolb
- generate localised files under a single variant group [#70](https://github.com/yonaskolb/XcodeGen/pull/70) @ryohey
- don't apply common project settings to configs with no type [#100](https://github.com/yonaskolb/XcodeGen/pull/100) @yonaskolb
- config references in settings can now be partially matched and are case insensitive [#111](https://github.com/yonaskolb/XcodeGen/pull/111) @yonaskolb
- other small internal changes @yonaskolb

#### Fixed
- embed Carthage frameworks for macOS [#82](https://github.com/yonaskolb/XcodeGen/pull/82) @toshi0383
- fixed copying of watchOS app resources [#96](https://github.com/yonaskolb/XcodeGen/pull/96) @keith
- automatically ignore more file types for a target's sources (entitlements, gpx, apns) [#94](https://github.com/yonaskolb/XcodeGen/pull/94) @keith
- change make build to a PHONY task [#98](https://github.com/yonaskolb/XcodeGen/pull/98) @keith
- allow copying of resource files from dependant targets [#95](https://github.com/yonaskolb/XcodeGen/pull/95) @keith
- fixed library linking [#93](https://github.com/yonaskolb/XcodeGen/pull/93) @keith
- fixed duplicate carthage file references [#107](https://github.com/yonaskolb/XcodeGen/pull/107) @yonaskolb
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
- Fixed wrong carthage directory name reference for macOS [#74](https://github.com/yonaskolb/XcodeGen/pull/74) @toshi0383
- Removed unnecessary `carthage copy-frameworks` for macOS app target [#76](https://github.com/yonaskolb/XcodeGen/pull/76) @toshi0383
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
- add support setting xcconfig files on a project with `configFiles` [#64](https://github.com/yonaskolb/XcodeGen/pull/64)
- add `fileGroups` to project spec for adding groups of files that aren't target source files [#64](https://github.com/yonaskolb/XcodeGen/pull/64)
- better output (more info, emoji, colors)
- add `options.bundleIdPrefix` for autogenerating `PRODUCT_BUNDLE_IDENTIFIER` [#67](https://github.com/yonaskolb/XcodeGen/pull/67)
- add `:REPLACE` syntax when merging `include` [#68](https://github.com/yonaskolb/XcodeGen/pull/68)
- add `mint` installation support

#### Fixed
- fixed homebrew installation
- fixed target xcconfig files not working via `configFiles` [#64](https://github.com/yonaskolb/XcodeGen/pull/64)
- look for `INFOPLIST_FILE` setting in project and xcconfig files before adding it automatically. It was just looking in target settings before [#64](https://github.com/yonaskolb/XcodeGen/pull/64)
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
- Swift 4 support [#52](https://github.com/yonaskolb/XcodeGen/pull/52)
- Support for C and C++ files [#48](https://github.com/yonaskolb/XcodeGen/pull/48) by @antoniocasero
- Xcode 9 default settings

#### Fixed
- fixed empty string in YAML not being parsed properly [#50](https://github.com/yonaskolb/XcodeGen/pull/50) by @antoniocasero

#### Changed
- updated to xcodeproj 0.1.2 [#56](https://github.com/yonaskolb/XcodeGen/pull/56)
- **BREAKING**: changed target definitions from list to map [#54](https://github.com/yonaskolb/XcodeGen/pull/54) See [Project Spec](docs/ProjectSpec.md)


[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.6.1...1.0.0)

## 0.6.1

#### Added
- Ability to set PBXProject attributes [#45](https://github.com/yonaskolb/XcodeGen/pull/45)

#### Changed
- Don't bother linking target frameworks for target dependencies.
- Move code signing default settings from all iOS targets to iOS application targets, via Product + Platform setting preset files [#46](https://github.com/yonaskolb/XcodeGen/pull/46)

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.6.0...0.6.1)

## 0.6.0

#### Added
- Allow a project spec to include other project specs [#44](https://github.com/yonaskolb/XcodeGen/pull/44)

#### Changed
- Changed default spec path to `project.yml`
- Changed default project directory to the current directory instead of the spec file's directory

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.5.1...0.6.0)

## 0.5.1

#### Fixed
- Fix embedded framework dependencies
- Add `CODE_SIGN_IDENTITY[sdk=iphoneos*]` back to iOS targets
- Fix build scripts with "" generating invalid projects [#43](https://github.com/yonaskolb/XcodeGen/pull/43)

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.5.0...0.5.1)

## 0.5.0
#### Added
- Added multi platform targets [#35](https://github.com/yonaskolb/XcodeGen/pull/35)
- Automatically generate platform specific `FRAMEWORK_SEARCH_PATHS` for Carthage dependencies [#38](https://github.com/yonaskolb/XcodeGen/pull/38)
- Automatically find Info.plist and set `INFOPLIST_FILE` build setting if it doesn't exist on a target [#40](https://github.com/yonaskolb/XcodeGen/pull/40)
- Add options for controlling embedding of dependencies [#37](https://github.com/yonaskolb/XcodeGen/pull/37)

#### Fixed
- Fixed localized files not being added to a target's resources

#### Changed
- Renamed Setting Presets to Setting Groups
- Carthage group is now created under top level Frameworks group

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.4.0...0.5.0)

## 0.4.0

##### Added
- Homebrew support [#16](https://github.com/yonaskolb/XcodeGen/pull/16) by @pepibumur
- Added `runOnlyWhenInstalling` to build scripts [#32](https://github.com/yonaskolb/XcodeGen/pull/32)
- Added `carthageBuildPath` option [#34](https://github.com/yonaskolb/XcodeGen/pull/34)

#### Fixed
- Fixed installations of XcodeGen not applying build setting presets for configs, products, and platforms, due to missing resources

#### Changed
- Upgraded to https://github.com/swift-xcode/xcodeproj 0.1.1 [#33](https://github.com/yonaskolb/XcodeGen/pull/33)

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.3.0...0.4.0)

## 0.3.0 - Extensions and Scheme Tests

#### Added
- Support for app extension dependencies, using the same `target: MyExtension` syntax [#19](https://github.com/yonaskolb/XcodeGen/pull/19)
- Added test targets to generated target schemes via `Target.scheme.testTargets` [#21](https://github.com/yonaskolb/XcodeGen/pull/21)

#### Changed
- Updated xcodeproj to 0.0.9

#### Fixed
- Fixed watch and messages apps not copying carthage dependencies

#### Breaking changes
- Changed `Target.generatedSchemes` to `Target.scheme.configVariants`

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.2...0.3.0)

## 0.2.0 - Build scripts

#### Added
- Added Target build scripts with `Target.prebuildScripts` and `Target.postbuildScripts` [#17](https://github.com/yonaskolb/XcodeGen/pull/17)
- Support for absolute paths in target sources, run script files, and config files
- Add validation for incorrect `Target.configFiles`

#### Fixed
- Fixed some project objects sometimes having duplicate ids

[Commits](https://github.com/yonaskolb/XcodeGen/compare/0.1...0.2)

## 0.1.0
First official release
