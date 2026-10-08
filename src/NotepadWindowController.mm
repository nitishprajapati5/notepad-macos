#import "NotepadWindowController.h"
#import "NotepadFileManager.h"
#import "AppDelegate.h"
#import "ScintillaView+Notepad.h"
#import "StatusBarView.h"
#import "EmptyDocumentOverlayView.h"
#import "FindReplaceController.h"
#import "PreferencesManager.h"
#import "Scintilla.h"

@interface NotepadWindowController ()
@end

@implementation NotepadWindowController

- (instancetype)initWithFilePath:(nullable NSString *)filePath {
    NSRect contentRect = NSMakeRect(120, 120, 800, 560);
    NSWindowStyleMask style = NSWindowStyleMaskTitled |
                              NSWindowStyleMaskClosable |
                              NSWindowStyleMaskMiniaturizable |
                              NSWindowStyleMaskResizable;

    NSWindow *win = [[NSWindow alloc] initWithContentRect:contentRect
                                                styleMask:style
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    [win center];
    win.minSize = NSMakeSize(400, 200);
    win.backgroundColor = [[PreferencesManager sharedManager] isDarkModeActive] ?
        [NSColor colorWithCalibratedRed:0.12 green:0.12 blue:0.12 alpha:1.0] : [NSColor whiteColor];
    [win setFrameAutosaveName:@"NotepadMainWindow"];

    self = [super initWithWindow:win];
    if (self) {
        _filePath = [filePath copy];
        _encoding = NSUTF8StringEncoding;
        win.delegate = self;

        [self setupUIInWindow:win];
        [self updateWindowTitle];
        [self updateStatusBar];

        // Register appearance and preferences observers
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                            selector:@selector(handleAppearanceChanged:)
                                                                name:@"AppleInterfaceThemeChangedNotification"
                                                              object:nil];


        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePreferencesChanged:)
                                                     name:NPPreferencesDidChangeNotification
                                                   object:nil];

        if (_filePath) {
            [self loadFile:_filePath];
        }
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

    // Status Bar (pinned to bottom like Windows Notepad)
    _statusBar = [[StatusBarView alloc] initWithFrame:NSMakeRect(0, 0, contentView.bounds.size.width, sbHeight)];
    _statusBar.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    _statusBar.hidden = !showStatusBar;
    _statusBar.delegate = self;
    [contentView addSubview:_statusBar];

    // Scintilla Editor (takes entire area above status bar)
    NSRect editorFrame = NSMakeRect(0, sbHeight, contentView.bounds.size.width, contentView.bounds.size.height - sbHeight);
    _editor = [[ScintillaView alloc] initWithFrame:editorFrame];
    _editor.autoresizesSubviews = YES;
    _editor.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _editor.delegate = self;
    [contentView addSubview:_editor];

    // Empty Document Overlay (centered watermark tips)
    _emptyOverlayView = [[EmptyDocumentOverlayView alloc] initWithFrame:editorFrame];
    _emptyOverlayView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [contentView addSubview:_emptyOverlayView positioned:NSWindowAbove relativeTo:_editor];
    [self updateEmptyStateVisibility];

    // Apply initial theme, appearance & settings
    [self applyThemeAndAppearance];
    [_editor message:SCI_SETSAVEPOINT];
}

- (void)applyThemeAndAppearance {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    BOOL isDark = [prefs isDarkModeActive];

    if (@available(macOS 10.14, *)) {
        if (prefs.themeMode == NPThemeModeLight) {
            self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        } else if (prefs.themeMode == NPThemeModeDark) {
            self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        } else {
            self.window.appearance = nil; // System Default: inherits from system
        }
        self.editor.appearance = self.window.effectiveAppearance;
        self.statusBar.appearance = self.window.effectiveAppearance;
        self.emptyOverlayView.appearance = self.window.effectiveAppearance;
    }

    self.window.backgroundColor = isDark ?
        [NSColor colorWithCalibratedRed:0.12 green:0.12 blue:0.12 alpha:1.0] : [NSColor whiteColor];

    [self.editor np_applyDefaultTheme];
    [self.statusBar setNeedsDisplay:YES];
    [self.emptyOverlayView updateTheme];
    [self updateStatusBar];
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
        [self applyThemeAndAppearance];
    });
}

- (void)updateWindowTitle {
    NSString *fileName = self.filePath ? [self.filePath lastPathComponent] : @"Untitled";
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
    if (!self.editor || !self.statusBar) return;

    // 1. Line & Column (1-based) & Selection Metrics
    long pos = [self.editor getGeneralProperty:SCI_GETCURRENTPOS];
    long line = [self.editor getGeneralProperty:SCI_LINEFROMPOSITION parameter:pos] + 1;
    long col = [self.editor getGeneralProperty:SCI_GETCOLUMN parameter:pos] + 1;

    long selStart = [self.editor getGeneralProperty:SCI_GETSELECTIONSTART];
    long selEnd = [self.editor getGeneralProperty:SCI_GETSELECTIONEND];
    if (selEnd > selStart) {
        long startLine = [self.editor getGeneralProperty:SCI_LINEFROMPOSITION parameter:selStart];
        long endLine = [self.editor getGeneralProperty:SCI_LINEFROMPOSITION parameter:selEnd];
        long linesSelected = (endLine - startLine) + 1;
        long charsSelected = selEnd - selStart;
        [self.statusBar updateLine:line column:col selectedChars:charsSelected selectedLines:linesSelected];
    } else {
        [self.statusBar updateLine:line column:col];
    }

    // 2. Zoom Percentage
    long zoom = [self.editor getGeneralProperty:SCI_GETZOOM];
    long zoomPercent = 100 + (zoom * 10);
    [self.statusBar updateZoom:zoomPercent];

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
    if (self.encoding == NSISOLatin1StringEncoding || self.encoding == NSWindowsCP1252StringEncoding) {
        encName = @"ANSI";
    } else if (self.encoding == NSUTF16StringEncoding || self.encoding == NSUTF16LittleEndianStringEncoding) {
        encName = @"UTF-16 LE";
    } else if (self.encoding == NSUTF16BigEndianStringEncoding) {
        encName = @"UTF-16 BE";
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
    [self updateStatusBar];
    [self updateWindowTitle];
}

- (void)loadFile:(NSString *)path {
    [[NotepadFileManager sharedManager] openFileAtPath:path inController:self];
    [self updateEmptyStateVisibility];
}

- (void)updateEmptyStateVisibility {
    if (!self.editor || !_emptyOverlayView) return;
    long length = [self.editor message:SCI_GETLENGTH];
    BOOL isEmpty = (length == 0);

    if (isEmpty && _emptyOverlayView.isHidden) {
        _emptyOverlayView.alphaValue = 0.0;
        _emptyOverlayView.hidden = NO;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.15;
            self->_emptyOverlayView.animator.alphaValue = 1.0;
        }];
    } else if (!isEmpty && !_emptyOverlayView.isHidden) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.12;
            self->_emptyOverlayView.animator.alphaValue = 0.0;
        } completionHandler:^{
            if ([self.editor message:SCI_GETLENGTH] > 0) {
                self->_emptyOverlayView.hidden = YES;
            }
        }];
    }
}

#pragma mark - Scintilla Notifications

- (BOOL)isDirty {
    if (!self.editor) return NO;
    return [self.editor getGeneralProperty:SCI_GETMODIFY] != 0;
}

- (void)setIsDirty:(BOOL)isDirty {
    if (!isDirty && self.editor) {
        [self.editor message:SCI_SETSAVEPOINT];
    }
    [self updateWindowTitle];
}

#pragma mark - Scintilla Notifications

- (void)notification:(SCNotification *)notification {
    if (!notification) return;

    switch (notification->nmhdr.code) {
        case SCN_SAVEPOINTREACHED:
        case SCN_SAVEPOINTLEFT:
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
        default:
            break;
    }
}

#pragma mark - Window Delegate

- (BOOL)windowShouldClose:(NSWindow *)sender {
    if (!self.isDirty) {
        return YES;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"Do you want to save changes to \"%@\"?",
                         self.filePath ? [self.filePath lastPathComponent] : @"Untitled"];
    alert.informativeText = @"Your changes will be lost if you don't save them.";
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Don't Save"];
    [alert addButtonWithTitle:@"Cancel"];

    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        return [self saveFile];
    } else if (response == NSAlertSecondButtonReturn) {
        return YES;
    } else {
        return NO;
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
    if ([appDelegate respondsToSelector:@selector(removeWindowController:)]) {
        [appDelegate removeWindowController:self];
    }
}

#pragma mark - Actions

- (IBAction)newDocument:(nullable id)sender {
    AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
    [appDelegate newDocument:sender];
}

- (IBAction)newWindow:(nullable id)sender {
    AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
    [appDelegate newWindow:sender];
}

- (IBAction)openDocument:(nullable id)sender {
    [[NotepadFileManager sharedManager] openDocumentInController:self];
}

- (BOOL)saveFile {
    return [[NotepadFileManager sharedManager] saveController:self];
}

- (BOOL)saveFileAs {
    return [[NotepadFileManager sharedManager] saveAsController:self];
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
    [self runPageLayout:sender];
}

- (IBAction)runPageLayout:(nullable id)sender {
    NSPageLayout *pageLayout = [NSPageLayout pageLayout];
    [pageLayout beginSheetWithPrintInfo:[NSPrintInfo sharedPrintInfo]
                         modalForWindow:self.window
                               delegate:nil
                         didEndSelector:NULL
                            contextInfo:NULL];
}

- (IBAction)printDocument:(nullable id)sender {
    NSPrintInfo *printInfo = [NSPrintInfo sharedPrintInfo];
    [printInfo setHorizontalPagination:NSPrintingPaginationModeFit];
    [printInfo setVerticalPagination:NSPrintingPaginationModeAutomatic];

    NSRect printRect = NSMakeRect(0, 0, printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin,
                                       printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin);
    NSTextView *printView = [[NSTextView alloc] initWithFrame:printRect];
    NSString *text = [self.editor np_text];
    NSString *fontName = [self.editor np_fontName];
    NSInteger fontSize = [self.editor np_fontSize];
    NSFont *font = [NSFont fontWithName:fontName size:fontSize] ?: [NSFont monospacedSystemFontOfSize:11.0 weight:NSFontWeightRegular];
    [printView setFont:font];
    [printView setString:text ?: @""];
    [printView setHorizontallyResizable:NO];
    [printView setVerticallyResizable:YES];
    [[printView textContainer] setWidthTracksTextView:YES];
    [[printView textContainer] setContainerSize:NSMakeSize(printRect.size.width, CGFLOAT_MAX)];

    NSPrintOperation *op = [NSPrintOperation printOperationWithView:printView printInfo:printInfo];
    [op setShowsPrintPanel:YES];
    [op setShowsProgressPanel:YES];
    [op runOperationModalForWindow:self.window delegate:nil didRunSelector:NULL contextInfo:NULL];
}

- (IBAction)undo:(nullable id)sender {
    [self.editor message:SCI_UNDO];
    [self updateStatusBar];
}

- (IBAction)redo:(nullable id)sender {
    [self.editor message:SCI_REDO];
    [self updateStatusBar];
}

- (IBAction)cut:(nullable id)sender {
    [self.editor message:SCI_CUT];
    [self updateStatusBar];
}

- (IBAction)copy:(nullable id)sender {
    [self.editor message:SCI_COPY];
}

- (IBAction)paste:(nullable id)sender {
    [self.editor message:SCI_PASTE];
    [self updateStatusBar];
}

- (IBAction)delete:(nullable id)sender {
    if ([self.editor getGeneralProperty:SCI_GETSELECTIONSTART] != [self.editor getGeneralProperty:SCI_GETSELECTIONEND]) {
        [self.editor message:SCI_CLEAR];
    } else {
        [self.editor message:SCI_DELETEBACK];
    }
}

- (IBAction)selectAll:(nullable id)sender {
    [self.editor message:SCI_SELECTALL];
}

- (IBAction)showFind:(nullable id)sender {
    [[FindReplaceController sharedController] showForEditor:self.editor];
}

- (IBAction)showReplace:(nullable id)sender {
    [[FindReplaceController sharedController] showReplaceForEditor:self.editor];
}

- (IBAction)findNext:(nullable id)sender {
    FindReplaceController *frc = [FindReplaceController sharedController];
    frc.editor = self.editor;
    [frc findNext];
}

- (IBAction)findPrevious:(nullable id)sender {
    FindReplaceController *frc = [FindReplaceController sharedController];
    frc.editor = self.editor;
    [frc findPrevious];
}

- (IBAction)goToLine:(nullable id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Go To Line";
    alert.informativeText = @"Enter line number:";
    [alert addButtonWithTitle:@"Go To"];
    [alert addButtonWithTitle:@"Cancel"];

    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"1";
    alert.accessoryView = input;
    [alert.window setInitialFirstResponder:input];

    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            NSInteger line = [input.stringValue integerValue];
            if (line > 0) {
                [self.editor message:SCI_GOTOLINE wParam:line - 1 lParam:0];
                [self.editor message:SCI_SCROLLCARET];
                [self updateStatusBar];
            }
        }
    }];
}

// Windows Notepad F5 signature feature
- (IBAction)insertTimeDate:(nullable id)sender {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"h:mm a M/d/yyyy"];
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
    if (dateStr) {
        [self.editor message:SCI_REPLACESEL wParam:0 lParam:(sptr_t)[dateStr UTF8String]];
        [self.editor message:SCI_SCROLLCARET];
        [self updateStatusBar];
    }
}

- (IBAction)toggleWordWrap:(nullable id)sender {
    BOOL current = [self.editor np_wordWrap];
    [self.editor np_setWordWrap:!current];
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.wordWrap = !current;
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
    [self.editor message:SCI_ZOOMIN];
    [self updateStatusBar];
}

- (IBAction)zoomOut:(nullable id)sender {
    [self.editor message:SCI_ZOOMOUT];
    [self updateStatusBar];
}

- (IBAction)restoreDefaultZoom:(nullable id)sender {
    [self.editor setGeneralProperty:SCI_SETZOOM value:0];
    [self updateStatusBar];
}

- (IBAction)toggleStatusBar:(nullable id)sender {
    BOOL isHidden = self.statusBar.isHidden;
    self.statusBar.hidden = !isHidden;
    [self layoutSubviews];
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.showStatusBar = isHidden;
    [prefs savePreferences];
}

- (void)layoutSubviews {
    if (!self.editor || !self.statusBar) return;
    NSRect bounds = self.window.contentView.bounds;
    BOOL showStatusBar = !self.statusBar.isHidden;
    CGFloat sbHeight = showStatusBar ? 24.0 : 0.0;
    self.statusBar.frame = NSMakeRect(0, 0, bounds.size.width, sbHeight);
    self.editor.frame = NSMakeRect(0, sbHeight, bounds.size.width, bounds.size.height - sbHeight);
    if (self.emptyOverlayView) {
        self.emptyOverlayView.frame = self.editor.frame;
    }
}

- (IBAction)toggleLineNumbers:(nullable id)sender {
    BOOL current = [self.editor np_lineNumbersVisible];
    [self.editor np_setLineNumbersVisible:!current];
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.showLineNumbers = !current;
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

#pragma mark - Menu Item Validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = menuItem.action;
    if (action == @selector(saveDocument:)) {
        return self.isDirty || self.filePath == nil;
    }
    if (action == @selector(saveDocumentAs:)) {
        return YES;
    }
    if (action == @selector(revertDocument:)) {
        return self.filePath != nil && self.isDirty;
    }
    if (action == @selector(undo:)) {
        return [self.editor message:SCI_CANUNDO] != 0;
    }
    if (action == @selector(redo:)) {
        return [self.editor message:SCI_CANREDO] != 0;
    }
    if (action == @selector(cut:) || action == @selector(copy:)) {
        return [self.editor getGeneralProperty:SCI_GETSELECTIONSTART] != [self.editor getGeneralProperty:SCI_GETSELECTIONEND];
    }
    if (action == @selector(paste:)) {
        return [self.editor message:SCI_CANPASTE] != 0;
    }
    if (action == @selector(delete:)) {
        return [self.editor message:SCI_GETLENGTH] > 0;
    }
    if (action == @selector(selectAll:)) {
        return [self.editor message:SCI_GETLENGTH] > 0;
    }
    if (action == @selector(toggleWordWrap:)) {
        menuItem.state = [self.editor np_wordWrap] ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    if (action == @selector(toggleStatusBar:)) {
        menuItem.state = self.statusBar.isHidden ? NSControlStateValueOff : NSControlStateValueOn;
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
    if (action == @selector(restoreDefaultZoom:)) {
        return [self.editor getGeneralProperty:SCI_GETZOOM] != 0;
    }
    if (action == @selector(runPageSpec:) || action == @selector(runPageLayout:)) {
        return YES;
    }
    if (action == @selector(printDocument:)) {
        return YES;
    }
    return YES;
}

@end
