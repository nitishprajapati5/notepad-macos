#import "ScintillaView+Notepad.h"
#import "PreferencesManager.h"
#import "Scintilla.h"

@implementation ScintillaView (Notepad)

- (void)np_setText:(NSString *)text {
    [self setString:text ?: @""];
    [self message:SCI_EMPTYUNDOBUFFER];
}

- (NSString *)np_text {
    return [self string] ?: @"";
}

- (void)np_applyDefaultTheme {
    [self suspendDrawing:YES];

    PreferencesManager *prefs = [PreferencesManager sharedManager];
    NSString *fontName = prefs.fontName ?: @"Menlo";
    NSInteger fontSize = prefs.fontSize > 0 ? prefs.fontSize : 12;

    // Check if SF Mono is preferred/available
    if ([fontName isEqualToString:@"SF Mono"]) {
        if (@available(macOS 10.15, *)) {
            NSFont *sfMono = [NSFont fontWithName:@"SF Mono" size:fontSize];
            if (!sfMono) {
                fontName = @"Menlo";
            }
        } else {
            fontName = @"Menlo";
        }
    }

    [self setStringProperty:SCI_STYLESETFONT parameter:STYLE_DEFAULT value:fontName];
    [self setGeneralProperty:SCI_STYLESETSIZE parameter:STYLE_DEFAULT value:fontSize];

    // Dynamic appearance colors
    NSAppearance *appearance = self.effectiveAppearance ?: [NSApp effectiveAppearance];
    BOOL isDark = NO;
    if (@available(macOS 10.14, *)) {
        NSAppearanceName match = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
        isDark = [match isEqualToString:NSAppearanceNameDarkAqua];
    }

    if (isDark) {
        [self setColorProperty:SCI_STYLESETFORE parameter:STYLE_DEFAULT value:[NSColor whiteColor]];
        [self setColorProperty:SCI_STYLESETBACK parameter:STYLE_DEFAULT value:[NSColor colorWithCalibratedWhite:0.12 alpha:1.0]];
        [self setColorProperty:SCI_SETCARETLINEBACK parameter:0 value:[NSColor colorWithCalibratedWhite:0.18 alpha:1.0]];
        [self setColorProperty:SCI_SETCARETFORE parameter:0 value:[NSColor whiteColor]];
        [self setColorProperty:SCI_STYLESETFORE parameter:STYLE_LINENUMBER value:[NSColor colorWithCalibratedWhite:0.55 alpha:1.0]];
        [self setColorProperty:SCI_STYLESETBACK parameter:STYLE_LINENUMBER value:[NSColor colorWithCalibratedWhite:0.16 alpha:1.0]];
    } else {
        [self setColorProperty:SCI_STYLESETFORE parameter:STYLE_DEFAULT value:[NSColor blackColor]];
        [self setColorProperty:SCI_STYLESETBACK parameter:STYLE_DEFAULT value:[NSColor whiteColor]];
        [self setColorProperty:SCI_SETCARETLINEBACK parameter:0 value:[NSColor colorWithCalibratedRed:0.95 green:0.95 blue:0.97 alpha:1.0]];
        [self setColorProperty:SCI_SETCARETFORE parameter:0 value:[NSColor blackColor]];
        [self setColorProperty:SCI_STYLESETFORE parameter:STYLE_LINENUMBER value:[NSColor colorWithCalibratedWhite:0.50 alpha:1.0]];
        [self setColorProperty:SCI_STYLESETBACK parameter:STYLE_LINENUMBER value:[NSColor colorWithCalibratedWhite:0.96 alpha:1.0]];
    }

    [self message:SCI_STYLECLEARALL];

    // Native selection highlight
    [self setColorProperty:SCI_SETSELBACK parameter:1 value:[NSColor selectedTextBackgroundColor]];

    // Caret appearance & line highlight
    [self message:SCI_SETCARETLINEVISIBLE wParam:1 lParam:0];
    [self message:SCI_SETCARETWIDTH wParam:2 lParam:0];

    // Tab & EOL setup (Phase 2.2 defaults: tab width 4, use tabs, EOL LF)
    NSInteger tabWidth = prefs.tabWidth > 0 ? prefs.tabWidth : 4;
    [self message:SCI_SETTABWIDTH wParam:tabWidth lParam:0];
    [self message:SCI_SETUSETABS wParam:1 lParam:0]; // Use spaces: false -> use tabs
    [self message:SCI_SETEOLMODE wParam:SC_EOL_LF lParam:0];
    [self message:SCI_SETVIEWEOL wParam:0 lParam:0];

    // Margin & Wrap defaults from preferences
    [self np_setLineNumbersVisible:prefs.showLineNumbers];
    [self np_setWordWrap:prefs.wordWrap];

    [self suspendDrawing:NO];
}

- (void)np_setWordWrap:(BOOL)enabled {
    [self message:SCI_SETWRAPMODE wParam:enabled ? SC_WRAP_WORD : SC_WRAP_NONE lParam:0];
}

- (BOOL)np_wordWrap {
    return [self message:SCI_GETWRAPMODE] != SC_WRAP_NONE;
}

- (void)np_setLineNumbersVisible:(BOOL)visible {
    if (visible) {
        [self setGeneralProperty:SCI_SETMARGINTYPEN parameter:0 value:SC_MARGIN_NUMBER];
        [self setGeneralProperty:SCI_SETMARGINWIDTHN parameter:0 value:42];
    } else {
        [self setGeneralProperty:SCI_SETMARGINWIDTHN parameter:0 value:0];
    }
}

- (BOOL)np_lineNumbersVisible {
    return [self getGeneralProperty:SCI_GETMARGINWIDTHN parameter:0] > 0;
}

- (void)np_setFontName:(NSString *)fontName size:(NSInteger)pointSize {
    [self suspendDrawing:YES];
    [self setStringProperty:SCI_STYLESETFONT parameter:STYLE_DEFAULT value:fontName];
    [self setGeneralProperty:SCI_STYLESETSIZE parameter:STYLE_DEFAULT value:pointSize];
    [self message:SCI_STYLECLEARALL];
    [self suspendDrawing:NO];
}

- (NSString *)np_fontName {
    return [self getStringProperty:SCI_STYLEGETFONT parameter:STYLE_DEFAULT] ?: @"Menlo";
}

- (NSInteger)np_fontSize {
    return [self getGeneralProperty:SCI_STYLEGETSIZE parameter:STYLE_DEFAULT];
}

- (void)np_setTabWidth:(NSInteger)tabWidth {
    [self message:SCI_SETTABWIDTH wParam:tabWidth lParam:0];
}

- (NSInteger)np_tabWidth {
    return [self message:SCI_GETTABWIDTH];
}

@end
