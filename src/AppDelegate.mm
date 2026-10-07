#import "AppDelegate.h"
#import "NotepadWindowController.h"

@implementation AppDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _windowControllers = [NSMutableArray array];
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self createMainMenu];

    if (self.windowControllers.count == 0) {
        [self newDocument:nil];
    }
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename {
    NotepadWindowController *wc = [[NotepadWindowController alloc] initWithFilePath:filename];
    [self.windowControllers addObject:wc];
    [wc showWindow:nil];
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}

- (void)newDocument:(nullable id)sender {
    NotepadWindowController *wc = [[NotepadWindowController alloc] initWithFilePath:nil];
    [self.windowControllers addObject:wc];
    [wc showWindow:nil];
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
    [fileMenu addItemWithTitle:@"Save"
                        action:@selector(saveDocument:)
                 keyEquivalent:@"s"];
    NSMenuItem *saveAs = [fileMenu addItemWithTitle:@"Save As…"
                                             action:@selector(saveDocumentAs:)
                                      keyEquivalent:@"S"];
    [saveAs setKeyEquivalentModifierMask:(NSEventModifierFlagShift | NSEventModifierFlagCommand)];
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
    [editMenu addItemWithTitle:@"Replace…"
                        action:@selector(showReplace:)
                 keyEquivalent:@"h"];
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
                 keyEquivalent:@"+"];
    [zoomMenu addItemWithTitle:@"Zoom Out"
                        action:@selector(zoomOut:)
                 keyEquivalent:@"-"];
    [zoomMenu addItemWithTitle:@"Restore Default Zoom"
                        action:@selector(restoreDefaultZoom:)
                 keyEquivalent:@"0"];
    [zoomSubmenuItem setSubmenu:zoomMenu];
    [viewMenu addItem:zoomSubmenuItem];

    [viewMenu addItem:[NSMenuItem separatorItem]];
    [viewMenu addItemWithTitle:@"Status Bar"
                        action:@selector(toggleStatusBar:)
                 keyEquivalent:@""];
    [viewMenuItem setSubmenu:viewMenu];
    [menubar addItem:viewMenuItem];

    // 6. Help Menu
    NSMenuItem *helpMenuItem = [[NSMenuItem alloc] init];
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
    [helpMenu addItemWithTitle:@"About Notepad"
                        action:@selector(orderFrontStandardAboutPanel:)
                 keyEquivalent:@""];
    [helpMenuItem setSubmenu:helpMenu];
    [menubar addItem:helpMenuItem];

    [NSApp setMainMenu:menubar];
}

@end
