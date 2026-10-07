#import "ScintillaView+Notepad.h"
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

    // Default font & size
    NSString *fontName = @"Menlo";
    if (@available(macOS 10.15, *)) {
        NSFont *sfMono = [NSFont fontWithName:@"SF Mono" size:13.0];
        if (sfMono) {
            fontName = @"SF Mono";
        }
    }
    
    [self setStringProperty:SCI_STYLESETFONT parameter:STYLE_DEFAULT value:fontName];
    [self setGeneralProperty:SCI_STYLESETSIZE parameter:STYLE_DEFAULT value:13];

    // Dynamic appearance colors
    NSAppearance *appearance = [NSApp effectiveAppearance];
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

    // Caret line & indentation setup
    [self message:SCI_SETCARETLINEVISIBLE wParam:1 lParam:0];
    [self message:SCI_SETTABWIDTH wParam:4 lParam:0];
    [self message:SCI_SETUSETABS wParam:0 lParam:0];
    [self message:SCI_SETEOLMODE wParam:SC_EOL_LF lParam:0];
    [self message:SCI_SETVIEWEOL wParam:0 lParam:0];

    // Line number margin default
    [self np_setLineNumbersVisible:YES];

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

@end
