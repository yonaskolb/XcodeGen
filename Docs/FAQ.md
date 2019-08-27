# Frequently asked questions
- [Can I still check in my project](#can-i-still-check-in-my-project)
- [Can I use CocoaPods](#can-i-use-cocoapods)
- [Can I use Crashlytics](#can-i-use-crashlytics)
- [How do I setup code signing](#how-do-i-setup-code-signing)

## Can I still check in my project
Absolutely. You will get the most out of XcodeGen by adding your project to your `.gitignore`, as this way you avoid merge conflicts. But you can also check it in as a halfway step.
>Note that you can run `xcodegen` as a step in your build process on CI.

## What happens when I switch branches
If files were added or removed in the new checkout you will most likely need to run `xcodegen` again so that your project will reference all your files. Unfortunately this is a manual step at the moment, but in the future this could be automated.

For now you can always add xcodegen as a git `post-checkout` hook.
 
## Can I use CocoaPods
Yes, simply generate your project and then run `pod install` which will integrate with your project and create a workspace.

## Can I use Crashlytics
Yes, but you need to use a little trick when using CocoaPods. Add this script in your `Podfile`:

```ruby:Podfile
// Your dependencies
pod 'Fabric'
pod 'Crashlytics'

script_phase :name => 'Run Fabric',
             :script => '"${PODS_ROOT}/Fabric/run"'
             :input_files => ['$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)']

```

This script will be added after `[CP] Embed Pods Frameworks.`

## How do I setup code signing

At the moment there are no special options for code signing in XcodeGen, and this must be configured via regular build settings. For code signing to work, you need to tell Xcode which development team to use. This requires setting the `DEVELOPMENT_TEAM` and possibly `CODE_SIGN_STYLE` build settings. See [Configuring build settings](Usage.md#configuring-build-settings) for how to do that
