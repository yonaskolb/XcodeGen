# Project spec
The project spec can be written in either YAML or JSON. All the examples below use YAML

### name
Each spec must contain a name which is used for the generated project name

```yaml
name: My Project
```
#### configs
Configs specify the build configurations in the project.
Each config maps to a build type of either `debug` or `release` which will then apply default build settings for those types. Any value other than `debug` or `release` (for example "none"), will mean no default build settings will be loaded

```yaml
configs:
  Debug: debug
  Release: release
```
If no configs are specified, default `Debug` and `Release` configs will be created automatically

#### settings
Project settings use the [Settings](#settings-spec) spec. Default base and config type settings will be applied first before any custom settings

#### settingPresets
Setting presets can be used to group build settings together and reuse them elsewhere. Each preset is a Settings schema, so can include other presets

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

## Settings Spec
Settings can be defined on the project and each target, and the format is the same. Settings can either be a simple list of build settings or can be more advanced with the following properties:

- `presets`: a list of presets to include and merge
- `configs`: a mapping of config name to a new nested settings spec. These settings will only be applied for that config
- `base`: used to specify default settings that apply to any config

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

## targets
This is list of targets

```yaml
targets:
  - name: MyTarget
```
#### type
This specifies the product type of the target. This will provide default build settings for that product type. Type can be any of the following:

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

#### platform
Specifies the platform for the target. This will provide default build settings for that platform. It can be any of the following:

- iOS
- tvOS
- macOS
- watchOS

#### sources
Specifies the source directories for the target. This can either be a single path or a list of paths. Applicable source files, resources, headers, and lproj files will be parsed appropriately

```yaml
targets:
  - name: MyTarget
    sources: MyTargetSource
  - name: MyOtherTarget
    sources:
      - MyOtherTargetSource1
      - MyOtherTargetSource2
```

#### settings
Species the build settings for the target. This uses the same [Settings](#settings-spec) spec as the project. Default platform and product type settings will be applied first before any custom settings

#### dependencies
Species the dependencies for the target. This can be another target, a framework path, or a carthage dependency.

Carthage dependencies look for frameworks in `Carthage/Build/PLATFORM/FRAMEWORK.framework` where `PLATFORM` is the target's platform, and `FRAMEWORK` is the carthage framework you've specified.
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

#### configFiles
Specifies `.xcconfig` files for each configuration for the target.

```yaml
targets:
  - name: MyTarget
    configFiles:
      Debug: config_files/debug.xcconfig
      Release: config_files/release.xcconfig
```

#### generateSchemes
This is a conveniance used to automatically generate schemes for a target based on large amount of configs. A list of names is provided, then for each of these names a scheme is created, using configs that contain the name with debug and release variants. This is useful for having different environment schemes.

For example, the following spec would create 3 schemes called:

- MyApp Test
- MyApp Staging
- MyApp Production

Each scheme would use different build configuration for the different build types, specifically debug configs for `run`, `test`, and `anaylze`, and release configs for `profile` and `archive`

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
    generateSchemes:
      - Test
      - Staging
      - Production
```
