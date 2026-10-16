#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PreferencesWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>

+ (instancetype)sharedPreferencesWindowController;
- (void)showWindow:(nullable id)sender;
- (void)showCategoryIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
