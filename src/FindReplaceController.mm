#import "FindReplaceController.h"
#import "ScintillaView.h"
#import "Scintilla.h"
#include <vector>

static const int kFindIndicator = 28;
static const int kCurrentMatchIndicator = 29;

@interface FindReplaceController ()
@property (nonatomic, strong) NSTextField *findField;
@property (nonatomic, strong) NSTextField *replaceField;
@property (nonatomic, strong) NSButton *caseSensitiveCheck;
@property (nonatomic, strong) NSButton *wholeWordCheck;
@property (nonatomic, strong) NSButton *wrapAroundCheck;
@property (nonatomic, strong) NSButton *regexCheck;
@property (nonatomic, strong) NSTextField *statusLabel;

@property (nonatomic, strong) NSArray<NSValue *> *cachedMatches;
@property (nonatomic, assign) NSInteger currentMatchIndex;
@end

@implementation FindReplaceController

+ (instancetype)sharedController {
    static FindReplaceController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FindReplaceController alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(240, 260, 440, 245)
                                                styleMask:NSWindowStyleMaskTitled |
                                                          NSWindowStyleMaskClosable |
                                                          NSWindowStyleMaskUtilityWindow
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    [panel setTitle:@"Find & Replace"];
    [panel setHidesOnDeactivate:NO];
    [panel setFloatingPanel:YES];
    [panel setBecomesKeyOnlyIfNeeded:NO];

    self = [super initWithWindow:panel];
    if (self) {
        panel.delegate = self;
        _currentMatchIndex = -1;
        _cachedMatches = @[];
        [self setupUIInPanel:panel];
    }
    return self;
}

- (void)setupUIInPanel:(NSPanel *)panel {
    NSView *cv = panel.contentView;

    // 1. Find Field
    NSTextField *findLabel = [NSTextField labelWithString:@"Find:"];
    findLabel.frame = NSMakeRect(18, 204, 65, 18);
    findLabel.alignment = NSTextAlignmentRight;
    findLabel.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightMedium];
    [cv addSubview:findLabel];

    _findField = [[NSTextField alloc] initWithFrame:NSMakeRect(88, 201, 334, 24)];
    _findField.placeholderString = @"Search text or regular expression";
    _findField.delegate = self;
    _findField.target = self;
    _findField.action = @selector(findFieldAction:);
    [cv addSubview:_findField];

    // 2. Replace Field
    NSTextField *replaceLabel = [NSTextField labelWithString:@"Replace:"];
    replaceLabel.frame = NSMakeRect(18, 170, 65, 18);
    replaceLabel.alignment = NSTextAlignmentRight;
    replaceLabel.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightMedium];
    [cv addSubview:replaceLabel];

    _replaceField = [[NSTextField alloc] initWithFrame:NSMakeRect(88, 167, 334, 24)];
    _replaceField.placeholderString = @"Replacement text (e.g. $1 or \\1 for captures)";
    _replaceField.delegate = self;
    _replaceField.target = self;
    _replaceField.action = @selector(replaceAndFindNext);
    [cv addSubview:_replaceField];

    // 3. Option Checkboxes (Row 1)
    _caseSensitiveCheck = [NSButton checkboxWithTitle:@"Match Case" target:self action:@selector(optionsChanged:)];
    _caseSensitiveCheck.frame = NSMakeRect(88, 137, 100, 18);
    _caseSensitiveCheck.font = [NSFont systemFontOfSize:11.5];
    [cv addSubview:_caseSensitiveCheck];

    _wholeWordCheck = [NSButton checkboxWithTitle:@"Whole Word" target:self action:@selector(optionsChanged:)];
    _wholeWordCheck.frame = NSMakeRect(196, 137, 100, 18);
    _wholeWordCheck.font = [NSFont systemFontOfSize:11.5];
    [cv addSubview:_wholeWordCheck];

    _wrapAroundCheck = [NSButton checkboxWithTitle:@"Wrap Around" target:self action:@selector(optionsChanged:)];
    _wrapAroundCheck.state = NSControlStateValueOn;
    _wrapAroundCheck.frame = NSMakeRect(308, 137, 105, 18);
    _wrapAroundCheck.font = [NSFont systemFontOfSize:11.5];
    [cv addSubview:_wrapAroundCheck];

    // Option Checkboxes (Row 2: Regex)
    _regexCheck = [NSButton checkboxWithTitle:@"Regular Expression" target:self action:@selector(optionsChanged:)];
    _regexCheck.frame = NSMakeRect(88, 114, 150, 18);
    _regexCheck.font = [NSFont systemFontOfSize:11.5];
    [cv addSubview:_regexCheck];

    // 4. Status & Match Counter Label
    _statusLabel = [NSTextField labelWithString:@""];
    _statusLabel.frame = NSMakeRect(88, 86, 334, 18);
    _statusLabel.font = [NSFont monospacedDigitSystemFontOfSize:11.5 weight:NSFontWeightRegular];
    _statusLabel.textColor = [NSColor secondaryLabelColor];
    [cv addSubview:_statusLabel];

    // 5. Action Buttons (Bottom Bar)
    NSButton *btnFindNext = [NSButton buttonWithTitle:@"Find Next" target:self action:@selector(findNext)];
    btnFindNext.frame = NSMakeRect(14, 16, 82, 30);
    btnFindNext.keyEquivalent = @"\r"; // Enter triggers Find Next
    [cv addSubview:btnFindNext];

    NSButton *btnFindPrev = [NSButton buttonWithTitle:@"Find Prev" target:self action:@selector(findPrevious)];
    btnFindPrev.frame = NSMakeRect(98, 16, 82, 30);
    [cv addSubview:btnFindPrev];

    NSButton *btnReplace = [NSButton buttonWithTitle:@"Replace" target:self action:@selector(replaceAndFindNext)];
    btnReplace.frame = NSMakeRect(182, 16, 76, 30);
    [cv addSubview:btnReplace];

    NSButton *btnReplaceAll = [NSButton buttonWithTitle:@"Replace All" target:self action:@selector(replaceAll)];
    btnReplaceAll.frame = NSMakeRect(260, 16, 92, 30);
    [cv addSubview:btnReplaceAll];

    NSButton *btnClose = [NSButton buttonWithTitle:@"Close" target:self action:@selector(closePanel)];
    btnClose.frame = NSMakeRect(354, 16, 72, 30);
    btnClose.keyEquivalent = @"\e"; // Esc triggers Close
    [cv addSubview:btnClose];

    // Key view loop for tab navigation
    _findField.nextKeyView = _replaceField;
    _replaceField.nextKeyView = _caseSensitiveCheck;
    _caseSensitiveCheck.nextKeyView = _wholeWordCheck;
    _wholeWordCheck.nextKeyView = _wrapAroundCheck;
    _wrapAroundCheck.nextKeyView = _regexCheck;
    _regexCheck.nextKeyView = btnFindNext;
    btnFindNext.nextKeyView = btnFindPrev;
    btnFindPrev.nextKeyView = btnReplace;
    btnReplace.nextKeyView = btnReplaceAll;
    btnReplaceAll.nextKeyView = btnClose;
    btnClose.nextKeyView = _findField;
}

#pragma mark - Presentation

- (void)showForEditor:(nullable ScintillaView *)editor {
    self.editor = editor;
    [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:_findField];

    // If single-line text is selected in editor, populate find field
    if (editor) {
        long selStart = [editor getGeneralProperty:SCI_GETSELECTIONSTART];
        long selEnd = [editor getGeneralProperty:SCI_GETSELECTIONEND];
        if (selEnd > selStart && (selEnd - selStart) < 300) {
            long len = [editor message:SCI_GETSELTEXT wParam:0 lParam:0];
            if (len > 1) {
                std::vector<char> buf(len + 1, 0);
                [editor message:SCI_GETSELTEXT wParam:0 lParam:(sptr_t)buf.data()];
                NSString *selectedText = [NSString stringWithUTF8String:buf.data()];
                if (selectedText.length > 0 && ![selectedText containsString:@"\n"] && ![selectedText containsString:@"\r"]) {
                    _findField.stringValue = selectedText;
                    [_findField selectText:nil];
                }
            }
        }
    }

    [self updateMatchesAndHighlight:YES];
}

- (void)showReplaceForEditor:(nullable ScintillaView *)editor {
    [self showForEditor:editor];
    [self.window makeFirstResponder:_replaceField];
}

- (void)closePanel {
    [self clearHighlights];
    [self.window performClose:nil];
    if (self.editor) {
        [self.editor.window makeKeyWindow];
        [self.editor.window makeFirstResponder:self.editor];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    [self clearHighlights];
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)obj {
    [self updateMatchesAndHighlight:YES];
}

- (void)findFieldAction:(id)sender {
    NSEvent *currentEvent = [NSApp currentEvent];
    if ((currentEvent.modifierFlags & NSEventModifierFlagShift) != 0) {
        [self findPrevious];
    } else {
        [self findNext];
    }
}

- (void)optionsChanged:(id)sender {
    BOOL isRegex = (_regexCheck.state == NSControlStateValueOn);
    _wholeWordCheck.enabled = !isRegex;
    [self updateMatchesAndHighlight:YES];
}

#pragma mark - Regex & Search Flags

- (BOOL)isRegexValid:(NSString *)pattern error:(NSString * _Nullable * _Nullable)outError {
    if (pattern.length == 0) return YES;
    NSError *err = nil;
    NSRegularExpressionOptions opts = 0;
    if (_caseSensitiveCheck.state == NSControlStateValueOff) {
        opts |= NSRegularExpressionCaseInsensitive;
    }
    [NSRegularExpression regularExpressionWithPattern:pattern options:opts error:&err];
    if (err) {
        if (outError) *outError = err.localizedDescription;
        return NO;
    }
    return YES;
}

- (int)currentSearchFlags {
    int flags = 0;
    if (_caseSensitiveCheck.state == NSControlStateValueOn) {
        flags |= SCFIND_MATCHCASE;
    }
    if (_regexCheck.state == NSControlStateValueOn) {
        flags |= (SCFIND_REGEXP | SCFIND_CXX11REGEX);
    } else {
        if (_wholeWordCheck.state == NSControlStateValueOn) {
            flags |= SCFIND_WHOLEWORD;
        }
    }
    return flags;
}

- (NSString *)scintillaRegexReplacementString:(NSString *)replacement {
    if (replacement.length == 0) return @"";
    NSMutableString *result = [NSMutableString string];
    NSUInteger len = replacement.length;
    for (NSUInteger i = 0; i < len; i++) {
        unichar c = [replacement characterAtIndex:i];
        if (c == '$' && i + 1 < len) {
            unichar next = [replacement characterAtIndex:i + 1];
            if (next >= '0' && next <= '9') {
                [result appendFormat:@"\\%C", next];
                i++;
                continue;
            } else if (next == '&') {
                [result appendString:@"\\0"];
                i++;
                continue;
            } else if (next == '$') {
                [result appendString:@"$"];
                i++;
                continue;
            }
        }
        [result appendFormat:@"%C", c];
    }
    return result;
}

#pragma mark - Highlight & Indicator Setup

- (void)setupIndicatorsInEditor:(ScintillaView *)editor {
    if (!editor) return;

    // Indicator 28: All document matches (amber/gold translucent box)
    [editor message:SCI_INDICSETSTYLE wParam:kFindIndicator lParam:INDIC_ROUNDBOX];
    [editor message:SCI_INDICSETFORE wParam:kFindIndicator lParam:0x00BEFF]; // RGB(255, 190, 0)
    [editor message:SCI_INDICSETALPHA wParam:kFindIndicator lParam:75];
    [editor message:SCI_INDICSETOUTLINEALPHA wParam:kFindIndicator lParam:180];
    [editor message:SCI_INDICSETUNDER wParam:kFindIndicator lParam:1];

    // Indicator 29: Current active match (vibrant tangerine highlight)
    [editor message:SCI_INDICSETSTYLE wParam:kCurrentMatchIndicator lParam:INDIC_ROUNDBOX];
    [editor message:SCI_INDICSETFORE wParam:kCurrentMatchIndicator lParam:0x006EFF]; // RGB(255, 110, 0)
    [editor message:SCI_INDICSETALPHA wParam:kCurrentMatchIndicator lParam:160];
    [editor message:SCI_INDICSETOUTLINEALPHA wParam:kCurrentMatchIndicator lParam:255];
    [editor message:SCI_INDICSETUNDER wParam:kCurrentMatchIndicator lParam:1];
}

- (void)clearHighlights {
    if (!self.editor) return;
    long docLength = [self.editor message:SCI_GETLENGTH];
    if (docLength > 0) {
        [self.editor message:SCI_SETINDICATORCURRENT wParam:kFindIndicator lParam:0];
        [self.editor message:SCI_INDICATORCLEARRANGE wParam:0 lParam:docLength];
        [self.editor message:SCI_SETINDICATORCURRENT wParam:kCurrentMatchIndicator lParam:0];
        [self.editor message:SCI_INDICATORCLEARRANGE wParam:0 lParam:docLength];
    }
}

- (void)highlightCurrentMatch {
    if (!self.editor) return;
    long docLength = [self.editor message:SCI_GETLENGTH];
    if (docLength <= 0) return;

    [self.editor message:SCI_SETINDICATORCURRENT wParam:kCurrentMatchIndicator lParam:0];
    [self.editor message:SCI_INDICATORCLEARRANGE wParam:0 lParam:docLength];

    if (_currentMatchIndex >= 0 && _currentMatchIndex < (NSInteger)_cachedMatches.count) {
        NSRange r = [_cachedMatches[_currentMatchIndex] rangeValue];
        if (r.length > 0) {
            [self setupIndicatorsInEditor:self.editor];
            [self.editor message:SCI_SETINDICATORCURRENT wParam:kCurrentMatchIndicator lParam:0];
            [self.editor message:SCI_INDICATORFILLRANGE wParam:r.location lParam:r.length];
        }
    }
}

#pragma mark - Match Enumeration & Counter

- (void)updateMatchesAndHighlight:(BOOL)refreshIndicators {
    if (!self.editor) {
        _statusLabel.stringValue = @"";
        _cachedMatches = @[];
        _currentMatchIndex = -1;
        return;
    }

    NSString *query = _findField.stringValue;
    if (query.length == 0) {
        [self clearHighlights];
        _statusLabel.stringValue = @"";
        _cachedMatches = @[];
        _currentMatchIndex = -1;
        return;
    }

    BOOL isRegex = (_regexCheck.state == NSControlStateValueOn);
    if (isRegex) {
        NSString *regexErr = nil;
        if (![self isRegexValid:query error:&regexErr]) {
            [self clearHighlights];
            _statusLabel.stringValue = [NSString stringWithFormat:@"⚠️ Invalid Regex: %@", regexErr ?: @"Syntax error"];
            _statusLabel.textColor = [NSColor systemRedColor];
            _cachedMatches = @[];
            _currentMatchIndex = -1;
            return;
        }
    }

    _statusLabel.textColor = [NSColor secondaryLabelColor];

    int flags = [self currentSearchFlags];
    long docLength = [self.editor message:SCI_GETLENGTH];
    if (docLength == 0) {
        _statusLabel.stringValue = @"Document is empty";
        _cachedMatches = @[];
        _currentMatchIndex = -1;
        [self clearHighlights];
        return;
    }

    // Save target range & search flags before scanning
    long origTargetStart = [self.editor getGeneralProperty:SCI_GETTARGETSTART];
    long origTargetEnd = [self.editor getGeneralProperty:SCI_GETTARGETEND];
    long origFlags = [self.editor getGeneralProperty:SCI_GETSEARCHFLAGS];

    [self.editor message:SCI_SETSEARCHFLAGS wParam:flags lParam:0];

    NSMutableArray<NSValue *> *matches = [NSMutableArray array];
    const char *utf8Query = [query UTF8String];
    long queryLen = strlen(utf8Query);
    long searchPos = 0;

    while (searchPos < docLength && matches.count < 5000) {
        [self.editor message:SCI_SETTARGETSTART wParam:searchPos lParam:0];
        [self.editor message:SCI_SETTARGETEND wParam:docLength lParam:0];

        long pos = [self.editor message:SCI_SEARCHINTARGET wParam:queryLen lParam:(sptr_t)utf8Query];
        if (pos < 0) {
            break;
        }

        long mStart = [self.editor getGeneralProperty:SCI_GETTARGETSTART];
        long mEnd = [self.editor getGeneralProperty:SCI_GETTARGETEND];
        long mLen = mEnd - mStart;

        if (mLen > 0) {
            [matches addObject:[NSValue valueWithRange:NSMakeRange(mStart, mLen)]];
            searchPos = mEnd;
        } else {
            [matches addObject:[NSValue valueWithRange:NSMakeRange(mStart, 0)]];
            searchPos = mStart + 1;
        }
    }

    // Restore target & flags
    [self.editor message:SCI_SETTARGETSTART wParam:origTargetStart lParam:0];
    [self.editor message:SCI_SETTARGETEND wParam:origTargetEnd lParam:0];
    [self.editor message:SCI_SETSEARCHFLAGS wParam:origFlags lParam:0];

    _cachedMatches = [matches copy];

    // Apply indicators to all matches
    if (refreshIndicators) {
        [self setupIndicatorsInEditor:self.editor];
        [self.editor message:SCI_SETINDICATORCURRENT wParam:kFindIndicator lParam:0];
        [self.editor message:SCI_INDICATORCLEARRANGE wParam:0 lParam:docLength];
        for (NSValue *val in _cachedMatches) {
            NSRange r = [val rangeValue];
            if (r.length > 0) {
                [self.editor message:SCI_INDICATORFILLRANGE wParam:r.location lParam:r.length];
            }
        }
    }

    // Determine current match index based on selection
    long selStart = [self.editor getGeneralProperty:SCI_GETSELECTIONSTART];
    long selEnd = [self.editor getGeneralProperty:SCI_GETSELECTIONEND];
    _currentMatchIndex = -1;

    for (NSInteger i = 0; i < (NSInteger)_cachedMatches.count; i++) {
        NSRange r = [_cachedMatches[i] rangeValue];
        if ((long)r.location == selStart && (long)(r.location + r.length) == selEnd) {
            _currentMatchIndex = i;
            break;
        }
    }

    if (refreshIndicators) {
        [self highlightCurrentMatch];
    }

    if (_cachedMatches.count == 0) {
        _statusLabel.stringValue = @"No matches found";
        _statusLabel.textColor = [NSColor secondaryLabelColor];
    } else if (_currentMatchIndex >= 0) {
        _statusLabel.stringValue = [NSString stringWithFormat:@"%ld of %ld matches",
                                    (long)(_currentMatchIndex + 1), (long)_cachedMatches.count];
        _statusLabel.textColor = [NSColor controlTextColor];
    } else {
        _statusLabel.stringValue = [NSString stringWithFormat:@"%ld match%@ found",
                                    (long)_cachedMatches.count, _cachedMatches.count == 1 ? @"" : @"es"];
        _statusLabel.textColor = [NSColor secondaryLabelColor];
    }
}

#pragma mark - Find Operations

- (void)findNext {
    [self searchWithDirectionBackwards:NO];
}

- (void)findPrevious {
    [self searchWithDirectionBackwards:YES];
}

- (void)searchWithDirectionBackwards:(BOOL)backwards {
    if (!self.editor) return;

    NSString *query = _findField.stringValue;
    if (query.length == 0) {
        // If query is empty, try grabbing current selection from editor
        long selStart = [self.editor getGeneralProperty:SCI_GETSELECTIONSTART];
        long selEnd = [self.editor getGeneralProperty:SCI_GETSELECTIONEND];
        if (selEnd > selStart) {
            long len = [self.editor message:SCI_GETSELTEXT wParam:0 lParam:0];
            if (len > 1) {
                std::vector<char> buf(len + 1, 0);
                [self.editor message:SCI_GETSELTEXT wParam:0 lParam:(sptr_t)buf.data()];
                NSString *sel = [NSString stringWithUTF8String:buf.data()];
                if (sel.length > 0 && ![sel containsString:@"\n"]) {
                    _findField.stringValue = sel;
                    query = sel;
                }
            }
        }
        if (query.length == 0) {
            [self showForEditor:self.editor];
            return;
        }
    }

    // Refresh cached matches list
    [self updateMatchesAndHighlight:NO];

    if (_cachedMatches.count == 0) {
        NSBeep();
        _statusLabel.stringValue = @"No matches found";
        _statusLabel.textColor = [NSColor systemRedColor];
        return;
    }

    long selStart = [self.editor getGeneralProperty:SCI_GETSELECTIONSTART];
    long selEnd = [self.editor getGeneralProperty:SCI_GETSELECTIONEND];
    BOOL wrapAround = (_wrapAroundCheck.state == NSControlStateValueOn);

    NSInteger targetIndex = -1;

    if (!backwards) {
        // Forward search: find first match whose starting location >= current selEnd
        for (NSInteger i = 0; i < (NSInteger)_cachedMatches.count; i++) {
            NSRange r = [_cachedMatches[i] rangeValue];
            if ((long)r.location >= selEnd) {
                targetIndex = i;
                break;
            }
        }

        if (targetIndex < 0) {
            if (wrapAround) {
                targetIndex = 0; // Wrap to beginning
            } else {
                NSBeep();
                _statusLabel.stringValue = @"Reached end of document";
                return;
            }
        }
    } else {
        // Reverse search (Find Previous): find last match before current selStart
        for (NSInteger i = (NSInteger)_cachedMatches.count - 1; i >= 0; i--) {
            NSRange r = [_cachedMatches[i] rangeValue];
            if ((long)r.location < selStart) {
                targetIndex = i;
                break;
            }
        }

        if (targetIndex < 0) {
            if (wrapAround) {
                targetIndex = _cachedMatches.count - 1; // Wrap to end
            } else {
                NSBeep();
                _statusLabel.stringValue = @"Reached beginning of document";
                return;
            }
        }
    }

    if (targetIndex >= 0 && targetIndex < (NSInteger)_cachedMatches.count) {
        _currentMatchIndex = targetIndex;
        NSRange matchRange = [_cachedMatches[targetIndex] rangeValue];

        // Select and scroll match range into view
        [self.editor message:SCI_SETSEL wParam:matchRange.location lParam:matchRange.location + matchRange.length];
        [self.editor message:SCI_SCROLLRANGE wParam:matchRange.location lParam:matchRange.location + matchRange.length];
        [self.editor message:SCI_SCROLLCARET];

        // Highlight active match prominently
        [self highlightCurrentMatch];

        _statusLabel.stringValue = [NSString stringWithFormat:@"%ld of %ld matches",
                                    (long)(_currentMatchIndex + 1), (long)_cachedMatches.count];
        _statusLabel.textColor = [NSColor controlTextColor];
    }
}

#pragma mark - Replace Operations

- (void)replaceAndFindNext {
    if (!self.editor) return;

    NSString *query = _findField.stringValue;
    if (query.length == 0) return;

    [self updateMatchesAndHighlight:NO];

    if (_cachedMatches.count == 0) {
        NSBeep();
        _statusLabel.stringValue = @"No matches found to replace";
        return;
    }

    long selStart = [self.editor getGeneralProperty:SCI_GETSELECTIONSTART];
    long selEnd = [self.editor getGeneralProperty:SCI_GETSELECTIONEND];
    BOOL isRegex = (_regexCheck.state == NSControlStateValueOn);

    // Check if the current selection exactly matches one of our found match ranges
    BOOL currentIsMatch = NO;
    if (_currentMatchIndex >= 0 && _currentMatchIndex < (NSInteger)_cachedMatches.count) {
        NSRange curr = [_cachedMatches[_currentMatchIndex] rangeValue];
        if ((long)curr.location == selStart && (long)(curr.location + curr.length) == selEnd) {
            currentIsMatch = YES;
        }
    }

    NSString *repText = _replaceField.stringValue ?: @"";
    if (isRegex) {
        repText = [self scintillaRegexReplacementString:repText];
    }
    const char *utf8Query = [query UTF8String];
    long queryLen = strlen(utf8Query);
    const char *utf8Rep = [repText UTF8String];
    long repLen = strlen(utf8Rep);

    if (currentIsMatch) {
        int flags = [self currentSearchFlags];
        [self.editor message:SCI_SETSEARCHFLAGS wParam:flags lParam:0];
        [self.editor message:SCI_SETTARGETSTART wParam:selStart lParam:0];
        [self.editor message:SCI_SETTARGETEND wParam:selEnd lParam:0];

        // Ensure capture groups are populated for this exact target
        if (isRegex) {
            [self.editor message:SCI_SEARCHINTARGET wParam:queryLen lParam:(sptr_t)utf8Query];
            [self.editor message:SCI_REPLACETARGETRE wParam:repLen lParam:(sptr_t)utf8Rep];
        } else {
            [self.editor message:SCI_REPLACETARGET wParam:repLen lParam:(sptr_t)utf8Rep];
        }

        // Advance to next match after replacing
        [self updateMatchesAndHighlight:YES];
        [self findNext];
    } else {
        // Jump to and highlight next match first so user can preview before replacement
        [self findNext];
    }
}

- (void)replaceAll {
    if (!self.editor) return;

    NSString *query = _findField.stringValue;
    if (query.length == 0) return;

    BOOL isRegex = (_regexCheck.state == NSControlStateValueOn);
    if (isRegex) {
        NSString *err = nil;
        if (![self isRegexValid:query error:&err]) {
            _statusLabel.stringValue = [NSString stringWithFormat:@"⚠️ Regex: %@", err];
            _statusLabel.textColor = [NSColor systemRedColor];
            return;
        }
    }

    int flags = [self currentSearchFlags];
    NSString *repText = _replaceField.stringValue ?: @"";
    if (isRegex) {
        repText = [self scintillaRegexReplacementString:repText];
    }
    const char *utf8Query = [query UTF8String];
    long queryLen = strlen(utf8Query);
    const char *utf8Rep = [repText UTF8String];
    long repLen = strlen(utf8Rep);

    [self.editor message:SCI_BEGINUNDOACTION];

    long searchPos = 0;
    NSInteger replacedCount = 0;
    [self.editor message:SCI_SETSEARCHFLAGS wParam:flags lParam:0];

    while (searchPos < [self.editor message:SCI_GETLENGTH]) {
        long docLen = [self.editor message:SCI_GETLENGTH];
        [self.editor message:SCI_SETTARGETSTART wParam:searchPos lParam:0];
        [self.editor message:SCI_SETTARGETEND wParam:docLen lParam:0];

        long pos = [self.editor message:SCI_SEARCHINTARGET wParam:queryLen lParam:(sptr_t)utf8Query];
        if (pos < 0) {
            break;
        }

        long mStart = [self.editor getGeneralProperty:SCI_GETTARGETSTART];
        long mEnd = [self.editor getGeneralProperty:SCI_GETTARGETEND];
        long replacedLen = 0;

        if (isRegex) {
            replacedLen = [self.editor message:SCI_REPLACETARGETRE wParam:repLen lParam:(sptr_t)utf8Rep];
        } else {
            replacedLen = [self.editor message:SCI_REPLACETARGET wParam:repLen lParam:(sptr_t)utf8Rep];
        }

        replacedCount++;
        long nextSearchPos = mStart + replacedLen;
        if (nextSearchPos <= searchPos) {
            searchPos++; // guard against zero-length infinite loops
        } else {
            searchPos = nextSearchPos;
        }
    }

    [self.editor message:SCI_ENDUNDOACTION];

    [self updateMatchesAndHighlight:YES];

    _statusLabel.stringValue = [NSString stringWithFormat:@"Replaced %ld occurrence%@",
                                (long)replacedCount, replacedCount == 1 ? @"" : @"s"];
    _statusLabel.textColor = [NSColor controlTextColor];
}

#pragma mark - External Editor Events

- (void)editorContentDidChange:(nullable ScintillaView *)editor {
    if (!self.window.isVisible) return;
    if (editor && editor == self.editor) {
        [self updateMatchesAndHighlight:YES];
    }
}

- (void)editorSelectionDidChange:(nullable ScintillaView *)editor {
    if (!self.window.isVisible) return;
    if (editor && editor == self.editor && _cachedMatches.count > 0) {
        long selStart = [self.editor getGeneralProperty:SCI_GETSELECTIONSTART];
        long selEnd = [self.editor getGeneralProperty:SCI_GETSELECTIONEND];
        NSInteger newIndex = -1;
        for (NSInteger i = 0; i < (NSInteger)_cachedMatches.count; i++) {
            NSRange r = [_cachedMatches[i] rangeValue];
            if ((long)r.location == selStart && (long)(r.location + r.length) == selEnd) {
                newIndex = i;
                break;
            }
        }
        if (newIndex != _currentMatchIndex) {
            _currentMatchIndex = newIndex;
            [self highlightCurrentMatch];
            if (_currentMatchIndex >= 0) {
                _statusLabel.stringValue = [NSString stringWithFormat:@"%ld of %ld matches",
                                            (long)(_currentMatchIndex + 1), (long)_cachedMatches.count];
                _statusLabel.textColor = [NSColor controlTextColor];
            } else {
                _statusLabel.stringValue = [NSString stringWithFormat:@"%ld match%@ found",
                                            (long)_cachedMatches.count, _cachedMatches.count == 1 ? @"" : @"es"];
                _statusLabel.textColor = [NSColor secondaryLabelColor];
            }
        }
    }
}

@end
