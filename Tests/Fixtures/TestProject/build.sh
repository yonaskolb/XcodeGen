#!/bin/bash
set -e

echo "
⚙️ Building iOS app"
xcodebuild -quiet -workspace Workspace.xcworkspace -scheme "App_iOS Test" -configuration "Test Debug" -xcconfig fixtures.xcconfig
echo "✅ Successfully built iOS app"

echo "
⚙️ Building macOS app"
xcodebuild -quiet -workspace Workspace.xcworkspace -scheme "App_macOS" -configuration "Test Debug" -xcconfig fixtures.xcconfig
echo "✅ Successfully built macOS app"
