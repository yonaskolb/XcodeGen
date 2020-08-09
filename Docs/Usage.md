
- [Configuring build settings](#configuring-build-settings)
    - [Setting Presets](#setting-presets)
    - [Settings](#settings)
    - [Setting Groups](#setting-groups)
    - [xcconfig files](#xcconfig-files)
- [Dependencies](#dependencies)
    - [CocoaPods](#cocoapods)
    - [Carthage](#carthage)
    - [Swift Package](#swift-package)
    - [SDK](#sdk)
    - [Framework](#framework)

# Configuring build settings
There are various ways of configuring build settings

Xcode resolves a certain build setting for a configuration and target by looking up the different levels until it finds a value. This can be seen in Xcode when the `Levels` option is on in the `Build Settings` tab. The different levels of build settings are:

- target
- target xcconfig file
- project
- project xcconfig file
- sdk defaults

XcodeGen will apply settings to a target or project level by merging different methods
- [Setting Presets](#setting-presets)
- [Setting Groups](#setting-groups)
- [Settings](#settings) `base`
- [Settings](#settings) for a specific `config`

The values from [xcconfig files](#xcconfig-files) will then sit a level above this. Note that as a convenience, any settings in an xcconfig file will also overwrite any settings from [Setting Presets](#setting-presets)

>Note that when defining build settings you need to know the write name and value. In Xcode build settings are shown by default with a nicely formatted title and value. To be able to see what the actual build setting names and values are make sure you're in a `Build Settings` tab and go `Editor -> Show Setting Titles` and also `Editor -> Show Definitions`. This will then give you the actual names and values that XcodeGen expects.

### Setting Presets
XcodeGen applies default settings to your project and targets similar to how Xcode creates them when you create a new project or target.
Debug and Release settings will be applied to your project. Targets will also get specific settings depending on the platform and product type.

>You can change or disable how these setting presets are applied via the `options.settingPresets` which you can find more about in [Options](#options)

### Settings
The `project` and each `target` have a `settings` object that you can define. This can be a simple map of build settings or can provide build settings per `config` via `configs` or `base`. See [Settings](ProjectSpec.md#settings) for more details.

```yaml
settings:
  DEVELOPMENT_TEAM: T45H45J
targets:
  App:
    settings:
      base:
        CODE_SIGN_ENTITLEMENTS: App/Entitlements.entitlements
      configs:
        Debug:
          DEBUG_MODE: YES
        Release:
          DEBUG_MODE: NO
     
```

### Setting Groups
Each `settings` can also reference one or more setting groups which let you reuse groups of build settings across targets or configurations. See [Setting Groups](ProjectSpec.md#setting-groups) for more details. Note that each setting group is also a full [Settings](ProjectSpec.md#settings) object, so you can reference other groups or define settings by config.

```yaml
settingGroups:
  app:
    DEVELOPMENT_TEAM: T45H45J
targets:
  App:
    settings:
      groups: [app]
```

### xcconfig files
The `project` and each `target` have a `configFiles` object that lets you reference `.xcconfig` files per configuration.

>This is good guide to xcconfig files [https://pewpewthespells.com/blog/xcconfig_guide](https://pewpewthespells.com/blog/xcconfig_guide.html)

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

### xcodebuild environment variables
You can also always override any build settings on CI when building by passing specific build settings to xcodebuild like so:

```sh
DEVELOPMENT_TEAM=XXXXXXXXX xcodebuild ...
```

# Dependencies

Each target can declare one or more dependencies. See [Dependency](ProjectSpec.md#dependency) in the ProjectSpec for more info about all the properties

### CocoaPods
Use your `Podfile` as normal. The pods themselves don't need to be referenced in the project spec. After you generate your project simply run `pod install` which will integrate with your project and create a workspace.

### Carthage
XcodeGen makes integrating Carthage dependencies super easy!

You simply reference them in each target that requires them and XcodeGen does the rest by automatically linking and embedding the carthage frameworks where necessary.

```yaml
targets:
  App:
    dependencies:
      - target: Framework
      - carthage: Kingfisher
  Framework:
    dependencies:
      - carthage: Alamofire
```

Some Carthage dependencies actually vend multiple frameworks. For example `github "ReactiveCocoa/ReactiveCocoa" ~> 8.0` vends 2 frameworks `ReactiveCocoa` and `ReactiveMapKit`.
By default these all have to be listed if you want to link and use them:

```yml
targets:
  App:
    dependencies:
      - carthage: ReactiveCocoa
      - carthage: ReactiveMapKit 
```

XcodeGen can look these up for you automatically! This can be enabled with a global `options.findCarthageFrameworks` or can be overriden for each Carthage dependency. Note that if this is enabled, the Carthage dependencies need to have already been built before XcodeGen is run. This is because XcodeGen loads `.version` files that Carthage writes in the `Carthage/Build` directory which lists the all the frameworks. The name you use must also be the name of the `.version` file Carthage writes to `Carthage/Build`. Be aware that in some cases this name can differ from the name of the repo in the Cartfile and even the framework name. If the `.version` file is not found or fails parsing, XcodeGen will fallback to the regular Framework lookup in the relevant Carthage directory.

```yml
options:
  findCarthageFrameworks: true
targets:
  App:
    dependencies:
      - carthage: ReactiveCocoa # will find ReactiveMapKit as well
      - carthage: OtherCarthageDependency
        findFrameworks: false # disables the global option
```

XcodeGen automatically creates the build phase that Carthage requires which lists all the files and runs `carthage copy-frameworks`. You can change the invocation of carthage to something different, for example if you are running it with [Mint](https://github.com/yonaskolb/mint). This is then prepended to ` copy frameworks`

```yaml
options:
  carthageExecutablePath: mint run Carthage/Carthage
```

By default XcodeGen looks for carthage frameworks in `Carthage/Build`. You can change this with the `carthageBuildPath` option

```yaml
options:
  carthageBuildPath: ../../Carthage/Build
```

### Swift Package
Swift Packages can be integrated by defining them at the project level and then referencing them in targets

```yaml
packages:
  Yams:
    url: https://github.com/jpsim/Yams
    from: 2.0.0
  SwiftPM:
    url: https://github.com/apple/swift-package-manager
    branch: swift-5.0-branch
  RxClient:
    path: ../RxClient
targets:
  App:
    dependencies:
      # by default the package product that is linked to is the same as the package name
      - package: Yams
      - package: SwiftPM
      - package: RxClient
      - package: SwiftPM
        product: SPMUtility # specify a specific product
```
If you want to check in the `Package.resolved` file so that everyone is on the same versions, you need to check in `ProjectName.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

> Note that Swift Packages don't work in projects with configurations other than `Debug` and `Release`. That limitation is tracked here bugs.swift.org/browse/SR-10927

Specified local packages get put into a `Packages` group in the root of the project by default. This can be changed with `options.localPackagesGroup`.

### SDK
System frameworks and libs can be linked by using the `sdk` dependency type. You can either specify frameworks or libs by using a `.framework`, `.tbd` or `dylib` filename, respectively

```yaml
targets:
  App:
    dependencies:
      - sdk: Contacts.framework
      - sdk: libc++.tbd
      - sdk: libz.dylib
```

### Framework
Individual frameworks can also be linked by specifying a path to them

```yamlå
targets:
  App:
    dependencies:
      - framework: Vendor/MyFramework.framework
```
