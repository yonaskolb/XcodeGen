TOOL_NAME = xcodegen

INSTALL_PATH = /usr/local/bin/$(TOOL_NAME)
SHARE_PATH = /usr/local/share/$(TOOL_NAME)
BUILD_PATH = .build/release/$(TOOL_NAME)
CURRENT_PATH = $(PWD)

install:
	swift build -c release -Xswiftc -static-stdlib
	cp -f $(BUILD_PATH) $(INSTALL_PATH)
	mkdir -p $(SHARE_PATH)
	cp -R $(CURRENT_PATH)/SettingPresets $(SHARE_PATH)/SettingPresets
uninstall:
	rm -f $(INSTALL_PATH)
