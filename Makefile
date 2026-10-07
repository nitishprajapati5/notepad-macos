# ==============================================================================
# Notepad for macOS — Makefile (Simple & Lightweight like Windows Notepad)
# ==============================================================================

APP_NAME      = Notepad
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

$(BUNDLE_DIR): $(MACOS_DIR)/$(APP_NAME) $(CONTENTS_DIR)/Info.plist
	@echo "✅ Built $(BUNDLE_DIR)"

# Link Executable
$(MACOS_DIR)/$(APP_NAME): $(ALL_OBJS) | $(MACOS_DIR)
	@echo "🔗 Linking $(APP_NAME) (Universal: arm64 + x86_64)..."
	$(OBJCXX) $(ARCH_FLAGS) $(FRAMEWORKS) -stdlib=libc++ -fobjc-arc -o $@ $(ALL_OBJS)

# Bundle Info.plist and Scintilla resources
$(CONTENTS_DIR)/Info.plist: resources/Info.plist | $(CONTENTS_DIR) $(RESOURCES_DIR)
	cp $< $@
	@cp -f scintilla/cocoa/res/*.png $(RESOURCES_DIR)/ 2>/dev/null || true

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

clean:
	rm -rf build/
