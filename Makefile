TOOL_NAME = XcodeGen
export EXECUTABLE_NAME = xcodegen
VERSION = 1.10.3

PREFIX = /usr/local
INSTALL_PATH = $(PREFIX)/bin/$(EXECUTABLE_NAME)
SHARE_PATH = $(PREFIX)/share/$(EXECUTABLE_NAME)
CURRENT_PATH = $(PWD)
REPO = https://github.com/yonaskolb/$(TOOL_NAME)
RELEASE_TAR = $(REPO)/archive/$(VERSION).tar.gz
SHA = $(shell curl -L -s $(RELEASE_TAR) | shasum -a 256 | sed 's/ .*//')

.PHONY: install build uninstall format_code update_brew release

install: build
	mkdir -p $(PREFIX)/bin
	cp -f .build/release/$(EXECUTABLE_NAME) $(INSTALL_PATH)
	mkdir -p $(SHARE_PATH)
	cp -R $(CURRENT_PATH)/SettingPresets $(SHARE_PATH)/SettingPresets

build:
	swift build --disable-sandbox -c release -Xswiftc -static-stdlib

uninstall:
	rm -f $(INSTALL_PATH)
	rm -rf $(SHARE_PATH)

format_code:
	swiftformat Tests --wraparguments beforefirst --stripunusedargs closure-only --header strip --disable blankLinesAtStartOfScope
	swiftformat Sources --wraparguments beforefirst --stripunusedargs closure-only --header strip --disable blankLinesAtStartOfScope

update_brew:
	sed -i '' 's|\(url ".*/archive/\)\(.*\)\(.tar\)|\1$(VERSION)\3|' Formula/xcodegen.rb
	sed -i '' 's|\(sha256 "\)\(.*\)\("\)|\1$(SHA)\3|' Formula/xcodegen.rb

	git add .
	git commit -m "Update brew to $(VERSION)"

release: format_code
	sed -i '' 's|\(let version = try Version("\)\(.*\)\(")\)|\1$(VERSION)\3|' Sources/XcodeGen/main.swift

	git add .
	git commit -m "Update to $(VERSION)"
	git tag $(VERSION)

publish: archive bump_brew
	echo "published $(VERSION)"

bump_brew:
	brew bump-formula-pr --url=$(RELEASE_TAR) Mint

archive: build
	./scripts/archive.sh
