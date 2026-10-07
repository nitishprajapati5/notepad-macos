#import "FindReplaceController.h"
#import "ScintillaView.h"
#import "Scintilla.h"

@interface FindReplaceController ()
@property (nonatomic, strong) NSTextField *findField;
@property (nonatomic, strong) NSTextField *replaceField;
@property (nonatomic, strong) NSButton *caseSensitiveCheck;
@property (nonatomic, strong) NSButton *wholeWordCheck;
@property (nonatomic, strong) NSButton *wrapAroundCheck;
@end

@implementation FindReplaceController

- (instancetype)init {
    NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(200, 200, 380, 220)
                                                styleMask:NSWindowStyleMaskTitled |
                                                          NSWindowStyleMaskClosable |
                                                          NSWindowStyleMaskUtilityWindow
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    [panel setTitle:@"Find & Replace"];
    [panel setFloatingPanel:YES];

    self = [super initWithWindow:panel];
    if (self) {
        [self setupUIInPanel:panel];
    }
    return self;
}

- (void)setupUIInPanel:(NSPanel *)panel {
    NSView *cv = panel.contentView;

    NSTextField *findLabel = [NSTextField labelWithString:@"Find:"];
    findLabel.frame = NSMakeRect(20, 170, 70, 20);
    [cv addSubview:findLabel];

    _findField = [[NSTextField alloc] initWithFrame:NSMakeRect(95, 168, 260, 24)];
    [cv addSubview:_findField];

    NSTextField *replaceLabel = [NSTextField labelWithString:@"Replace:"];
    replaceLabel.frame = NSMakeRect(20, 134, 70, 20);
    [cv addSubview:replaceLabel];

    _replaceField = [[NSTextField alloc] initWithFrame:NSMakeRect(95, 132, 260, 24)];
    [cv addSubview:_replaceField];

    _caseSensitiveCheck = [NSButton checkboxWithTitle:@"Match Case" target:nil action:nil];
    _caseSensitiveCheck.frame = NSMakeRect(20, 98, 120, 20);
    [cv addSubview:_caseSensitiveCheck];

    _wholeWordCheck = [NSButton checkboxWithTitle:@"Whole Word" target:nil action:nil];
    _wholeWordCheck.frame = NSMakeRect(145, 98, 110, 20);
    [cv addSubview:_wholeWordCheck];

    _wrapAroundCheck = [NSButton checkboxWithTitle:@"Wrap Around" target:nil action:nil];
    _wrapAroundCheck.state = NSControlStateValueOn;
    _wrapAroundCheck.frame = NSMakeRect(260, 98, 110, 20);
    [cv addSubview:_wrapAroundCheck];

    NSButton *btnFindNext = [NSButton buttonWithTitle:@"Find Next" target:self action:@selector(findNext)];
    btnFindNext.frame = NSMakeRect(20, 50, 100, 32);
    [cv addSubview:btnFindNext];

    NSButton *btnReplace = [NSButton buttonWithTitle:@"Replace" target:self action:@selector(replaceAndFindNext)];
    btnReplace.frame = NSMakeRect(130, 50, 95, 32);
    [cv addSubview:btnReplace];

    NSButton *btnReplaceAll = [NSButton buttonWithTitle:@"Replace All" target:self action:@selector(replaceAll)];
    btnReplaceAll.frame = NSMakeRect(235, 50, 105, 32);
    [cv addSubview:btnReplaceAll];

    NSButton *btnClose = [NSButton buttonWithTitle:@"Close" target:panel action:@selector(performClose:)];
    btnClose.frame = NSMakeRect(255, 12, 85, 30);
    [cv addSubview:btnClose];
}

- (void)showForEditor:(nullable ScintillaView *)editor {
    self.editor = editor;
    [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:_findField];
}

- (void)findNext {
    if (!self.editor || _findField.stringValue.length == 0) return;
    [self.editor findAndHighlightText:_findField.stringValue
                            matchCase:(_caseSensitiveCheck.state == NSControlStateValueOn)
                            wholeWord:(_wholeWordCheck.state == NSControlStateValueOn)
                             scrollTo:YES
                                 wrap:(_wrapAroundCheck.state == NSControlStateValueOn)
                            backwards:NO];
}

- (void)findPrevious {
    if (!self.editor || _findField.stringValue.length == 0) return;
    [self.editor findAndHighlightText:_findField.stringValue
                            matchCase:(_caseSensitiveCheck.state == NSControlStateValueOn)
                            wholeWord:(_wholeWordCheck.state == NSControlStateValueOn)
                             scrollTo:YES
                                 wrap:(_wrapAroundCheck.state == NSControlStateValueOn)
                            backwards:YES];
}

- (void)replaceAndFindNext {
    if (!self.editor || _findField.stringValue.length == 0) return;
    [self.editor findAndReplaceText:_findField.stringValue
                             byText:_replaceField.stringValue ?: @""
                          matchCase:(_caseSensitiveCheck.state == NSControlStateValueOn)
                          wholeWord:(_wholeWordCheck.state == NSControlStateValueOn)
                              doAll:NO];
    [self findNext];
}

- (void)replaceAll {
    if (!self.editor || _findField.stringValue.length == 0) return;
    [self.editor findAndReplaceText:_findField.stringValue
                             byText:_replaceField.stringValue ?: @""
                          matchCase:(_caseSensitiveCheck.state == NSControlStateValueOn)
                          wholeWord:(_wholeWordCheck.state == NSControlStateValueOn)
                              doAll:YES];
}

@end
