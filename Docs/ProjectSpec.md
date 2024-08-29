# Project Spec

The project spec can be written in either YAML or JSON. All the examples below use YAML.

- [x] required property
- [ ] optional property

Some of the YAML examples below don't show all the required properties. For example not all target examples will have a platform or type, even though they are required.

You can also use environment variables in your configuration file, by using `${SOME_VARIABLE}` in a string.

- [Project](#project)
  - [Include](#include)
  - [Options](#options)
  - [GroupOrdering](#groupordering)
  - [FileType](#filetype)
  - [Breakpoints](#breakpoints)
    - [Breakpoint Action](#breakpoint-action)
  - [Configs](#configs)
  - [Setting Groups](#setting-groups)
- [Settings](#settings)
- [Target](#target)
  - [Product Type](#product-type)
  - [Platform](#platform)
  - [Supported Destinations](#supported-destinations)
  - [Sources](#sources)
    - [Target Source](#target-source)
  - [Dependency](#dependency)
  - [Config Files](#config-files)
  - [Plist](#plist)
  - [Build Tool Plug-ins](#build-tool-plug-ins)
  - [Build Script](#build-script)
  - [Build Rule](#build-rule)
  - [Target Scheme](#target-scheme)
  - [Legacy Target](#legacy-target)
- [Aggregate Target](#aggregate-target)
- [Target Template](#target-template)
- [Scheme](#scheme)
  - [Build](#build)
  - [Common Build Action options](#common-build-action-options)
  - [Execution Action](#execution-action)
  - [Run Action](#run-action)
  - [Test Action](#test-action)
    - [Test Target](#test-target)
    - [Other Parameters](#other-parameters)
    - [Testable Target Reference](#testable-target-reference)
  - [Archive Action](#archive-action)
  - [Simulate Location](#simulate-location)
  - [Scheme Management](#scheme-management)
  - [Environment Variable](#environment-variable)
  - [Test Plan](#test-plan)
- [Scheme Template](#scheme-template)
- [Swift Package](#swift-package)
  - [Remote Package](#remote-package)
  - [Local Package](#local-package)
- [Project Reference](#project-reference)

## Project

- [x] **name**:  **String** - Name of the generated project
- [ ] **include**:  **[Include](#include)** - One or more paths to other specs
- [ ] **options**: **[Options](#options)** - Various options to override default behaviour
- [ ] **attributes**: **[String: Any]** - The PBXProject attributes. This is for advanced use. If no value is set for `LastUpgradeCheck`, it will be defaulted to ``{"LastUpgradeCheck": "XcodeVersion"}`` with `xcodeVersion` being set by [Options](#options)`.xcodeVersion`
- [ ] **breakpoints**: [Breakpoints](#breakpoints) - Add shared breakpoints to the generated project
- [ ] **configs**: **[Configs](#configs)** - Project build configurations. Defaults to `Debug` and `Release` configs
- [ ] **configFiles**: **[Config Files](#config-files)** - `.xcconfig` files per config
- [ ] **settings**: **[Settings](#settings)** - Project specific settings. Default base and config type settings will be applied first before any settings defined here
- [ ] **settingGroups**: **[Setting Groups](#setting-groups)** - Setting groups mapped by name
- [ ] **targets**: **[String: [Target](#target)]** - The list of targets in the project mapped by name
- [ ] **fileGroups**: **[String]** - A list of paths to add to the root of the project. These aren't files that will be included in your targets, but that you'd like to include in the project hierarchy anyway. For example a folder of xcconfig files that aren't already added by any target sources, or a Readme file.
- [ ] **schemes**: **[Scheme](#scheme)** - A list of schemes by name. This allows more control over what is found in [Target Scheme](#target-scheme)
- [ ] **schemeTemplates**: **[String: [Scheme Template](#scheme-template)]** - a list of schemes that can be used as templates for actual schemes which reference them via a `template` property. They can be used to extract common scheme settings. Works great in combination with `include`.
- [ ] **targetTemplates**: **[String: [Target Template](#target-template)]** - a list of targets that can be used as templates for actual targets which reference them via a `template` property. They can be used to extract common target settings. Works great in combination with `include`.
- [ ] **packages**: **[String: [Swift Package](#swift-package)]** - a map of Swift packages by name.
- [ ] **projectReferences**: **[String: [Project Reference](#project-reference)]** - a map of project references by name

### Include

One or more specs can be included in the project spec. This can be used to split your project spec into multiple files, for easier structuring or sharing between multiple specs. Included specs can also include other specs and so on.

Include can either be a list of includes or a single include. They will be merged in order and then the current spec will be merged on top.

An include can be provided via a string (the path) or an object of the form:

**Include Object**

- [x] **path**: **String** - The path to the included file.
- [ ] **relativePaths**: **Bool** - Dictates whether the included spec specifies paths relative to itself (the default) or the root spec file.
- [ ] **enable**: **Bool** - Dictates whether the specified spec should be included or not. You can also specify it by environment variable.
```yaml
include:
  - includedFile.yml
  - path: path/to/includedFile.yml
    relativePaths: false
    enable: ${INCLUDE_ADDITIONAL_YAML}
```

By default specs are merged additively. That is for every value:

- if existing value and new value are both dictionaries merge them and continue down the hierarchy
- if existing value and new value are both an array then add the new value to the end of the array
- otherwise replace the existing value with the new value

This merging behaviour can be overridden on a value basis. If you wish to replace a whole value (set a new dictionary or new array instead of merging them) then just affix `:REPLACE` to the key


```yaml
include:
  - base.yml
name: CustomSpec
targets:
  MyTarget: # target lives in base.yml
    sources:REPLACE:
      - my_new_sources
```

Note that target names can also be changed by adding a `name` property to a target.

### Options

- [ ] **minimumXcodeGenVersion**: **String** - The minimum version of XcodeGen required.
- [ ] **carthageBuildPath**: **String** - The path to the carthage build directory. Defaults to `Carthage/Build`. This is used when specifying target carthage dependencies
- [ ] **carthageExecutablePath**: **String** - The path to the carthage executable. Defaults to `carthage`. You can specify when you use custom built or locally installed Carthage using [Mint](https://github.com/yonaskolb/Mint), for example.
- [ ] **createIntermediateGroups**: **Bool** - If this is specified and set to `true`, then intermediate groups will be created for every path component between the folder containing the source and next existing group it finds or the base path. For example, when enabled if a source path is specified as `Vendor/Foo/Hello.swift`, the group `Vendor` will created as a parent of the `Foo` group. This can be overridden in a specific [Target source](#target-source)
- [ ] **bundleIdPrefix**: **String** - If this is specified then any target that doesn't have an `PRODUCT_BUNDLE_IDENTIFIER` (via all levels of build settings) will get an autogenerated one by combining `bundleIdPrefix` and the target name: `bundleIdPrefix.name`. The target name will be stripped of all characters that aren't alphanumerics, hyphens, or periods. Underscores will be replaced with hyphens.
- [ ] **settingPresets**: **String** - This controls the settings that are automatically applied to the project and its targets. These are the same build settings that Xcode would add when creating a new project. Project settings are applied by config type. Target settings are applied by the product type and platform. By default this is set to `all`
	- `all`: project and target settings
	- `project`: only project settings
	- `targets`: only target settings
	- `none`: no settings are automatically applied
- [ ] **developmentLanguage**: **String** - Sets the development language of the project. Defaults to `en`
- [ ] **usesTabs**: **Bool** - If this is specified, the Xcode project will override the user's setting determining whether or not tabs or spaces should be used in the project.
- [ ] **indentWidth**: **Int** - If this is specified, the Xcode project will override the user's setting for indent width in number of spaces.
- [ ] **tabWidth**: **Int** - If this is specified, the Xcode project will override the user's setting for indent width in number of spaces.
- [ ] **xcodeVersion**: **String** - The version of Xcode. This defaults to the latest version periodically. You can specify it in the format `0910` or `9.1`
- [ ] **deploymentTarget**: **[[Platform](#platform): String]** - A project wide deployment target can be specified for each platform otherwise the default SDK version in Xcode will be used. This will be overridden by any custom build settings that set the deployment target eg `IPHONEOS_DEPLOYMENT_TARGET`. Target specific deployment targets can also be set with [Target](#target).deploymentTarget.
- [ ] **disabledValidations**: **[String]** - A list of validations that can be disabled if they're too strict for your use case. By default this is set to an empty array. Currently these are the available options:
  - `missingConfigs`: Disable errors for configurations in yaml files that don't exist in the project itself. This can be useful if you include the same yaml file in different projects
  - `missingConfigFiles`: Disable checking for the existence of configuration files. This can be useful for generating a project in a context where config files are not available.
  - `missingTestPlans`: Disable checking if test plan paths exist. This can be useful if your test plans haven't been created yet.
- [ ] **defaultConfig**: **String** - The default configuration for command line builds from Xcode. If the configuration provided here doesn't match one in your [configs](#configs) key, XcodeGen will fail. If you don't set this, the first configuration alphabetically will be chosen.
- [ ] **groupSortPosition**: **String** - Where groups are sorted in relation to other files. Either:
  - `none` - sorted alphabetically with all the other files
  - `top` - at the top, before files
  - `bottom` (default) - at the bottom, after other files
- [ ] **groupOrdering**: **[[GroupOrdering]](#groupOrdering)** - An order of groups.
- [ ] **transitivelyLinkDependencies**: **Bool** - If this is `true` then targets will link to the dependencies of their target dependencies. If a target should embed its dependencies, such as application and test bundles, it will embed these transitive dependencies as well. Some complex setups might want to set this to `false` and explicitly specify dependencies at every level. Targets can override this with [Target](#target).transitivelyLinkDependencies. Defaults to `false`.
- [ ] **generateEmptyDirectories**: **Bool** - If this is `true` then empty directories will be added to project too else will be missed. Defaults to `false`.
- [ ] **findCarthageFrameworks**: **Bool** - When this is set to `true`, all the individual frameworks for Carthage framework dependencies will automatically be found. This property can be overridden individually for each carthage dependency - for more details see See **findFrameworks** in the [Dependency](#dependency) section. Defaults to `false`.
- [ ] **localPackagesGroup**: **String** - The group name that local packages are put into. This defaults to `Packages`. Use `""` to specify the project root.
- [ ] **fileTypes**: **[String: [FileType](#filetype)]** - A list of default file options for specific file extensions across the project. Values in [Sources](#sources) will overwrite these settings.
- [ ] **preGenCommand**: **String** - A bash command to run before the project has been generated. If the project isn't generated due to no changes when using the cache then this won't run. This is useful for running things like generating resources files before the project is regenerated.
- [ ] **postGenCommand**: **String** - A bash command to run after the project has been generated. If the project isn't generated due to no changes when using the cache then this won't run. This is useful for running things like `pod install` only if the project is actually regenerated.
- [ ] **useBaseInternationalization**: **Bool** If this is `false` and your project does not include resources located in a **Base.lproj** directory then `Base` will not be included in the projects 'known regions'. The default value is `true`. 
- [ ] **schemePathPrefix**: **String** - A path prefix for relative paths in schemes, such as StoreKitConfiguration. The default is `"../../"`, which is suitable for non-workspace projects. For use in workspaces, use `"../"`.

```yaml
options:
  deploymentTarget:
    watchOS: "2.0"
    tvOS: "10.0"
  postGenCommand: pod install
```

### GroupOrdering

Describe an order of groups. Available parameters:

- [ ] **pattern**: **String** - A group name pattern. Can be just a single string and also can be a regex pattern. Optional option, if you don't set it, it will pattern for the main group, i.e. the project.
- [ ] **order**: **[String]** - An order of groups.

```yaml
options:
  groupOrdering: 
    - order: [Sources, Resources, Tests, Support files, Configurations]
    - pattern: '^.*Screen$'
      order: [View, Presenter, Interactor, Entities, Assembly]
```

In this example, we set up the order of two groups. First one is the main group, i.e. the project, note that in this case, we shouldn't set `pattern` option and the second group order is for groups whose names ends with `Screen`.

### FileType
Default settings for file extensions. See [Sources](#sources) for more documentation on properties. If you overwrite an extension that XcodeGen already provides by default, you will need to provide all the settings.

- [ ] **file**: **Bool** - Whether this extension should be treated like a file. Defaults to true.
- [ ] **buildPhase**: **String** - The default build phase.
- [ ] **attributes**: **[String]** - Additional settings attributes that will be applied to any build files.
- [ ] **resourceTags**: **[String]** - On Demand Resource Tags that will be applied to any resources. This also adds to the project attribute's knownAssetTags.
- [ ] **compilerFlags**: **[String]** - A list of compiler flags to add.

### Breakpoints

- [x] **type**: **String** - Breakpoint type
    - `File`: file breakpoint
    - `Exception`: exception breakpoint
    - `SwiftError`: swift error breakpoint
    - `OpenGLError`: OpenGL breakpoint
    - `Symbolic`: symbolic breakpoint
    - `IDEConstraintError`: IDE constraint breakpoint
    - `IDETestFailure`: IDE test failure breakpoint
    - `RuntimeIssue`: Runtime issue breakpoint
- [ ] **enabled**: **Bool** - Indicates whether it should be active. Default to `true`
- [ ] **ignoreCount**: **Int** - Indicates how many times it should be ignored before stopping, Default to `0`
- [ ] **continueAfterRunningActions**: **Bool** - Indicates if should automatically continue after evaluating actions, Default to `false`
- [ ] **path**: **String** - Breakpoint file path (only required by file breakpoints)
- [ ] **line**: **Int** - Breakpoint line (only required by file breakpoints)
- [ ] **symbol**: **String** - Breakpoint symbol (only used by symbolic breakpoints)
- [ ] **module**: **String** - Breakpoint module (only used by symbolic breakpoints)
- [ ] **scope**: **String** - Breakpoint scope (only used by exception breakpoints)
    - `All`
    - `Objective-C` (default)
    - `C++`
- [ ] **stopOnStyle**: **String** - Indicates if should stop on style (only used by exception breakpoints)
    -`throw` (default)
    -`catch`
- [ ] **condition**: **String** - Breakpoint condition
- [ ] **actions**: **[[Breakpoint Action](#breakpoint-action)]** - breakpoint actions

```yaml
breakpoints:
  - type: ExceptionBreakpoint
    enabled: true
    ignoreCount: 0
    continueAfterRunningActions: false
```

#### Breakpoint Action

- [x] **type**: **String** - Breakpoint action type
    - `DebuggerCommand`: execute debugger command
    - `Log`: log message
    - `ShellCommand`: execute shell command
    - `GraphicsTrace`: capture GPU frame
    - `AppleScript`: execute AppleScript
    - `Sound`: play sound
- [ ] **command**: **String** - Debugger command (only used by debugger command breakpoint action)
- [ ] **message**: **String** - Log message (only used log message breakpoint action)
- [ ] **conveyanceType**: **String** - Conveyance type (only used by log message breakpoint action)
    - `console`: log message to console (default)
    - `speak`: speak message
- [ ] **path**: **String** - Shell command file path (only used by shell command breakpoint action)
- [ ] **arguments**: **String** - Shell command arguments (only used by shell command breakpoint action)
- [ ] **waitUntilDone**: **Bool** - Indicates whether it should wait until done (only used by shell command breakpoint action). Default to `false`
- [ ] **script**: **String** - AppleScript (only used by AppleScript breakpoint action)
- [ ] **sound**: **String** - Sound name (only used by sound breakpoint action)
    - `Basso` (default)
    - `Blow`
    - `Bottle`
    - `Frog`
    - `Funk`
    - `Glass`
    - `Hero`
    - `Morse`
    - `Ping`
    - `Pop`
    - `Purr`
    - `Sosumi`
    - `Submarine`
    - `Tink`

```yaml
actions:
  - type: Sound
    sound: Blow
```

### Configs

Each config maps to a build type of either `debug` or `release` which will then apply default `Build Settings` to the project. Any value other than `debug` or `release` (for example `none`), will mean no default `Build Settings` will be applied to the project.

```yaml
configs:
  Debug: debug
  Beta: release
  AppStore: release
```
If no configs are specified, default `Debug` and `Release` configs will be created automatically.

### Setting Groups

Setting groups are named groups of `Build Settings` that can be reused elsewhere. Each preset is a [Settings](#settings) schema, so can include other `groups`  or define settings by `configs`.

```yaml
settingGroups:
  preset_generic:
    CUSTOM_SETTING: value_custom
  preset_debug:
    BUILD_SETTING: value_debug
  preset_release:
    base:
      BUILD_SETTING: value_release
  preset_all:
    groups:
      - preset_generic
    configs:
      debug:
        groups:
          - preset_debug
      release:
        groups:
          - preset_release

targets:
  Application:
    settings:
      groups: 
        - preset_all
```

## Settings

Settings correspond to `Build Settings` tab in Xcode. To display Setting Names instead of Setting Titles, select `Editor -> Show Setting Names` in Xcode.

Settings can either be a simple map of `Build Settings` `[String:String]`, or can be more advanced with the following properties:

- [ ] **groups**: **[String]** - List of [Setting Groups](#setting-groups) to include and merge
- [ ] **configs**: **[String:[Settings](#settings)]** - Mapping of config name to a settings spec. These settings will only be applied for that config. Each key will be matched to any configs that contain the key and is case insensitive. So if you had `Staging Debug` and `Staging Release`, you could apply settings to both of them using `staging`. However if a config name is an exact match to a config it won't be applied to any others. eg `Release` will be applied to config `Release` but not `Staging Release`
- [ ] **base**: **[String:String]** - Used to specify default settings that apply to any config

```yaml
settings:
  GENERATE_INFOPLIST_FILE: NO
  CODE_SIGNING_ALLOWED: NO
  WRAPPER_EXTENSION: bundle
```

Don't mix simple maps with `groups`, `base` and `configs`.
If `groups`, `base`, `configs` are used then simple maps is silently ignored.

In this example, `CURRENT_PROJECT_VERSION` will be set, but `MARKETING_VERSION` will be ignored:
```yaml
settings:
  MARKETING_VERSION: 100.0.0
  base:
    CURRENT_PROJECT_VERSION: 100.0
```

```yaml
settings:
  base:
    PRODUCT_NAME: XcodeGenProduct
  configs:
    debug:
      CODE_SIGN_IDENTITY: iPhone Developer
      PRODUCT_BUNDLE_IDENTIFIER: com.tomtom.debug_app
    release:
      CODE_SIGN_IDENTITY: iPhone Distribution
      PRODUCT_BUNDLE_IDENTIFIER: com.tomtom.app
      PROVISIONING_PROFILE_SPECIFIER: "Xcodegen Release"
  groups:
    - my_settings
```

Settings are merged in the following order: `groups`, `base`, `configs` (simple maps are ignored).

## Target

- [x] **type**: **[Product Type](#product-type)** - Product type of the target
- [x] **platform**: **[Platform](#platform)** - Platform of the target
- [ ] **supportedDestinations**: **[[Supported Destinations](#supported-destinations)]** - List of supported platform destinations for the target.
- [ ] **deploymentTarget**: **String** - The deployment target (eg `9.2`). If this is not specified the value from the project set in [Options](#options)`.deploymentTarget.PLATFORM` will be used.
- [ ] **sources**: **[Sources](#sources)** - Source directories of the target
- [ ] **configFiles**: **[Config Files](#config-files)** - `.xcconfig` files per config
- [ ] **settings**: **[Settings](#settings)** - Target specific build settings. Default platform and product type settings will be applied first before any custom settings defined here. Other context dependant settings will be set automatically as well:
	- `INFOPLIST_FILE`: If it doesn't exist your sources will be searched for `Info.plist` files and the first one found will be used for this setting
	- `FRAMEWORK_SEARCH_PATHS`: If carthage framework dependencies are used, the platform build path will be added to this setting
	- `OTHER_LDFLAGS`:  See `requiresObjCLinking` below
  - `TEST_TARGET_NAME`: for ui tests that target an application
  - `TEST_HOST`: for unit tests that target an application
- [ ] **dependencies**: **[[Dependency](#dependency)]** - Dependencies for the target
- [ ] **info**: **[Plist](#plist)** - If defined, this will generate and write an `Info.plist` to the specified path and use it by setting the `INFOPLIST_FILE` build setting for every configuration, unless `INFOPLIST_FILE` is already defined in  **settings** for this configuration. The following properties are generated automatically if appropriate, the rest will have to be provided.
  - `CFBundleIdentifier`
  - `CFBundleInfoDictionaryVersion`
  - `CFBundleExecutable` **Not generated for targets of type bundle**
  - `CFBundleName`
  - `CFBundleDevelopmentRegion`
  - `CFBundleShortVersionString`
  - `CFBundleVersion`
  - `CFBundlePackageType`
- [ ] **entitlements**: **[Plist](#plist)** - If defined this will generate and write a `.entitlements` file, and use it by setting `CODE_SIGN_ENTITLEMENTS` build setting for every configuration. All properties must be provided
- [ ] **templates**: **[String]** - A list of [Target Templates](#target-template) referenced by name that will be merged with the target in order. Any instances of `${target_name}` within these templates will be replaced with the target name.
- [ ] **templateAttributes**: **[String: String]** - A list of attributes where each instance of `${attributeName}` within the templates listed in `templates` will be replaced with the value specified.
- [ ] **transitivelyLinkDependencies**: **Bool** - If this is not specified the value from the project set in [Options](#options)`.transitivelyLinkDependencies` will be used.
- [ ] **directlyEmbedCarthageDependencies**: **Bool** - If this is `true` Carthage framework dependencies will be embedded using an `Embed Frameworks` build phase instead of the `copy-frameworks` script. Defaults to `true` for all targets except iOS/tvOS/watchOS Applications.
- [ ] **requiresObjCLinking**: **Bool** - If this is `true` any targets that link to this target will have `-ObjC` added to their `OTHER_LDFLAGS`. This is required if a static library has any categories or extensions on Objective-C code. See [this guide](https://pewpewthespells.com/blog/objc_linker_flags.html#objc) for more details. Defaults to `true` if `type` is `library.static`. If you are 100% sure you don't have categories or extensions on Objective-C code (pure Swift with no use of Foundation/UIKit) you can set this to `false`, otherwise it's best to leave it alone.
- [ ] **onlyCopyFilesOnInstall**: **Bool** – If this is `true`, the `Embed Frameworks` and `Embed App Extensions` (if available) build phases will have the "Copy only when installing" chekbox checked. Defaults to `false`.
- [ ] **buildToolPlugins**: **[[Build Tool Plug-ins](#build-tool-plug-ins)]** - Commands for the build system that run automatically *during* the build.
- [ ] **preBuildScripts**: **[[Build Script](#build-script)]** - Build scripts that run *before* any other build phases
- [ ] **postCompileScripts**: **[[Build Script](#build-script)]** - Build scripts that run after the Compile Sources phase
- [ ] **postBuildScripts**: **[[Build Script](#build-script)]** - Build scripts that run *after* any other build phases
- [ ] **buildRules**: **[[Build Rule](#build-rule)]** - Custom build rules
- [ ] **scheme**: **[Target Scheme](#target-scheme)** - Generated scheme with tests or config variants
- [ ] **legacy**: **[Legacy Target](#legacy-target)** - When present, opt-in to make an Xcode "External Build System" legacy target instead.
- [ ] **attributes**: **[String: Any]** - This sets values in the project `TargetAttributes`. It is merged with `attributes` from the project and anything automatically added by XcodeGen, with any duplicate values being override by values specified here. This is for advanced use only. Properties that are already set include:
	- `DevelopmentTeam`: if all configurations have the same `DEVELOPMENT_TEAM` setting
	- `ProvisioningStyle`: if all configurations have the same `CODE_SIGN_STYLE` setting
	- `TestTargetID`: if all configurations have the same `TEST_TARGET_NAME` setting
- [ ] **putResourcesBeforeSourcesBuildPhase**: **Bool** - If this is `true` the `Copy Resources` step will be placed before the `Compile Sources` build step.

### Product Type

This will provide default build settings for a certain product type. It can be any of the following:

- `application`
- `application.on-demand-install-capable`
- `application.messages`
- `application.watchapp`
- `application.watchapp2`
- `application.watchapp2-container`
- `app-extension`
- `app-extension.intents-service`
- `app-extension.messages`
- `app-extension.messages-sticker-pack`
- `bundle`
- `bundle.ocunit-test`
- `bundle.ui-testing`
- `bundle.unit-test`
- `extensionkit-extension`
- `framework`
- `instruments-package`
- `library.dynamic`
- `library.static`
- `framework.static`
- `tool`
- `tv-app-extension`
- `watchkit-extension`
- `watchkit2-extension`
- `xcode-extension`
- `driver-extension`
- `system-extension`
- `xpc-service`
- ``""`` (used for legacy targets)

### Platform

This will provide default build settings for a certain platform. It can be any of the following:

- `auto` (available only when we use `supportedDestinations`)
- `iOS`
- `tvOS`
- `macOS`
- `watchOS`
- `visionOS` (`visionOS` doesn't support Carthage usage)

Note that when we use supported destinations with Xcode 14+ we can avoid the definition of platform that fallbacks to the `auto` value.

**Multi Platform targets**

You can also specify an array of platforms. This will generate a target for each platform.
If `deploymentTarget` is specified for a multi platform target, it can have different values per platform similar to how it's defined in [Options](#options). See below for an example.
If you reference the string `${platform}` anywhere within the target spec, that will be replaced with the platform.

The generated targets by default will have a suffix of `_${platform}` applied, you can change this by specifying a `platformSuffix` or `platformPrefix`.

If no `PRODUCT_NAME` build setting is specified for a target, this will be set to the target name, so that this target can be imported under a single name.

```yaml
targets:
  MyFramework:
    sources: MyFramework
    platform: [iOS, tvOS]
    deploymentTarget:
      iOS: 9.0
      tvOS: 10.0
    type: framework
    settings:
      base:
        INFOPLIST_FILE: MyApp/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.myapp
        MY_SETTING: platform ${platform}
      groups:
        - ${platform}
```

The above will generate 2 targets named `MyFramework_iOS` and `MyFramework_tvOS`, with all the relevant platform build settings. They will both have a `PRODUCT_NAME` of `MyFramework`

### Supported Destinations

This will provide a mix of default build settings for the chosen platform destinations. It can be any of the following:

- `iOS`
- `tvOS`
- `macOS`
- `macCatalyst`
- `visionOS`
- `watchOS`

```yaml
targets:
  MyFramework:
    type: framework
    supportedDestinations: [iOS, tvOS]
    deploymentTarget:
      iOS: 9.0
      tvOS: 10.0
    sources:
      - path: MySources
        inferDestinationFiltersByPath: true
      - path: OtherSources
        destinationFilters: [iOS]
```

Note that the definition of supported destinations can be applied to almost every type of bundle making everything more easy to manage (app targets, unit tests, UI tests etc). App targets currently do not support the watchOS destination. Create a separate target using `platform` for watchOS apps. See Apple's [Configuring a multiplatform app](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target) for details.

### Sources

Specifies the source directories for a target. This can either be a single source or a list of sources. Applicable source files, resources, headers, and `.lproj` files will be parsed appropriately.

A source can be provided via a string (the path) or an object of the form:

#### Target Source

- [x] **path**: **String** - The path to the source file or directory.
- [ ] **name**: **String** - Can be used to override the name of the source file or directory. By default the last component of the path is used for the name
- [ ] **group**: **String** - Can be used to override the parent group of the source file or directory. By default a group is created at the root with the name of this source file or directory or intermediate groups are created if `createIntermediateGroups` is set to `true`. Multiple groups can be created by separating each one using a `/`. If multiple target sources share the same `group`, they will be put together in the same parent group.
- [ ] **compilerFlags**: **[String]** or **String** - A list of compilerFlags to add to files under this specific path provided as a list or a space delimited string. Defaults to empty.
- [ ] **excludes**: **[String]** - A list of [global patterns](https://en.wikipedia.org/wiki/Glob_(programming)) representing the files to exclude. These rules are relative to `path` and _not the directory where `project.yml` resides_. XcodeGen uses Bash 4's Glob behaviors where globstar (**) is enabled.
- [ ] **includes**: **[String]** - A list of global patterns in the same format as `excludes` representing the files to include. These rules are relative to `path` and _not the directory where `project.yml` resides_. If **excludes** is present and file conflicts with **includes**, **excludes** will override the **includes** behavior.
- [ ] **destinationFilters**: **[[Supported Destinations](#supported-destinations)]** - List of supported platform destinations the files should filter to. Defaults to all supported destinations.
- [ ] **inferDestinationFiltersByPath**: **Bool** - This is a convenience filter that helps you to filter the files if their paths match these patterns `**/<supportedDestination>/*` or `*_<supportedDestination>.swift`. Note, if you use `destinationFilters` this flag will be ignored.
- [ ] **createIntermediateGroups**: **Bool** - This overrides the value in [Options](#options).
- [ ] **optional**: **Bool** - Disable missing path check. Defaults to false.
- [ ] **buildPhase**: **String** - This manually sets the build phase this file or files in this directory will be added to, otherwise XcodeGen will guess based on the file extension. Note that `Info.plist` files will never be added to any build phases, no matter what this setting is. Possible values are:
	- `sources` - Compile Sources phase
	- `resources` - Copy Bundle Resources phase
	- `headers` - Headers Phase
	- `copyFiles` - Copy Files Phase. Must be specified as an object with the following fields:
		- [x] **destination**: **String** - Destination of the Copy Files phase. This can be one of the following values:
			- `absolutePath`
			- `productsDirectory`
			- `wrapper`
			- `executables`
			- `resources`
			- `javaResources`
			- `frameworks`
			- `sharedFrameworks`
			- `sharedSupport`
			- `plugins`
		- [ ] **subpath**: **String** - The path inside of the destination to copy the files.
	- `none` - Will not be added to any build phases
- [ ] **type**: **String**: This can be one of the following values
	- `file`: a file reference with a parent group will be created (Default for files or directories with extensions)
	- `group`: a group with all it's containing files. (Default for directories without extensions)
	- `folder`: a folder reference.
- [ ] **headerVisibility**: **String** - The visibility of any headers. This defaults to `public`, but can be either:
	- `public`
	- `private`
	- `project`
- [ ] **attributes**: **[String]** - Additional settings attributes that will be applied to any build files.
- [ ] **resourceTags**: **[String]** - On Demand Resource Tags that will be applied to any resources. This also adds to the project attribute's knownAssetTags

```yaml
targets:
  MyTarget:
    sources: MyTargetSource
  MyOtherTarget:
    supportedDestinations: [iOS, tvOS]
    sources:
      - MyOtherTargetSource1
      - path: MyOtherTargetSource2
        inferDestinationFiltersByPath: true
        name: MyNewName
        excludes:
          - "ios/*.[mh]"
          - "configs/server[0-2].json"
          - "*-Private.h"
          - "**/*.md" # excludes all files with the .md extension
          - "ios/**/*Tests.[hm]" # excludes all files with an h or m extension within the ios directory.
        compilerFlags:
          - "-Werror"
          - "-Wextra"
      - path: MyOtherTargetSource3
        destinationFilters: [iOS]
        compilerFlags: "-Werror -Wextra"
      - path: ModuleMaps
        buildPhase:
          copyFiles:
            destination: productsDirectory
            subpath: include/$(PRODUCT_NAME)
      - path: Resources
        type: folder
      - path: Path/To/File.asset
        resourceTags: [tag1, tag2]
```

### Dependency

A dependency can be one of a 6 types:

- `target: name` - links to another target. If you are using project references you can specify a target within another project by using `ProjectName/TargetName` for the name
- `framework: path` - links to a framework or XCFramework
- `carthage: name` - helper for linking to a Carthage framework (not XCFramework)
- `sdk: name` - links to a dependency with the SDK. This can either be a relative path within the sdk root or a single filename that references a framework (.framework) or lib (.tbd)
- `package: name` - links to a Swift Package. The name must match the name of a package defined in the top level `packages`
- `bundle: name` - adds the pre-built bundle for the supplied name to the copy resources build phase. This is useful when a dependency exists on a static library target that has an associated bundle target, both existing in a separate project. Only usable in target types which can copy resources.

**Linking options**:

- [ ] **embed**: **Bool** - Whether to embed the dependency. Defaults to true for application target and false for non application targets.
- [ ] **link**: **Bool** - Whether to link the dependency. Defaults to `true` depending on the type of the dependency and the type of the target (e.g. static libraries will only link to executables by default).
- [ ] **codeSign**: **Bool** - Whether the `codeSignOnCopy` setting is applied when embedding framework. Defaults to true.
- [ ] **removeHeaders**: **Bool** - Whether the `removeHeadersOnCopy` setting is applied when embedding the framework. Defaults to true.
- [ ] **weak**: **Bool** - Whether the `Weak` setting is applied when linking the framework. Defaults to false.
- [ ] **platformFilter**: **String** - This field is specific to Mac Catalyst. It corresponds to the "Platforms" dropdown in the Frameworks & Libraries section of Target settings in Xcode. Available options are: **iOS**, **macOS** and **all**. Defaults is **all**.
- [ ] **destinationFilters**: **[[Supported Destinations](#supported-destinations)]** - List of supported platform destinations this dependency should filter to. Defaults to all supported destinations.
- [ ] **platforms**: **[[Platform](#platform)]** - List of platforms this dependency should apply to. Defaults to all applicable platforms.
- **copy** - Copy Files Phase for this dependency. This only applies when `embed` is true. Must be specified as an object with the following fields:
    - [x] **destination**: **String** - Destination of the Copy Files phase. This can be one of the following values:
        - `absolutePath`
        - `productsDirectory`
        - `wrapper`
        - `executables`
        - `resources`
        - `javaResources`
        - `frameworks`
        - `sharedFrameworks`
        - `sharedSupport`
        - `plugins`
    - [ ] **subpath**: **String** - The path inside of the destination to copy the files.

**Implicit Framework options**:

This only applies to `framework` dependencies. Implicit framework dependencies are useful in Xcode Workspaces which have multiple `.xcodeproj` that are not embedded within each other yet have a dependency on a framework built in an adjacent `.xcodeproj`.  By having `Find Implicit Dependencies` checked within your scheme `Build Options` Xcode can link built frameworks in `BUILT_PRODUCTS_DIR`.

- [ ] **implicit**: **Bool** - Whether the framework is an implicit dependency. Defaults to `false` .

**Carthage Dependency**

- [ ] **findFrameworks**: **Bool** - Whether to find Carthage frameworks automatically. Defaults to `true` .
- [ ] **linkType**: **String** - Dependency link type. This value should be `dynamic` or `static`. Default value is `dynamic` .

Carthage frameworks are expected to be in `CARTHAGE_BUILD_PATH/PLATFORM/FRAMEWORK.framework` where:

 - `CARTHAGE_BUILD_PATH` = `options.carthageBuildPath` or `Carthage/Build` by default
 - `PLATFORM` = the target's platform
 - `FRAMEWORK` = the specified name.

 To link an XCFramework produced by Carthage (in `CARTHAGE_BUILD_PATH/FRAMEWORK.xcframework`), use a normal `framework:`
 dependency. The helper logic provided by this dependency type is not necessary.

All the individual frameworks of a Carthage dependency can be automatically found via `findFrameworks: true`. This overrides the value of [Options](#options).findCarthageFrameworks. Otherwise each one will have to be listed individually.
Xcodegen uses `.version` files generated by Carthage in order for this framework lookup to work, so the Carthage dependencies will need to have already been built at the time XcodeGen is run.

If any applications contain carthage dependencies within itself or any dependent targets, a carthage copy files script is automatically added to the application containing all the relevant frameworks. A `FRAMEWORK_SEARCH_PATHS` setting is also automatically added

Carthage officially supports static frameworks. In this case, frameworks are expected to be in `CARTHAGE_BUILD_PATH/PLATFORM/Static/FRAMEWORK.framework`.
You can specify `linkType` to `static` to integrate static ones.

```yaml
projectReferences:
  FooLib:
    path: path/to/FooLib.xcodeproj
targets:
  MyTarget:
    supportedDestinations: [iOS, tvOS]
    dependencies:
      - target: MyFramework
        destinationFilters: [iOS]
      - target: FooLib/FooTarget
      - framework: path/to/framework.framework
        destinationFilters: [tvOS]
      - carthage: Result
        findFrameworks: false
        linkType: static
        destinationFilters: [iOS]
      - sdk: Contacts.framework
      - sdk: libc++.tbd
      - sdk: libz.dylib
  MyFramework:
    type: framework
```

**SDK Dependency**

- [ ] **root**: **String** - Root of framework path, for example `DEVELOPER_DIR`. Default value is `BUILT_PRODUCTS_DIR`

```yaml
targets:
  MyTestTarget:
    dependencies:
      - target: MyFramework
      - framework: path/to/framework.framework
      - sdk: Contacts.framework
      - sdk: Platforms/iPhoneOS.platform/Developer/Library/Frameworks/XCTest
        root: DEVELOPER_DIR
  MyFramework:
    type: framework
```

**Package dependency**
- [ ] **product**: **String** - The product to use from the package. This defaults to the package name, so is only required if a Package has multiple libraries or a library with a differing name. Use this over `products` when you want to define different linking options per product.
- [ ] **products**: **String** - A list of products to use from the package. This can be used when depending on multiple products from a package.

```yaml
packages:
  Yams:
    url: https://github.com/jpsim/Yams
    majorVersion: 2.0.0
  SwiftPM:
    url: https://github.com/apple/swift-package-manager
    branch: swift-5.0-branch
targets:
  App:
    dependencies:
      - package: Yams 
      - package: SwiftPM
        product: SPMUtility
```

Depending on multiple products from a package:

```yaml
packages:
  FooFeature:
    path: Packages/FooFeature
targets:
  App:
    dependencies:
      - package: FooFeature
        products:
          - FooDomain
          - FooUI
```

### Config Files

Specifies `.xcconfig` files for each configuration.

```yaml
configFiles:
  Debug: debug.xcconfig
  Release: release.xcconfig
targets:
  App:
    configFiles:
      Debug: App/debug.xcconfig
      Release: App/release.xcconfig
```
### Plist
Plists are created on disk on every generation of the project. They can be used as a way to define `Info.plist` or `.entitlement` files. Some `Info.plist` properties are generated automatically.

- [x] **path**: **String** - This is the path where the plist will be written to
- [x] **properties**: **[String: Any]** - This is a map of all the plist keys and values

```yml
targets:
  App:
    info:
      path: App/Info.plist
      properties:
        UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]
        UILaunchStoryboardName: LaunchScreen
    entitlements:
      path: App/App.entitlements
      properties:
        com.apple.security.application-groups: group.com.app
```

### Build Tool Plug-ins

To add `Build Tool Plug-ins`, you need to add information about plugins to [Target](#target):

- **buildToolPlugins**: List of plugins to connect to the target

Each plugin includes information:

- [x] **plugin**: **String** - plugin name 
- [x] **package**: **String** - the name of the package that contains the plugin

Сonnect the plugin to the desired target:

```yaml
targets:
  App:
    buildToolPlugins:
      - plugin: MyPlugin
        package: MyPackage
```

Don't forget to add a package containing the plugin we need:

```yaml
packages:
  MyPackage:
    url: https://github.com/MyPackage
    from: 1.3.0
```

### Build Script

Run script build phases can be added at 3 different points in the build:

- **preBuildScripts**: Before any other build phases
- **postCompileScripts**: After the compile sources build phase
- **postBuildScripts**: After any other build phases

Each script can contain:

- [x] **path**: **String** - a relative or absolute path to a shell script
- [x] **script**: **String** - an inline shell script
- [ ] **name**: **String** - name of a script. Defaults to `Run Script`
- [ ] **inputFiles**: **[String]** - list of input files
- [ ] **outputFiles**: **[String]** - list of output files
- [ ] **inputFileLists**: **[String]** - list of input .xcfilelist
- [ ] **outputFileLists**: **[String]** - list of output .xcfilelist
- [ ] **shell**: **String** - shell used for the script. Defaults to `/bin/sh`
- [ ] **showEnvVars**: **Bool** - whether the environment variables accessible to the script show be printed to the build log. Defaults to `true`
- [ ] **runOnlyWhenInstalling**: **Bool** - whether the script is only run when installing (`runOnlyForDeploymentPostprocessing`). Defaults to `false`
- [ ] **basedOnDependencyAnalysis**: **Bool** - whether to skip the script if inputs, context, or outputs haven't changed. Defaults to `true`
- [ ] **discoveredDependencyFile**: **String** - discovered dependency .d file. Defaults to none

Either a **path** or **script** must be defined, the rest are optional.

A multiline script can be written using the various YAML multiline methods, for example with `|` as below:

```yaml
targets:
  MyTarget:
    preBuildScripts:
      - path: myscripts/my_script.sh
        name: My Script
        inputFiles:
          - $(SRCROOT)/file1
          - $(SRCROOT)/file2
        inputFileLists:
          - $(SRCROOT)/inputFiles.xcfilelist
        outputFiles:
          - $(DERIVED_FILE_DIR)/file1
          - $(DERIVED_FILE_DIR)/file2
        outputFileLists:
          - $(SRCROOT)/outputFiles.xcfilelist
        discoveredDependencyFile: $(DERIVED_FILE_DIR)/target.d
    postCompileScripts:
      - script: swiftlint
        name: Swiftlint
      - script: |
      		command do
      		othercommand
    postBuildScripts:
      - path: myscripts/my_final_script.sh
        name: My Final Script
```

### Build Rule

- [ ] **filePattern**: **String** - A glob pattern for the files that will have the build rule run on them. This or `fileType` must be defined
- [ ] **fileType**: **String** - A file type determined by Xcode. The available types can be seen by hovering your mouse of the `Process` dropdown in the Xcode interface. For example `sourcecode.swift` or `file.xib`. This or `filePattern` must be defined.
- [ ] **script**: **String** - The script that will be run on each file. This or `compilerSpec` must be defined.
- [ ] **compilerSpec**: **String**: A reference to a built in apple tool to run on each file. This is for advanced use and the the values for this must be checked. This or `script` must be defined.
- [ ] **name**: **String** - The name of a build rule. Defaults to `Build Rule`
- [ ] **outputFiles**: **[String]** - The list of output files
- [ ] **outputFilesCompilerFlags**: **[String]** - The list of compiler flags to apply to the output files
- [ ] **runOncePerArchitecture**: **Bool** - a boolean that indicates if this rule should run once per architecture. This defaults to true

```yaml
targets:
  MyTarget:
    buildRules:
      - filePattern: "*.xcassets"
        script: generate_assets.py
      - fileType: sourcecode.swift
        script: pre_process_swift.py
      - filePattern: "*.txt"
        name: My Build Rule
        compilerSpec: com.apple.xcode.tools.swift.compiler
        outputFiles:
          - $(SRCROOT)/Generated.swift
        runOncePerArchitecture: false
```

### Target Scheme

This is a convenience used to automatically generate schemes for a target based on different configs or included tests. If you want more control check out the top level [Scheme](#scheme).

- [x] **configVariants**: **[String]** - This generates a scheme for each entry, using configs that contain the name with debug and release variants. This is useful for having different environment schemes.
- [ ] **testTargets**: **[[Test Target](#test-target)]** - a list of test targets that should be included in the scheme. These will be added to the build targets and the test entries. Each entry can either be a simple string, or a [Test Target](#test-target)
- [ ] **gatherCoverageData**: **Bool** - a boolean that indicates if this scheme should gather coverage data. This defaults to false
- [ ] **coverageTargets**: **[[Testable Target Reference](#testable-target-reference) - a list of targets to gather code coverage. Each entry can either be a simple string, a string using [Project Reference](#project-reference) or [Testable Target Reference](#testable-target-reference)
- [ ] **disableMainThreadChecker**: **Bool** - a boolean that indicates if this scheme should disable the Main Thread Checker. This defaults to false
- [ ] **stopOnEveryMainThreadCheckerIssue**: **Bool** - a boolean that indicates if this scheme should stop at every Main Thread Checker issue. This defaults to false
- [ ] **disableThreadPerformanceChecker**: **Bool** - a boolean that indicates if this scheme should disable the Thread Performance Checker. This defaults to false
- [ ] **buildImplicitDependencies**: **Bool** - Flag to determine if Xcode should build implicit dependencies of this scheme. By default this is `true` if not set.
- [ ] **language**: **String** - a String that indicates the language used for running and testing. This defaults to nil
- [ ] **region**: **String** - a String that indicates the region used for running and testing. This defaults to nil
- [ ] **commandLineArguments**: **[String:Bool]** - a dictionary from the argument name (`String`) to if it is enabled (`Bool`). These arguments will be added to the Test, Profile and Run scheme actions
- [ ] **environmentVariables**: **[[Environment Variable](#environment-variable)]** or **[String:String]** - environment variables for Run, Test and Profile scheme actions. When passing a dictionary, every key-value entry maps to a corresponding variable that is enabled.
- [ ] **testPlans**:  **[[Test Plan](#test-plan)]** - List of test plan locations that will be referenced in the scheme.
- [ ] **preActions**: **[[Execution Action](#execution-action)]** - Scripts that are run *before* the build action
- [ ] **postActions**: **[[Execution Action](#execution-action)]** - Scripts that are run *after* the build action
- [ ] **management**: **[Scheme Management](#scheme-management)** - Management options for the scheme
- [ ] **storeKitConfiguration**: **String** - specify storekit configuration to use during run. See [Options](#options).

For example, the spec below would create 3 schemes called:

- MyApp Test
- MyApp Staging
- MyApp Production

Each scheme would use different build configuration for the different build types, specifically debug configs for `run`, `test`, and `analyze`, and release configs for `profile` and `archive`.
The MyUnitTests target would also be linked.

```yaml
configs:
  Test Debug: debug
  Staging Debug: debug
  Production Debug: debug
  Test Release: release
  Staging Release: release
  Production Release: release
targets:
  MyApp:
    scheme:
      testTargets:
        - MyUnitTests
      configVariants:
        - Test
        - Staging
        - Production
      gatherCoverageData: true
      coverageTargets:
        - MyTarget1
        - ExternalTarget/OtherTarget1
      commandLineArguments:
        "-MyEnabledArg": true
        "-MyDisabledArg": false
      environmentVariables:
        MY_ENV_VAR: VALUE
  MyUnitTests:
    sources: Tests
```

### Legacy Target

By providing a legacy target, you are opting in to the "Legacy Target" mode. This is the "External Build Tool" from the Xcode GUI. This is useful for scripts that you want to run as dependencies of other targets, but you want to make sure that it only runs once even if it is specified as a dependency from multiple other targets.

- [x] ***toolPath***: String - Path to the build tool used in the legacy target.
- [ ] ***arguments***: String - Build arguments used for the build tool in the legacy target
- [ ] ***passSettings***: Bool - Whether or not to pass build settings down to the build tool in the legacy target.
- [ ] ***workingDirectory***: String - The working directory under which the build tool will be invoked in the legacy target.

## Aggregate Target

This is used to override settings or run build scripts in specific targets

- [x] **targets**: **[String]** - The list of target names to include as target dependencies
- [ ] **configFiles**: **[Config Files](#config-files)** - `.xcconfig` files per config
- [ ] **settings**: **[Settings](#settings)** - Target specific build settings.
- [ ] **buildToolPlugins**: **[[Build Tool Plug-ins](#build-tool-plug-ins)]** - Commands for the build system that run automatically *during* the build
- [ ] **buildScripts**: **[[Build Script](#build-script)]** - Build scripts to run
- [ ] **scheme**: **[Target Scheme](#target-scheme)** - Generated scheme
- [ ] **attributes**: **[String: Any]** - This sets values in the project `TargetAttributes`. It is merged with `attributes` from the project and anything automatically added by XcodeGen, with any duplicate values being override by values specified here

## Target Template

This is a template that can be referenced from a normal target using the `templates` property. The properties of this template are the same as a [Target](#target).
Any instances of `${target_name}` within each template will be replaced by the final target name which references the template.
Any attributes defined within a targets `templateAttributes` will be used to replace any attribute references in the template using the syntax `${attribute_name}`.


```yaml
targets:
  MyFramework:
    templates: 
      - Framework
    templateAttributes:
      frameworkName: AwesomeFramework
    sources:
      - SomeSources
targetTemplates:
  Framework:
    platform: iOS
    type: framework
    sources:
      - ${frameworkName}/${target_name}
```

## Scheme

Schemes allows for more control than the convenience [Target Scheme](#target-scheme) on [Target](#target)

- [x] ***build***: Build options
- [ ] ***run***: The run action
- [ ] ***test***: The test action
- [ ] ***profile***: The profile action
- [ ] ***analyze***: The analyze action
- [ ] ***archive***: The archive action
- [ ] ***management***: management metadata

### Build

- [x] **targets**: **[String:String]** or **[String:[String]]** - A map of target names to build and which build types they should be enabled for. The build types can be `all`, `none`, or an array of the following types:
	- `run` or `running`
	- `test` or `testing`
	- `profile` or `profiling`
	- `analyze` or `analyzing`
	- `archive` or `archiving`

- [ ] **parallelizeBuild**: **Bool** - Whether or not your targets should be built in parallel. By default this is `true` if not set.
  - `true`: Build targets in parallel
  - `false`: Build targets serially
- [ ] **buildImplicitDependencies**: **Bool** - Flag to determine if Xcode should build implicit dependencies of this scheme. By default this is `true` if not set.

  - `true`: Discover implicit dependencies of this scheme
  - `false`: Only build explicit dependencies of this scheme

- [ ] **runPostActionsOnFailure**: **Bool** - Flag to determine if Xcode should run post scripts despite failure build. By default this is `false` if not set.
- `true`: Run post scripts even if build is failed
- `false`: Only run post scripts if build success


```yaml
targets:
  MyTarget: all
  FooLib/FooTarget: [test, run]
parallelizeBuild: true
buildImplicitDependencies: true
```

### Common Build Action options

The different actions share some properties:

- [ ] **config**: **String** - All build actions can be set to use a certain config. If a config, or the build action itself, is not defined the first configuration found of a certain type will be used, depending on the type:
	- `debug`: run, test, analyze
	- `release`: profile, archive
- [ ] **commandLineArguments**: **[String:Bool]** - `run`, `test` and `profile` actions have a map of command line arguments to whether they are enabled
- [ ] **preActions**: **[[Execution Action](#execution-action)]** - Scripts that are run *before* the action
- [ ] **postActions**: **[[Execution Action](#execution-action)]** - Scripts that are run *after* the action
- [ ] **environmentVariables**: **[[Environment Variable](#environment-variable)]** or **[String:String]** - `run`, `test` and `profile` actions can define the environment variables. When passing a dictionary, every key-value entry maps to a corresponding variable that is enabled.
- [ ] **enableGPUFrameCaptureMode**: **GPUFrameCaptureMode** - Property value set for `GPU Frame Capture`. Possible values are `autoEnabled`, `metal`, `openGL`, `disabled`. Default is `autoEnabled`.
- [ ] **enableGPUValidationMode**: **GPUValidationMode** - Property value set for `Metal API Validation`. Possible values are `enabled`, `disabled`, `extended`. Default is `enabled`.
- [ ] **disableMainThreadChecker**: **Bool** - `run` and `test` actions can define a boolean that indicates that this scheme should disable the Main Thread Checker. This defaults to false
- [ ] **stopOnEveryMainThreadCheckerIssue**: **Bool** - a boolean that indicates if this scheme should stop at every Main Thread Checker issue. This defaults to false
- [ ] **disableThreadPerformanceChecker**: **Bool** - `run` action can define a boolean that indicates that this scheme should disable the Thread Performance Checker. This defaults to false
- [ ] **language**: **String** - `run` and `test` actions can define a language that is used for Application Language
- [ ] **region**: **String** - `run` and `test` actions can define a language that is used for Application Region
- [ ] **debugEnabled**: **Bool** - `run` and `test` actions can define a whether debugger should be used. This defaults to true.
- [ ] **simulateLocation**: **[Simulate Location](#simulate-location)** - `run` action can define a simulated location
- [ ] **askForAppToLaunch**: **Bool** - `run` and `profile` actions can define the executable set to ask to launch. This defaults to false.
- [ ] **launchAutomaticallySubstyle**: **String** - `run` action can define the launch automatically substyle ('2' for extensions).
- [ ] **storeKitConfiguration**: **String** - `run` action can specify a storekit configuration. See [Options](#options).
- [ ] **macroExpansion**: **String** - `run` and `test` actions can define the macro expansion from other target. This defaults to nil.

### Execution Action

Scheme run scripts added via **preActions** or **postActions**. They run before or after a build action, respectively, and in the order defined. Each execution action can contain:

- [x] **script**: **String** - an inline shell script
- [ ] **name**: **String** - name of a script. Defaults to `Run Script`
- [ ] **settingsTarget**: **String** - name of a build or test target whose settings will be available as environment variables.

A multiline script can be written using the various YAML multiline methods, for example with `|`. See [Build Script](#build-script).

### Run Action
- [ ] **executable**: **String** - the name of the target to launch as an executable. Defaults to the first runnable build target in the scheme, or the first build target if a runnable build target is not found
- [ ] **customLLDBInit**: **String** - the absolute path to the custom `.lldbinit` file

### Test Action

- [ ] **gatherCoverageData**: **Bool** - a boolean that indicates if this scheme should gather coverage data. This defaults to false
- [ ] **coverageTargets**: **[[Testable Target Reference](#testable-target-reference)]** - a list of targets to gather code coverage. Each entry can either be a simple string, a string using [Project Reference](#project-reference) or [Testable Target Reference](#testable-target-reference)
- [ ] **targets**: **[[Test Target](#test-target)]** - a list of targets to test. Each entry can either be a simple string, or a [Test Target](#test-target)
- [ ] **customLLDBInit**: **String** - the absolute path to the custom `.lldbinit` file
- [ ] **captureScreenshotsAutomatically**: **Bool** - indicates whether screenshots should be captured automatically while UI Testing. This defaults to true.
- [ ] **deleteScreenshotsWhenEachTestSucceeds**: **Bool** - whether successful UI tests should cause automatically-captured screenshots to be deleted. If `captureScreenshotsAutomatically` is false, this value is ignored. This defaults to true.
- [ ] **testPlans**:  **[[Test Plan](#test-plan)]** - List of test plan locations that will be referenced in the scheme.

#### Test Target
A target can be one of a 2 types:

- **name**: **String** - The name of the target.
- **target**: **[Testable Target Reference](#testable-target-reference)** - The information of the target. You can specify more detailed information than `name:`.

As syntax sugar, you can also specify **[Testable Target Reference](#testable-target-reference)** without `target`.

#### Other Parameters

- [ ] **parallelizable**: **Bool** - Whether to run tests in parallel. Defaults to false
- [ ] **randomExecutionOrder**: **Bool** - Whether to run tests in a random order. Defaults to false
- [ ] **location**: **String** - GPX file or predefined value for simulating location. See [Simulate Location](#simulate-location) for location examples.
- [ ] **skipped**: **Bool** - Whether to skip all of the test target tests. Defaults to false
- [ ] **skippedTests**: **[String]** - List of tests in the test target to skip. Defaults to empty
- [ ] **selectedTests**: **[String]** - List of tests in the test target to whitelist and select. Defaults to empty. This will override `skippedTests` if provided

#### Testable Target Reference
A Testable Target Reference can be one of 3 types:
- `package: {local-swift-package-name}/{target-name}`: Name of local swift package and its target.
- `local: {target-name}`:  Name of local target.
- `project: {project-reference-name}/{target-name}`:  Name of local swift package and its target.

### Archive Action

- [ ] **customArchiveName**: **String** - the custom name to give to the archive
- [ ] **revealArchiveInOrganizer**: **Bool** - flag to determine whether the archive will be revealed in Xcode's Organizer after it's done building


### Simulate Location
- [x] **allow**: **Bool** - enable location simulation 
- [ ] **defaultLocation**: **String** - set the default location, possible values:
	- `London, England`
	- `Johannesburg, South Africa`
	- `Moscow, Russia`
	- `Mumbai, India`
	- `Tokyo, Japan`
	- `Sydney, Australia`
	- `Hong Kong, China`
	- `Honolulu, HI, USA`
	- `San Francisco, CA, USA`
	- `Mexico City, Mexico`
	- `New York, NY, USA`
	- `Rio de Janeiro, Brazil`
	- `<relative-path-to-gpx-file>` (e.g. ./location.gpx)   
	 Setting the **defaultLocation** to a custom gpx file, you also need to add that file to `fileGroups` for Xcode be able to use it:
	 
```yaml
targets:
  MyTarget:
    fileGroups:
      - location.gpx
```

Note that the path the gpx file will be prefixed according to the `schemePathPrefix` option in order to support both `.xcodeproj` and `.xcworkspace` setups. See [Options](#options).

### Scheme Management
- [ ] **shared**: **Bool** - indicates whether the scheme is shared
- [ ] **orderHint**: **Int** - used by Xcode to sort the schemes
- [ ] **isShown**: **Bool** - indicates whether the sheme is shown in the scheme list

### Environment Variable

- [x] **variable**: **String** - variable's name.
- [x] **value**: **String** - variable's value.
- [ ] **isEnabled**: **Bool** - indicates whether the environment variable is enabled. This defaults to true.

```yaml
schemes:
  Production:
    build:
      targets:
        MyTarget1: all
        MyTarget2: [run, archive]
    run:
      config: prod-debug
      commandLineArguments:
        "-MyEnabledArg": true
        "-MyDisabledArg": false
      environmentVariables:
        RUN_ENV_VAR: VALUE
    test:
      config: prod-debug
      commandLineArguments:
        "-MyEnabledArg": true
        "-MyDisabledArg": false
      gatherCoverageData: true
      coverageTargets:
        - MyTarget1
        - ExternalTarget/OtherTarget1
        - package: LocalPackage/TestTarget
      targets: 
        - Tester1 
        - name: Tester2
          parallelizable: true
          randomExecutionOrder: true
          skippedTests: [Test/testExample()]
        - package: APIClient/APIClientTests
          parallelizable: true
          randomExecutionOrder: true
      environmentVariables:
        - variable: TEST_ENV_VAR
          value: VALUE
          isEnabled: false
    profile:
      config: prod-release
    analyze:
      config: prod-debug
    archive:
      config: prod-release
      customArchiveName: MyTarget
      revealArchiveInOrganizer: false
```

### Test Plan
For now test plans are not generated by XcodeGen and must be created in Xcode and checked in, and then referenced by path. If the test targets are added, removed or renamed, the test plans may need to be updated in Xcode.

- [x] **path**: **String** - path that provides the `xctestplan` location.
- [ ] **defaultPlan**: **Bool** - a bool that defines if given plan is the default one. Defaults to false. If no default is set on any test plan, the first plan is set as the default.

```yaml
schemes:
  TestTarget:
    test:
      testPlans:
        - path: app.xctestplan
          defaultPlan: true
```

## Scheme Template

This is a template that can be referenced from a normal scheme using the `templates` property. The properties of this template are the same as a [Scheme](#scheme). This functions identically in practice to [Target Template](#target-template).
Any instances of `${scheme_name}` within each template will be replaced by the final scheme name which references the template.
Any attributes defined within a scheme's `templateAttributes` will be used to replace any attribute references in the template using the syntax `${attribute_name}`.

```yaml
schemes:
  MyModule:
    templates:
      - FeatureModuleScheme
    templateAttributes:
      testTargetName: MyModuleTests

schemeTemplates:
  FeatureModuleScheme:
    templates:
      - TestScheme
    build:
      targets:
       ${scheme_name}: build

  TestScheme:
    test:
      gatherCoverageData: true
      targets:
        - name: ${testTargetName}
          parallelizable: true
          randomExecutionOrder: true
```

The result will be a scheme that builds `MyModule` when you request a build, and will test against `MyModuleTests` when you request to run tests. This is particularly useful when you work in a very modular application and each module has a similar structure.

## Swift Package
Swift packages are defined at a project level, and then linked to individual targets via a [Dependency](#dependency).

### Remote Package

- [x] **url**: **URL** - the url to the package
- [x] **version**: **String** - the version of the package to use. It can take a few forms:
  - `majorVersion: 1.2.0` or `from: 1.2.0`
  - `minorVersion: 1.2.1`
  - `exactVersion: 1.2.1` or `version: 1.2.1`
  - `minVersion: 1.0.0, maxVersion: 1.2.9`
  - `branch: master`
  - `revision: xxxxxx`
- [ ] **github** : **String**- this is an optional helper you can use for github repos. Instead of specifying the full url in `url` you can just specify the github org and repo
  
### Local Package

- [x] **path**: **String** - the path to the package in local. The path must be directory with a `Package.swift`.
- [ ] **group** : **String**- Optional path that specifies the location where the package will live in your xcode project. Use `""` to specify the project root.

```yml
packages:
  Yams:
    url: https://github.com/jpsim/Yams
    from: 2.0.0
  Ink:
    github: JohnSundell/Ink
    from: 0.5.0
  RxClient:
    path: ../RxClient
  AppFeature:
    path: ../Packages
    group: Domains/AppFeature
```

## Project Reference

Project References are defined at a project level, and then you can use the project name to refer its target via a [Scheme](#scheme)

- [x] **path**: **String** - The path to the `xcodeproj` file to reference.

```yml
projectReferences:
  YamsProject:
    path: ./Carthage/Checkouts/Yams/Yams.xcodeproj
schemes:
  TestTarget:
    build:
      targets:
        YamsProject/Yams: ["run"]
```
