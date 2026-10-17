#import "PreferencesWindowController.h"
#import "PreferencesManager.h"

@interface NPCategoryItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, copy) NSString *systemSymbol;
@end

@implementation NPCategoryItem
+ (instancetype)itemWithTitle:(NSString *)title icon:(NSString *)icon symbol:(NSString *)symbol {
    NPCategoryItem *item = [[NPCategoryItem alloc] init];
    item.title = title;
    item.iconName = icon;
    item.systemSymbol = symbol;
    return item;
}
@end

// ─────────────────────────────────────────────────────────────────────────────
// NPColorSwatchRowView — A modern row of colored circles for preset selection
// ─────────────────────────────────────────────────────────────────────────────

@interface NPColorSwatchRowView : NSView
@property (nonatomic, strong) NSArray<NSColor *> *swatchColors;
@property (nonatomic, assign) NSInteger selectedIndex;               // -1 = custom/none
@property (nonatomic, copy) void (^onSelectIndex)(NSInteger index);  // -1 = open color picker
@end

@implementation NPColorSwatchRowView {
    NSInteger _hovered;  // -1 = none, 999 = custom
    NSTrackingArea *_trackArea;
}

static const CGFloat NPSwatchDiam = 28.0;
static const CGFloat NPSwatchGap = 10.0;
static const NSInteger NPCustomIdx = 999;

- (instancetype)initWithFrame:(NSRect)fr {
    self = [super initWithFrame:fr];
    if (self) {
        _hovered = -1;
        _selectedIndex = 0;
    }
    return self;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (_trackArea)
        [self removeTrackingArea:_trackArea];
    _trackArea = [[NSTrackingArea alloc]
        initWithRect:self.bounds
             options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInKeyWindow
               owner:self
            userInfo:nil];
    [self addTrackingArea:_trackArea];
}

- (NSRect)rectForIndex:(NSInteger)i {
    CGFloat x = i * (NPSwatchDiam + NPSwatchGap);
    CGFloat y = (self.bounds.size.height - NPSwatchDiam) / 2.0;
    return NSMakeRect(x, y, NPSwatchDiam, NPSwatchDiam);
}

- (NSRect)customRect {
    NSInteger n = (NSInteger)self.swatchColors.count;
    CGFloat x = n * (NPSwatchDiam + NPSwatchGap) + 14.0;
    CGFloat y = (self.bounds.size.height - NPSwatchDiam) / 2.0;
    return NSMakeRect(x, y, NPSwatchDiam, NPSwatchDiam);
}

- (NSInteger)hitTestIndex:(NSPoint)pt {
    if (NSPointInRect(pt, NSInsetRect([self customRect], -4, -4)))
        return NPCustomIdx;
    for (NSInteger i = 0; i < (NSInteger)self.swatchColors.count; i++) {
        if (NSPointInRect(pt, NSInsetRect([self rectForIndex:i], -4, -4)))
            return i;
    }
    return -1;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    for (NSInteger i = 0; i < (NSInteger)self.swatchColors.count; i++) {
        NSRect r = [self rectForIndex:i];
        BOOL sel = (i == _selectedIndex);
        BOOL hov = (i == _hovered);

        // Outer selection ring + gap
        if (sel) {
            NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(r, -4.5, -4.5)];
            [[NSColor colorWithCalibratedWhite:0.80 alpha:1.0] setStroke];
            ring.lineWidth = 2.5;
            [ring stroke];
            // Gap ring (card bg color)
            NSBezierPath *gap = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(r, -1.5, -1.5)];
            [[NSColor colorWithCalibratedWhite:0.14 alpha:1.0] setFill];
            [gap fill];
        } else if (hov) {
            NSBezierPath *hovRing = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(r, -3, -3)];
            [[NSColor colorWithCalibratedWhite:0.55 alpha:0.5] setStroke];
            hovRing.lineWidth = 1.5;
            [hovRing stroke];
        }

        NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:r];
        [self.swatchColors[i] setFill];
        [circle fill];
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.20] setStroke];
        circle.lineWidth = 1.0;
        [circle stroke];

        // White checkmark for selected
        if (sel) {
            CGFloat cx = NSMidX(r), cy = NSMidY(r);
            NSBezierPath *ck = [NSBezierPath bezierPath];
            [ck moveToPoint:NSMakePoint(cx - 5.5, cy - 1.0)];
            [ck lineToPoint:NSMakePoint(cx - 1.5, cy - 5.0)];
            [ck lineToPoint:NSMakePoint(cx + 6.5, cy + 5.0)];
            ck.lineCapStyle = NSLineCapStyleRound;
            ck.lineJoinStyle = NSLineJoinStyleRound;
            ck.lineWidth = 2.2;
            [[NSColor whiteColor] setStroke];
            [ck stroke];
        }
    }

    // Custom "+" swatch at the end
    NSRect cr = [self customRect];
    BOOL customSel = (_selectedIndex == -1);
    BOOL customHov = (_hovered == NPCustomIdx);

    if (customSel) {
        NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(cr, -4.5, -4.5)];
        [[NSColor colorWithCalibratedWhite:0.80 alpha:1.0] setStroke];
        ring.lineWidth = 2.5;
        [ring stroke];
        NSBezierPath *gap = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(cr, -1.5, -1.5)];
        [[NSColor colorWithCalibratedWhite:0.14 alpha:1.0] setFill];
        [gap fill];
    }

    NSBezierPath *cCircle = [NSBezierPath bezierPathWithOvalInRect:cr];
    [[NSColor colorWithCalibratedWhite:customHov ? 0.38 : 0.24 alpha:1.0] setFill];
    [cCircle fill];
    [[NSColor colorWithCalibratedWhite:0.46 alpha:1.0] setStroke];
    cCircle.lineWidth = 1.2;
    [cCircle stroke];

    // "+" icon
    NSString *plusStr = @"+";
    NSDictionary *plusAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:17.0 weight:NSFontWeightLight],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.82 alpha:1.0]
    };
    NSSize psz = [plusStr sizeWithAttributes:plusAttrs];
    [plusStr drawAtPoint:NSMakePoint(NSMidX(cr) - psz.width / 2.0, NSMidY(cr) - psz.height / 2.0 - 0.5)
          withAttributes:plusAttrs];
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint pt = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger idx = [self hitTestIndex:pt];
    if (idx == NPCustomIdx) {
        _selectedIndex = -1;
        [self setNeedsDisplay:YES];
        if (self.onSelectIndex)
            self.onSelectIndex(-1);
    } else if (idx >= 0 && idx < (NSInteger)self.swatchColors.count) {
        _selectedIndex = idx;
        [self setNeedsDisplay:YES];
        if (self.onSelectIndex)
            self.onSelectIndex(idx);
    }
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint pt = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger newH = [self hitTestIndex:pt];
    if (newH != _hovered) {
        _hovered = newH;
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseExited:(NSEvent *)event {
    _hovered = -1;
    [self setNeedsDisplay:YES];
}

@end

// ─────────────────────────────────────────────────────────────────────────────
// NPTabColorPreviewView — Renders a live mini preview of the active tab
// ─────────────────────────────────────────────────────────────────────────────

@interface NPTabColorPreviewView : NSView
@property (nonatomic, strong) NSColor *baseColor;
@property (nonatomic, assign) BOOL isDark;
@end

@implementation NPTabColorPreviewView

- (void)setBaseColor:(NSColor *)baseColor {
    _baseColor = baseColor;
    [self setNeedsDisplay:YES];
}
- (void)setIsDark:(BOOL)isDark {
    _isDark = isDark;
    [self setNeedsDisplay:YES];
}

static void NPDrawTabPill(NSBezierPath **outPath, NSRect rect, CGFloat radius) {
    NSBezierPath *p = [NSBezierPath bezierPath];
    [p moveToPoint:NSMakePoint(rect.origin.x, rect.origin.y)];
    [p lineToPoint:NSMakePoint(rect.origin.x, NSMaxY(rect) - radius)];
    [p appendBezierPathWithArcWithCenter:NSMakePoint(rect.origin.x + radius, NSMaxY(rect) - radius)
                                  radius:radius
                              startAngle:180
                                endAngle:90
                               clockwise:YES];
    [p lineToPoint:NSMakePoint(NSMaxX(rect) - radius, NSMaxY(rect))];
    [p appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect) - radius, NSMaxY(rect) - radius)
                                  radius:radius
                              startAngle:90
                                endAngle:0
                               clockwise:YES];
    [p lineToPoint:NSMakePoint(NSMaxX(rect), rect.origin.y)];
    [p closePath];
    *outPath = p;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = self.bounds;
    BOOL dark = self.isDark;

    // Container background
    NSColor *barBg = dark ? [NSColor colorWithCalibratedRed:0.085 green:0.090 blue:0.100 alpha:1.0]
                          : [NSColor colorWithCalibratedWhite:0.895 alpha:1.0];
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:8.0 yRadius:8.0];
    [barBg setFill];
    [bgPath fill];

    // Container border
    NSColor *borderColor =
        dark ? [NSColor colorWithCalibratedWhite:0.22 alpha:0.60] : [NSColor colorWithCalibratedWhite:0.70 alpha:0.80];
    [borderColor setStroke];
    bgPath.lineWidth = 1.0;
    [bgPath stroke];

    // Bottom separator line (editor boundary)
    NSColor *sepColor =
        dark ? [NSColor colorWithCalibratedWhite:0.18 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.76 alpha:1.0];
    [sepColor setFill];
    NSRectFill(NSMakeRect(0, 0, bounds.size.width, 1.0));

    // ─── Active Tab ───────────────────────────────────────────────────────
    CGFloat tabH = bounds.size.height - 8.0;
    CGFloat tabY = 2.0;
    CGFloat activeW = 148.0;
    NSRect activeRect = NSMakeRect(8.0, tabY, activeW, tabH);

    NSColor *base = self.baseColor ?: [NSColor colorWithCalibratedRed:0.85 green:0.51 blue:0.15 alpha:1.0];
    NSColor *rgb = [base colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] ?: base;
    CGFloat cr = 0, cg = 0, cb = 0, ca = 1.0;
    [rgb getRed:&cr green:&cg blue:&cb alpha:&ca];

    NSColor *topC, *botC, *strokeC;
    if (dark) {
        topC = [NSColor colorWithCalibratedRed:MIN(1.0, cr * 1.08)
                                         green:MIN(1.0, cg * 1.08)
                                          blue:MIN(1.0, cb * 1.08)
                                         alpha:1.0];
        botC = [NSColor colorWithCalibratedRed:MAX(0.0, cr * 0.68)
                                         green:MAX(0.0, cg * 0.68)
                                          blue:MAX(0.0, cb * 0.68)
                                         alpha:1.0];
        strokeC = [NSColor colorWithCalibratedRed:MIN(1.0, cr * 1.25)
                                            green:MIN(1.0, cg * 1.25)
                                             blue:MIN(1.0, cb * 1.25)
                                            alpha:0.85];
    } else {
        topC = [NSColor colorWithCalibratedRed:MIN(1.0, cr * 1.15)
                                         green:MIN(1.0, cg * 1.15)
                                          blue:MIN(1.0, cb * 1.15)
                                         alpha:1.0];
        botC = [NSColor colorWithCalibratedRed:MAX(0.0, cr * 0.80)
                                         green:MAX(0.0, cg * 0.80)
                                          blue:MAX(0.0, cb * 0.80)
                                         alpha:1.0];
        strokeC = [NSColor colorWithCalibratedRed:MIN(1.0, cr * 1.28)
                                            green:MIN(1.0, cg * 1.28)
                                             blue:MIN(1.0, cb * 1.28)
                                            alpha:0.95];
    }

    NSBezierPath *activePath = nil;
    NPDrawTabPill(&activePath, activeRect, 6.0);
    [[[NSGradient alloc] initWithStartingColor:topC endingColor:botC] drawInBezierPath:activePath angle:270];
    [strokeC setStroke];
    activePath.lineWidth = 1.0;
    [activePath stroke];

    // Disk icon
    CGFloat dSz = 12.0;
    CGFloat dX = activeRect.origin.x + 9.0;
    CGFloat dY = activeRect.origin.y + (activeRect.size.height - dSz) / 2.0;
    NSBezierPath *diskBd = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(dX, dY, dSz, dSz)
                                                           xRadius:1.5
                                                           yRadius:1.5];
    [[NSColor colorWithCalibratedRed:0.30 green:0.58 blue:0.95 alpha:1.0] setStroke];
    diskBd.lineWidth = 1.0;
    [diskBd stroke];
    NSBezierPath *shutBd = [NSBezierPath bezierPathWithRect:NSMakeRect(dX + 2.5, dY + dSz - 4.5, dSz - 5.0, 3.8)];
    [[NSColor colorWithCalibratedWhite:0.88 alpha:1.0] setStroke];
    shutBd.lineWidth = 0.8;
    [shutBd stroke];

    // Title "new 1"
    NSDictionary *wTitle = @{
        NSFontAttributeName: [NSFont systemFontOfSize:12.5 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    NSAttributedString *ts = [[NSAttributedString alloc] initWithString:@"new 1" attributes:wTitle];
    CGFloat titleY = activeRect.origin.y + (activeRect.size.height - [ts size].height) / 2.0;
    [ts drawAtPoint:NSMakePoint(dX + dSz + 7.0, titleY)];

    // Close ✕
    NSDictionary *xA = @{
        NSFontAttributeName: [NSFont systemFontOfSize:10.0 weight:NSFontWeightBold],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1.0 alpha:0.85]
    };
    NSAttributedString *xs = [[NSAttributedString alloc] initWithString:@"✕" attributes:xA];
    CGFloat xX = NSMaxX(activeRect) - [xs size].width - 8.0;
    [xs drawAtPoint:NSMakePoint(xX, titleY)];

    // ─── Inactive Tab 1 "new 2" ──────────────────────────────────────────
    CGFloat inactW = 98.0;
    NSRect inact1Rect = NSMakeRect(NSMaxX(activeRect) + 3.0, tabY, inactW, tabH);
    NSBezierPath *inact1 = nil;
    NPDrawTabPill(&inact1, inact1Rect, 6.0);

    NSColor *iBg = dark ? [NSColor colorWithCalibratedRed:0.13 green:0.135 blue:0.155 alpha:1.0]
                        : [NSColor colorWithCalibratedWhite:0.86 alpha:1.0];
    [iBg setFill];
    [inact1 fill];
    NSColor *iBrd = dark ? [NSColor colorWithCalibratedRed:0.22 green:0.23 blue:0.26 alpha:1.0]
                         : [NSColor colorWithCalibratedWhite:0.76 alpha:1.0];
    [iBrd setStroke];
    inact1.lineWidth = 1.0;
    [inact1 stroke];

    NSDictionary *iA = @{
        NSFontAttributeName: [NSFont systemFontOfSize:12.0 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: dark ? [NSColor colorWithCalibratedWhite:0.68 alpha:1.0]
                                             : [NSColor colorWithCalibratedWhite:0.28 alpha:1.0]
    };
    [[[NSAttributedString alloc] initWithString:@"new 2"
                                     attributes:iA] drawAtPoint:NSMakePoint(inact1Rect.origin.x + 12.0, titleY)];

    // ─── Inactive Tab 2 "new 3" ──────────────────────────────────────────
    NSRect inact2Rect = NSMakeRect(NSMaxX(inact1Rect) + 3.0, tabY, inactW, tabH);
    NSBezierPath *inact2 = nil;
    NPDrawTabPill(&inact2, inact2Rect, 6.0);
    [iBg setFill];
    [inact2 fill];
    [iBrd setStroke];
    inact2.lineWidth = 1.0;
    [inact2 stroke];
    [[[NSAttributedString alloc] initWithString:@"new 3"
                                     attributes:iA] drawAtPoint:NSMakePoint(inact2Rect.origin.x + 12.0, titleY)];

    // ─── "+" New Tab Button ───────────────────────────────────────────────
    NSDictionary *plusA = @{
        NSFontAttributeName: [NSFont systemFontOfSize:15.0 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: dark ? [NSColor colorWithCalibratedWhite:0.55 alpha:1.0]
                                             : [NSColor colorWithCalibratedWhite:0.40 alpha:1.0]
    };
    [[[NSAttributedString alloc] initWithString:@"+"
                                     attributes:plusA] drawAtPoint:NSMakePoint(NSMaxX(inact2Rect) + 10.0, titleY)];
}

@end

@interface PreferencesWindowController ()

@property (nonatomic, strong) NSArray<NPCategoryItem *> *categories;
@property (nonatomic, strong) NSScrollView *tableScrollView;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSView *detailContainer;
@property (nonatomic, strong) NSBox *verticalDivider;
@property (nonatomic, strong) NSBox *bottomDivider;
@property (nonatomic, strong) NSButton *closeButton;

// Section Views
@property (nonatomic, strong) NSView *generalView;
@property (nonatomic, strong) NSView *editorView;
@property (nonatomic, strong) NSView *themeView;
@property (nonatomic, strong) NSView *encodingView;
@property (nonatomic, strong) NSView *backupView;

// General Controls
@property (nonatomic, strong) NSButton *showStatusBarCheckbox;
@property (nonatomic, strong) NSButton *showLineNumbersCheckbox;
@property (nonatomic, strong) NSButton *wordWrapCheckbox;
@property (nonatomic, strong) NPColorSwatchRowView *tabColorSwatchRow;  // New modern swatch row
@property (nonatomic, strong) NSPopUpButton *tabColorPresetPopup;       // Kept for compat (hidden)
@property (nonatomic, strong) NSColorWell *tabColorWell;
@property (nonatomic, strong) NSButton *randomColorButton;
@property (nonatomic, strong) NSButton *useRandomTabColorsCheckbox;
@property (nonatomic, strong) NPTabColorPreviewView *tabColorPreviewView;

// Editor Controls
@property (nonatomic, strong) NSPopUpButton *fontFamilyPopup;
@property (nonatomic, strong) NSPopUpButton *fontSizePopup;
@property (nonatomic, strong) NSTextView *fontPreviewTextView;
@property (nonatomic, strong) NSScrollView *previewScrollView;
@property (nonatomic, strong) NSPopUpButton *tabWidthPopup;
@property (nonatomic, strong) NSButton *useSpacesCheckbox;

// Theme Controls
@property (nonatomic, strong) NSSegmentedControl *themeSegmentedControl;

// Encoding Controls
@property (nonatomic, strong) NSPopUpButton *encodingPopup;

// Backup & Advanced Controls
@property (nonatomic, strong) NSButton *backupOnSaveCheckbox;
@property (nonatomic, strong) NSButton *autoIndentCheckbox;

// Tracked labels & boxes for dynamic Light / Dark mode updates
@property (nonatomic, strong) NSMutableArray<NSBox *> *cardBoxes;
@property (nonatomic, strong) NSMutableArray<NSTextField *> *cardHeaderLabels;
@property (nonatomic, strong) NSMutableArray<NSTextField *> *fieldLabels;
@property (nonatomic, strong) NSMutableArray<NSTextField *> *secondaryLabels;

@end

@implementation PreferencesWindowController

+ (instancetype)sharedPreferencesWindowController {
    static PreferencesWindowController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[PreferencesWindowController alloc] init]; });
    return instance;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 740, 540);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;

    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Preferences";
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        window.delegate = self;

        _cardBoxes = [NSMutableArray array];
        _cardHeaderLabels = [NSMutableArray array];
        _fieldLabels = [NSMutableArray array];
        _secondaryLabels = [NSMutableArray array];

        self.categories = @[
            [NPCategoryItem itemWithTitle:@"General" icon:NSImageNamePreferencesGeneral symbol:@"gearshape"],
            [NPCategoryItem itemWithTitle:@"Editor" icon:NSImageNameMultipleDocuments symbol:@"doc.text"],
            [NPCategoryItem itemWithTitle:@"Dark Mode" icon:NSImageNameColorPanel symbol:@"moon.fill"],
            [NPCategoryItem itemWithTitle:@"New Document" icon:NSImageNameFolder symbol:@"character.book.closed"],
            [NPCategoryItem itemWithTitle:@"Backup" icon:NSImageNameAdvanced symbol:@"archivebox"]
        ];

        [self setupUI];
        [self applyThemeColors];
        [self reloadPreferencesValues];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePreferencesChanged:)
                                                     name:NPPreferencesDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Color Palette (Flawless High-Contrast Dark & Light Mode)

- (BOOL)isDark {
    return [[PreferencesManager sharedManager] isDarkModeActive];
}

- (NSColor *)windowBgColor {
    return [self isDark] ? [NSColor colorWithCalibratedRed:0.07 green:0.07 blue:0.08 alpha:1.0]
                         :                                         // Deep rich black #121214
               [NSColor colorWithCalibratedWhite:0.94 alpha:1.0];  // Light gray #F0F1F3
}

- (NSColor *)sidebarBgColor {
    return [self isDark] ? [NSColor colorWithCalibratedRed:0.09 green:0.09 blue:0.105 alpha:1.0]
                         :                                         // Deep obsidian #17171B
               [NSColor colorWithCalibratedWhite:0.89 alpha:1.0];  // Clean sidebar #E3E5E8
}

- (NSColor *)cardBgColor {
    return [self isDark] ? [NSColor colorWithCalibratedRed:0.115 green:0.115 blue:0.135 alpha:1.0]
                         :            // Graphite Card #1D1D22
               [NSColor whiteColor];  // Crisp White #FFFFFF
}

- (NSColor *)cardBorderColor {
    return [self isDark] ? [NSColor colorWithCalibratedRed:0.20 green:0.20 blue:0.23 alpha:1.0]
                         :                                         // Subtle border #33333B
               [NSColor colorWithCalibratedWhite:0.80 alpha:1.0];  // Light border #CCCCCC
}

- (NSColor *)previewBgColor {
    return [self isDark] ? [NSColor colorWithCalibratedRed:0.055 green:0.055 blue:0.065 alpha:1.0]
                         : [NSColor whiteColor];
}

- (NSColor *)previewTextColor {
    return [self isDark] ? [NSColor colorWithCalibratedWhite:0.93 alpha:1.0] : [NSColor blackColor];
}

- (NSColor *)primaryTextColor {
    return [self isDark] ? [NSColor colorWithCalibratedWhite:0.95 alpha:1.0]
                         : [NSColor colorWithCalibratedWhite:0.08 alpha:1.0];  // Deep rich black #141414 for
                                                                               // 100% visibility in Light mode
}

- (NSColor *)secondaryTextColor {
    return [self isDark] ? [NSColor colorWithCalibratedWhite:0.62 alpha:1.0]
                         : [NSColor colorWithCalibratedWhite:0.35 alpha:1.0];  // Crisp charcoal #595959
                                                                               // for readable descriptions
                                                                               // in Light mode
}

- (void)applyThemeColors {
    PreferencesManager *prefs = [PreferencesManager sharedManager];

    // Enforce proper Cocoa Aqua / DarkAqua appearance on the window itself
    if (@available(macOS 10.14, *)) {
        if (prefs.themeMode == NPThemeModeLight) {
            self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        } else if (prefs.themeMode == NPThemeModeDark) {
            self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        } else {
            self.window.appearance = nil;
        }
    }

    NSColor *winColor = [self windowBgColor];
    self.window.backgroundColor = winColor;

    NSView *contentView = self.window.contentView;
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = winColor.CGColor;

    NSColor *sideColor = [self sidebarBgColor];
    self.tableScrollView.wantsLayer = YES;
    self.tableScrollView.layer.backgroundColor = sideColor.CGColor;
    self.tableView.backgroundColor = sideColor;

    self.detailContainer.wantsLayer = YES;
    self.detailContainer.layer.backgroundColor = winColor.CGColor;

    NSColor *cardFill = [self cardBgColor];
    NSColor *cardBorder = [self cardBorderColor];
    for (NSBox *box in self.cardBoxes) {
        box.fillColor = cardFill;
        box.borderColor = cardBorder;
    }

    NSColor *priColor = [self primaryTextColor];
    for (NSTextField *label in self.cardHeaderLabels) {
        label.textColor = priColor;
    }
    for (NSTextField *label in self.fieldLabels) {
        label.textColor = priColor;
    }

    NSColor *secColor = [self secondaryTextColor];
    for (NSTextField *label in self.secondaryLabels) {
        label.textColor = secColor;
    }

    if (self.previewScrollView) {
        self.previewScrollView.wantsLayer = YES;
        self.previewScrollView.layer.backgroundColor = [self previewBgColor].CGColor;
        self.previewScrollView.layer.borderColor = [self isDark]
                                                       ? [NSColor colorWithCalibratedWhite:0.25 alpha:1.0].CGColor
                                                       : [NSColor colorWithCalibratedWhite:0.75 alpha:1.0].CGColor;
        self.previewScrollView.layer.borderWidth = 1.0;
    }

    if (self.tabColorPreviewView) {
        self.tabColorPreviewView.isDark = [self isDark];
    }

    [self updateFontPreview];
    [self.tableView reloadData];
}

#pragma mark - UI Setup

- (void)setupUI {
    NSView *contentView = self.window.contentView;
    contentView.wantsLayer = YES;

    CGFloat windowWidth = 740;
    CGFloat windowHeight = 540;
    CGFloat bottomBarHeight = 52;
    CGFloat sidebarWidth = 180;
    CGFloat mainHeight = windowHeight - bottomBarHeight;

    // 1. Sidebar ScrollView & TableView
    self.tableScrollView =
        [[NSScrollView alloc] initWithFrame:NSMakeRect(0, bottomBarHeight, sidebarWidth, mainHeight)];
    self.tableScrollView.hasVerticalScroller = NO;
    self.tableScrollView.hasHorizontalScroller = NO;
    self.tableScrollView.borderType = NSNoBorder;
    self.tableScrollView.drawsBackground = YES;

    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"CategoryColumn"];
    column.width = sidebarWidth - 4;

    self.tableView = [[NSTableView alloc] initWithFrame:self.tableScrollView.bounds];
    [self.tableView addTableColumn:column];
    self.tableView.headerView = nil;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 36;
    self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;

    self.tableScrollView.documentView = self.tableView;
    [contentView addSubview:self.tableScrollView];

    // 2. Vertical Divider
    self.verticalDivider = [[NSBox alloc] initWithFrame:NSMakeRect(sidebarWidth, bottomBarHeight, 1, mainHeight)];
    self.verticalDivider.boxType = NSBoxSeparator;
    [contentView addSubview:self.verticalDivider];

    // 3. Detail Content Container
    CGFloat detailX = sidebarWidth + 1;
    CGFloat detailWidth = windowWidth - detailX;
    self.detailContainer = [[NSView alloc] initWithFrame:NSMakeRect(detailX, bottomBarHeight, detailWidth, mainHeight)];
    self.detailContainer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [contentView addSubview:self.detailContainer];

    // 4. Bottom Bar
    self.bottomDivider = [[NSBox alloc] initWithFrame:NSMakeRect(0, bottomBarHeight, windowWidth, 1)];
    self.bottomDivider.boxType = NSBoxSeparator;
    [contentView addSubview:self.bottomDivider];

    self.closeButton = [NSButton buttonWithTitle:@"Close" target:self action:@selector(closeButtonClicked:)];
    self.closeButton.bezelStyle = NSBezelStyleRounded;
    self.closeButton.frame = NSMakeRect(windowWidth - 110, 12, 95, 30);
    self.closeButton.keyEquivalent = @"\r";
    [contentView addSubview:self.closeButton];

    // Build the 5 Category Views with ample widths & vertical breathing space
    [self buildGeneralView:NSMakeRect(0, 0, detailWidth, mainHeight)];
    [self buildEditorView:NSMakeRect(0, 0, detailWidth, mainHeight)];
    [self buildThemeView:NSMakeRect(0, 0, detailWidth, mainHeight)];
    //   [self buildEncodingView:NSMakeRect(0, 0, detailWidth, mainHeight)];
    [self buildBackupView:NSMakeRect(0, 0, detailWidth, mainHeight)];

    // Select initial row (General)
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    [self showCategoryIndex:0];
}

#pragma mark - Card & Component Construction Helpers

- (NSBox *)createCardWithTitle:(NSString *)title frame:(NSRect)frame {
    NSBox *box = [[NSBox alloc] initWithFrame:frame];
    box.boxType = NSBoxCustom;
    box.borderWidth = 1.0;
    box.borderColor = [self cardBorderColor];
    box.fillColor = [self cardBgColor];
    box.cornerRadius = 10.0;
    box.titlePosition = NSNoTitle;

    NSTextField *titleLabel = [NSTextField labelWithString:title];
    titleLabel.font = [NSFont systemFontOfSize:13.5 weight:NSFontWeightSemibold];
    titleLabel.textColor = [self primaryTextColor];
    titleLabel.frame = NSMakeRect(22, frame.size.height - 34, frame.size.width - 44, 20);
    [box addSubview:titleLabel];

    [self.cardBoxes addObject:box];
    [self.cardHeaderLabels addObject:titleLabel];
    return box;
}

- (NSTextField *)makeFieldLabel:(NSString *)text frame:(NSRect)frame {
    NSTextField *label = [NSTextField labelWithString:text];
    label.frame = frame;
    label.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
    label.textColor = [self primaryTextColor];
    [self.fieldLabels addObject:label];
    return label;
}

- (NSTextField *)makeDescriptionLabel:(NSString *)text frame:(NSRect)frame {
    NSTextField *label = [NSTextField labelWithString:text];
    label.frame = frame;
    label.editable = NO;
    label.selectable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.maximumNumberOfLines = 0;
    label.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightRegular];
    label.textColor = [self secondaryTextColor];
    [self.secondaryLabels addObject:label];
    return label;
}

#pragma mark - Category Views

// 1. General View
- (void)buildGeneralView:(NSRect)bounds {
    self.generalView = [[NSView alloc] initWithFrame:bounds];

    CGFloat cardWidth = bounds.size.width - 48;

    // Card 1: Interface & View (Height 135)
    CGFloat interfaceCardHeight = 135;
    CGFloat interfaceCardY = bounds.size.height - interfaceCardHeight - 16;
    NSBox *interfaceCard = [self createCardWithTitle:@"Interface & View"
                                               frame:NSMakeRect(24, interfaceCardY, cardWidth, interfaceCardHeight)];

    self.showStatusBarCheckbox = [NSButton checkboxWithTitle:@"Show status bar"
                                                      target:self
                                                      action:@selector(statusBarToggled:)];
    self.showStatusBarCheckbox.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightRegular];
    self.showStatusBarCheckbox.frame = NSMakeRect(24, 72, cardWidth - 48, 24);
    [interfaceCard addSubview:self.showStatusBarCheckbox];

    self.showLineNumbersCheckbox = [NSButton checkboxWithTitle:@"Show line numbers gutter"
                                                        target:self
                                                        action:@selector(lineNumbersToggled:)];
    self.showLineNumbersCheckbox.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightRegular];
    self.showLineNumbersCheckbox.frame = NSMakeRect(24, 42, cardWidth - 48, 24);
    [interfaceCard addSubview:self.showLineNumbersCheckbox];

    self.wordWrapCheckbox = [NSButton checkboxWithTitle:@"Word wrap by default"
                                                 target:self
                                                 action:@selector(wordWrapToggled:)];
    self.wordWrapCheckbox.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightRegular];
    self.wordWrapCheckbox.frame = NSMakeRect(24, 12, cardWidth - 48, 24);
    [interfaceCard addSubview:self.wordWrapCheckbox];

    [self.generalView addSubview:interfaceCard];

    // Card 2: Tab Color & Appearance — redesigned with swatch circles (Height
    // 330)
    CGFloat tabCardHeight = 330;
    CGFloat tabCardY = interfaceCardY - 16 - tabCardHeight;
    NSBox *tabCard = [self createCardWithTitle:@"Tab Color & Style"
                                         frame:NSMakeRect(24, tabCardY, cardWidth, tabCardHeight)];

    // ── Row: "Preset Colors:" label ──────────────────────────────────────────
    NSTextField *colorLabel = [self makeFieldLabel:@"Preset Colors:" frame:NSMakeRect(24, 272, 110, 20)];
    [tabCard addSubview:colorLabel];

    // ── Row: NPColorSwatchRowView ─────────────────────────────────────────────
    // 10 presets + "+" custom circle
    NSArray<NSDictionary *> *presets = [PreferencesManager presetTabColors];
    NSMutableArray<NSColor *> *swatchColors = [NSMutableArray array];
    for (NSDictionary *p in presets) {
        [swatchColors addObject:[PreferencesManager colorFromHexString:p[@"hex"]]];
    }

    // Hidden popup for backward-compat actions
    self.tabColorPresetPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.tabColorPresetPopup.hidden = YES;
    [self populateTabColorPresets];
    [tabCard addSubview:self.tabColorPresetPopup];

    CGFloat swatchRowH = 46.0;
    CGFloat swatchRowW = cardWidth - 48;
    self.tabColorSwatchRow = [[NPColorSwatchRowView alloc] initWithFrame:NSMakeRect(24, 222, swatchRowW, swatchRowH)];
    self.tabColorSwatchRow.swatchColors = swatchColors;

    __weak PreferencesWindowController *wSelf = self;
    self.tabColorSwatchRow.onSelectIndex = ^(NSInteger idx) {
        if (idx == -1) {
            // Custom — open color well
            [wSelf.tabColorWell activate:YES];
            wSelf.tabColorSwatchRow.selectedIndex = -1;
        } else {
            NSArray<NSDictionary *> *ps = [PreferencesManager presetTabColors];
            if (idx < (NSInteger)ps.count) {
                NSString *hex = ps[idx][@"hex"];
                [PreferencesManager sharedManager].activeTabColorHex = hex;
                [[PreferencesManager sharedManager] savePreferences];
                [wSelf updateTabColorControls];
            }
        }
    };
    [tabCard addSubview:self.tabColorSwatchRow];

    // ── Separator ──────────────────────────────────────────────────────────────
    NSBox *sep1 = [[NSBox alloc] initWithFrame:NSMakeRect(24, 214, cardWidth - 48, 1)];
    sep1.boxType = NSBoxSeparator;
    [tabCard addSubview:sep1];

    // ── Row: Color Well + 🎲 Random button ───────────────────────────────────
    // Color well (hidden well, only activates when custom swatch clicked)
    self.tabColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(24, 180, 32, 28)];
    self.tabColorWell.target = self;
    self.tabColorWell.action = @selector(tabColorWellChanged:);
    [tabCard addSubview:self.tabColorWell];

    NSTextField *wellLabel = [self makeDescriptionLabel:@"Custom" frame:NSMakeRect(60, 184, 52, 18)];
    [tabCard addSubview:wellLabel];

    self.randomColorButton = [NSButton buttonWithTitle:@"🎲  Random Color"
                                                target:self
                                                action:@selector(randomColorButtonClicked:)];
    self.randomColorButton.bezelStyle = NSBezelStyleRounded;
    self.randomColorButton.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
    self.randomColorButton.frame = NSMakeRect(cardWidth - 48 - 148, 178, 148, 30);
    [tabCard addSubview:self.randomColorButton];

    // ── Checkbox: Assign random ───────────────────────────────────────────────
    self.useRandomTabColorsCheckbox = [NSButton checkboxWithTitle:@"Assign random vibrant color to each new tab"
                                                           target:self
                                                           action:@selector(randomTabColorsToggled:)];
    self.useRandomTabColorsCheckbox.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightRegular];
    self.useRandomTabColorsCheckbox.frame = NSMakeRect(24, 148, cardWidth - 48, 24);
    [tabCard addSubview:self.useRandomTabColorsCheckbox];

    // ── Separator ──────────────────────────────────────────────────────────────
    NSBox *sep2 = [[NSBox alloc] initWithFrame:NSMakeRect(24, 140, cardWidth - 48, 1)];
    sep2.boxType = NSBoxSeparator;
    [tabCard addSubview:sep2];

    // ── Live Preview label ────────────────────────────────────────────────────
    NSTextField *previewTitle = [self makeFieldLabel:@"Live Preview:" frame:NSMakeRect(24, 120, 120, 20)];
    [tabCard addSubview:previewTitle];

    // ── Preview view (3 tabs) ─────────────────────────────────────────────────
    self.tabColorPreviewView = [[NPTabColorPreviewView alloc] initWithFrame:NSMakeRect(24, 52, cardWidth - 48, 62)];
    self.tabColorPreviewView.baseColor = [[PreferencesManager sharedManager] activeTabColor];
    self.tabColorPreviewView.isDark = [self isDark];
    [tabCard addSubview:self.tabColorPreviewView];

    // ── Hint label ────────────────────────────────────────────────────────────
    NSTextField *tabHintLabel =
        [self makeDescriptionLabel:@"Click a preset swatch to apply instantly, or tap + to pick a "
                                   @"custom color. Roll 🎲 for a random vibrant color that "
                                   @"generates depth gradients dynamically."
                             frame:NSMakeRect(24, 12, cardWidth - 48, 36)];
    [tabCard addSubview:tabHintLabel];

    [self.generalView addSubview:tabCard];
}

- (void)populateTabColorPresets {
    [self.tabColorPresetPopup removeAllItems];
    for (NSDictionary *preset in [PreferencesManager presetTabColors]) {
        [self.tabColorPresetPopup addItemWithTitle:preset[@"name"]];
        NSMenuItem *item = [self.tabColorPresetPopup lastItem];
        item.representedObject = preset[@"hex"];
    }
    [[self.tabColorPresetPopup menu] addItem:[NSMenuItem separatorItem]];
    [self.tabColorPresetPopup addItemWithTitle:@"Custom Color..."];
    [self.tabColorPresetPopup lastItem].representedObject = @"CUSTOM";
}

- (void)updateTabColorControls {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    NSColor *activeColor = [prefs activeTabColor];

    self.tabColorWell.color = activeColor;
    self.tabColorPreviewView.baseColor = activeColor;
    self.tabColorPreviewView.isDark = [self isDark];
    self.useRandomTabColorsCheckbox.state = prefs.useRandomTabColors ? NSControlStateValueOn : NSControlStateValueOff;

    // Sync swatch row selection
    NSString *currentHex = [prefs.activeTabColorHex uppercaseString];
    NSArray<NSDictionary *> *presets = [PreferencesManager presetTabColors];
    NSInteger swatchIdx = -1;  // -1 = custom
    for (NSInteger i = 0; i < (NSInteger)presets.count; i++) {
        NSString *presetHex = [presets[i][@"hex"] uppercaseString];
        if ([presetHex isEqualToString:currentHex]) {
            swatchIdx = i;
            break;
        }
    }
    self.tabColorSwatchRow.selectedIndex = swatchIdx;
    [self.tabColorSwatchRow setNeedsDisplay:YES];

    // Also keep hidden popup in sync (backward compat)
    BOOL matched = NO;
    for (NSMenuItem *item in self.tabColorPresetPopup.itemArray) {
        if ([item.representedObject isKindOfClass:[NSString class]]) {
            NSString *hex = [(NSString *)item.representedObject uppercaseString];
            if ([hex isEqualToString:currentHex]) {
                [self.tabColorPresetPopup selectItem:item];
                matched = YES;
                break;
            }
        }
    }
    if (!matched) {
        [self.tabColorPresetPopup selectItemWithTitle:@"Custom Color..."];
    }
}

// 2. Editor View (Font, Size, Preview, Tabs)
- (void)buildEditorView:(NSRect)bounds {
    self.editorView = [[NSView alloc] initWithFrame:bounds];

    CGFloat cardWidth = bounds.size.width - 48;

    // Card 1: Font Selection (Height 120)
    CGFloat fontCardHeight = 122;
    CGFloat fontCardY = bounds.size.height - fontCardHeight - 16;
    NSBox *fontCard = [self createCardWithTitle:@"Font Style & Size"
                                          frame:NSMakeRect(24, fontCardY, cardWidth, fontCardHeight)];

    NSTextField *fontLabel = [self makeFieldLabel:@"Font:" frame:NSMakeRect(24, 54, 45, 22)];
    [fontCard addSubview:fontLabel];

    self.fontFamilyPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(72, 51, 260, 28) pullsDown:NO];
    [self populateFontFamilies];
    self.fontFamilyPopup.target = self;
    self.fontFamilyPopup.action = @selector(fontFamilyChanged:);
    [fontCard addSubview:self.fontFamilyPopup];

    NSTextField *sizeLabel = [self makeFieldLabel:@"Size:" frame:NSMakeRect(350, 54, 40, 22)];
    [fontCard addSubview:sizeLabel];

    self.fontSizePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(394, 51, 92, 28) pullsDown:NO];
    NSArray *sizes = @[@(8), @(9), @(10), @(11), @(12), @(13), @(14), @(15), @(16), @(18), @(20), @(24), @(28), @(32)];
    for (NSNumber *sz in sizes) {
        [self.fontSizePopup addItemWithTitle:[NSString stringWithFormat:@"%@ pt", sz]];
        [self.fontSizePopup lastItem].tag = [sz integerValue];
    }
    self.fontSizePopup.target = self;
    self.fontSizePopup.action = @selector(fontSizeChanged:);
    [fontCard addSubview:self.fontSizePopup];

    NSTextField *hintLabel =
        [self makeDescriptionLabel:@"Monospace fonts are recommended for clean code and text alignment."
                             frame:NSMakeRect(72, 20, cardWidth - 96, 18)];
    [fontCard addSubview:hintLabel];

    [self.editorView addSubview:fontCard];

    // Card 2: Live Preview (Height 150)
    CGFloat prevCardHeight = 152;
    CGFloat prevCardY = fontCardY - prevCardHeight - 14;
    NSBox *previewCard = [self createCardWithTitle:@"Sample Text Preview"
                                             frame:NSMakeRect(24, prevCardY, cardWidth, prevCardHeight)];

    self.previewScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 18, cardWidth - 40, 95)];
    self.previewScrollView.hasVerticalScroller = YES;
    self.previewScrollView.borderType = NSLineBorder;
    self.previewScrollView.wantsLayer = YES;
    self.previewScrollView.layer.cornerRadius = 6.0;

    self.fontPreviewTextView = [[NSTextView alloc] initWithFrame:self.previewScrollView.bounds];
    self.fontPreviewTextView.editable = NO;
    self.fontPreviewTextView.selectable = YES;
    self.fontPreviewTextView.string = @"The quick brown fox jumps over the lazy dog\n"
                                      @"0123456789 — [({!@#$%^&*})];\n"
                                      @"int main(int argc, char *argv[]) {\n"
                                      @"    printf(\"Notepad for macOS\\n\");\n"
                                      @"    return 0;\n"
                                      @"}";
    self.previewScrollView.documentView = self.fontPreviewTextView;
    [previewCard addSubview:self.previewScrollView];

    [self.editorView addSubview:previewCard];

    // Card 3: Tab Settings (Height 116)
    CGFloat tabCardHeight = 118;
    CGFloat tabCardY = prevCardY - tabCardHeight - 14;
    NSBox *tabCard = [self createCardWithTitle:@"Tab & Indentation"
                                         frame:NSMakeRect(24, tabCardY, cardWidth, tabCardHeight)];

    NSTextField *tabLabel = [self makeFieldLabel:@"Tab size:" frame:NSMakeRect(24, 52, 70, 22)];
    [tabCard addSubview:tabLabel];

    self.tabWidthPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(98, 49, 130, 28) pullsDown:NO];
    [self.tabWidthPopup addItemWithTitle:@"2 spaces"];
    [self.tabWidthPopup lastItem].tag = 2;
    [self.tabWidthPopup addItemWithTitle:@"4 spaces"];
    [self.tabWidthPopup lastItem].tag = 4;
    [self.tabWidthPopup addItemWithTitle:@"8 spaces"];
    [self.tabWidthPopup lastItem].tag = 8;
    self.tabWidthPopup.target = self;
    self.tabWidthPopup.action = @selector(tabWidthChanged:);
    [tabCard addSubview:self.tabWidthPopup];

    self.useSpacesCheckbox = [NSButton checkboxWithTitle:@"Replace by space (use spaces instead of tabs)"
                                                  target:self
                                                  action:@selector(useSpacesToggled:)];
    self.useSpacesCheckbox.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightRegular];
    self.useSpacesCheckbox.frame = NSMakeRect(24, 18, cardWidth - 48, 22);
    [tabCard addSubview:self.useSpacesCheckbox];

    [self.editorView addSubview:tabCard];
}

// 3. Dark Mode / Theme View
- (void)buildThemeView:(NSRect)bounds {
    self.themeView = [[NSView alloc] initWithFrame:bounds];

    CGFloat cardWidth = bounds.size.width - 48;
    CGFloat cardHeight = 245;
    CGFloat cardY = bounds.size.height - cardHeight - 24;

    NSBox *themeCard = [self createCardWithTitle:@"Color Theme" frame:NSMakeRect(24, cardY, cardWidth, cardHeight)];

    NSTextField *themeLabel = [self makeFieldLabel:@"Mode:" frame:NSMakeRect(24, 156, 50, 22)];
    [themeCard addSubview:themeLabel];

    self.themeSegmentedControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Light", @"Dark", @"System Default"]
                                                                   trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                         target:self
                                                                         action:@selector(themeChanged:)];
    self.themeSegmentedControl.frame = NSMakeRect(78, 152, 380, 30);
    [themeCard addSubview:self.themeSegmentedControl];

    [self.themeView addSubview:themeCard];
}

// 4. New Document & Encoding View
// - (void)buildEncodingView:(NSRect)bounds {
//   self.encodingView = [[NSView alloc] initWithFrame:bounds];

//   CGFloat cardWidth = bounds.size.width - 48;
//   CGFloat cardHeight = 245;
//   CGFloat cardY = bounds.size.height - cardHeight - 24;

//   NSBox *encCard =
//       [self createCardWithTitle:@"New Document & Default Encoding"
//                           frame:NSMakeRect(24, cardY, cardWidth, cardHeight)];

//   NSTextField *encLabel = [self makeFieldLabel:@"Encoding:"
//                                          frame:NSMakeRect(24, 156, 75, 22)];
//   [encCard addSubview:encLabel];

//   self.encodingPopup =
//       [[NSPopUpButton alloc] initWithFrame:NSMakeRect(105, 153, 310, 28)
//                                  pullsDown:NO];
//   for (NSDictionary *item in [PreferencesManager supportedEncodings]) {
//     [self.encodingPopup addItemWithTitle:item[@"name"]];
//     [self.encodingPopup lastItem].tag = [item[@"encoding"] integerValue];
//   }
//   self.encodingPopup.target = self;
//   self.encodingPopup.action = @selector(encodingChanged:);
//   [encCard addSubview:self.encodingPopup];

//   NSString *noteText =
//       @"• New Documents & Live Synchronization:\n"
//       @"  This character encoding is applied when creating new untitled "
//       @"documents.\n"
//       @"  Changing it here will immediately synchronize with the active status "
//       @"bar footer.\n\n"
//       @"• Fallback Decoding:\n"
//       @"  Also utilized as the preferred decoding format when opening legacy "
//       @"text files\n"
//       @"  that do not contain an explicit Byte Order Mark (BOM).";

//   NSTextField *noteLabel =
//       [self makeDescriptionLabel:noteText
//                            frame:NSMakeRect(24, 20, cardWidth - 48, 115)];
//   [encCard addSubview:noteLabel];

//   [self.encodingView addSubview:encCard];
// }

// 5. Backup & Advanced View
- (void)buildBackupView:(NSRect)bounds {
    self.backupView = [[NSView alloc] initWithFrame:bounds];

    CGFloat cardWidth = bounds.size.width - 48;

    // Card 1: Backup on Save (Height 140)
    CGFloat backupCardHeight = 142;
    CGFloat backupCardY = bounds.size.height - backupCardHeight - 24;
    NSBox *backupCard = [self createCardWithTitle:@"Backup on Save"
                                            frame:NSMakeRect(24, backupCardY, cardWidth, backupCardHeight)];

    self.backupOnSaveCheckbox = [NSButton checkboxWithTitle:@"Enable backup on save (.bak)"
                                                     target:self
                                                     action:@selector(backupOnSaveToggled:)];
    self.backupOnSaveCheckbox.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightRegular];
    self.backupOnSaveCheckbox.frame = NSMakeRect(24, 68, cardWidth - 48, 24);
    [backupCard addSubview:self.backupOnSaveCheckbox];

    NSString *backupText = @"Creates a duplicate copy of the existing file with a .bak extension "
                           @"prior to writing new changes, protecting against accidental data loss.";
    NSTextField *backupDesc = [self makeDescriptionLabel:backupText frame:NSMakeRect(48, 20, cardWidth - 72, 40)];
    [backupCard addSubview:backupDesc];

    [self.backupView addSubview:backupCard];

    // Card 2: Auto-Indentation (Height 136)
    CGFloat indentCardHeight = 138;
    CGFloat indentCardY = backupCardY - indentCardHeight - 16;
    NSBox *indentCard = [self createCardWithTitle:@"Auto-Indentation"
                                            frame:NSMakeRect(24, indentCardY, cardWidth, indentCardHeight)];

    self.autoIndentCheckbox = [NSButton checkboxWithTitle:@"Auto-indent new lines on Return"
                                                   target:self
                                                   action:@selector(autoIndentToggled:)];
    self.autoIndentCheckbox.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightRegular];
    self.autoIndentCheckbox.frame = NSMakeRect(24, 66, cardWidth - 48, 24);
    [indentCard addSubview:self.autoIndentCheckbox];

    NSString *indentText = @"When pressing Return/Enter, the new line will automatically match the "
                           @"leading indentation depth of the preceding line.";
    NSTextField *indentDesc = [self makeDescriptionLabel:indentText frame:NSMakeRect(48, 20, cardWidth - 72, 38)];
    [indentCard addSubview:indentDesc];

    [self.backupView addSubview:indentCard];
}

#pragma mark - Font Population Helper

- (void)populateFontFamilies {
    [self.fontFamilyPopup removeAllItems];

    NSArray *preferredMonospace = @[
        @"Menlo", @"Monaco", @"SF Mono", @"Courier New", @"Courier", @"JetBrains Mono", @"Fira Code", @"Consolas",
        @"Andale Mono"
    ];

    NSFontManager *fm = [NSFontManager sharedFontManager];
    NSArray<NSString *> *allFamilies = [fm availableFontFamilies];

    // 1. Monospace section
    NSMenuItem *monoHeader = [[NSMenuItem alloc] initWithTitle:@"── Monospace Fonts ──" action:nil keyEquivalent:@""];
    [monoHeader setEnabled:NO];
    [self.fontFamilyPopup.menu addItem:monoHeader];

    for (NSString *name in preferredMonospace) {
        if ([allFamilies containsObject:name]) {
            [self.fontFamilyPopup addItemWithTitle:name];
        }
    }

    // 2. Separator & Other System Fonts
    [self.fontFamilyPopup.menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *systemHeader = [[NSMenuItem alloc] initWithTitle:@"── All System Fonts ──"
                                                          action:nil
                                                   keyEquivalent:@""];
    [systemHeader setEnabled:NO];
    [self.fontFamilyPopup.menu addItem:systemHeader];

    for (NSString *name in allFamilies) {
        if (![preferredMonospace containsObject:name]) {
            [self.fontFamilyPopup addItemWithTitle:name];
        }
    }
}

#pragma mark - NSTableViewDataSource & Delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.categories.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"CategoryCell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, 36)];
        cell.identifier = @"CategoryCell";

        NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(10, 8, 20, 20)];
        iconView.imageScaling = NSImageScaleProportionallyDown;
        [cell addSubview:iconView];
        cell.imageView = iconView;

        NSTextField *textField = [NSTextField labelWithString:@""];
        textField.frame = NSMakeRect(38, 8, tableColumn.width - 48, 20);
        textField.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
        [cell addSubview:textField];
        cell.textField = textField;
    }

    NPCategoryItem *item = self.categories[row];
    cell.textField.stringValue = item.title;
    cell.textField.textColor = [self primaryTextColor];

    NSImage *img = nil;
    if (@available(macOS 11.0, *)) {
        img = [NSImage imageWithSystemSymbolName:item.systemSymbol accessibilityDescription:item.title];
    }
    if (!img) {
        img = [NSImage imageNamed:item.iconName];
    }
    cell.imageView.image = img;

    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = self.tableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < (NSInteger)self.categories.count) {
        [self showCategoryIndex:selectedRow];
    }
}

- (void)showCategoryIndex:(NSInteger)index {
    [[self.detailContainer subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];

    NSView *targetView = nil;
    switch (index) {
    case 0:
        targetView = self.generalView;
        break;
    case 1:
        targetView = self.editorView;
        break;
    case 2:
        targetView = self.themeView;
        break;
    case 3:
        targetView = self.encodingView;
        break;
    case 4:
        targetView = self.backupView;
        break;
    default:
        targetView = self.generalView;
        break;
    }

    if (targetView) {
        targetView.frame = self.detailContainer.bounds;
        targetView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self.detailContainer addSubview:targetView];
        [self updateFontPreview];
    }

    if (self.tableView.selectedRow != index) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
    }
}

#pragma mark - Populate Data

- (void)reloadPreferencesValues {
    PreferencesManager *prefs = [PreferencesManager sharedManager];

    // General
    self.showStatusBarCheckbox.state = prefs.showStatusBar ? NSControlStateValueOn : NSControlStateValueOff;
    self.showLineNumbersCheckbox.state = prefs.showLineNumbers ? NSControlStateValueOn : NSControlStateValueOff;
    self.wordWrapCheckbox.state = prefs.wordWrap ? NSControlStateValueOn : NSControlStateValueOff;

    // Editor: Font family & size
    NSString *currentFont = prefs.fontName ?: @"Menlo";
    if ([self.fontFamilyPopup itemWithTitle:currentFont]) {
        [self.fontFamilyPopup selectItemWithTitle:currentFont];
    } else {
        [self.fontFamilyPopup addItemWithTitle:currentFont];
        [self.fontFamilyPopup selectItemWithTitle:currentFont];
    }

    [self.fontSizePopup selectItemWithTag:prefs.fontSize];
    [self.tabWidthPopup selectItemWithTag:prefs.tabWidth];
    self.useSpacesCheckbox.state = prefs.useSpaces ? NSControlStateValueOn : NSControlStateValueOff;

    // Theme
    NSInteger segment = 2;  // System default
    if (prefs.themeMode == NPThemeModeLight)
        segment = 0;
    else if (prefs.themeMode == NPThemeModeDark)
        segment = 1;
    self.themeSegmentedControl.selectedSegment = segment;

    // Encoding
    [self.encodingPopup selectItemWithTag:prefs.defaultEncoding];

    // Backup & Advanced
    self.backupOnSaveCheckbox.state = prefs.backupOnSave ? NSControlStateValueOn : NSControlStateValueOff;
    self.autoIndentCheckbox.state = prefs.autoIndent ? NSControlStateValueOn : NSControlStateValueOff;

    [self updateTabColorControls];
    [self updateFontPreview];
}

- (void)updateFontPreview {
    if (!self.fontPreviewTextView)
        return;

    PreferencesManager *prefs = [PreferencesManager sharedManager];
    NSString *fontName = prefs.fontName ?: @"Menlo";
    NSInteger fontSize = prefs.fontSize > 0 ? prefs.fontSize : 16;

    NSFont *font = [NSFont fontWithName:fontName size:fontSize]
                       ?: [NSFont monospacedSystemFontOfSize:fontSize weight:NSFontWeightRegular];
    self.fontPreviewTextView.font = font;

    self.fontPreviewTextView.backgroundColor = [self previewBgColor];
    self.fontPreviewTextView.textColor = [self previewTextColor];
}

- (void)handlePreferencesChanged:(NSNotification *)notification {
    [self applyThemeColors];
    [self reloadPreferencesValues];
}

#pragma mark - Actions

- (void)fontFamilyChanged:(id)sender {
    NSString *selectedFont = self.fontFamilyPopup.titleOfSelectedItem;
    if (selectedFont.length > 0 && ![selectedFont hasPrefix:@"──"]) {
        PreferencesManager *prefs = [PreferencesManager sharedManager];
        prefs.fontName = selectedFont;
        [prefs savePreferences];
        [self updateFontPreview];
    }
}

- (void)fontSizeChanged:(id)sender {
    NSInteger selectedSize = self.fontSizePopup.selectedTag;
    if (selectedSize > 0) {
        PreferencesManager *prefs = [PreferencesManager sharedManager];
        prefs.fontSize = selectedSize;
        [prefs savePreferences];
        [self updateFontPreview];
    }
}

- (void)tabWidthChanged:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.tabWidth = self.tabWidthPopup.selectedTag;
    [prefs savePreferences];
}

- (void)useSpacesToggled:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.useSpaces = (self.useSpacesCheckbox.state == NSControlStateValueOn);
    [prefs savePreferences];
}

- (void)wordWrapToggled:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.wordWrap = (self.wordWrapCheckbox.state == NSControlStateValueOn);
    [prefs savePreferences];
}

- (void)themeChanged:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    NSInteger seg = self.themeSegmentedControl.selectedSegment;
    if (seg == 0) {
        prefs.themeMode = NPThemeModeLight;
    } else if (seg == 1) {
        prefs.themeMode = NPThemeModeDark;
    } else {
        prefs.themeMode = NPThemeModeSystem;
    }
    [prefs savePreferences];
    [self applyThemeColors];
}

- (void)lineNumbersToggled:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.showLineNumbers = (self.showLineNumbersCheckbox.state == NSControlStateValueOn);
    [prefs savePreferences];
}

- (void)statusBarToggled:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.showStatusBar = (self.showStatusBarCheckbox.state == NSControlStateValueOn);
    [prefs savePreferences];
}

- (void)tabColorPresetChanged:(id)sender {
    NSMenuItem *selected = self.tabColorPresetPopup.selectedItem;
    if (!selected)
        return;

    NSString *hex = (NSString *)selected.representedObject;
    if ([hex isEqualToString:@"CUSTOM"]) {
        [self.tabColorWell activate:YES];
        return;
    }

    if (hex.length > 0) {
        PreferencesManager *prefs = [PreferencesManager sharedManager];
        prefs.activeTabColorHex = hex;
        [prefs savePreferences];
        [self updateTabColorControls];
    }
}

- (void)tabColorWellChanged:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    [prefs setActiveTabColor:self.tabColorWell.color];
    [self updateTabColorControls];
}

- (void)randomColorButtonClicked:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    [prefs pickRandomTabColor];
    [self updateTabColorControls];
}

- (void)randomTabColorsToggled:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.useRandomTabColors = (self.useRandomTabColorsCheckbox.state == NSControlStateValueOn);
    [prefs savePreferences];
}

- (void)encodingChanged:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.defaultEncoding = (NSStringEncoding)self.encodingPopup.selectedTag;
    [prefs savePreferences];
}

- (void)backupOnSaveToggled:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.backupOnSave = (self.backupOnSaveCheckbox.state == NSControlStateValueOn);
    [prefs savePreferences];
}

- (void)autoIndentToggled:(id)sender {
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    prefs.autoIndent = (self.autoIndentCheckbox.state == NSControlStateValueOn);
    [prefs savePreferences];
}

- (void)closeButtonClicked:(id)sender {
    [self.window close];
}

- (void)showWindow:(nullable id)sender {
    [self applyThemeColors];
    [self reloadPreferencesValues];
    [super showWindow:sender];
    [self.window makeKeyAndOrderFront:sender];
    [NSApp activateIgnoringOtherApps:YES];
}

@end
