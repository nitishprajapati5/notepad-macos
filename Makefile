# ==============================================================================
# Notepad for macOS — Makefile (Simple & Lightweight like Windows Notepad)
# ==============================================================================

APP_NAME      = Notepad
VERSION       ?= 1.0.0
BUILD_NUMBER  ?= 1

BUNDLE_DIR    = build/$(APP_NAME).app
CONTENTS_DIR  = $(BUNDLE_DIR)/Contents
MACOS_DIR     = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

CXX           = clang++
CC            = clang
OBJCXX        = clang++

# Universal Binary Architectures (Apple Silicon arm64 + Intel x86_64)
ARCH_FLAGS    = -arch arm64 -arch x86_64 -mmacosx-version-min=11.0

# Compiler Flags
CXXFLAGS      = $(ARCH_FLAGS) -std=c++17 -stdlib=libc++ -O2 -DNDEBUG -DSCI_NAMESPACE \
                -fvisibility=hidden -fvisibility-inlines-hidden \
                -Wno-deprecated-declarations -Wno-unused-variable
OBJCXXFLAGS   = $(ARCH_FLAGS) -std=c++17 -stdlib=libc++ -ObjC++ -fobjc-arc -O2 -DNDEBUG -DSCI_NAMESPACE \
                -Wno-deprecated-declarations -Wno-unused-variable
CFLAGS        = $(ARCH_FLAGS) -O2

# Frameworks
FRAMEWORKS    = -framework Cocoa -framework QuartzCore

# Include Paths (scintilla/, src/)
SCINTILLA_INC = -Iscintilla/include \
                -Iscintilla/src \
                -Iscintilla/cocoa
APP_INC       = -Isrc

INCLUDES      = $(SCINTILLA_INC) $(APP_INC)

# Build Directories
OBJ_DIR       = build/obj
SCI_OBJ_DIR   = $(OBJ_DIR)/scintilla
COCOA_OBJ_DIR = $(OBJ_DIR)/cocoa
APP_OBJ_DIR   = $(OBJ_DIR)/src

# ==============================================================================
# Sources
# ==============================================================================
SCI_SRCS    = $(wildcard scintilla/src/*.cxx)
SCI_OBJS    = $(patsubst scintilla/src/%.cxx,$(SCI_OBJ_DIR)/%.o,$(SCI_SRCS))

COCOA_SRCS  = scintilla/cocoa/PlatCocoa.mm \
              scintilla/cocoa/ScintillaCocoa.mm \
              scintilla/cocoa/ScintillaView.mm \
              scintilla/cocoa/InfoBar.mm
COCOA_OBJS  = $(patsubst scintilla/cocoa/%.mm,$(COCOA_OBJ_DIR)/%.o,$(COCOA_SRCS))

APP_SRCS    = $(wildcard src/*.mm)
APP_OBJS    = $(patsubst src/%.mm,$(APP_OBJ_DIR)/%.o,$(APP_SRCS))

ALL_OBJS    = $(SCI_OBJS) $(COCOA_OBJS) $(APP_OBJS)

# ==============================================================================
# Targets
# ==============================================================================
.PHONY: all clean run

all: $(BUNDLE_DIR)

$(BUNDLE_DIR): $(MACOS_DIR)/$(APP_NAME) $(CONTENTS_DIR)/Info.plist $(RESOURCES_DIR)/AppIcon.icns
	@echo "✅ Built $(BUNDLE_DIR)"

# Link Executable
$(MACOS_DIR)/$(APP_NAME): $(ALL_OBJS) | $(MACOS_DIR)
	@echo "🔗 Linking $(APP_NAME) (Universal: arm64 + x86_64)..."
	$(OBJCXX) $(ARCH_FLAGS) $(FRAMEWORKS) -stdlib=libc++ -fobjc-arc -o $@ $(ALL_OBJS)

# Bundle Info.plist and resources
$(CONTENTS_DIR)/Info.plist: resources/Info.plist | $(CONTENTS_DIR) $(RESOURCES_DIR)
	@cp $< $@
	@plutil -replace CFBundleShortVersionString -string "$(VERSION)" $@
	@plutil -replace CFBundleVersion -string "$(BUILD_NUMBER)" $@
	@cp -f scintilla/cocoa/res/*.png $(RESOURCES_DIR)/ 2>/dev/null || true
	@cp -f resources/*.icns $(RESOURCES_DIR)/ 2>/dev/null || true

$(RESOURCES_DIR)/AppIcon.icns: resources/AppIcon.icns | $(RESOURCES_DIR)
	@cp -f $< $@

# ==============================================================================
# Compilation Rules
# ==============================================================================

# Scintilla C++ sources
$(SCI_OBJ_DIR)/%.o: scintilla/src/%.cxx | $(SCI_OBJ_DIR)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

# Scintilla Cocoa sources
$(COCOA_OBJ_DIR)/%.o: scintilla/cocoa/%.mm | $(COCOA_OBJ_DIR)
	$(OBJCXX) $(OBJCXXFLAGS) $(INCLUDES) -c $< -o $@

# App sources in src/
$(APP_OBJ_DIR)/%.o: src/%.mm | $(APP_OBJ_DIR)
	@mkdir -p $(dir $@)
	$(OBJCXX) $(OBJCXXFLAGS) $(INCLUDES) -c $< -o $@

# ==============================================================================
# Directory Setup
# ==============================================================================
$(SCI_OBJ_DIR) $(COCOA_OBJ_DIR) $(APP_OBJ_DIR) $(MACOS_DIR) $(CONTENTS_DIR) $(RESOURCES_DIR):
	mkdir -p $@

# ==============================================================================
# Convenience Rules
# ==============================================================================
run: all
	open $(BUNDLE_DIR)

CLANG_FORMAT ?= $(shell xcrun -f clang-format 2>/dev/null || which clang-format 2>/dev/null || echo "/Library/Developer/CommandLineTools/usr/bin/clang-format")

format:
	@echo "Formatting sources in src/..."
	@$(CLANG_FORMAT) -i -style=file src/*.h src/*.mm
	@echo "✅ Formatted successfully"

check-format:
	@echo "Checking formatting of sources in src/..."
	@$(CLANG_FORMAT) --dry-run --Werror -style=file src/*.h src/*.mm
	@echo "✅ Code formatting check passed"

package: all
	@echo "📦 Packaging $(APP_NAME) v$(VERSION) (Build $(BUILD_NUMBER)) for macOS..."
	@rm -rf build/dist build/Notepad-macOS* build/checksums.txt
	@mkdir -p build/dist/Notepad
	@cp -R $(BUNDLE_DIR) build/dist/Notepad/
	@ln -s /Applications build/dist/Notepad/Applications
	@hdiutil create -volname "Notepad $(VERSION)" -srcfolder build/dist/Notepad -ov -format UDZO build/Notepad-macOS-v$(VERSION).dmg
	@cd build && zip -q -r -y Notepad-macOS-v$(VERSION)-Universal.zip $(APP_NAME).app
	@cp -f build/Notepad-macOS-v$(VERSION).dmg build/Notepad-macOS.dmg
	@cp -f build/Notepad-macOS-v$(VERSION)-Universal.zip build/Notepad-macOS-Universal.zip
	@shasum -a 256 build/Notepad-macOS-v$(VERSION).dmg build/Notepad-macOS-v$(VERSION)-Universal.zip build/Notepad-macOS.dmg build/Notepad-macOS-Universal.zip > build/checksums.txt
	@echo "✅ Packaged: build/Notepad-macOS-v$(VERSION).dmg and build/Notepad-macOS-v$(VERSION)-Universal.zip"

clean:
	rm -rf build/ build-cmake/

