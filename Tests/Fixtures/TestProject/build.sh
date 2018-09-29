#!/bin/bash
set -e

carthage bootstrap --cache-builds
xcodebuild -project Project.xcodeproj -scheme "App_iOS Test" -configuration "Test Debug" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO | xcpretty
