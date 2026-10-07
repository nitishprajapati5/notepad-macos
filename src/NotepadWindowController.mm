#import "NotepadWindowController.h"
#import "AppDelegate.h"
#import "ScintillaView+Notepad.h"
#import "StatusBarView.h"
#import "FindReplaceController.h"
#import "PreferencesManager.h"
#import "Scintilla.h"

@interface NotepadWindowController ()
@property (nonatomic, strong) NSLayoutConstraint *statusBarHeightConstraint;
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
    win.backgroundColor = [NSColor whiteColor];
    if (@available(macOS 10.14, *)) {
        win.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    }
    [win setFrameAutosaveName:@"NotepadMainWindow"];

    self = [super initWithWindow:win];
    if (self) {
        _filePath = [filePath copy];
        _isDirty = NO;
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

    // Scintilla Editor (takes entire top area down to status bar)
    _editor = [[ScintillaView alloc] initWithFrame:contentView.bounds];
    _editor.translatesAutoresizingMaskIntoConstraints = NO;
    _editor.delegate = self;
    [contentView addSubview:_editor];

    // Status Bar (pinned to bottom like Windows Notepad)
    _statusBar = [[StatusBarView alloc] initWithFrame:NSMakeRect(0, 0, contentView.bounds.size.width, 24)];
    _statusBar.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:_statusBar];

    _statusBarHeightConstraint = [_statusBar.heightAnchor constraintEqualToConstant:24.0];

    [NSLayoutConstraint activateConstraints:@[
        [_editor.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [_editor.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [_editor.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [_editor.bottomAnchor constraintEqualToAnchor:_statusBar.topAnchor],

        [_statusBar.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [_statusBar.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [_statusBar.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
        _statusBarHeightConstraint
    ]];

    // Apply default theme and initial editor settings
    [_editor np_applyDefaultTheme];
    [_editor message:SCI_SETSAVEPOINT];
}

- (void)handleAppearanceChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.editor np_applyDefaultTheme];
        [self.statusBar setNeedsDisplay:YES];
    });
}

- (void)handlePreferencesChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.editor np_applyDefaultTheme];
        [self updateStatusBar];
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

    // 1. Line & Column (1-based)
    long pos = [self.editor getGeneralProperty:SCI_GETCURRENTPOS];
    long line = [self.editor getGeneralProperty:SCI_LINEFROMPOSITION parameter:pos] + 1;
    long col = [self.editor getGeneralProperty:SCI_GETCOLUMN parameter:pos] + 1;
    [self.statusBar updateLine:line column:col];

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
    if (self.encoding == NSISOLatin1StringEncoding) {
        encName = @"ANSI";
    } else if (self.encoding == NSUTF16StringEncoding) {
        encName = @"UTF-16 LE";
    } else if (self.encoding == NSUTF16BigEndianStringEncoding) {
        encName = @"UTF-16 BE";
    }
    [self.statusBar setEncodingName:encName];
}

- (void)loadFile:(NSString *)path {
    NSError *error = nil;
    NSStringEncoding usedEncoding = NSUTF8StringEncoding;
    NSString *content = [NSString stringWithContentsOfFile:path
                                               usedEncoding:&usedEncoding
                                                      error:&error];
    if (!content) {
        content = [NSString stringWithContentsOfFile:path
                                            encoding:NSISOLatin1StringEncoding
                                               error:&error];
        usedEncoding = NSISOLatin1StringEncoding;
    }

    if (content) {
        self.encoding = usedEncoding;
        self.filePath = path;
        [self.editor np_setText:content];

        // Detect EOL from file content
        if ([content containsString:@"\r\n"]) {
            [self.editor message:SCI_SETEOLMODE wParam:SC_EOL_CRLF lParam:0];
        } else if ([content containsString:@"\n"]) {
            [self.editor message:SCI_SETEOLMODE wParam:SC_EOL_LF lParam:0];
        } else if ([content containsString:@"\r"]) {
            [self.editor message:SCI_SETEOLMODE wParam:SC_EOL_CR lParam:0];
        }

        [self.editor message:SCI_SETSAVEPOINT];
        self.isDirty = NO;
        [self updateWindowTitle];
        [self updateStatusBar];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Could not open file";
        alert.informativeText = error.localizedDescription ?: @"Unknown error occurred.";
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
    }
}

#pragma mark - Scintilla Notifications

- (void)notification:(SCNotification *)notification {
    if (!notification) return;

    switch (notification->nmhdr.code) {
        case SCN_SAVEPOINTREACHED:
            self.isDirty = NO;
            [self updateWindowTitle];
            break;
        case SCN_SAVEPOINTLEFT:
            self.isDirty = YES;
            [self updateWindowTitle];
            break;
        case SCN_UPDATEUI:
            [self updateStatusBar];
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
    AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
    [appDelegate openDocument:sender];
}

- (BOOL)saveFile {
    if (!self.filePath) {
        return [self saveFileAs];
    }

    NSString *content = [self.editor np_text];
    NSError *error = nil;
    BOOL success = [content writeToFile:self.filePath
                             atomically:YES
                               encoding:self.encoding
                                  error:&error];

    if (success) {
        [self.editor message:SCI_SETSAVEPOINT];
        self.isDirty = NO;
        [self updateWindowTitle];
        return YES;
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Save Failed";
        alert.informativeText = error.localizedDescription ?: @"Could not save document.";
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
        return NO;
    }
}

- (BOOL)saveFileAs {
    NSSavePanel *panel = [NSSavePanel savePanel];
    if (self.filePath) {
        panel.directoryURL = [NSURL fileURLWithPath:[self.filePath stringByDeletingLastPathComponent]];
        panel.nameFieldStringValue = [self.filePath lastPathComponent];
    } else {
        panel.nameFieldStringValue = @"Untitled.txt";
    }

    NSModalResponse result = [panel runModal];
    if (result == NSModalResponseOK && panel.URL.path) {
        self.filePath = panel.URL.path;
        return [self saveFile];
    }
    return NO;
}

- (IBAction)saveDocument:(nullable id)sender {
    [self saveFile];
}

- (IBAction)saveDocumentAs:(nullable id)sender {
    [self saveFileAs];
}

- (IBAction)printDocument:(nullable id)sender {
    NSPrintInfo *printInfo = [NSPrintInfo sharedPrintInfo];
    NSPrintOperation *op = [NSPrintOperation printOperationWithView:self.editor printInfo:printInfo];
    [op runOperationModalForWindow:self.window delegate:nil didRunSelector:NULL contextInfo:NULL];
}

- (IBAction)showFind:(nullable id)sender {
    if (!_findReplaceController) {
        _findReplaceController = [[FindReplaceController alloc] init];
    }
    [_findReplaceController showForEditor:self.editor];
}

- (IBAction)showReplace:(nullable id)sender {
    [self showFind:sender];
}

- (IBAction)findNext:(nullable id)sender {
    if (_findReplaceController) {
        [_findReplaceController findNext];
    } else {
        [self showFind:sender];
    }
}

- (IBAction)findPrevious:(nullable id)sender {
    if (_findReplaceController) {
        [_findReplaceController findPrevious];
    } else {
        [self showFind:sender];
    }
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
    [self.editor insertText:dateStr];
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
    _statusBarHeightConstraint.constant = isHidden ? 24.0 : 0.0;
    [self.window.contentView layoutSubtreeIfNeeded];
}

@end
