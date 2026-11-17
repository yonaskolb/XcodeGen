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
  if diff <(echo "$pbxproj") <(echo "$xcproj") > "$work/diff"; then
    echo "✅  $description"
  else
    echo "❌  $description is different with project.xcproj"
    head -40 "$work/diff"
    failed=1
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

  list() {
    xcodebuild -list -json -project "$work/$1/$directory/$project" 2>/dev/null | normalize
  }
  pbxproj_list="$(list pbxproj)"
  compare "$directory/$project targets, configurations and schemes" "$pbxproj_list" "$(list xcproj)"

  configurations="$(echo "$pbxproj_list" | python3 -c 'import json, sys; print("\n".join(json.load(sys.stdin)["project"]["configurations"]))')"
  while read -r configuration; do
    settings() {
      xcodebuild -showBuildSettings -json -alltargets -skipPackageUpdates -configuration "$configuration" -project "$work/$1/$directory/$project" 2>/dev/null | normalize
    }
    compare "$directory/$project $configuration build settings" "$(settings pbxproj)" "$(settings xcproj)"
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
  # build both formats the same way, so that a failure can be attributed to the project file format or not
  for format in pbxproj xcproj; do
    echo "⚙️  Building TestProject from project.$format"
    (cd "$work/$format/TestProject" && ./build.sh)
    echo "✅  Built TestProject from project.$format"
  done
fi

exit $failed
