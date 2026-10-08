#import "AppDelegate.h"
#import "NotepadWindowController.h"
#import "NotepadFileManager.h"
#import "NotepadDocumentController.h"
#import "ScintillaView+Notepad.h"
#import "PreferencesManager.h"

@implementation AppDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _windowControllers = [NSMutableArray array];
        [NotepadDocumentController sharedDocumentController];
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self createMainMenu];

    NSImage *appIcon = [[NSBundle mainBundle] imageForResource:@"AppIcon"];
    if (appIcon) {
        [NSApp setApplicationIconImage:appIcon];
    }

    if (self.windowControllers.count == 0) {
        [self newDocument:nil];
    }
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename {
    [self openFileAtPath:filename];
    return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray<NSString *> *)filenames {
    for (NSString *filename in filenames) {
        [self openFileAtPath:filename];
    }
    [sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    if (!flag) {
        [self newDocument:nil];
    }
    return YES;
}

- (IBAction)runPageSpec:(nullable id)sender {
    NSPageLayout *pageLayout = [NSPageLayout pageLayout];
    NSWindow *keyWin = [NSApp keyWindow];
    if (keyWin) {
        [pageLayout beginSheetWithPrintInfo:[NSPrintInfo sharedPrintInfo]
                             modalForWindow:keyWin
                                   delegate:nil
                             didEndSelector:NULL
                                contextInfo:NULL];
    } else {
        [pageLayout runModalWithPrintInfo:[NSPrintInfo sharedPrintInfo]];
    }
}

- (void)newDocument:(nullable id)sender {
    NotepadWindowController *wc = [[NotepadWindowController alloc] initWithFilePath:nil];
    [self addWindowController:wc];
    [wc showWindow:nil];
}

- (void)newWindow:(nullable id)sender {
    [self newDocument:sender];
}

- (void)openDocument:(nullable id)sender {
    NSWindowController *activeWC = [[NSApp keyWindow] windowController];
    NotepadWindowController *notepadWC = [activeWC isKindOfClass:[NotepadWindowController class]] ? (NotepadWindowController *)activeWC : nil;
    [[NotepadFileManager sharedManager] openDocumentInController:notepadWC];
}

- (void)openFileAtPath:(NSString *)filePath {
    NSWindowController *activeWC = [[NSApp keyWindow] windowController];
    NotepadWindowController *notepadWC = [activeWC isKindOfClass:[NotepadWindowController class]] ? (NotepadWindowController *)activeWC : nil;
    [[NotepadFileManager sharedManager] openFileAtPath:filePath inController:notepadWC];
}

- (void)addWindowController:(NotepadWindowController *)controller {
    if (controller && ![self.windowControllers containsObject:controller]) {
        [self.windowControllers addObject:controller];
    }
}

- (void)removeWindowController:(NotepadWindowController *)controller {
    if (controller) {
        [self.windowControllers removeObject:controller];
    }
}

#pragma mark - Windows Notepad Menu Bar

- (void)createMainMenu {
    NSMenu *menubar = [[NSMenu alloc] init];

    // 1. Application Menu (Notepad)
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Notepad"];
    [appMenu addItemWithTitle:@"About Notepad"
                       action:@selector(orderFrontStandardAboutPanel:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Preferences…"
                       action:@selector(chooseFont:)
                keyEquivalent:@","];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Hide Notepad"
                       action:@selector(hide:)
                keyEquivalent:@"h"];
    NSMenuItem *hideOthers = [appMenu addItemWithTitle:@"Hide Others"
                                                action:@selector(hideOtherApplications:)
                                         keyEquivalent:@"h"];
    [hideOthers setKeyEquivalentModifierMask:(NSEventModifierFlagOption | NSEventModifierFlagCommand)];
    [appMenu addItemWithTitle:@"Show All"
                       action:@selector(unhideAllApplications:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Exit"
                       action:@selector(terminate:)
                keyEquivalent:@"q"];
    [appMenuItem setSubmenu:appMenu];
    [menubar addItem:appMenuItem];

    // 2. File Menu
    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenu addItemWithTitle:@"New"
                        action:@selector(newDocument:)
                 keyEquivalent:@"n"];
    NSMenuItem *newWin = [fileMenu addItemWithTitle:@"New Window"
                                             action:@selector(newWindow:)
                                      keyEquivalent:@"N"];
    [newWin setKeyEquivalentModifierMask:(NSEventModifierFlagShift | NSEventModifierFlagCommand)];
    [fileMenu addItemWithTitle:@"Open…"
                        action:@selector(openDocument:)
                 keyEquivalent:@"o"];

    // Open Recent Submenu
    NSMenuItem *openRecentItem = [[NSMenuItem alloc] initWithTitle:@"Open Recent" action:nil keyEquivalent:@""];
    NSMenu *openRecentMenu = [[NSMenu alloc] initWithTitle:@"Open Recent"];
    [openRecentMenu addItemWithTitle:@"Clear Menu"
                              action:@selector(clearRecentDocuments:)
                       keyEquivalent:@""];
    [openRecentItem setSubmenu:openRecentMenu];
    [fileMenu addItem:openRecentItem];

    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Save"
                        action:@selector(saveDocument:)
                 keyEquivalent:@"s"];
    NSMenuItem *saveAs = [fileMenu addItemWithTitle:@"Save As…"
                                             action:@selector(saveDocumentAs:)
                                      keyEquivalent:@"S"];
    [saveAs setKeyEquivalentModifierMask:(NSEventModifierFlagShift | NSEventModifierFlagCommand)];
    [fileMenu addItemWithTitle:@"Revert to Saved"
                        action:@selector(revertDocument:)
                 keyEquivalent:@""];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *pageSetup = [fileMenu addItemWithTitle:@"Page Setup…"
                                                 action:@selector(runPageSpec:)
                                          keyEquivalent:@"P"];
    [pageSetup setKeyEquivalentModifierMask:(NSEventModifierFlagShift | NSEventModifierFlagCommand)];
    [fileMenu addItemWithTitle:@"Print…"
                        action:@selector(printDocument:)
                 keyEquivalent:@"p"];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Close Window"
                        action:@selector(performClose:)
                 keyEquivalent:@"w"];
    [fileMenuItem setSubmenu:fileMenu];
    [menubar addItem:fileMenuItem];

    // 3. Edit Menu
    NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Undo"
                        action:@selector(undo:)
                 keyEquivalent:@"z"];
    NSMenuItem *redo = [editMenu addItemWithTitle:@"Redo"
                                           action:@selector(redo:)
                                    keyEquivalent:@"Z"];
    [redo setKeyEquivalentModifierMask:(NSEventModifierFlagShift | NSEventModifierFlagCommand)];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut"
                        action:@selector(cut:)
                 keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy"
                        action:@selector(copy:)
                 keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste"
                        action:@selector(paste:)
                 keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Delete"
                        action:@selector(delete:)
                 keyEquivalent:@"\b"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Find…"
                        action:@selector(showFind:)
                 keyEquivalent:@"f"];
    [editMenu addItemWithTitle:@"Find Next"
                        action:@selector(findNext:)
                 keyEquivalent:@"g"];
    NSMenuItem *findPrev = [editMenu addItemWithTitle:@"Find Previous"
                                                action:@selector(findPrevious:)
                                         keyEquivalent:@"G"];
    [findPrev setKeyEquivalentModifierMask:(NSEventModifierFlagShift | NSEventModifierFlagCommand)];
    NSMenuItem *replaceItem = [editMenu addItemWithTitle:@"Replace…"
                                                  action:@selector(showReplace:)
                                           keyEquivalent:@"f"];
    [replaceItem setKeyEquivalentModifierMask:(NSEventModifierFlagOption | NSEventModifierFlagCommand)];
    [editMenu addItemWithTitle:@"Go To…"
                        action:@selector(goToLine:)
                 keyEquivalent:@"l"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Select All"
                        action:@selector(selectAll:)
                 keyEquivalent:@"a"];
    // Signature Windows Notepad F5 feature
    NSMenuItem *timeDate = [editMenu addItemWithTitle:@"Time/Date"
                                               action:@selector(insertTimeDate:)
                                        keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSF5FunctionKey]];
    [timeDate setKeyEquivalentModifierMask:0];
    [editMenuItem setSubmenu:editMenu];
    [menubar addItem:editMenuItem];

    // 4. Format Menu
    NSMenuItem *formatMenuItem = [[NSMenuItem alloc] init];
    NSMenu *formatMenu = [[NSMenu alloc] initWithTitle:@"Format"];
    [formatMenu addItemWithTitle:@"Word Wrap"
                          action:@selector(toggleWordWrap:)
                   keyEquivalent:@""];
    [formatMenu addItemWithTitle:@"Font…"
                          action:@selector(chooseFont:)
                   keyEquivalent:@"t"];
    [formatMenuItem setSubmenu:formatMenu];
    [menubar addItem:formatMenuItem];

    // 5. View Menu
    NSMenuItem *viewMenuItem = [[NSMenuItem alloc] init];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];

    // Zoom Submenu
    NSMenuItem *zoomSubmenuItem = [[NSMenuItem alloc] initWithTitle:@"Zoom" action:nil keyEquivalent:@""];
    NSMenu *zoomMenu = [[NSMenu alloc] initWithTitle:@"Zoom"];
    [zoomMenu addItemWithTitle:@"Zoom In"
                        action:@selector(zoomIn:)
                 keyEquivalent:@"="];
    [zoomMenu addItemWithTitle:@"Zoom Out"
                        action:@selector(zoomOut:)
                 keyEquivalent:@"-"];
    [zoomMenu addItemWithTitle:@"Restore Default Zoom"
                        action:@selector(restoreDefaultZoom:)
                 keyEquivalent:@"0"];
    [zoomSubmenuItem setSubmenu:zoomMenu];
    [viewMenu addItem:zoomSubmenuItem];

    // Theme Submenu (Light / Dark / System Default)
    NSMenuItem *themeSubmenuItem = [[NSMenuItem alloc] initWithTitle:@"Theme" action:nil keyEquivalent:@""];
    NSMenu *themeMenu = [[NSMenu alloc] initWithTitle:@"Theme"];
    [themeMenu addItemWithTitle:@"Light"
                         action:@selector(setThemeLight:)
                  keyEquivalent:@""];
    [themeMenu addItemWithTitle:@"Dark"
                         action:@selector(setThemeDark:)
                  keyEquivalent:@""];
    [themeMenu addItemWithTitle:@"System Default"
                         action:@selector(setThemeSystem:)
                  keyEquivalent:@""];
    [themeSubmenuItem setSubmenu:themeMenu];
    [viewMenu addItem:themeSubmenuItem];

    [viewMenu addItem:[NSMenuItem separatorItem]];
    [viewMenu addItemWithTitle:@"Status Bar"
                        action:@selector(toggleStatusBar:)
                 keyEquivalent:@""];
    [viewMenu addItemWithTitle:@"Show Line Numbers"
                        action:@selector(toggleLineNumbers:)
                 keyEquivalent:@""];
    [viewMenuItem setSubmenu:viewMenu];
    [menubar addItem:viewMenuItem];

    // 6. Window Menu
    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenu addItemWithTitle:@"Minimize"
                          action:@selector(performMiniaturize:)
                   keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom"
                          action:@selector(performZoom:)
                   keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"Bring All to Front"
                          action:@selector(arrangeInFront:)
                   keyEquivalent:@""];
    [windowMenuItem setSubmenu:windowMenu];
    [menubar addItem:windowMenuItem];
    [NSApp setWindowsMenu:windowMenu];

    // 7. Help Menu
    NSMenuItem *helpMenuItem = [[NSMenuItem alloc] init];
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
    [helpMenu addItemWithTitle:@"About Notepad"
                        action:@selector(orderFrontStandardAboutPanel:)
                 keyEquivalent:@""];
    [helpMenuItem setSubmenu:helpMenu];
    [menubar addItem:helpMenuItem];

    [NSApp setMainMenu:menubar];
}

- (IBAction)setThemeLight:(nullable id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.themeMode = NPThemeModeLight;
    [prefs savePreferences];
}

- (IBAction)setThemeDark:(nullable id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.themeMode = NPThemeModeDark;
    [prefs savePreferences];
}

- (IBAction)setThemeSystem:(nullable id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.themeMode = NPThemeModeSystem;
    [prefs savePreferences];
}

@end
