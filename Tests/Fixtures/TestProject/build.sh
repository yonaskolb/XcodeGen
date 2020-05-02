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

echo "
⚙️ Building iOS app"
xcodebuild -quiet -workspace Workspace.xcworkspace -scheme "App_iOS Test" -configuration "Test Debug" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"
echo "✅ Successfully built iOS app"

echo "
⚙️ Building macOS app"
xcodebuild -quiet -workspace Workspace.xcworkspace -scheme "App_macOS" -configuration "Test Debug" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"
echo "✅ Successfully built macOS app"
