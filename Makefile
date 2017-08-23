TOOL_NAME = xcodegen
LIB_NAME = libCYaml.dylib

INSTALL_PATH = /usr/local/bin
LIB_PATH = /usr/local/lib
SHARE_PATH = /usr/local/share/xcodegen
BUILD_PATH = .build/release
CURRENT_PATH = $(PWD)

install:
	swift build -c release -Xlinker -rpath -Xlinker @executable_path -Xswiftc -static-stdlib
	install_name_tool -change $(CURRENT_PATH)/$(BUILD_PATH)/$(LIB_NAME) $(LIB_PATH)/$(LIB_NAME) $(BUILD_PATH)/$(TOOL_NAME)
	cp -f $(BUILD_PATH)/$(TOOL_NAME) $(INSTALL_PATH)/$(TOOL_NAME)
	cp $(BUILD_PATH)/$(LIB_NAME) $(LIB_PATH)/$(LIB_NAME)
	mkdir -p $(SHARE_PATH)
	cp -R $(CURRENT_PATH)/SettingPresets $(SHARE_PATH)/SettingPresets
uninstall:
	rm -f $(INSTALL_PATH)/$(TOOL_NAME)
