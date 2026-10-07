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

    // Set font & size on STYLE_DEFAULT
    [self setStringProperty:SCI_STYLESETFONT parameter:STYLE_DEFAULT value:fontName];
    [self setGeneralProperty:SCI_STYLESETSIZE parameter:STYLE_DEFAULT value:fontSize];

    // Colors: Pure White background (0xFFFFFF) and Pitch-Black text (0x000000)
    // Note: Scintilla BGR/RGB integer format: Black = 0x000000, White = 0xFFFFFF
    [self message:SCI_STYLESETFORE wParam:STYLE_DEFAULT lParam:0x000000];
    [self message:SCI_STYLESETBACK wParam:STYLE_DEFAULT lParam:0xFFFFFF];

    // Clear all styles to copy STYLE_DEFAULT across all style slots
    [self message:SCI_STYLECLEARALL];

    // Explicitly enforce black text and white background across all styles 0..127
    // Style 0 is the primary style applied to all typed plain text without a lexer.
    for (int i = 0; i < 128; i++) {
        [self message:SCI_STYLESETFORE wParam:i lParam:0x000000];
        [self message:SCI_STYLESETBACK wParam:i lParam:0xFFFFFF];
        [self setStringProperty:SCI_STYLESETFONT parameter:i value:fontName];
        [self setGeneralProperty:SCI_STYLESETSIZE parameter:i value:fontSize];
    }

    // Line number margin styling (when enabled)
    [self message:SCI_STYLESETFORE wParam:STYLE_LINENUMBER lParam:0x707070];
    [self message:SCI_STYLESETBACK wParam:STYLE_LINENUMBER lParam:0xF5F5F5];

    // Caret styling: Black 1px cursor matching Windows Notepad, no caret line background
    [self message:SCI_SETCARETFORE wParam:0x000000 lParam:0];
    [self message:SCI_SETCARETWIDTH wParam:1 lParam:0];
    [self message:SCI_SETCARETLINEVISIBLE wParam:0 lParam:0];

    // Selection colors: native macOS selection highlight with white selected text
    [self setColorProperty:SCI_SETSELBACK parameter:1 value:[NSColor selectedTextBackgroundColor]];
    [self setColorProperty:SCI_SETSELFORE parameter:1 value:[NSColor selectedTextColor]];

    // Tab & EOL setup (Phase 2 defaults: tab width 4, use tabs, EOL LF)
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
    for (int i = 0; i < 128; i++) {
        [self setStringProperty:SCI_STYLESETFONT parameter:i value:fontName];
        [self setGeneralProperty:SCI_STYLESETSIZE parameter:i value:pointSize];
    }
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
