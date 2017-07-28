INSTALL_PATH = /usr/local/bin/xcodegen
LIB_PATH = /usr/local/lib
BUILD_PATH = .build/release
CURRENT_PATH = $(PWD)

TOOL_NAME = XcodeGen
LIB_NAME = libCYaml.dylib

install:
	swift build -c release -Xlinker -rpath -Xlinker @executable_path -Xswiftc -static-stdlib
	install_name_tool -change $(CURRENT_PATH)/$(BUILD_PATH)/$(LIB_NAME) $(LIB_PATH)/$(LIB_NAME) $(BUILD_PATH)/$(TOOL_NAME)
	cp -f $(BUILD_PATH)/$(TOOL_NAME) $(INSTALL_PATH)
	cp $(BUILD_PATH)/$(LIB_NAME) $(LIB_PATH)/$(LIB_NAME)
uninstall:
	rm -f $(INSTALL_PATH)
