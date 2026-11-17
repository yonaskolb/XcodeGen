#!/bin/bash
# Generates the fixtures in both project file formats and checks that Xcode sees the same projects in both.
# Requires Xcode 27.2 or later. Pass --build to also build the TestProject fixture from its project.xcproj.
set -e

if ! xcodebuild -version | head -1 | awk '{ split($2, v, "."); exit !(v[1] > 27 || (v[1] == 27 && v[2] >= 2)) }'; then
  echo "⚠️  Skipping, comparing project file formats requires Xcode 27.2 or later"
  exit 0
fi

swift build
xcodegen="$(swift build --show-bin-path)/xcodegen"
work="$(cd -P "$(mktemp -d)" && pwd)"
trap 'rm -rf "$work"' EXIT

specs=(
  TestProject/AnotherProject/project.yml
  TestProject/project.yml
  CarthageProject/project.yml
  SPM/project.yml
  XCProjProject/project.yml
)

for format in pbxproj xcproj; do
  cp -R Tests/Fixtures "$work/$format"
  find "$work/$format" -name project.xcproj -delete
  for spec in "${specs[@]}"; do
    directory="$work/$format/$(dirname "$spec")"
    # generate both formats with the same project format, so the file format is the only difference
    cat > "$directory/format.yml" <<EOF
include: [$(basename "$spec")]
options:
  projectFormat: xcode27_0
  projectFileFormat: $format
EOF
    (cd "$directory" && "$xcodegen" generate --quiet --spec format.yml)
  done
done

normalize() {
  # Xcode reports paths both with and without the /private prefix of the temporary directory
  sed -E "s#(/private)?${work#/private}/(pbxproj|xcproj)#ROOT#g"
}

failed=0
compare() {
  local description="$1" pbxproj="$2" xcproj="$3"
  if diff "$pbxproj" "$xcproj" > "$work/diff"; then
    echo "✅  $description"
  else
    echo "❌  $description is different with project.xcproj"
    head -40 "$work/diff"
    failed=1
  fi
}

# Saves the normalized output of xcodebuild to a file. Fails when xcodebuild fails or prints nothing,
# so that projects Xcode can't read in both formats aren't reported as the same.
xcodebuild_output() {
  local file="$1"
  shift
  if xcodebuild "$@" > "$file" 2> "$work/xcodebuild.log" && [ -s "$file" ]; then
    normalize < "$file" > "$file.normalized"
    mv "$file.normalized" "$file"
  else
    echo "❌  xcodebuild $* failed"
    tail -20 "$work/xcodebuild.log"
    failed=1
    return 1
  fi
}

for spec in "${specs[@]}"; do
  directory="$(dirname "$spec")"
  project="$(cd "$work/pbxproj/$directory" && ls -d *.xcodeproj)"
  if [ -e "$work/xcproj/$directory/$project/project.pbxproj" ] || [ ! -e "$work/xcproj/$directory/$project/project.xcproj" ]; then
    echo "❌  $directory/$project doesn't contain only a project.xcproj"
    failed=1
    continue
  fi

  for format in pbxproj xcproj; do
    xcodebuild_output "$work/$format.list" -list -json -project "$work/$format/$directory/$project" || continue 2
  done
  compare "$directory/$project targets, configurations and schemes" "$work/pbxproj.list" "$work/xcproj.list"

  configurations="$(python3 -c 'import json, sys; print("\n".join(json.load(sys.stdin)["project"]["configurations"]))' < "$work/pbxproj.list")"
  while read -r configuration; do
    for format in pbxproj xcproj; do
      xcodebuild_output "$work/$format.settings" -showBuildSettings -json -alltargets -skipPackageUpdates -configuration "$configuration" -project "$work/$format/$directory/$project" || continue 2
    done
    compare "$directory/$project $configuration build settings" "$work/pbxproj.settings" "$work/xcproj.settings"
  done <<< "$configurations"

  if diff -r "$work/pbxproj/$directory/$project/xcshareddata" "$work/xcproj/$directory/$project/xcshareddata" > "$work/diff"; then
    echo "✅  $directory/$project shared data"
  else
    echo "❌  $directory/$project shared data is different with project.xcproj"
    head -40 "$work/diff"
    failed=1
  fi
done

if [ "$1" == "--build" ]; then
  # the TestProject is already built from its project.pbxproj by scripts/build-fixtures.sh
  echo "⚙️  Building TestProject from project.xcproj"
  (cd "$work/xcproj/TestProject" && ./build.sh)
  echo "✅  Built TestProject from project.xcproj"
fi

exit $failed
