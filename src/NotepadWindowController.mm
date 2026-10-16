#import "NotepadWindowController.h"
#import "NotepadFileManager.h"
#import "AppDelegate.h"
#import "ScintillaView+Notepad.h"
#import "StatusBarView.h"
#import "EmptyDocumentOverlayView.h"
#import "FindReplaceController.h"
#import "PreferencesManager.h"
#import "Scintilla.h"
#import "ScintillaPrintView.h"

@interface NotepadWindowController ()
@end

@implementation NotepadWindowController

- (instancetype)initWithFilePath:(nullable NSString *)filePath {
    NSRect contentRect = NSMakeRect(120, 120, 840, 580);
    NSWindowStyleMask style = NSWindowStyleMaskTitled |
                              NSWindowStyleMaskClosable |
                              NSWindowStyleMaskMiniaturizable |
                              NSWindowStyleMaskResizable;

    NSWindow *win = [[NSWindow alloc] initWithContentRect:contentRect
                                                styleMask:style
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    [win center];
    win.minSize = NSMakeSize(480, 240);
    win.backgroundColor = [[PreferencesManager sharedManager] isDarkModeActive] ?
        [NSColor colorWithCalibratedRed:0.125 green:0.125 blue:0.125 alpha:1.0] : [NSColor whiteColor];
    [win setFrameAutosaveName:@"NotepadMainWindow"];

    // Disable macOS native window tabbing so our custom Notepad++ tabs are used
    win.tabbingMode = NSWindowTabbingModeDisallowed;

    self = [super initWithWindow:win];
    if (self) {
        win.delegate = self;
        _tabs = [NSMutableArray array];
        _currentTabIndex = -1;

        [self setupUIInWindow:win];

        // Register appearance and preferences observers
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                            selector:@selector(handleAppearanceChanged:)
                                                                name:@"AppleInterfaceThemeChangedNotification"
                                                              object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePreferencesChanged:)
                                                     name:NPPreferencesDidChangeNotification
                                                   object:nil];

        // Create initial tab
        [self addNewTabWithFilePath:filePath];
        [self layoutSubviews];
    }
    return self;
}

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupUIInWindow:(NSWindow *)window {
    NSView *contentView = window.contentView;
    contentView.autoresizesSubviews = YES;

    BOOL showStatusBar = [PreferencesManager sharedManager].showStatusBar;
    CGFloat sbHeight = showStatusBar ? 24.0 : 0.0;
    CGFloat tabBarHeight = 36.0;

    // 1. Status Bar at the bottom
    _statusBar = [[StatusBarView alloc] initWithFrame:NSMakeRect(0, 0, contentView.bounds.size.width, sbHeight)];
    _statusBar.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    _statusBar.hidden = !showStatusBar;
    _statusBar.delegate = self;
    [contentView addSubview:_statusBar];

    // 2. Tab Bar at the top - placed on top
    NSRect tabRect = NSMakeRect(0, contentView.bounds.size.height - tabBarHeight, contentView.bounds.size.width, tabBarHeight);
    _tabBarView = [[NotepadTabBarView alloc] initWithFrame:tabRect];
    _tabBarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    _tabBarView.delegate = self;
    [contentView addSubview:_tabBarView];
}

- (void)layoutSubviews {
    if (!self.window || !self.window.contentView) return;
    NSView *contentView = self.window.contentView;
    BOOL showStatusBar = [PreferencesManager sharedManager].showStatusBar;
    CGFloat sbHeight = showStatusBar ? 24.0 : 0.0;
    CGFloat tabBarHeight = 36.0;

    CGFloat totalH = contentView.bounds.size.height;
    CGFloat totalW = contentView.bounds.size.width;

    self.statusBar.frame = NSMakeRect(0, 0, totalW, sbHeight);
    self.tabBarView.frame = NSMakeRect(0, totalH - tabBarHeight, totalW, tabBarHeight);

    NSRect editorFrame = NSMakeRect(0, sbHeight, totalW, MAX(0, totalH - sbHeight - tabBarHeight));
    for (NotepadTabItem *tab in self.tabs) {
        tab.editor.frame = editorFrame;
        tab.emptyOverlayView.frame = editorFrame;
    }
}

- (void)windowDidResize:(NSNotification *)notification {
    [self layoutSubviews];
}

- (void)windowDidEndLiveResize:(NSNotification *)notification {
    [self layoutSubviews];
}

#pragma mark - Dynamic Active Tab Accessors

- (NotepadTabItem *)currentTab {
    if (self.currentTabIndex >= 0 && self.currentTabIndex < (NSInteger)self.tabs.count) {
        return self.tabs[self.currentTabIndex];
    }
    return nil;
}

- (ScintillaView *)editor {
    return self.currentTab.editor;
}

- (EmptyDocumentOverlayView *)emptyOverlayView {
    return self.currentTab.emptyOverlayView;
}

- (NSString *)filePath {
    return self.currentTab.filePath;
}

- (void)setFilePath:(NSString *)path {
    if (self.currentTab) {
        self.currentTab.filePath = [path copy];
        self.currentTab.title = [path lastPathComponent];
        self.tabBarView.tabs = self.tabs;
        [self.tabBarView reloadTabs];
        [self updateWindowTitle];
    }
}

- (BOOL)isDirty {
    return self.currentTab.isDirty;
}

- (void)setIsDirty:(BOOL)isDirty {
    if (self.currentTab) {
        self.currentTab.isDirty = isDirty;
        if (!isDirty && self.currentTab.editor) {
            [self.currentTab.editor message:SCI_SETSAVEPOINT];
        }
        self.tabBarView.tabs = self.tabs;
        [self.tabBarView reloadTabs];
        [self updateWindowTitle];
    }
}

- (NSStringEncoding)encoding {
    return self.currentTab ? self.currentTab.encoding : [PreferencesManager sharedManager].defaultEncoding;
}

- (void)setEncoding:(NSStringEncoding)encoding {
    if (self.currentTab) {
        self.currentTab.encoding = encoding;
        [self updateStatusBar];
    }
}

#pragma mark - Multi-Tab Management (Notepad++ / Windows 11 style)

- (void)addNewTabWithFilePath:(nullable NSString *)path {
    NSInteger count = self.tabs.count + 1;
    NSString *title = path ? [path lastPathComponent] : [NSString stringWithFormat:@"new %ld", (long)count];

    NotepadTabItem *item = [NotepadTabItem tabWithTitle:title filePath:path];
    item.editor.delegate = self;

    NSView *contentView = self.window.contentView;
    CGFloat sbHeight = [PreferencesManager sharedManager].showStatusBar ? 24.0 : 0.0;
    CGFloat tabBarHeight = 36.0;
    NSRect editorFrame = NSMakeRect(0, sbHeight, contentView.bounds.size.width, MAX(0, contentView.bounds.size.height - sbHeight - tabBarHeight));

    item.editor.frame = editorFrame;
    item.editor.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [contentView addSubview:item.editor positioned:NSWindowBelow relativeTo:self.tabBarView];

    item.emptyOverlayView.frame = editorFrame;
    item.emptyOverlayView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [contentView addSubview:item.emptyOverlayView positioned:NSWindowAbove relativeTo:item.editor];

    [self.tabs addObject:item];
    self.tabBarView.tabs = self.tabs;

    if (path) {
        [self selectTabAtIndex:self.tabs.count - 1];
        [self loadFile:path];
    } else {
        [self selectTabAtIndex:self.tabs.count - 1];
    }
}

- (void)selectTabAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.tabs.count) return;

    _currentTabIndex = index;
    self.tabBarView.selectedIndex = index;

    NSView *contentView = self.window.contentView;
    CGFloat sbHeight = [PreferencesManager sharedManager].showStatusBar ? 24.0 : 0.0;
    CGFloat tabBarHeight = 36.0;
    NSRect editorFrame = NSMakeRect(0, sbHeight, contentView.bounds.size.width, MAX(0, contentView.bounds.size.height - sbHeight - tabBarHeight));

    for (NSInteger i = 0; i < (NSInteger)self.tabs.count; i++) {
        NotepadTabItem *tab = self.tabs[i];
        BOOL isActive = (i == index);
        tab.editor.hidden = !isActive;
        if (isActive) {
            long length = [tab.editor message:SCI_GETLENGTH];
            tab.emptyOverlayView.hidden = (length > 0);
            tab.editor.frame = editorFrame;
            tab.emptyOverlayView.frame = editorFrame;
        } else {
            tab.emptyOverlayView.hidden = YES;
        }
    }

    NotepadTabItem *activeTab = self.currentTab;
    if (activeTab) {
        NSView *targetFocus = activeTab.editor.content ?: activeTab.editor;
        [self.window makeFirstResponder:targetFocus];
    }

    [self applyThemeAndAppearance];
    [self updateWindowTitle];
    [self updateStatusBar];
    [self updateEmptyStateVisibility];
    [self.tabBarView reloadTabs];
}

- (void)closeTabAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.tabs.count) return;

    NotepadTabItem *tab = self.tabs[index];
    if (tab.isDirty) {
        [self selectTabAtIndex:index];

        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = [NSString stringWithFormat:@"Do you want to save changes to \"%@\"?", tab.title];
        alert.informativeText = @"Your changes will be lost if you don't save them.";
        [alert addButtonWithTitle:@"Save"];
        [alert addButtonWithTitle:@"Don't Save"];
        [alert addButtonWithTitle:@"Cancel"];

        NSModalResponse res = [alert runModal];
        if (res == NSAlertFirstButtonReturn) {
            if (![self saveFile]) return;
        } else if (res == NSAlertThirdButtonReturn) {
            return; // Cancel
        }
    }

    [tab.editor removeFromSuperview];
    [tab.emptyOverlayView removeFromSuperview];
    [self.tabs removeObjectAtIndex:index];
    self.tabBarView.tabs = self.tabs;

    if (self.tabs.count == 0) {
        // If last tab is closed, create a fresh untitled tab (Notepad++ behavior)
        [self addNewTabWithFilePath:nil];
    } else {
        NSInteger nextIndex = MIN(index, (NSInteger)self.tabs.count - 1);
        [self selectTabAtIndex:nextIndex];
    }
}

- (IBAction)newTab:(nullable id)sender {
    [self addNewTabWithFilePath:nil];
}

- (IBAction)closeTab:(nullable id)sender {
    [self closeTabAtIndex:self.currentTabIndex];
}

- (IBAction)nextTab:(nullable id)sender {
    if (self.tabs.count <= 1) return;
    NSInteger next = (self.currentTabIndex + 1) % self.tabs.count;
    [self selectTabAtIndex:next];
}

- (IBAction)previousTab:(nullable id)sender {
    if (self.tabs.count <= 1) return;
    NSInteger prev = (self.currentTabIndex - 1 + self.tabs.count) % self.tabs.count;
    [self selectTabAtIndex:prev];
}

#pragma mark - NotepadTabBarViewDelegate

- (void)tabBarView:(NotepadTabBarView *)tabBar didSelectTabAtIndex:(NSInteger)index {
    [self selectTabAtIndex:index];
}

- (void)tabBarView:(NotepadTabBarView *)tabBar didCloseTabAtIndex:(NSInteger)index {
    [self closeTabAtIndex:index];
}

- (void)tabBarViewDidClickNewTab:(NotepadTabBarView *)tabBar {
    [self addNewTabWithFilePath:nil];
}

#pragma mark - Themes & Preferences

- (void)applyThemeAndAppearance {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    BOOL isDark = [prefs isDarkModeActive];

    if (@available(macOS 10.14, *)) {
        if (prefs.themeMode == NPThemeModeLight) {
            self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        } else if (prefs.themeMode == NPThemeModeDark) {
            self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        } else {
            self.window.appearance = nil;
        }
    }

    self.window.backgroundColor = isDark ?
        [NSColor colorWithCalibratedRed:0.125 green:0.125 blue:0.125 alpha:1.0] : [NSColor whiteColor];

    [self.tabBarView updateTheme];

    for (NotepadTabItem *tab in self.tabs) {
        if (@available(macOS 10.14, *)) {
            tab.editor.appearance = self.window.effectiveAppearance;
            tab.emptyOverlayView.appearance = self.window.effectiveAppearance;
        }
        [tab.editor np_applyDefaultTheme];
        [tab.emptyOverlayView updateTheme];
    }

    if (self.statusBar) {
        if (@available(macOS 10.14, *)) {
            self.statusBar.appearance = self.window.effectiveAppearance;
        }
        [self.statusBar setNeedsDisplay:YES];
        [self updateStatusBar];
    }
}

- (void)handleAppearanceChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self applyThemeAndAppearance];
    });
}

- (void)handlePreferencesChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        PreferencesManager *prefs = [PreferencesManager sharedManager];
        if (self.statusBar && self.statusBar.isHidden == prefs.showStatusBar) {
            self.statusBar.hidden = !prefs.showStatusBar;
            [self layoutSubviews];
        }

        for (NotepadTabItem *tab in self.tabs) {
            [tab.editor np_setWordWrap:prefs.wordWrap];
            [tab.editor np_setLineNumbersVisible:prefs.showLineNumbers];
            [tab.editor np_setTabWidth:prefs.tabWidth];
            [tab.editor np_setUseSpaces:prefs.useSpaces];
        }

        // Synchronize active encoding with Settings Panel defaultEncoding
        self.encoding = prefs.defaultEncoding;

        [self applyThemeAndAppearance];
        [self updateStatusBar];
    });
}

- (void)updateWindowTitle {
    NSString *fileName = self.filePath ? [self.filePath lastPathComponent] : (self.currentTab ? self.currentTab.title : @"Untitled");
    NSString *title = [NSString stringWithFormat:@"%@%@ - Notepad", self.isDirty ? @"*" : @"", fileName];
    [self.window setTitle:title];
    [self.window setDocumentEdited:self.isDirty];

    if (self.filePath) {
        [self.window setRepresentedFilename:self.filePath];
    } else {
        [self.window setRepresentedFilename:@""];
    }
}

- (void)updateStatusBar {
    if (!self.editor || !self.statusBar || self.statusBar.isHidden) return;

    // 1. Cursor Position & Selection
    sptr_t pos = [self.editor message:SCI_GETCURRENTPOS];
    sptr_t line = [self.editor message:SCI_LINEFROMPOSITION wParam:pos];
    sptr_t col = [self.editor message:SCI_GETCOLUMN wParam:pos];

    sptr_t selStart = [self.editor message:SCI_GETSELECTIONSTART];
    sptr_t selEnd = [self.editor message:SCI_GETSELECTIONEND];
    NSInteger selChars = labs((long)(selEnd - selStart));

    if (selChars > 0) {
        sptr_t startLine = [self.editor message:SCI_LINEFROMPOSITION wParam:selStart];
        sptr_t endLine = [self.editor message:SCI_LINEFROMPOSITION wParam:selEnd];
        NSInteger selLines = labs((long)(endLine - startLine)) + 1;
        [self.statusBar updateLine:(line + 1) column:(col + 1) selectedChars:selChars selectedLines:selLines];
    } else {
        [self.statusBar updateLine:(line + 1) column:(col + 1)];
    }

    // 2. Zoom Level
    sptr_t zoomFactor = [self.editor message:SCI_GETZOOM];
    [self.statusBar updateZoom:(100 + (NSInteger)zoomFactor * 10)];

    // 3. EOL Mode
    long eol = [self.editor getGeneralProperty:SCI_GETEOLMODE];
    if (eol == SC_EOL_CRLF) {
        [self.statusBar setEolModeName:@"Windows (CRLF)"];
    } else if (eol == SC_EOL_CR) {
        [self.statusBar setEolModeName:@"Macintosh (CR)"];
    } else {
        [self.statusBar setEolModeName:@"Unix (LF)"];
    }

    // 4. Encoding
    NSString *encName = @"UTF-8";
    if (self.encoding == NSWindowsCP1252StringEncoding) {
        encName = @"Windows-1252";
    } else if (self.encoding == NSISOLatin1StringEncoding) {
        encName = @"ISO-8859-1";
    } else if (self.encoding == NSASCIIStringEncoding) {
        encName = @"US-ASCII";
    } else if (self.encoding == NSUTF16StringEncoding || self.encoding == NSUTF16LittleEndianStringEncoding) {
        encName = @"UTF-16 LE";
    } else if (self.encoding == NSUTF16BigEndianStringEncoding) {
        encName = @"UTF-16 BE";
    } else if (self.encoding == NSUTF8StringEncoding) {
        encName = @"UTF-8";
    } else {
        encName = [PreferencesManager nameForEncoding:self.encoding];
    }
    [self.statusBar setEncodingName:encName];
}

#pragma mark - StatusBarViewDelegate

- (void)statusBarDidClickPosition:(StatusBarView *)statusBar {
    [self goToLine:nil];
}

- (void)statusBarDidRequestZoomIn:(StatusBarView *)statusBar {
    [self zoomIn:nil];
}

- (void)statusBarDidRequestZoomOut:(StatusBarView *)statusBar {
    [self zoomOut:nil];
}

- (void)statusBarDidRequestZoomReset:(StatusBarView *)statusBar {
    [self restoreDefaultZoom:nil];
}

- (void)statusBar:(StatusBarView *)statusBar didSelectEolMode:(NSInteger)eolMode {
    if (!self.editor) return;
    [self.editor message:SCI_SETEOLMODE wParam:eolMode lParam:0];
    [self.editor message:SCI_CONVERTEOLS wParam:eolMode lParam:0];
    [self updateStatusBar];
    [self updateWindowTitle];
}

- (void)statusBar:(StatusBarView *)statusBar didSelectEncoding:(NSStringEncoding)encoding {
    if (self.encoding == encoding) return;
    self.encoding = encoding;
    [PreferencesManager sharedManager].defaultEncoding = encoding;
    [[PreferencesManager sharedManager] savePreferences];
    [self updateStatusBar];
    [self updateWindowTitle];
}

- (void)loadFile:(NSString *)path {
    [[NotepadFileManager sharedManager] openFileAtPath:path inController:self];
    [self updateEmptyStateVisibility];
}

- (void)updateEmptyStateVisibility {
    if (!self.editor || !self.emptyOverlayView) return;
    long length = [self.editor message:SCI_GETLENGTH];
    self.emptyOverlayView.hidden = (length > 0);
}

- (BOOL)saveFile {
    return [[NotepadFileManager sharedManager] saveController:self];
}

- (BOOL)saveFileAs {
    return [[NotepadFileManager sharedManager] saveAsController:self];
}

#pragma mark - Scintilla Notifications

- (void)notification:(SCNotification *)notification {
    if (!notification) return;

    switch (notification->nmhdr.code) {
        case SCN_SAVEPOINTREACHED:
            if (self.currentTab) {
                self.currentTab.isDirty = NO;
                [self.tabBarView reloadTabs];
            }
            [self updateWindowTitle];
            break;
        case SCN_SAVEPOINTLEFT:
            if (self.currentTab) {
                self.currentTab.isDirty = YES;
                [self.tabBarView reloadTabs];
            }
            [self updateWindowTitle];
            break;
        case SCN_UPDATEUI:
            [self updateStatusBar];
            [[FindReplaceController sharedController] editorSelectionDidChange:self.editor];
            break;
        case SCN_MODIFIED:
            if ((notification->modificationType & (SC_MOD_INSERTTEXT | SC_MOD_DELETETEXT)) != 0) {
                [[FindReplaceController sharedController] editorContentDidChange:self.editor];
                [self updateEmptyStateVisibility];
            }
            break;
        case SCN_CHARADDED:
            if ([PreferencesManager sharedManager].autoIndent && (notification->ch == '\n' || notification->ch == '\r')) {
                sptr_t curPos = [self.editor message:SCI_GETCURRENTPOS];
                sptr_t curLine = [self.editor message:SCI_LINEFROMPOSITION wParam:curPos];
                if (curLine > 0) {
                    sptr_t prevIndentation = [self.editor message:SCI_GETLINEINDENTATION wParam:curLine - 1];
                    if (prevIndentation > 0) {
                        [self.editor message:SCI_SETLINEINDENTATION wParam:curLine lParam:prevIndentation];
                        sptr_t indentPos = [self.editor message:SCI_GETLINEINDENTPOSITION wParam:curLine];
                        [self.editor message:SCI_SETCURRENTPOS wParam:indentPos];
                        [self.editor message:SCI_SETSELECTIONSTART wParam:indentPos];
                        [self.editor message:SCI_SETSELECTIONEND wParam:indentPos];
                    }
                }
            }
            break;
        default:
            break;
    }
}

#pragma mark - Window Delegate

- (BOOL)windowShouldClose:(NSWindow *)sender {
    for (NSInteger i = 0; i < (NSInteger)self.tabs.count; i++) {
        NotepadTabItem *tab = self.tabs[i];
        if (tab.isDirty) {
            [self selectTabAtIndex:i];

            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = [NSString stringWithFormat:@"Do you want to save changes to \"%@\"?", tab.title];
            alert.informativeText = @"Your changes will be lost if you don't save them.";
            [alert addButtonWithTitle:@"Save"];
            [alert addButtonWithTitle:@"Don't Save"];
            [alert addButtonWithTitle:@"Cancel"];

            NSModalResponse response = [alert runModal];
            if (response == NSAlertFirstButtonReturn) {
                if (![self saveFile]) {
                    return NO;
                }
            } else if (response == NSAlertThirdButtonReturn) {
                return NO; // Cancel
            }
        }
    }
    return YES;
}

- (void)windowWillClose:(NSNotification *)notification {
    AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
    [appDelegate removeWindowController:self];
}

#pragma mark - Standard Actions

- (IBAction)newDocument:(nullable id)sender {
    [self newTab:sender];
}

- (IBAction)newWindow:(nullable id)sender {
    AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
    NotepadWindowController *wc = [[NotepadWindowController alloc] initWithFilePath:nil];
    [appDelegate addWindowController:wc];
    [wc showWindow:nil];
}

- (IBAction)openDocument:(nullable id)sender {
    [[NotepadFileManager sharedManager] openDocumentInController:self];
}

- (IBAction)saveDocument:(nullable id)sender {
    [self saveFile];
}

- (IBAction)saveDocumentAs:(nullable id)sender {
    [self saveFileAs];
}

- (IBAction)revertDocument:(nullable id)sender {
    [[NotepadFileManager sharedManager] revertController:self];
}

- (IBAction)runPageSpec:(nullable id)sender {
    NSPageLayout *pageLayout = [NSPageLayout pageLayout];
    [pageLayout beginSheetWithPrintInfo:[NSPrintInfo sharedPrintInfo]
                         modalForWindow:self.window
                               delegate:nil
                         didEndSelector:NULL
                            contextInfo:NULL];
}

- (IBAction)runPageLayout:(nullable id)sender {
    [self runPageSpec:sender];
}

- (IBAction)printDocument:(nullable id)sender {
    if (!self.editor) return;
    NSPrintInfo *pi = [NSPrintInfo sharedPrintInfo];
    // Create custom NSView that calls SCI_FORMATRANGE in drawRect:
    ScintillaPrintView *pv = [[ScintillaPrintView alloc] initWithEditor:self.editor
                                                              printInfo:pi];
    if (self.currentTab.title.length > 0) {
        pv.documentTitle = self.currentTab.title;
    }
    NSPrintOperation *op = [NSPrintOperation printOperationWithView:pv printInfo:pi];
    if (self.currentTab.title.length > 0) {
        [op setJobTitle:self.currentTab.title];
    }
    [op runOperationModalForWindow:self.window delegate:nil
                   didRunSelector:NULL contextInfo:NULL];
}

- (IBAction)undo:(nullable id)sender {
    if (self.editor && [self.editor message:SCI_CANUNDO]) {
        [self.editor message:SCI_UNDO];
    }
}

- (IBAction)redo:(nullable id)sender {
    if (self.editor && [self.editor message:SCI_CANREDO]) {
        [self.editor message:SCI_REDO];
    }
}

- (IBAction)cut:(nullable id)sender {
    if (self.editor) [self.editor message:SCI_CUT];
}

- (IBAction)copy:(nullable id)sender {
    if (self.editor) [self.editor message:SCI_COPY];
}

- (IBAction)paste:(nullable id)sender {
    if (self.editor) [self.editor message:SCI_PASTE];
}

- (IBAction)delete:(nullable id)sender {
    if (self.editor) [self.editor message:SCI_CLEAR];
}

- (IBAction)selectAll:(nullable id)sender {
    if (self.editor) [self.editor message:SCI_SELECTALL];
}

- (IBAction)showFind:(nullable id)sender {
    [[FindReplaceController sharedController] showForEditor:self.editor];
}

- (IBAction)showReplace:(nullable id)sender {
    [[FindReplaceController sharedController] showReplaceForEditor:self.editor];
}

- (IBAction)findNext:(nullable id)sender {
    [[FindReplaceController sharedController] findNext];
}

- (IBAction)findPrevious:(nullable id)sender {
    [[FindReplaceController sharedController] findPrevious];
}

- (IBAction)goToLine:(nullable id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Go To Line";
    alert.informativeText = @"Line number:";
    [alert addButtonWithTitle:@"Go To"];
    [alert addButtonWithTitle:@"Cancel"];

    sptr_t curPos = [self.editor message:SCI_GETCURRENTPOS];
    sptr_t curLine = [self.editor message:SCI_LINEFROMPOSITION wParam:curPos] + 1;
    sptr_t totalLines = [self.editor message:SCI_GETLINECOUNT];

    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = [NSString stringWithFormat:@"%ld", (long)curLine];
    alert.accessoryView = input;

    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            NSInteger targetLine = [input.stringValue integerValue];
            if (targetLine > 0 && targetLine <= totalLines) {
                sptr_t lineStartPos = [self.editor message:SCI_POSITIONFROMLINE wParam:(targetLine - 1)];
                [self.editor message:SCI_GOTOPOS wParam:lineStartPos];
                [self.editor message:SCI_SCROLLCARET];
                [self updateStatusBar];
            }
        }
    }];
}

- (IBAction)insertTimeDate:(nullable id)sender {
    if (!self.editor) return;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"h:mm a M/d/yyyy"];
    NSString *dateTimeString = [formatter stringFromDate:[NSDate date]];
    sptr_t curPos = [self.editor message:SCI_GETCURRENTPOS];
    [self.editor setStringProperty:SCI_INSERTTEXT parameter:curPos value:dateTimeString];
    [self.editor message:SCI_GOTOPOS wParam:(curPos + [dateTimeString lengthOfBytesUsingEncoding:NSUTF8StringEncoding])];
    [self.editor message:SCI_SCROLLCARET];
}

- (IBAction)toggleWordWrap:(nullable id)sender {
    BOOL currentWrap = [self.editor np_wordWrap];
    [self.editor np_setWordWrap:!currentWrap];
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.wordWrap = !currentWrap;
    [prefs savePreferences];
}

- (IBAction)chooseFont:(nullable id)sender {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSString *currentFontName = [self.editor np_fontName];
    NSInteger currentFontSize = [self.editor np_fontSize];
    NSFont *font = [NSFont fontWithName:currentFontName size:currentFontSize] ?: [NSFont systemFontOfSize:12.0];
    [fontManager setSelectedFont:font isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (void)changeFont:(id)sender {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSString *currentFontName = [self.editor np_fontName];
    NSInteger currentFontSize = [self.editor np_fontSize];
    NSFont *currentFont = [NSFont fontWithName:currentFontName size:currentFontSize] ?: [NSFont systemFontOfSize:12.0];
    NSFont *newFont = [fontManager convertFont:currentFont];
    if (newFont) {
        [self.editor np_setFontName:newFont.fontName size:(NSInteger)newFont.pointSize];
        PreferencesManager *prefs = [PreferencesManager sharedManager];
        prefs.fontName = newFont.fontName;
        prefs.fontSize = (NSInteger)newFont.pointSize;
        [prefs savePreferences];
    }
}

- (IBAction)zoomIn:(nullable id)sender {
    sptr_t zoom = [self.editor message:SCI_GETZOOM];
    if (zoom < 20) {
        [self.editor message:SCI_ZOOMIN];
        [self updateStatusBar];
    }
}

- (IBAction)zoomOut:(nullable id)sender {
    sptr_t zoom = [self.editor message:SCI_GETZOOM];
    if (zoom > -10) {
        [self.editor message:SCI_ZOOMOUT];
        [self updateStatusBar];
    }
}

- (IBAction)restoreDefaultZoom:(nullable id)sender {
    [self.editor message:SCI_SETZOOM wParam:0 lParam:0];
    [self updateStatusBar];
}

- (IBAction)toggleStatusBar:(nullable id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.showStatusBar = !prefs.showStatusBar;
    [prefs savePreferences];
}

- (IBAction)toggleLineNumbers:(nullable id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.showLineNumbers = !prefs.showLineNumbers;
    [prefs savePreferences];
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

#pragma mark - NSMenuItemValidation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = menuItem.action;

    if (action == @selector(undo:)) {
        return self.editor && [self.editor message:SCI_CANUNDO];
    }
    if (action == @selector(redo:)) {
        return self.editor && [self.editor message:SCI_CANREDO];
    }
    if (action == @selector(cut:) || action == @selector(copy:) || action == @selector(delete:)) {
        sptr_t start = [self.editor message:SCI_GETSELECTIONSTART];
        sptr_t end = [self.editor message:SCI_GETSELECTIONEND];
        return (start != end);
    }
    if (action == @selector(paste:)) {
        return self.editor && [self.editor message:SCI_CANPASTE];
    }
    if (action == @selector(selectAll:) || action == @selector(insertTimeDate:)) {
        return (self.editor != nil);
    }
    if (action == @selector(toggleWordWrap:)) {
        menuItem.state = [self.editor np_wordWrap] ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    if (action == @selector(toggleStatusBar:)) {
        menuItem.state = [PreferencesManager sharedManager].showStatusBar ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    if (action == @selector(toggleLineNumbers:)) {
        menuItem.state = [self.editor np_lineNumbersVisible] ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    if (action == @selector(setThemeLight:)) {
        menuItem.state = ([PreferencesManager sharedManager].themeMode == NPThemeModeLight) ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    if (action == @selector(setThemeDark:)) {
        menuItem.state = ([PreferencesManager sharedManager].themeMode == NPThemeModeDark) ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    if (action == @selector(setThemeSystem:)) {
        menuItem.state = ([PreferencesManager sharedManager].themeMode == NPThemeModeSystem) ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    if (action == @selector(revertDocument:)) {
        return (self.filePath != nil && self.isDirty);
    }

    return YES;
}

@end
