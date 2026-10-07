#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const NPPreferencesDidChangeNotification;

@interface PreferencesManager : NSObject

@property (nonatomic, copy) NSString *fontName;
@property (nonatomic, assign) NSInteger fontSize;
@property (nonatomic, assign) NSInteger tabWidth;
@property (nonatomic, assign) BOOL wordWrap;
@property (nonatomic, assign) BOOL showLineNumbers;
@property (nonatomic, assign) BOOL showStatusBar;

+ (instancetype)sharedManager;
- (void)savePreferences;
- (void)loadPreferences;

@end

NS_ASSUME_NONNULL_END
