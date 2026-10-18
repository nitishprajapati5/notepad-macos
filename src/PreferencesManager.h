#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const NPPreferencesDidChangeNotification;

typedef NS_ENUM(NSInteger, NPThemeMode) { NPThemeModeLight = 0, NPThemeModeDark = 1, NPThemeModeSystem = 2 };

@interface PreferencesManager : NSObject

@property (nonatomic, copy) NSString *fontName;
@property (nonatomic, assign) NSInteger fontSize;
@property (nonatomic, assign) NSInteger tabWidth;
@property (nonatomic, assign) BOOL useSpaces;
@property (nonatomic, assign) BOOL wordWrap;
@property (nonatomic, assign) BOOL showLineNumbers;
@property (nonatomic, assign) BOOL showStatusBar;
@property (nonatomic, assign) NPThemeMode themeMode;
@property (nonatomic, assign) NSStringEncoding defaultEncoding;
@property (nonatomic, assign) BOOL backupOnSave;
@property (nonatomic, assign) BOOL autoIndent;
@property (nonatomic, copy) NSString *activeTabColorHex;
@property (nonatomic, assign) BOOL useRandomTabColors;
@property (nonatomic, assign) BOOL restoreSessionOnLaunch;
@property (nonatomic, assign) BOOL continuousAutoSave;
@property (nonatomic, assign) BOOL versionHistoryEnabled;

+ (instancetype)sharedManager;
+ (NSArray<NSDictionary<NSString *, id> *> *)supportedEncodings;
+ (NSString *)nameForEncoding:(NSStringEncoding)encoding;
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)presetTabColors;
+ (NSColor *)colorFromHexString:(NSString *)hexString;
+ (NSString *)hexStringFromColor:(NSColor *)color;
+ (NSColor *)randomVibrantColor;

- (NSColor *)activeTabColor;
- (void)setActiveTabColor:(NSColor *)color;
- (void)pickRandomTabColor;
- (BOOL)isDarkModeActive;
- (void)savePreferences;
- (void)loadPreferences;

@end

NS_ASSUME_NONNULL_END
