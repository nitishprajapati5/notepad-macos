#import <Cocoa/Cocoa.h>
#import "ScintillaView.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScintillaView (Notepad)

- (void)np_setText:(NSString *)text;
- (NSString *)np_text;
- (void)np_applyDefaultTheme;
- (void)np_setWordWrap:(BOOL)enabled;
- (BOOL)np_wordWrap;
- (void)np_setLineNumbersVisible:(BOOL)visible;
- (BOOL)np_lineNumbersVisible;
- (void)np_setFontName:(NSString *)fontName size:(NSInteger)pointSize;
- (NSString *)np_fontName;
- (NSInteger)np_fontSize;
- (void)np_setTabWidth:(NSInteger)tabWidth;
- (NSInteger)np_tabWidth;

@end

NS_ASSUME_NONNULL_END
