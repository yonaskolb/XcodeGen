# Frequently asked questions
- [Can I still check in my project](#can-i-still-check-in-my-project)
- [Can I use Cocoapods](#can-i-use-cocoapods)
- [How do I setup code signing](#how-do-i-setup-code-signing)

## Can I still check in my project
Absolutely. You will get the most out of XcodeGen by adding your project to your `.gitignore`, as this way you avoid merge conflicts. But you can also check it in as a halfway step.
>Note that you can run `xcodegen` as a step in your build process on CI.

## What happens when I switch branches
If files were added or removed in the new checkout you will most likely need to run `xcodegen` again so that your project will reference all your files. Unfortunately this is a manual step at the moment, but in the future this could be automated.

For now you can always add xcodegen as a git `post-checkout` hook.
 
## Can I use Cocoapods
Yes, simply generate your project and then run `pod install` which will integrate with your project and create a workspace.

## How do I setup code signing

At the moment there are no special options for code signing in XcodeGen, and this must be configured via regular build settings. For code signing to work, you need to tell Xcode which development team to use. This requires setting the `DEVELOPMENT_TEAM` and possibly `CODE_SIGN_STYLE` build settings. See [Configuring build settings](Usage#configuring-build-settings) for how to do that
