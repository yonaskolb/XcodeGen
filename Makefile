TOOL_NAME = XcodeGen
export EXECUTABLE_NAME = xcodegen
VERSION = 2.49.0

PREFIX = /usr/local
INSTALL_PATH = $(PREFIX)/bin/$(EXECUTABLE_NAME)
SHARE_PATH = $(PREFIX)/share/$(EXECUTABLE_NAME)
CURRENT_PATH = $(PWD)
REPO = https://github.com/yonaskolb/$(TOOL_NAME)
SWIFT_BUILD_FLAGS = --disable-sandbox -c release
ifeq ($(shell uname -s),Darwin)
	SWIFT_BUILD_FLAGS += --arch arm64 --arch x86_64
endif
BUILD_PATH = $(shell swift build $(SWIFT_BUILD_FLAGS) --show-bin-path)
EXECUTABLE_PATH = $(BUILD_PATH)/$(EXECUTABLE_NAME)

.PHONY: install build uninstall format_code release

install: build
	mkdir -p $(PREFIX)/bin
	cp -f $(EXECUTABLE_PATH) $(INSTALL_PATH)
	mkdir -p $(SHARE_PATH)
	cp -R $(CURRENT_PATH)/SettingPresets $(SHARE_PATH)/SettingPresets

build:
	swift build $(SWIFT_BUILD_FLAGS)

uninstall:
	rm -f $(INSTALL_PATH)
	rm -rf $(SHARE_PATH)

format_code:
	swiftformat .

release:
	sed -i '' 's|\(let version = Version("\)\(.*\)\(")\)|\1$(VERSION)\3|' Sources/XcodeGen/main.swift
	sed -i '' 's|\(.package(url: "https://github.com/yonaskolb/XcodeGen.git", from: "\)\(.*\)\(")\)|\1$(VERSION)\3|' README.md

	git add .
	git commit -m "Update to $(VERSION)"
	#git tag $(VERSION)

publish: archive
	echo "published $(VERSION)"

# ArtifactBundleGen looks for the universal binary in <build-folder>/apple/Products/Release,
# but newer Swift versions put it elsewhere (Swift 6.4 uses .build/out/Products/Release).
# Point the plugin at a folder that links to whatever path `swift build` reports.
ARTIFACT_BUNDLE_BUILD_FOLDER = .build/artifactbundle

archive: build
	./scripts/archive.sh "$(EXECUTABLE_PATH)"
	rm -rf $(ARTIFACT_BUNDLE_BUILD_FOLDER) $(EXECUTABLE_NAME).artifactbundle.zip
	mkdir -p $(ARTIFACT_BUNDLE_BUILD_FOLDER)/apple/Products
	ln -s "$(BUILD_PATH)" $(ARTIFACT_BUNDLE_BUILD_FOLDER)/apple/Products/Release
	swift package plugin --allow-writing-to-package-directory generate-artifact-bundle \
		--package-version $(VERSION) \
		--executable-name $(EXECUTABLE_NAME) \
		--build-config release \
		--build-folder $(ARTIFACT_BUNDLE_BUILD_FOLDER) \
		--include-resource-path LICENSE
	@unzip -l $(EXECUTABLE_NAME).artifactbundle.zip | grep -q "bin/$(EXECUTABLE_NAME)$$" \
		|| (echo "error: $(EXECUTABLE_NAME).artifactbundle.zip does not contain the $(EXECUTABLE_NAME) binary" && exit 1)
