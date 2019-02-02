#!/bin/bash
set -e

carthage bootstrap --cache-builds
echo "
Building iOS app"
xcodebuild -quiet -project Project.xcodeproj -scheme "App_iOS Test" -configuration "Test Debug" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
echo "
Building macOS app"
xcodebuild -quiet -project Project.xcodeproj -scheme "App_macOS" -configuration "Test Debug" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
