# Project Spec
The project spec can be written in either YAML or JSON. All the examples below use YAML.  

Some of the examples below don't show all the required properties when trying to explain something. For example not all target examples will have a platform or type, even though they are required.

Required properties are marked 🔵 and optional properties with ⚪️.

### Index

- [Project](#project)
	- [Options](#options)
	- [Configurations](#configurations)
	- [Setting Groups](#setting-groups)
- [Settings](#settings)
- [Target](#target)
	- [Product Type](#product-type)
	- [Platform](#platform)
	- [Sources](#sources)
	- [Configuration Files](#configuration-files)
	- [Settings](#settings)
	- [Build Script](#build-script)
	- [Dependency](#dependency)
	- [Target Scheme](#target-scheme)

## Project

- 🔵 **name**: `String` - Name of the generated project
- ⚪️ **include**: `[String]` - The paths to other specs. They will be merged in order and then the current spec will be merged on top. Target names can be changed by adding a `name` property. This can also be set as a single path string
- ⚪️ **options**: [Options](#options) - Various options to override default behaviour
- ⚪️ **attributes**: `map` - The PBXProject attributes. This is for advanced use. Defaults to ``{"LastUpgradeCheck": "0900"}``
- ⚪️ **configurations**: [Configurations](#configurations) - Project build configurations. Defaults to `Debug` and `Release` configurations
- ⚪️ **settings**: [Settings](#settings) - Project specific settings. Default base and configuration type settings will be applied first before any settings defined here
- ⚪️ **settingGroups**: [Setting Groups](#setting-groups) - Setting groups mapped by name
- ⚪️ **targets**: [Target](#target) - The list of targets in the project mapped by name

### Options
- ⚪️ **carthageBuildPath**: `String` - The path to the carthage build directory. Defaults to `Carthage/Build`. This is used when specifying target carthage dependencies

### Configurations
Each configuration maps to a build type of either `debug` or `release` which will then apply default build settings. Any value other than `debug` or `release` (for example "none"), will mean no default build settings will be applied.

```yaml
configurations:
  Debug: debug
  Release: release
```
If no configurations are specified, default `Debug` and `Release` configurations will be created automatically.


### Setting Groups
Setting groups are named groups of build settings that can be reused elsewhere. Each preset is a [Settings](#settings) schema, so can include other groups

```yaml
settingGroups:
  preset1:
    BUILD_SETTING: value
  preset2:
    base:
      BUILD_SETTING: value
    groups:
      - preset
  preset3:
     configurations:
        debug:
        	groups:
            - preset
```

## Settings
Settings can either be a simple map of build settings `[String: String]`, or can be more advanced with the following properties:

- ⚪️ **groups**: `[String]` - List of setting groups to include and merge
- ⚪️ **configurations**: [String: [Settings](#settings)] - Mapping of configuration name to a settings spec. These settings will only be applied for that config
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
  configurations:
    my_configuration:
      BUILD_SETTING_2: value 2
  groups:
    - my_settings
```

Settings are merged in the following order: groups, base, configurations.

## Target

- 🔵 **type**: [Product Type](#product-type) - Product type of the target
- 🔵 **platform**: [Platform](#platform) - Platform of the target
- ⚪️ **sources**: [Sources](#sources) - Source directories of the target
- ⚪️ **configurationFiles**: [Configuration Files](#configuration-files) - `.xcconfig` files per config
- ⚪️ **settings**: [Settings](#settings) - Target specific build settings. Default platform and product type settings will be applied first before any custom settings defined here. Other context dependant settings will be set automatically as well:
	- `INFOPLIST_FILE`: If it doesn't exist your sources will be searched for `Info.plist` files and the first one found will be used for this setting
	- `FRAMEWORK_SEARCH_PATHS`: If carthage dependencies are used, the platform build path will be added to this setting
- ⚪️ **prebuildScripts**: [[Build Script](#build-script)] - Build scripts that run *before* any other build phases
- ⚪️ **postbuildScripts**: [[Build Script](#build-script)] - Build scripts that run *after* any other build phases
- ⚪️ **dependencies**: [[Dependency](#dependency)] - Dependencies for the target
- ⚪️ **scheme**: [Target Scheme](#target-scheme) - Generated scheme with tests or configuration variants

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

```yaml
targets:
  MyFramework:
    sources: MyFramework
    platform: [iOS, tvOS]
    type: framework
    settings:
      base:
        INFOPLIST_FILE: MyApp/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.myapp
        MY_SETTING: platform $platform
      groups:
        - $platform
```
The above will generate 2 targets named `MyFramework_iOS` and `MyFramework_tvOS`, with all the relevant platform build settings. They will both have a `PRODUCT_NAME` of `MyFramework`

### Sources
Specifies the source directories for a target. This can either be a single path or a list of paths. Applicable source files, resources, headers, and lproj files will be parsed appropriately

```yaml
targets:
  MyTarget
    sources: MyTargetSource
  MyOtherTarget
    sources:
      - MyOtherTargetSource1
      - MyOtherTargetSource2
```

### Dependency
A dependency can be one of a 3 types:

- `target: name` - links to another target
- `framework: path` - links to a framework
- `carthage: name` - helper for linking to a carthage framework

**Embed options**:

These only applied to `target` and `framework` dependencies.

- ⚪️ **embed**: `Bool` - Whether to embed the dependency. Defaults to true for application target and false for non application targets.
- ⚪️ **codeSign**: `Bool` - Whether the `codeSignOnCopy` setting is applied when embedding framework. Defaults to true
- ⚪️ **removeHeaders**: `Bool` - Whether the `removeHeadersOnCopy` setting is applied when embedding the framework. Defaults to true

**Carthage Dependency**

Carthage frameworks are expected to be in `CARTHAGE_BUILD_PATH/PLATFORM/FRAMEWORK.framework` where:

 - `CARTHAGE_BUILD_PATH` = `options.carthageBuildPath` or `Carthage/Build` by default
 - `PLATFORM` = the target's platform
 - `FRAMEWORK` = the specified name.

If any applications contain carthage dependencies within itself or any dependent targets, a carthage copy files script is automatically added to the application containing all the relevant frameworks. A `FRAMEWORK_SEARCH_PATHS` setting is also automatically added

```yaml
targets:
  MyTarget:
    dependencies:
      - target: MyFramework
      - framework: path/to/framework.framework
      - carthage: Result  
  MyFramework:
    type: framework
```

### Configuration Files
Specifies `.xcconfig` files for each configuration.

```yaml
targets:
  MyTarget:
    configurationFiles:
      Debug: configuration_files/debug.xcconfig
      Release: configuration_files/release.xcconfig
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
  MyTarget:
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
This is a convenience used to automatically generate schemes for a target based on different configurations or included tests.

- 🔵 **configurationVariants**: `[String]` - This generates a scheme for each entry, using configurations that contain the name with debug and release variants. This is useful for having different environment schemes.
- ⚪️ **testTargets**: `[String]` - a list of test targets that should be included in the scheme. These will be added to the build targets and the test entries

For example, the spec below would create 3 schemes called:

- MyApp Test
- MyApp Staging
- MyApp Production

Each scheme would use different build configuration for the different build types, specifically debug configurations for `run`, `test`, and `anaylze`, and release configurations for `profile` and `archive`.
The MyUnitTests target would also be linked.

```
configurations:
  Test Debug: debug
  Staging Debug: debug
  Production Debug: debug
  Test Release: release
  Staging Release: release
  Production Release: release
targets
  MyApp:
    scheme:
      testTargets:
        - MyUnitTests
      configurationVariants:
        - Test
        - Staging
        - Production
  MyUnitTests:
    sources: Tests
```
