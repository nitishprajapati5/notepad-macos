#import "NotepadWindowController.h"
#import "ScintillaView+Notepad.h"
#import "StatusBarView.h"
#import "FindReplaceController.h"
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

    self = [super initWithWindow:win];
    if (self) {
        _filePath = [filePath copy];
        _isDirty = NO;
        _encoding = NSUTF8StringEncoding;
        win.delegate = self;

        [self setupUIInWindow:win];
        [self updateWindowTitle];
        [self updateStatusBar];

        if (_filePath) {
            [self loadFile:_filePath];
        }
    }
    return self;
}

- (void)setupUIInWindow:(NSWindow *)window {
    NSView *contentView = window.contentView;

    // Scintilla Editor
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

    [_editor np_applyDefaultTheme];
    // Plain text Notepad: default without margin numbers, word wrap off
    [_editor np_setLineNumbersVisible:NO];
    [_editor np_setWordWrap:NO];
}

- (void)updateWindowTitle {
    NSString *fileName = self.filePath ? [self.filePath lastPathComponent] : @"Untitled";
    NSString *title = [NSString stringWithFormat:@"%@ - Notepad", fileName];
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

    // 1. Line & Column
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

    if (notification->nmhdr.code == SCN_MODIFIED) {
        int modType = notification->modificationType;
        if ((modType & SC_MOD_INSERTTEXT) || (modType & SC_MOD_DELETETEXT)) {
            if (!self.isDirty) {
                self.isDirty = YES;
                [self updateWindowTitle];
            }
        }
    } else if (notification->nmhdr.code == SCN_UPDATEUI) {
        [self updateStatusBar];
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

#pragma mark - Actions

- (IBAction)newDocument:(nullable id)sender {
    NotepadWindowController *newController = [[NotepadWindowController alloc] initWithFilePath:nil];
    [newController showWindow:nil];
}

- (IBAction)newWindow:(nullable id)sender {
    [self newDocument:sender];
}

- (IBAction)openDocument:(nullable id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;

    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && panel.URL.path) {
            if (!self.filePath && !self.isDirty && [self.editor np_text].length == 0) {
                [self loadFile:panel.URL.path];
            } else {
                NotepadWindowController *wc = [[NotepadWindowController alloc] initWithFilePath:panel.URL.path];
                [wc showWindow:nil];
            }
        }
    }];
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
    [alert addButtonWithTitle:@"Go"];
    [alert addButtonWithTitle:@"Cancel"];

    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"1";
    alert.accessoryView = input;

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
}

- (IBAction)chooseFont:(nullable id)sender {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    [fontManager orderFrontFontPanel:self];
}

- (void)changeFont:(id)sender {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSFont *font = [fontManager convertFont:[NSFont systemFontOfSize:13.0]];
    if (font) {
        [self.editor setStringProperty:SCI_STYLESETFONT parameter:STYLE_DEFAULT value:font.familyName];
        [self.editor setGeneralProperty:SCI_STYLESETSIZE parameter:STYLE_DEFAULT value:(long)font.pointSize];
        [self.editor message:SCI_STYLECLEARALL];
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
}

@end
