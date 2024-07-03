# Frequently asked questions
- [Can I still check in my project](#can-i-still-check-in-my-project)
- [Can I use CocoaPods](#can-i-use-cocoapods)
- [Can I use Crashlytics](#can-i-use-crashlytics)
- [How do I setup code signing](#how-do-i-setup-code-signing)

## Can I still check in my project
Absolutely. You will get the most out of XcodeGen by adding your project to your `.gitignore`, as this way you avoid merge conflicts. But you can also check it in as a halfway step.
>Note that you can run `xcodegen` as a step in your build process on CI.

## What happens when I switch branches
If files were added or removed in the new checkout you will most likely need to run `xcodegen` again so that your project will reference all your files.

It's recommended to set up some [git hooks](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks) to automate the process:
- run `xcodegen generate --use-cache` on the following hooks. This will make sure the project is up to date when checking out, merging and rebasing
  - `post-checkout`
  - `post-rewrite`
  - `post-merge`
- run `xcodegen cache` on `pre-commit`. This will make sure that when switching branches the cache will be updated in case you made local changes, or are ammending a commit that added a new file.
 
## Can I use CocoaPods
Yes, you will just need to run `pod install` after the project is generated to integrate Cocoapods changes.

It's recommended to use a combination of `--use-cache` and the `postGenCommand` option which will only generate the project if required, and then only run `pod install` if the project has been regenerated.

## Can I use Crashlytics
Yes, but you need to use a little trick when using CocoaPods. Add this script in your `Podfile`:

```ruby:Podfile
// Your dependencies
pod 'Firebase/Crashlytics'

script_phase name: 'Run Firebase Crashlytics',
             shell_path: '/bin/sh',
             script: '"${PODS_ROOT}/FirebaseCrashlytics/run"',
             input_files: ['$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)']
```

This script will be added after `[CP] Embed Pods Frameworks.`

## How do I setup code signing

At the moment there are no special options for code signing in XcodeGen, and this must be configured via regular build settings. For code signing to work, you need to tell Xcode which development team to use. This requires setting the `DEVELOPMENT_TEAM` and possibly `CODE_SIGN_STYLE` build settings. See [Configuring build settings](Usage.md#configuring-build-settings) for how to do that
