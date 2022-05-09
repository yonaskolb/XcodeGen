#!/bin/bash
set -e

XCODE_VERSION=$(/usr/libexec/PlistBuddy -c "Print :DTXcode" "$(xcode-select -p)/../Info.plist")

CARTHAGE_DYNAMIC_FRAMEWORKS=(Result)
CARTHAGE_STATIC_FRAMEWORKS=(SwiftyJSON swift-nonempty)

XCODE_XCCONFIG_FILE="$PWD/carthage_dynamic.xcconfig" \
    carthage bootstrap $CARTHAGE_DYNAMIC_FRAMEWORKS --cache-builds

XCODE_XCCONFIG_FILE="$PWD/carthage_static.xcconfig" \
    carthage bootstrap $CARTHAGE_STATIC_FRAMEWORKS --cache-builds

echo "
⚙️ Building iOS app"
xcodebuild -quiet -workspace Workspace.xcworkspace -scheme "App_iOS Test" -configuration "Test Debug" -xcconfig fixtures.xcconfig
echo "✅ Successfully built iOS app"

echo "
⚙️ Building macOS app"
xcodebuild -quiet -workspace Workspace.xcworkspace -scheme "App_macOS" -configuration "Test Debug" -xcconfig fixtures.xcconfig
echo "✅ Successfully built macOS app"
