#!/bin/bash
set -e

CARTHAGE_DYNAMIC_FRAMEWORKS=(Result)
CARTHAGE_STATIC_FRAMEWORKS=(SwiftyJSON swift-nonempty)

carthage bootstrap $CARTHAGE_DYNAMIC_FRAMEWORKS --cache-builds

# Prepare xcconfig for static bootstrapping
STATIC_CONFIG=$(mktemp -d)/static.xcconfig
echo "MACH_O_TYPE = staticlib" > $STATIC_CONFIG

XCODE_XCCONFIG_FILE=$STATIC_CONFIG \
    carthage bootstrap $CARTHAGE_STATIC_FRAMEWORKS --cache-builds

XCODE_VERSION=$(/usr/libexec/PlistBuddy -c "Print :DTXcode" "$(xcode-select -p)/../Info.plist")

echo "
⚙️ Building iOS app"
xcodebuild -quiet -workspace Workspace.xcworkspace -scheme "App_iOS Test" -configuration "Test Debug" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"
echo "✅ Successfully built iOS app"

if [[ "$XCODE_VERSION" == 12* ]]; then
    echo "
    ⚙️ Building iOS app (Xcode 12+)"
    xcodebuild -quiet -project ProjectXcode12.xcodeproj -scheme "App_iOS_With_Clip Test" -configuration "Test Debug" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"
    echo "✅ Successfully built iOS app (Xcode 12+)"
fi

echo "
⚙️ Building macOS app"
xcodebuild -quiet -workspace Workspace.xcworkspace -scheme "App_macOS" -configuration "Test Debug" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"
echo "✅ Successfully built macOS app"
