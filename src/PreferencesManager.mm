#import "PreferencesManager.h"

NSString *const NPPreferencesDidChangeNotification = @"NPPreferencesDidChangeNotification";

static NSString *const kNPFontNameKey        = @"NP.fontName";
static NSString *const kNPFontSizeKey        = @"NP.fontSize";
static NSString *const kNPTabWidthKey        = @"NP.tabWidth";
static NSString *const kNPUseSpacesKey       = @"NP.useSpaces";
static NSString *const kNPWordWrapKey        = @"NP.wordWrap";
static NSString *const kNPShowLineNumbersKey = @"NP.showLineNumbers";
static NSString *const kNPShowStatusBarKey   = @"NP.showStatusBar";
static NSString *const kNPThemeModeKey       = @"NP.themeMode";
static NSString *const kNPDefaultEncodingKey = @"NP.defaultEncoding";
static NSString *const kNPBackupOnSaveKey    = @"NP.backupOnSave";
static NSString *const kNPAutoIndentKey      = @"NP.autoIndent";

@implementation PreferencesManager

+ (instancetype)sharedManager {
    static PreferencesManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PreferencesManager alloc] init];
    });
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
        kNPShowLineNumbersKey: @(NO),
        kNPShowStatusBarKey: @(YES),
        kNPThemeModeKey: @(NPThemeModeSystem),
        kNPDefaultEncodingKey: @(NSUTF8StringEncoding),
        kNPBackupOnSaveKey: @(NO),
        kNPAutoIndentKey: @(YES)
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
    [defs synchronize];

    [[NSNotificationCenter defaultCenter] postNotificationName:NPPreferencesDidChangeNotification
                                                        object:self];
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
            NSAppearanceName name = [appAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
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
