#import "PreferencesWindowController.h"
#import "PreferencesManager.h"

static NSString *const kToolbarEditor     = @"ToolbarEditor";
static NSString *const kToolbarAppearance = @"ToolbarAppearance";
static NSString *const kToolbarEncoding   = @"ToolbarEncoding";
static NSString *const kToolbarAdvanced   = @"ToolbarAdvanced";

@interface PreferencesWindowController ()

@property (nonatomic, strong) NSToolbar *toolbar;
@property (nonatomic, strong) NSView *containerView;

// Editor Controls
@property (nonatomic, strong) NSView *editorView;
@property (nonatomic, strong) NSTextField *fontDisplayLabel;
@property (nonatomic, strong) NSPopUpButton *tabWidthPopup;
@property (nonatomic, strong) NSButton *useSpacesCheckbox;
@property (nonatomic, strong) NSButton *wordWrapCheckbox;

// Appearance Controls
@property (nonatomic, strong) NSView *appearanceView;
@property (nonatomic, strong) NSSegmentedControl *themeSegmentedControl;
@property (nonatomic, strong) NSButton *showLineNumbersCheckbox;
@property (nonatomic, strong) NSButton *showStatusBarCheckbox;

// Encoding Controls
@property (nonatomic, strong) NSView *encodingView;
@property (nonatomic, strong) NSPopUpButton *encodingPopup;

// Advanced Controls
@property (nonatomic, strong) NSView *advancedView;
@property (nonatomic, strong) NSButton *backupOnSaveCheckbox;
@property (nonatomic, strong) NSButton *autoIndentCheckbox;

@property (nonatomic, copy) NSString *currentTabIdentifier;

@end

@implementation PreferencesWindowController

+ (instancetype)sharedPreferencesWindowController {
    static PreferencesWindowController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PreferencesWindowController alloc] init];
    });
    return instance;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 480, 260);
    NSWindowStyleMask style = NSWindowStyleMaskTitled |
                              NSWindowStyleMaskClosable;

    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Preferences";
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        window.delegate = self;
        [self setupUI];
        [self reloadPreferencesValues];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePreferencesChanged:)
                                                     name:NPPreferencesDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI Setup

- (void)setupUI {
    NSWindow *win = self.window;

    // Toolbar setup
    self.toolbar = [[NSToolbar alloc] initWithIdentifier:@"PreferencesToolbar"];
    self.toolbar.delegate = self;
    self.toolbar.allowsUserCustomization = NO;
    self.toolbar.autosavesConfiguration = NO;
    self.toolbar.displayMode = NSToolbarDisplayModeIconAndLabel;
    win.toolbar = self.toolbar;

    // Main container view
    self.containerView = [[NSView alloc] initWithFrame:win.contentView.bounds];
    self.containerView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [win.contentView addSubview:self.containerView];

    // Build the 4 views
    [self buildEditorView];
    [self buildAppearanceView];
    [self buildEncodingView];
    [self buildAdvancedView];

    // Select initial tab
    [self switchToTab:kToolbarEditor animate:NO];
    self.toolbar.selectedItemIdentifier = kToolbarEditor;
}

#pragma mark - Tab Views Construction

- (void)buildEditorView {
    NSRect bounds = NSMakeRect(0, 0, 480, 220);
    self.editorView = [[NSView alloc] initWithFrame:bounds];

    // Font Label & Preview
    NSTextField *fontTitle = [self makeLabel:@"Font:" bold:YES];
    fontTitle.frame = NSMakeRect(30, 160, 100, 22);
    [self.editorView addSubview:fontTitle];

    self.fontDisplayLabel = [self makeLabel:@"Menlo 12 pt" bold:NO];
    self.fontDisplayLabel.frame = NSMakeRect(140, 160, 190, 22);
    [self.editorView addSubview:self.fontDisplayLabel];

    NSButton *changeFontBtn = [NSButton buttonWithTitle:@"Select…" target:self action:@selector(changeFontClicked:)];
    changeFontBtn.bezelStyle = NSBezelStyleRounded;
    changeFontBtn.frame = NSMakeRect(340, 154, 100, 30);
    [self.editorView addSubview:changeFontBtn];

    // Tab Width
    NSTextField *tabTitle = [self makeLabel:@"Tab width:" bold:YES];
    tabTitle.frame = NSMakeRect(30, 115, 100, 22);
    [self.editorView addSubview:tabTitle];

    self.tabWidthPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(140, 112, 120, 26) pullsDown:NO];
    [self.tabWidthPopup addItemWithTitle:@"2 spaces"];
    [self.tabWidthPopup lastItem].tag = 2;
    [self.tabWidthPopup addItemWithTitle:@"4 spaces"];
    [self.tabWidthPopup lastItem].tag = 4;
    [self.tabWidthPopup addItemWithTitle:@"8 spaces"];
    [self.tabWidthPopup lastItem].tag = 8;
    self.tabWidthPopup.target = self;
    self.tabWidthPopup.action = @selector(tabWidthChanged:);
    [self.editorView addSubview:self.tabWidthPopup];

    // Checkboxes
    self.useSpacesCheckbox = [NSButton checkboxWithTitle:@"Insert spaces instead of tabs"
                                                  target:self
                                                  action:@selector(useSpacesToggled:)];
    self.useSpacesCheckbox.frame = NSMakeRect(140, 72, 300, 24);
    [self.editorView addSubview:self.useSpacesCheckbox];

    self.wordWrapCheckbox = [NSButton checkboxWithTitle:@"Wrap long lines by default"
                                                 target:self
                                                 action:@selector(wordWrapToggled:)];
    self.wordWrapCheckbox.frame = NSMakeRect(140, 38, 300, 24);
    [self.editorView addSubview:self.wordWrapCheckbox];
}

- (void)buildAppearanceView {
    NSRect bounds = NSMakeRect(0, 0, 480, 200);
    self.appearanceView = [[NSView alloc] initWithFrame:bounds];

    // Theme Mode
    NSTextField *themeTitle = [self makeLabel:@"Theme:" bold:YES];
    themeTitle.frame = NSMakeRect(30, 140, 100, 22);
    [self.appearanceView addSubview:themeTitle];

    self.themeSegmentedControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Light", @"Dark", @"System"]
                                                                   trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                         target:self
                                                                         action:@selector(themeChanged:)];
    self.themeSegmentedControl.frame = NSMakeRect(140, 137, 260, 28);
    [self.appearanceView addSubview:self.themeSegmentedControl];

    // Line Numbers Checkbox
    self.showLineNumbersCheckbox = [NSButton checkboxWithTitle:@"Show line numbers gutter"
                                                        target:self
                                                        action:@selector(lineNumbersToggled:)];
    self.showLineNumbersCheckbox.frame = NSMakeRect(140, 85, 300, 24);
    [self.appearanceView addSubview:self.showLineNumbersCheckbox];

    // Status Bar Checkbox
    self.showStatusBarCheckbox = [NSButton checkboxWithTitle:@"Show status bar"
                                                      target:self
                                                      action:@selector(statusBarToggled:)];
    self.showStatusBarCheckbox.frame = NSMakeRect(140, 48, 300, 24);
    [self.appearanceView addSubview:self.showStatusBarCheckbox];
}

- (void)buildEncodingView {
    NSRect bounds = NSMakeRect(0, 0, 480, 200);
    self.encodingView = [[NSView alloc] initWithFrame:bounds];

    NSTextField *encTitle = [self makeLabel:@"Default encoding:" bold:YES];
    encTitle.frame = NSMakeRect(30, 135, 120, 22);
    [self.encodingView addSubview:encTitle];

    self.encodingPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(160, 132, 260, 26) pullsDown:NO];
    for (NSDictionary *item in [PreferencesManager supportedEncodings]) {
        [self.encodingPopup addItemWithTitle:item[@"name"]];
        [self.encodingPopup lastItem].tag = [item[@"encoding"] integerValue];
    }
    self.encodingPopup.target = self;
    self.encodingPopup.action = @selector(encodingChanged:);
    [self.encodingView addSubview:self.encodingPopup];

    NSTextField *infoNote = [self makeLabel:@"Applied to newly created documents and used as fallback when opening files without a Byte Order Mark (BOM)." bold:NO];
    infoNote.textColor = [NSColor secondaryLabelColor];
    infoNote.font = [NSFont systemFontOfSize:11.0];
    infoNote.frame = NSMakeRect(160, 60, 280, 60);
    [self.encodingView addSubview:infoNote];
}

- (void)buildAdvancedView {
    NSRect bounds = NSMakeRect(0, 0, 480, 180);
    self.advancedView = [[NSView alloc] initWithFrame:bounds];

    // Backup On Save
    self.backupOnSaveCheckbox = [NSButton checkboxWithTitle:@"Create backup file (.bak) before saving"
                                                     target:self
                                                     action:@selector(backupOnSaveToggled:)];
    self.backupOnSaveCheckbox.frame = NSMakeRect(50, 115, 380, 24);
    [self.advancedView addSubview:self.backupOnSaveCheckbox];

    NSTextField *backupNote = [self makeLabel:@"Saves an unmodified copy of the file with a .bak extension prior to overwriting." bold:NO];
    backupNote.textColor = [NSColor secondaryLabelColor];
    backupNote.font = [NSFont systemFontOfSize:11.0];
    backupNote.frame = NSMakeRect(74, 82, 350, 32);
    [self.advancedView addSubview:backupNote];

    // Auto-indent
    self.autoIndentCheckbox = [NSButton checkboxWithTitle:@"Automatically indent new lines"
                                                   target:self
                                                   action:@selector(autoIndentToggled:)];
    self.autoIndentCheckbox.frame = NSMakeRect(50, 48, 380, 24);
    [self.advancedView addSubview:self.autoIndentCheckbox];
}

#pragma mark - Helper

- (NSTextField *)makeLabel:(NSString *)text bold:(BOOL)bold {
    NSTextField *label = [NSTextField labelWithString:text];
    label.editable = NO;
    label.selectable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    if (bold) {
        label.font = [NSFont boldSystemFontOfSize:13.0];
    } else {
        label.font = [NSFont systemFontOfSize:13.0];
    }
    return label;
}

#pragma mark - Tab Switching

- (void)switchToTab:(NSString *)identifier animate:(BOOL)animate {
    _currentTabIdentifier = [identifier copy];

    NSView *targetView = nil;
    if ([identifier isEqualToString:kToolbarEditor]) {
        targetView = self.editorView;
    } else if ([identifier isEqualToString:kToolbarAppearance]) {
        targetView = self.appearanceView;
    } else if ([identifier isEqualToString:kToolbarEncoding]) {
        targetView = self.encodingView;
    } else if ([identifier isEqualToString:kToolbarAdvanced]) {
        targetView = self.advancedView;
    }

    if (!targetView) return;

    // Adjust window frame to target view height
    NSRect contentFrame = self.window.contentView.frame;
    contentFrame.size.height = targetView.frame.size.height;
    contentFrame.size.width = targetView.frame.size.width;

    NSRect newWinFrame = [self.window frameRectForContentRect:contentFrame];
    newWinFrame.origin.x = self.window.frame.origin.x;
    newWinFrame.origin.y = self.window.frame.origin.y + (self.window.frame.size.height - newWinFrame.size.height);

    [[self.containerView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    targetView.frame = self.containerView.bounds;
    targetView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.containerView addSubview:targetView];

    [self.window setFrame:newWinFrame display:YES animate:animate];
}

#pragma mark - NSToolbarDelegate

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[kToolbarEditor, kToolbarAppearance, kToolbarEncoding, kToolbarAdvanced];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[kToolbarEditor, kToolbarAppearance, kToolbarEncoding, kToolbarAdvanced];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
    return @[kToolbarEditor, kToolbarAppearance, kToolbarEncoding, kToolbarAdvanced];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag {
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    item.target = self;
    item.action = @selector(toolbarItemClicked:);

    if ([itemIdentifier isEqualToString:kToolbarEditor]) {
        item.label = @"Editor";
        if (@available(macOS 11.0, *)) {
            item.image = [NSImage imageWithSystemSymbolName:@"square.and.pencil" accessibilityDescription:@"Editor"];
        } else {
            item.image = [NSImage imageNamed:NSImageNamePreferencesGeneral];
        }
    } else if ([itemIdentifier isEqualToString:kToolbarAppearance]) {
        item.label = @"Appearance";
        if (@available(macOS 11.0, *)) {
            item.image = [NSImage imageWithSystemSymbolName:@"paintbrush" accessibilityDescription:@"Appearance"];
        } else {
            item.image = [NSImage imageNamed:NSImageNameColorPanel];
        }
    } else if ([itemIdentifier isEqualToString:kToolbarEncoding]) {
        item.label = @"Encoding";
        if (@available(macOS 11.0, *)) {
            item.image = [NSImage imageWithSystemSymbolName:@"character.book.closed" accessibilityDescription:@"Encoding"];
        } else {
            item.image = [NSImage imageNamed:NSImageNameMultipleDocuments];
        }
    } else if ([itemIdentifier isEqualToString:kToolbarAdvanced]) {
        item.label = @"Advanced";
        if (@available(macOS 11.0, *)) {
            item.image = [NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:@"Advanced"];
        } else {
            item.image = [NSImage imageNamed:NSImageNameAdvanced];
        }
    }

    return item;
}

- (void)toolbarItemClicked:(NSToolbarItem *)item {
    [self switchToTab:item.itemIdentifier animate:YES];
}

#pragma mark - Populate Data

- (void)reloadPreferencesValues {
    PreferencesManager *prefs = [PreferencesManager sharedManager];

    // Editor
    self.fontDisplayLabel.stringValue = [NSString stringWithFormat:@"%@ %ld pt", prefs.fontName ?: @"Menlo", (long)prefs.fontSize];
    [self.tabWidthPopup selectItemWithTag:prefs.tabWidth];
    self.useSpacesCheckbox.state = prefs.useSpaces ? NSControlStateValueOn : NSControlStateValueOff;
    self.wordWrapCheckbox.state = prefs.wordWrap ? NSControlStateValueOn : NSControlStateValueOff;

    // Appearance
    NSInteger segment = 2; // System default
    if (prefs.themeMode == NPThemeModeLight) segment = 0;
    else if (prefs.themeMode == NPThemeModeDark) segment = 1;
    self.themeSegmentedControl.selectedSegment = segment;
    self.showLineNumbersCheckbox.state = prefs.showLineNumbers ? NSControlStateValueOn : NSControlStateValueOff;
    self.showStatusBarCheckbox.state = prefs.showStatusBar ? NSControlStateValueOn : NSControlStateValueOff;

    // Encoding
    [self.encodingPopup selectItemWithTag:prefs.defaultEncoding];

    // Advanced
    self.backupOnSaveCheckbox.state = prefs.backupOnSave ? NSControlStateValueOn : NSControlStateValueOff;
    self.autoIndentCheckbox.state = prefs.autoIndent ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)handlePreferencesChanged:(NSNotification *)notification {
    [self reloadPreferencesValues];
}

#pragma mark - Actions

- (void)changeFontClicked:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    fontManager.target = self;
    fontManager.action = @selector(changeFont:);

    NSFont *font = [NSFont fontWithName:prefs.fontName size:prefs.fontSize] ?: [NSFont monospacedSystemFontOfSize:prefs.fontSize weight:NSFontWeightRegular];
    [fontManager setSelectedFont:font isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (void)changeFont:(id)sender {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    NSFont *currentFont = [NSFont fontWithName:prefs.fontName size:prefs.fontSize] ?: [NSFont monospacedSystemFontOfSize:12.0 weight:NSFontWeightRegular];
    NSFont *newFont = [fontManager convertFont:currentFont];
    if (newFont) {
        prefs.fontName = newFont.fontName;
        prefs.fontSize = (NSInteger)newFont.pointSize;
        [prefs savePreferences];
    }
}

- (void)tabWidthChanged:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.tabWidth = self.tabWidthPopup.selectedTag;
    [prefs savePreferences];
}

- (void)useSpacesToggled:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.useSpaces = (self.useSpacesCheckbox.state == NSControlStateValueOn);
    [prefs savePreferences];
}

- (void)wordWrapToggled:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.wordWrap = (self.wordWrapCheckbox.state == NSControlStateValueOn);
    [prefs savePreferences];
}

- (void)themeChanged:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    NSInteger seg = self.themeSegmentedControl.selectedSegment;
    if (seg == 0) {
        prefs.themeMode = NPThemeModeLight;
    } else if (seg == 1) {
        prefs.themeMode = NPThemeModeDark;
    } else {
        prefs.themeMode = NPThemeModeSystem;
    }
    [prefs savePreferences];
}

- (void)lineNumbersToggled:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.showLineNumbers = (self.showLineNumbersCheckbox.state == NSControlStateValueOn);
    [prefs savePreferences];
}

- (void)statusBarToggled:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.showStatusBar = (self.showStatusBarCheckbox.state == NSControlStateValueOn);
    [prefs savePreferences];
}

- (void)encodingChanged:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.defaultEncoding = (NSStringEncoding)self.encodingPopup.selectedTag;
    [prefs savePreferences];
}

- (void)backupOnSaveToggled:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.backupOnSave = (self.backupOnSaveCheckbox.state == NSControlStateValueOn);
    [prefs savePreferences];
}

- (void)autoIndentToggled:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.autoIndent = (self.autoIndentCheckbox.state == NSControlStateValueOn);
    [prefs savePreferences];
}

- (void)showWindow:(nullable id)sender {
    [self reloadPreferencesValues];
    [super showWindow:sender];
    [self.window makeKeyAndOrderFront:sender];
    [NSApp activateIgnoringOtherApps:YES];
}

@end
