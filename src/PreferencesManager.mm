#import "PreferencesManager.h"

NSString *const NPPreferencesDidChangeNotification = @"NPPreferencesDidChangeNotification";

static NSString *const kNPFontNameKey = @"NP.fontName";
static NSString *const kNPFontSizeKey = @"NP.fontSize";
static NSString *const kNPTabWidthKey = @"NP.tabWidth";
static NSString *const kNPUseSpacesKey = @"NP.useSpaces";
static NSString *const kNPWordWrapKey = @"NP.wordWrap";
static NSString *const kNPShowLineNumbersKey = @"NP.showLineNumbers";
static NSString *const kNPShowStatusBarKey = @"NP.showStatusBar";
static NSString *const kNPThemeModeKey = @"NP.themeMode";
static NSString *const kNPDefaultEncodingKey = @"NP.defaultEncoding";
static NSString *const kNPBackupOnSaveKey = @"NP.backupOnSave";
static NSString *const kNPAutoIndentKey = @"NP.autoIndent";
static NSString *const kNPActiveTabColorKey = @"NP.activeTabColor";
static NSString *const kNPUseRandomTabColorsKey = @"NP.useRandomTabColors";
static NSString *const kNPRestoreSessionKey = @"NP.restoreSessionOnLaunch";
static NSString *const kNPContinuousAutoSaveKey = @"NP.continuousAutoSave";
static NSString *const kNPVersionHistoryKey = @"NP.versionHistoryEnabled";

@implementation PreferencesManager

+ (instancetype)sharedManager {
    static PreferencesManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[PreferencesManager alloc] init]; });
    return instance;
}

+ (NSArray<NSDictionary<NSString *, id> *> *)supportedEncodings {
    return @[
        @{@"name": @"UTF-8", @"encoding": @(NSUTF8StringEncoding)},
        @{@"name": @"UTF-16 LE", @"encoding": @(NSUTF16LittleEndianStringEncoding)},
        @{@"name": @"UTF-16 BE", @"encoding": @(NSUTF16BigEndianStringEncoding)},
        @{@"name": @"Western (Windows-1252)", @"encoding": @(NSWindowsCP1252StringEncoding)},
        @{@"name": @"US-ASCII", @"encoding": @(NSASCIIStringEncoding)},
        @{@"name": @"Western (ISO Latin 1)", @"encoding": @(NSISOLatin1StringEncoding)}
    ];
}

+ (NSString *)nameForEncoding:(NSStringEncoding)encoding {
    for (NSDictionary *item in [self supportedEncodings]) {
        if ([item[@"encoding"] unsignedIntegerValue] == encoding) {
            return item[@"name"];
        }
    }
    return [NSString localizedNameOfStringEncoding:encoding] ?: @"Custom";
}

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)presetTabColors {
    return @[
        @{@"name": @"Classic Amber (Default)", @"hex": @"#D98226"}, @{@"name": @"Emerald Green", @"hex": @"#27AE60"},
        @{@"name": @"Ocean Blue", @"hex": @"#2980B9"}, @{@"name": @"Royal Purple", @"hex": @"#8E44AD"},
        @{@"name": @"Crimson Red", @"hex": @"#C0392B"}, @{@"name": @"Modern Teal", @"hex": @"#16A085"},
        @{@"name": @"Coral Pink", @"hex": @"#E84393"}, @{@"name": @"Sunburst Orange", @"hex": @"#E67E22"},
        @{@"name": @"Slate Indigo", @"hex": @"#4B6584"}, @{@"name": @"Graphite Dark", @"hex": @"#4A5568"}
    ];
}

+ (NSColor *)colorFromHexString:(NSString *)hexString {
    if (!hexString || hexString.length == 0) {
        return [NSColor colorWithCalibratedRed:0.85 green:0.51 blue:0.15 alpha:1.0];  // Default #D98226
    }
    NSString *cleanHex = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    cleanHex = [cleanHex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cleanHex.length != 6) {
        return [NSColor colorWithCalibratedRed:0.85 green:0.51 blue:0.15 alpha:1.0];
    }
    unsigned int rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:cleanHex];
    if (![scanner scanHexInt:&rgbValue]) {
        return [NSColor colorWithCalibratedRed:0.85 green:0.51 blue:0.15 alpha:1.0];
    }
    CGFloat r = ((rgbValue >> 16) & 0xFF) / 255.0;
    CGFloat g = ((rgbValue >> 8) & 0xFF) / 255.0;
    CGFloat b = (rgbValue & 0xFF) / 255.0;
    return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
}

+ (NSString *)hexStringFromColor:(NSColor *)color {
    if (!color)
        return @"#D98226";
    NSColor *rgb = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] ?: color;
    CGFloat r = 0, g = 0, b = 0, a = 1.0;
    [rgb getRed:&r green:&g blue:&b alpha:&a];
    int redInt = (int)lround(r * 255.0);
    int greenInt = (int)lround(g * 255.0);
    int blueInt = (int)lround(b * 255.0);
    return [NSString stringWithFormat:@"#%02X%02X%02X", redInt, greenInt, blueInt];
}

+ (NSColor *)randomVibrantColor {
    // Generate harmonious, vibrant colors using calibrated HSB
    CGFloat hue = (CGFloat)arc4random_uniform(360) / 360.0;
    CGFloat saturation = 0.65 + ((CGFloat)arc4random_uniform(25) / 100.0);  // 0.65 - 0.90
    CGFloat brightness = 0.75 + ((CGFloat)arc4random_uniform(20) / 100.0);  // 0.75 - 0.95
    return [NSColor colorWithCalibratedHue:hue saturation:saturation brightness:brightness alpha:1.0];
}

- (NSColor *)activeTabColor {
    return [PreferencesManager colorFromHexString:self.activeTabColorHex];
}

- (void)setActiveTabColor:(NSColor *)color {
    self.activeTabColorHex = [PreferencesManager hexStringFromColor:color];
    [self savePreferences];
}

- (void)pickRandomTabColor {
    NSColor *randomColor = [PreferencesManager randomVibrantColor];
    [self setActiveTabColor:randomColor];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadPreferences];
    }
    return self;
}

- (void)loadPreferences {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

    NSDictionary *defaults = @{
        kNPFontNameKey: @"Menlo",
        kNPFontSizeKey: @(16),
        kNPTabWidthKey: @(4),
        kNPUseSpacesKey: @(NO),
        kNPWordWrapKey: @(NO),
        kNPShowLineNumbersKey: @(YES),
        kNPShowStatusBarKey: @(YES),
        kNPThemeModeKey: @(NPThemeModeSystem),
        kNPDefaultEncodingKey: @(NSUTF8StringEncoding),
        kNPBackupOnSaveKey: @(NO),
        kNPAutoIndentKey: @(YES),
        kNPActiveTabColorKey: @"#D98226",
        kNPUseRandomTabColorsKey: @(NO),
        kNPRestoreSessionKey: @(YES),
        kNPContinuousAutoSaveKey: @(YES),
        kNPVersionHistoryKey: @(YES)
    };
    [defs registerDefaults:defaults];

    _fontName = [defs stringForKey:kNPFontNameKey] ?: @"Menlo";
    _fontSize = [defs integerForKey:kNPFontSizeKey];
    if (_fontSize <= 0 || _fontSize == 12) {
        _fontSize = 16;
        [defs setInteger:16 forKey:kNPFontSizeKey];
    }
    _tabWidth = [defs integerForKey:kNPTabWidthKey];
    _useSpaces = [defs boolForKey:kNPUseSpacesKey];
    _wordWrap = [defs boolForKey:kNPWordWrapKey];
    _showLineNumbers = [defs boolForKey:kNPShowLineNumbersKey];
    _showStatusBar = [defs boolForKey:kNPShowStatusBarKey];
    _themeMode = (NPThemeMode)[defs integerForKey:kNPThemeModeKey];
    _defaultEncoding = (NSStringEncoding)[defs integerForKey:kNPDefaultEncodingKey];
    _backupOnSave = [defs boolForKey:kNPBackupOnSaveKey];
    _autoIndent = [defs boolForKey:kNPAutoIndentKey];
    _activeTabColorHex = [defs stringForKey:kNPActiveTabColorKey] ?: @"#D98226";
    _useRandomTabColors = [defs boolForKey:kNPUseRandomTabColorsKey];
    _restoreSessionOnLaunch = [defs boolForKey:kNPRestoreSessionKey];
    _continuousAutoSave = [defs boolForKey:kNPContinuousAutoSaveKey];
    _versionHistoryEnabled = [defs boolForKey:kNPVersionHistoryKey];
}

- (void)savePreferences {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:_fontName forKey:kNPFontNameKey];
    [defs setInteger:_fontSize forKey:kNPFontSizeKey];
    [defs setInteger:_tabWidth forKey:kNPTabWidthKey];
    [defs setBool:_useSpaces forKey:kNPUseSpacesKey];
    [defs setBool:_wordWrap forKey:kNPWordWrapKey];
    [defs setBool:_showLineNumbers forKey:kNPShowLineNumbersKey];
    [defs setBool:_showStatusBar forKey:kNPShowStatusBarKey];
    [defs setInteger:_themeMode forKey:kNPThemeModeKey];
    [defs setInteger:_defaultEncoding forKey:kNPDefaultEncodingKey];
    [defs setBool:_backupOnSave forKey:kNPBackupOnSaveKey];
    [defs setBool:_autoIndent forKey:kNPAutoIndentKey];
    [defs setObject:_activeTabColorHex forKey:kNPActiveTabColorKey];
    [defs setBool:_useRandomTabColors forKey:kNPUseRandomTabColorsKey];
    [defs setBool:_restoreSessionOnLaunch forKey:kNPRestoreSessionKey];
    [defs setBool:_continuousAutoSave forKey:kNPContinuousAutoSaveKey];
    [defs setBool:_versionHistoryEnabled forKey:kNPVersionHistoryKey];
    [defs synchronize];

    [[NSNotificationCenter defaultCenter] postNotificationName:NPPreferencesDidChangeNotification object:self];
}

- (BOOL)isDarkModeActive {
    if (self.themeMode == NPThemeModeDark) {
        return YES;
    } else if (self.themeMode == NPThemeModeLight) {
        return NO;
    } else {
        // System Default
        if (@available(macOS 10.14, *)) {
            NSAppearance *appAppearance = [NSApp effectiveAppearance];
            NSAppearanceName name =
                [appAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
            if ([name isEqualToString:NSAppearanceNameDarkAqua]) {
                return YES;
            }
            NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
            return [style isEqualToString:@"Dark"];
        }
        return NO;
    }
}

@end
