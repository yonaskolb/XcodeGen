TOOL_NAME = XcodeGen
export EXECUTABLE_NAME = xcodegen
VERSION = 2.15.0

PREFIX = /usr/local
INSTALL_PATH = $(PREFIX)/bin/$(EXECUTABLE_NAME)
SHARE_PATH = $(PREFIX)/share/$(EXECUTABLE_NAME)
CURRENT_PATH = $(PWD)
REPO = https://github.com/yonaskolb/$(TOOL_NAME)
RELEASE_TAR = $(REPO)/archive/$(VERSION).tar.gz
SHA = $(shell curl -L -s $(RELEASE_TAR) | shasum -a 256 | sed 's/ .*//')

.PHONY: install build uninstall format_code brew release

install: build
	mkdir -p $(PREFIX)/bin
	cp -f .build/release/$(EXECUTABLE_NAME) $(INSTALL_PATH)
	mkdir -p $(SHARE_PATH)
	cp -R $(CURRENT_PATH)/SettingPresets $(SHARE_PATH)/SettingPresets

build:
	swift build --disable-sandbox -c release

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

publish: archive brew
	echo "published $(VERSION)"

brew:
	brew update
	brew bump-formula-pr --url=$(RELEASE_TAR) XcodeGen

archive: build
	./scripts/archive.sh
