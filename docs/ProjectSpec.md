# Project Spec
The project spec can be written in either YAML or JSON. All the examples below use YAML.  

Some of the examples below don't show all the required properties when trying to explain something. For example not all target examples will have a platform or type, even though they are required.

Required properties are marked 🔵 and optional properties with ⚪️.

### Index

- [Project](#project)
	- [Options](#options)
	- [Configs](#configs)
	- [Setting Presets](#setting-presets)
- [Settings](#settings)
- [Target](#target) 
	- [Product Type](#product-type)
	- [Platform](#platform)
	- [Sources](#sources)
	- [Config Files](#config-files)
	- [Settings](#settings)
	- [Build Script](#build-script)
	- [Dependency](#dependency)
	- [Target Scheme](#target-scheme)

## Project

- 🔵 **name**: `String` - Name of the generated project
- ⚪️ **options**: [Options](#options) - Various options to override default behaviour
- ⚪️ **configs**: [Configs](#configs) - Project build configurations. Defaults to `Debug` and `Release` configs
- ⚪️ **settings**: [Settings](#settings) - Project specific settings. Default base and config type settings will be applied first before any settings defined here
- ⚪️ **settingPresets**: [Setting Presets](#setting-presets) - Setting presets mapped by name
- ⚪️ **targets**: [[Target](#target)] - The list of targets in the project

### Options
- ⚪️ **carthageBuildPath**: `String` - The path to the carthage build directory. Defaults to `Carthage/Build`. This is used when specifying target carthage dependencies

### Configs
Each config maps to a build type of either `debug` or `release` which will then apply default build settings. Any value other than `debug` or `release` (for example "none"), will mean no default build settings will be applied.

```yaml
configs:
  Debug: debug
  Release: release
```
If no configs are specified, default `Debug` and `Release` configs will be created automatically.


### Setting Presets
Setting presets are named groups of build settings that can be reused elsewhere. Each preset is a [Settings](#settings) schema, so can include other presets

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

## Settings
Settings can either be a simple map of build settings `[String: String]`, or can be more advanced with the following properties:

- ⚪️ **presets**: `[String]` - List of presets to include and merge
- ⚪️ **configs**: [String: [Settings](#settings)] - Mapping of config name to a settings spec. These settings will only be applied for that config
- ⚪️ **base**: `[String: String]` - Used to specify default settings that apply to any config

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

## Target

- 🔵 **name**: `String` - Name of the target
- 🔵 **type**: [Product Type](#product-type) - Product type of the target
- 🔵 **platform**: [Platform](#platform) - Platform of the target
- ⚪️ **sources**: [Sources](#sources) - Source directories of the target
- ⚪️ **configFiles**: [Config Files](#config-files) - `.xcconfig` files per config
- ⚪️ **settings**: [Settings](#settings) - Target specific build settings. Default platform and product type settings will be applied first before any custom settings defined here
- ⚪️ **prebuildScripts**: [[Build Script](#build-script)] - Build scripts that run *before* any other build phases
- ⚪️ **postbuildScripts**: [[Build Script](#build-script)] - Build scripts that run *after* any other build phases
- ⚪️ **dependencies**: [[Dependency](#dependency)] - Dependencies for the target
- ⚪️ **scheme**: [Target Scheme](#target-scheme) - Generated scheme with tests or config variants

### Product Type
This will provide default build settings for a certain product type. It can be any of the following:

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

### Platform
This will provide default build settings for a certain platform. It can be any of the following:

- iOS
- tvOS
- macOS
- watchOS

**Multi Platform targets**

You can also specify an array of platforms. This will generate a target for each platform.
If you reference the string `$platform` anywhere within the target spec, that will be replaced with the platform.

The generated targets by default will have a suffix of `_$platform` applied, you can change this by specifying a `platformSuffix` or `platformPrefix`.

If no `PRODUCT_NAME` build setting is specified for a target, this will be set to the target name, so that this target can be imported under a single name.

```
name: MyFramework
sources: MyFramework
platform: [iOS, tvOS]
type: framework
settings:
  base:
    INFOPLIST_FILE: MyApp/Info.plist
    PRODUCT_BUNDLE_IDENTIFIER: com.myapp
    MY_SETTING: platform $platform
  presets:
    - $platform
```
The above will generate 2 targets named `MyFramework_iOS` and `MyFramework_tvOS`, with all the relevant platform build settings. They will both have a `PRODUCT_NAME` of `MyFramework`

### Sources
Specifies the source directories for a target. This can either be a single path or a list of paths. Applicable source files, resources, headers, and lproj files will be parsed appropriately

```yaml
targets:
  - name: MyTarget
    sources: MyTargetSource
  - name: MyOtherTarget
    sources:
      - MyOtherTargetSource1
      - MyOtherTargetSource2
```

### Dependency
A dependency can be one of a few types:

- `target: name` - links to another target
- `framework: path` - links to a framework
- `carthage: name` - helper for linking to a carthage framework

**Carthage notes**

Carthage frameworks expected to be in `CARTHAGE_BUILD_PATH/PLATFORM/FRAMEWORK.framework` where:

 - `CARTHAGE_BUILD_PATH` = `options.carthageBuildPath` or `Carthage/Build` by default
 - `PLATFORM` = the target's platform
 - `FRAMEWORK` = the specified name.

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

### Config Files
Specifies `.xcconfig` files for each configuration.

```yaml
targets:
  - name: MyTarget
    configFiles:
      Debug: config_files/debug.xcconfig
      Release: config_files/release.xcconfig
```

### Build Script
Run script build phases added via **prebuildScripts** or **postBuildScripts**. They run before or after any other build phases respectively and in the order defined. Each script can contain:

- 🔵 **path**: `String` - a relative or absolute path to a shell script
- 🔵 **script**: `String` - an inline shell script
- ⚪️ **name**: `String` - name of a script. Defaults to `Run Script`
- ⚪️ **inputFiles**: `[String]` - list of input files
- ⚪️ **outputFiles**: `[String]` - list of output files
- ⚪️ **shell**: `String` - shell used for the script. Defaults to `/bin/sh`
- ⚪️ **runOnlyWhenInstalling**: `Bool` - whether the script is only run when installing (runOnlyForDeploymentPostprocessing). Defaults to no

Either a **path** or **script** must be defined, the rest are optional.

A multiline script can be written using the various YAML multiline methods, for example with `|` as below:

```yaml
targets:
  - name: MyTarget
    prebuildScripts:
      - path: myscripts/my_script.sh
        name: My Script
        inputFiles:
          - $(SRCROOT)/file1
          - $(SRCROOT)/file2
        outputFiles:
          - $(DERIVED_FILE_DIR)/file1
          - $(DERIVED_FILE_DIR)/file2
    postbuildScripts:
      - script: swiftlint
        name: Swiftlint
      - script: |
      		command do
      		othercommand
```

###  Target Scheme
This is a convenience used to automatically generate schemes for a target based on different configs or included tests.

- 🔵 **configVariants**: `[String]` - This generates a scheme for each entry, using configs that contain the name with debug and release variants. This is useful for having different environment schemes.
- ⚪️ **testTargets**: `[String]` - a list of test targets that should be included in the scheme. These will be added to the build targets and the test entries

For example, the spec below would create 3 schemes called:

- MyApp Test
- MyApp Staging
- MyApp Production

Each scheme would use different build configuration for the different build types, specifically debug configs for `run`, `test`, and `anaylze`, and release configs for `profile` and `archive`.
The MyUnitTests target would also be linked.

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
    scheme:
      testTargets:
        - MyUnitTests
      configVariants:
        - Test
        - Staging
        - Production
  - name: MyUnitTests
```
