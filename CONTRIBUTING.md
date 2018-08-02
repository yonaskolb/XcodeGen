# Contributing to XcodeGen

There are various ways to contribute to XcodeGen, and all are welcome and appreciated!

- [Bug Reports](#bug-reports)
- [Feature Requests](#feature-requests)
- [Answering Questions](#answering-questions)
- [Example Specs](#example-specs)
- [Documentation](#documentation)
- [Code](#code)

## Bug reports
Open issues about problems you may be encountering. When doing so please mention the version you're using `xcodegen --version`.

## Feature Requests
If you have a good idea for a feature or enhancement open an issue. 

## Answering Questions
Look through the open issues and answer any questions you can.

## Example specs
Submit your open source xcodegen spec to the [Examples](Docs/Examples.md) page.

## Documentation
Improve the documentation in the [Docs](Docs) directory.

## Code
You can submit your own code. This can be bug fixes or new features. If you're not sure what to work on check out the open [Issues](https://github.com/yonaskolb/XcodeGen/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc)

### Getting started
Make sure you have at least Xcode 9.2 installed.

First clone the repo:
```shell
git clone https://github.com/yonaskolb/XcodeGen.git
cd XcodeGen
make
```

To make editing easier you can generate the Xcode project using Swift PM:

```shell
swift package generate-xcodeproj
```

### Targets
- `ProjectSpec`: Project spec definitions, loading, parsing and validation
- `XcodeGen`: XcodeGen CLI
- `XcodeGenKit`: All the logic for generation
- `XcodeGenKitTests`: Generation tests

### Tests
Before submitting your PR run the tests to make sure they pass. This can be done either in Xcode or by running `swift test`.

As part of the tests there is a [TestProject](/Tests/Fixtures/TestProject) fixture that will be generated, and if the generated xcode project has any diff in it the test will fail. If the diff is a valid change, commit it as part of your changes.

> Note that sometimes having the `TestProject` open in Xcode will generate it's own diffs, so make sure to have it closed when running the tests.

If your change contains any new features or logic changes please add a unit test of your own to cover it. If it's a new feature, see if it can be integrated into the `TestProject` by adding any required files and then editing the [project spec](/Tests/Fixtures/TestProject/project.yml).

### Submitting your PR
Please give a small summary of what has changed. Also add any github issues links (`Resolves #100`).

Once your PR is created, please add a changelog entry to [CHANGELOG.md](/CHANGELOG.md) along with the PR number.
