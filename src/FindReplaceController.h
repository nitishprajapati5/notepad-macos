#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class ScintillaView;

@interface FindReplaceController : NSWindowController <NSTextFieldDelegate, NSWindowDelegate>

@property (nonatomic, weak, nullable) ScintillaView *editor;

+ (instancetype)sharedController;

- (void)showForEditor:(nullable ScintillaView *)editor;
- (void)showReplaceForEditor:(nullable ScintillaView *)editor;
- (void)findNext;
- (void)findPrevious;
- (void)replaceAndFindNext;
- (void)replaceAll;
- (void)clearHighlights;
- (void)editorContentDidChange:(nullable ScintillaView *)editor;
- (void)editorSelectionDidChange:(nullable ScintillaView *)editor;

@end

NS_ASSUME_NONNULL_END
