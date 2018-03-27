# Frequently asked questions

- [How do I setup code signing](#how-do-i-setup-code-signing)

## How do I setup code signing

For code signing to work, you need to tell Xcode wich development team to use. This can be done in one of several way:

#### By setting the `DEVELOPMENT_TEAM` in the target's settings

Simply specify your development team id in your `project.yml` file, like so:

```yml
# ...
targets:
  MyTarget:
    # ...
    settings:
      DEVELOPMENT_TEAM: XXXXXXXXX
```

#### By passing `DEVELOPMENT_TEAM` as an env variable

You can also pass `DEVELOPMENT_TEAM` as an environemntal variable to `xcodebuild`, like so:

```sh
DEVELOPMENT_TEAM=XXXXXXXXX xcodebuild ...
```

#### By using an `.xcconfig` file:

The development team can also be read from `.xcconfig` files, this allows you to specify different teams for different build configurations. Start by creating an `.xcconfig` file with the value:

```text
DEVELOPMENT_TEAM = XXXXXXXXX
```

Then reference the `.xcconfig` file in your `project.yml` specification:

```yml
# ...
targets:
  MyTarget:
    # ...
    configFiles:
      Debug: config_files/debug.xcconfig
      Release: config_files/release.xcconfig
```
