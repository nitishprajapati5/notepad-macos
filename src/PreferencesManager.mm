#import "PreferencesManager.h"

NSString *const NPPreferencesDidChangeNotification = @"NPPreferencesDidChangeNotification";

static NSString *const kNPFontNameKey        = @"NP.fontName";
static NSString *const kNPFontSizeKey        = @"NP.fontSize";
static NSString *const kNPTabWidthKey        = @"NP.tabWidth";
static NSString *const kNPWordWrapKey        = @"NP.wordWrap";
static NSString *const kNPShowLineNumbersKey = @"NP.showLineNumbers";

@implementation PreferencesManager

+ (instancetype)sharedManager {
    static PreferencesManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PreferencesManager alloc] init];
    });
    return instance;
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
        kNPFontSizeKey: @(13),
        kNPTabWidthKey: @(4),
        kNPWordWrapKey: @(NO),
        kNPShowLineNumbersKey: @(YES)
    };
    [defs registerDefaults:defaults];

    _fontName = [defs stringForKey:kNPFontNameKey] ?: @"Menlo";
    _fontSize = [defs integerForKey:kNPFontSizeKey];
    _tabWidth = [defs integerForKey:kNPTabWidthKey];
    _wordWrap = [defs boolForKey:kNPWordWrapKey];
    _showLineNumbers = [defs boolForKey:kNPShowLineNumbersKey];
}

- (void)savePreferences {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:_fontName forKey:kNPFontNameKey];
    [defs setInteger:_fontSize forKey:kNPFontSizeKey];
    [defs setInteger:_tabWidth forKey:kNPTabWidthKey];
    [defs setBool:_wordWrap forKey:kNPWordWrapKey];
    [defs setBool:_showLineNumbers forKey:kNPShowLineNumbersKey];
    [defs synchronize];

    [[NSNotificationCenter defaultCenter] postNotificationName:NPPreferencesDidChangeNotification
                                                        object:self];
}

@end
