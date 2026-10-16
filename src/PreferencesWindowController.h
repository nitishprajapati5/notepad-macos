#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PreferencesWindowController : NSWindowController <NSToolbarDelegate, NSWindowDelegate>

+ (instancetype)sharedPreferencesWindowController;
- (void)showWindow:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
