TOOL_NAME = XcodeGen
VERSION = 1.1.0

PREFIX = /usr/local
INSTALL_PATH = $(PREFIX)/bin/$(TOOL_NAME)
SHARE_PATH = $(PREFIX)/share/$(TOOL_NAME)
BUILD_PATH = .build/release/$(TOOL_NAME)
CURRENT_PATH = $(PWD)
TAR_FILENAME = $(TOOL_NAME)-$(VERSION).tar.gz

install: build
	mkdir -p $(PREFIX)/bin
	cp -f $(BUILD_PATH) $(INSTALL_PATH)
	mkdir -p $(SHARE_PATH)
	cp -R $(CURRENT_PATH)/SettingPresets $(SHARE_PATH)/SettingPresets

build:
	swift build --disable-sandbox -c release -Xswiftc -static-stdlib

uninstall:
	rm -f $(INSTALL_PATH)
	rm -rf $(SHARE_PATH)

get_sha:
	wget https://github.com/yonaskolb/$(TOOL_NAME)/archive/$(VERSION).tar.gz -O $(TAR_FILENAME)
	shasum -a 256 $(TAR_FILENAME)
	rm $(TAR_FILENAME)
