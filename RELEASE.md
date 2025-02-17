# The release process for XcodeGen

1. Make sure `CHANGELOG.md` is up to date:
   - All relevant entries have been added with the PR link and author
   - The new version number is added at the top after `Master`
1. Update the version at the top of `Makefile`
1. Run `make release`
1. Push commit and tag to github
1. Create release from tag on GitHub using the version number and relevant changelog contents
1. Run `make archive` and upload `xcodegen.zip` and `xcodegen.artifactbundle.zip` to the github release
