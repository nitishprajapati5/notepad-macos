#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class ScintillaView;

@interface FindReplaceController : NSWindowController

@property (nonatomic, weak, nullable) ScintillaView *editor;

- (void)showForEditor:(nullable ScintillaView *)editor;
- (void)findNext;
- (void)findPrevious;
- (void)replaceAndFindNext;
- (void)replaceAll;

@end

NS_ASSUME_NONNULL_END
