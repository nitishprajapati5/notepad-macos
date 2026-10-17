#import "NotepadTabBarView.h"
#import "PreferencesManager.h"

@interface NotepadTabBarView ()

@property (nonatomic, assign) NSInteger hoveredTabIndex;
@property (nonatomic, assign) NSInteger hoveredCloseIndex;
@property (nonatomic, assign) BOOL isPlusHovered;
@property (nonatomic, assign) BOOL isLeftScrollHovered;
@property (nonatomic, assign) BOOL isRightScrollHovered;
@property (nonatomic, assign) CGFloat scrollOffset;
@property (nonatomic, strong) NSTrackingArea *trackingArea;

@end

@implementation NotepadTabBarView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _tabs = @[];
        _selectedIndex = 0;
        _hoveredTabIndex = -1;
        _hoveredCloseIndex = -1;
        _isPlusHovered = NO;
        _isLeftScrollHovered = NO;
        _isRightScrollHovered = NO;
        _scrollOffset = 0.0;
    }
    return self;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.trackingArea) {
        [self removeTrackingArea:self.trackingArea];
    }
    NSTrackingAreaOptions options =
        NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect;
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:options owner:self userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

- (BOOL)isDark {
    return [[PreferencesManager sharedManager] isDarkModeActive];
}

- (CGFloat)leftOffset {
    if (self.window && (self.window.styleMask & NSWindowStyleMaskFullSizeContentView)) {
        return 76.0;  // Space for macOS window traffic lights in full-size mode
    }
    return 8.0;  // Standard left margin when titlebar is separate
}

- (CGFloat)tabWidth {
    if (self.tabs.count == 0)
        return 110.0;
    CGFloat available = self.bounds.size.width - [self leftOffset] - 50.0;
    CGFloat w = (available / self.tabs.count) - 3.0;
    return MAX(85.0, MIN(130.0, w));
}

- (CGFloat)totalContentWidth {
    CGFloat tWidth = [self tabWidth];
    return [self leftOffset] + self.tabs.count * (tWidth + 3.0) + 24.0 + 8.0;
}

- (BOOL)canScrollTabs {
    return [self totalContentWidth] > self.bounds.size.width;
}

- (CGFloat)availableWidthForTabs {
    return [self canScrollTabs] ? (self.bounds.size.width - 50.0) : self.bounds.size.width;
}

- (CGFloat)maxScrollOffset {
    CGFloat maxScroll = [self totalContentWidth] - [self availableWidthForTabs];
    return MAX(0.0, maxScroll);
}

- (void)clampScrollOffset {
    CGFloat maxScroll = [self maxScrollOffset];
    if (_scrollOffset > maxScroll) {
        _scrollOffset = maxScroll;
    }
    if (_scrollOffset < 0.0) {
        _scrollOffset = 0.0;
    }
}

- (void)scrollBy:(CGFloat)delta {
    _scrollOffset += delta;
    [self clampScrollOffset];
    [self setNeedsDisplay:YES];
}

- (void)ensureTabVisibleAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.tabs.count)
        return;

    CGFloat tWidth = [self tabWidth];
    CGFloat leftEdge = [self leftOffset] + index * (tWidth + 3.0);
    CGFloat rightEdge = leftEdge + tWidth;

    CGFloat visibleLeft = _scrollOffset + [self leftOffset];
    CGFloat availableWidth = [self availableWidthForTabs];
    CGFloat visibleRight = _scrollOffset + availableWidth;

    if (leftEdge < visibleLeft) {
        _scrollOffset = MAX(0.0, leftEdge - [self leftOffset]);
        [self setNeedsDisplay:YES];
    } else if (rightEdge > visibleRight) {
        _scrollOffset = MAX(0.0, rightEdge - availableWidth + 8.0);
        [self clampScrollOffset];
        [self setNeedsDisplay:YES];
    }
}

- (void)setSelectedIndex:(NSInteger)selectedIndex {
    _selectedIndex = selectedIndex;
    [self ensureTabVisibleAtIndex:selectedIndex];
    [self setNeedsDisplay:YES];
}

- (void)setFrame:(NSRect)frame {
    [super setFrame:frame];
    [self clampScrollOffset];
}

- (NSRect)rectForTabAtIndex:(NSInteger)index {
    CGFloat tWidth = [self tabWidth];
    CGFloat x = [self leftOffset] + index * (tWidth + 3.0) - _scrollOffset;
    return NSMakeRect(x, 3.0, tWidth, self.bounds.size.height - 6.0);
}

- (NSRect)closeButtonRectForTabRect:(NSRect)tabRect {
    CGFloat sz = 14.0;
    CGFloat x = NSMaxX(tabRect) - sz - 5.0;
    CGFloat y = tabRect.origin.y + (tabRect.size.height - sz) / 2.0;
    return NSMakeRect(x, y, sz, sz);
}

- (NSRect)plusButtonRect {
    CGFloat tWidth = [self tabWidth];
    CGFloat x = [self leftOffset] + self.tabs.count * (tWidth + 3.0) + 4.0 - _scrollOffset;
    CGFloat sz = 18.0;
    CGFloat y = (self.bounds.size.height - sz) / 2.0;
    return NSMakeRect(x, y, sz, sz);
}

- (NSRect)leftScrollButtonRect {
    CGFloat sz = 18.0;
    CGFloat y = (self.bounds.size.height - sz) / 2.0;
    return NSMakeRect(self.bounds.size.width - 44.0, y, sz, sz);
}

- (NSRect)rightScrollButtonRect {
    CGFloat sz = 18.0;
    CGFloat y = (self.bounds.size.height - sz) / 2.0;
    return NSMakeRect(self.bounds.size.width - 22.0, y, sz, sz);
}

- (void)reloadTabs {
    [self clampScrollOffset];
    [self ensureTabVisibleAtIndex:self.selectedIndex];
    [self setNeedsDisplay:YES];
}

- (void)updateTheme {
    [self setNeedsDisplay:YES];
}

#pragma mark - Mouse Events

- (void)scrollWheel:(NSEvent *)event {
    if ([self canScrollTabs]) {
        CGFloat delta = event.scrollingDeltaX;
        // Support vertical scrollwheel / shift-scrolling for horizontal tab navigation
        if (fabs(delta) < 0.1 &&
            (event.modifierFlags & NSEventModifierFlagShift || fabs(event.scrollingDeltaY) > 0.1)) {
            delta = -event.scrollingDeltaY;
        }
        if (event.hasPreciseScrollingDeltas) {
            [self scrollBy:-delta];
        } else {
            [self scrollBy:-delta * 14.0];
        }
    } else {
        [super scrollWheel:event];
    }
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger oldHoverTab = self.hoveredTabIndex;
    NSInteger oldHoverClose = self.hoveredCloseIndex;
    BOOL oldPlusHover = self.isPlusHovered;
    BOOL oldLeftScrollHover = self.isLeftScrollHovered;
    BOOL oldRightScrollHover = self.isRightScrollHovered;

    self.hoveredTabIndex = -1;
    self.hoveredCloseIndex = -1;
    self.isPlusHovered = NO;
    self.isLeftScrollHovered = NO;
    self.isRightScrollHovered = NO;

    if ([self canScrollTabs]) {
        if (NSPointInRect(location, [self leftScrollButtonRect])) {
            self.isLeftScrollHovered = YES;
        } else if (NSPointInRect(location, [self rightScrollButtonRect])) {
            self.isRightScrollHovered = YES;
        }
    }

    CGFloat clipRight = [self availableWidthForTabs];

    if (!self.isLeftScrollHovered && !self.isRightScrollHovered && location.x <= clipRight) {
        for (NSInteger i = 0; i < (NSInteger)self.tabs.count; i++) {
            NSRect tabRect = [self rectForTabAtIndex:i];
            if (NSPointInRect(location, tabRect)) {
                self.hoveredTabIndex = i;
                NSRect closeRect = [self closeButtonRectForTabRect:tabRect];
                if (NSPointInRect(location, closeRect)) {
                    self.hoveredCloseIndex = i;
                }
                break;
            }
        }

        if (NSPointInRect(location, [self plusButtonRect])) {
            self.isPlusHovered = YES;
        }
    }

    if (oldHoverTab != self.hoveredTabIndex || oldHoverClose != self.hoveredCloseIndex ||
        oldPlusHover != self.isPlusHovered || oldLeftScrollHover != self.isLeftScrollHovered ||
        oldRightScrollHover != self.isRightScrollHovered) {
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseExited:(NSEvent *)event {
    self.hoveredTabIndex = -1;
    self.hoveredCloseIndex = -1;
    self.isPlusHovered = NO;
    self.isLeftScrollHovered = NO;
    self.isRightScrollHovered = NO;
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];

    // 1. Check Scroll Buttons
    if ([self canScrollTabs]) {
        if (NSPointInRect(location, [self leftScrollButtonRect])) {
            CGFloat step = [self tabWidth] + 3.0;
            [self scrollBy:-step];
            return;
        }
        if (NSPointInRect(location, [self rightScrollButtonRect])) {
            CGFloat step = [self tabWidth] + 3.0;
            [self scrollBy:step];
            return;
        }
    }

    CGFloat clipRight = [self availableWidthForTabs];
    if ([self canScrollTabs] && location.x > clipRight) {
        return;  // Ignore clicks in scroll button margin area
    }

    // 2. Check [+] Plus button
    if (NSPointInRect(location, [self plusButtonRect])) {
        if ([self.delegate respondsToSelector:@selector(tabBarViewDidClickNewTab:)]) {
            [self.delegate tabBarViewDidClickNewTab:self];
        }
        return;
    }

    // 3. Check tabs
    for (NSInteger i = 0; i < (NSInteger)self.tabs.count; i++) {
        NSRect tabRect = [self rectForTabAtIndex:i];
        if (NSPointInRect(location, tabRect)) {
            NSRect closeRect = [self closeButtonRectForTabRect:tabRect];
            if (NSPointInRect(location, closeRect)) {
                if ([self.delegate respondsToSelector:@selector(tabBarView:didCloseTabAtIndex:)]) {
                    [self.delegate tabBarView:self didCloseTabAtIndex:i];
                }
            } else {
                if ([self.delegate respondsToSelector:@selector(tabBarView:didSelectTabAtIndex:)]) {
                    [self.delegate tabBarView:self didSelectTabAtIndex:i];
                }
            }
            return;
        }
    }

    // 4. Double click on empty tab bar area opens new tab (Notepad++ feature)
    if (event.clickCount == 2) {
        if ([self.delegate respondsToSelector:@selector(tabBarViewDidClickNewTab:)]) {
            [self.delegate tabBarViewDidClickNewTab:self];
        }
    }
}

- (void)otherMouseDown:(NSEvent *)event {
    // Middle click closes tab (buttonNumber 2)
    if (event.buttonNumber == 2) {
        NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
        CGFloat clipRight = [self availableWidthForTabs];
        if ([self canScrollTabs] && location.x > clipRight)
            return;

        for (NSInteger i = 0; i < (NSInteger)self.tabs.count; i++) {
            NSRect tabRect = [self rectForTabAtIndex:i];
            if (NSPointInRect(location, tabRect)) {
                if ([self.delegate respondsToSelector:@selector(tabBarView:didCloseTabAtIndex:)]) {
                    [self.delegate tabBarView:self didCloseTabAtIndex:i];
                }
                return;
            }
        }
    }
}

#pragma mark - Drawing Helpers

- (void)drawFloppyDiskInRect:(NSRect)rect isDirty:(BOOL)isDirty isDark:(BOOL)isDark isSelected:(BOOL)isSelected {
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;

    NSColor *bodyColor;
    NSColor *accentColor;

    if (isDirty) {
        // Red when modified / unsaved
        bodyColor = [NSColor colorWithCalibratedRed:0.98 green:0.32 blue:0.28 alpha:1.0];
        accentColor = [NSColor colorWithCalibratedRed:0.98 green:0.32 blue:0.28 alpha:1.0];
    } else if (isSelected) {
        // Active tab: Crisp white icon
        bodyColor = [NSColor colorWithCalibratedWhite:0.98 alpha:0.98];
        accentColor = [NSColor colorWithCalibratedWhite:0.98 alpha:0.98];
    } else {
        // Inactive tabs: Subtle light gray body with electric cyan shutter
        bodyColor = isDark ? [NSColor colorWithCalibratedWhite:0.75 alpha:0.9]
                           : [NSColor colorWithCalibratedWhite:0.38 alpha:0.9];
        accentColor = [NSColor colorWithCalibratedRed:0.26 green:0.78 blue:1.0 alpha:1.0];
    }

    // Outer floppy body path with notch at top-right
    NSBezierPath *body = [NSBezierPath bezierPath];
    CGFloat r = 1.0;
    CGFloat notch = 2.4;

    [body moveToPoint:NSMakePoint(x + r, y)];
    [body lineToPoint:NSMakePoint(x + w - r, y)];
    [body appendBezierPathWithArcWithCenter:NSMakePoint(x + w - r, y + r)
                                     radius:r
                                 startAngle:270
                                   endAngle:0
                                  clockwise:NO];
    [body lineToPoint:NSMakePoint(x + w, y + h - notch)];
    [body lineToPoint:NSMakePoint(x + w - notch, y + h)];
    [body lineToPoint:NSMakePoint(x + r, y + h)];
    [body appendBezierPathWithArcWithCenter:NSMakePoint(x + r, y + h - r)
                                     radius:r
                                 startAngle:90
                                   endAngle:180
                                  clockwise:NO];
    [body lineToPoint:NSMakePoint(x, y + r)];
    [body appendBezierPathWithArcWithCenter:NSMakePoint(x + r, y + r)
                                     radius:r
                                 startAngle:180
                                   endAngle:270
                                  clockwise:NO];
    [body closePath];

    body.lineWidth = 1.0;
    [bodyColor setStroke];
    [body stroke];

    // Metal shutter at top
    NSRect shutter = NSMakeRect(x + 2.2, y + h - 4.0, w - 4.4, 3.2);
    NSBezierPath *shutterPath = [NSBezierPath bezierPathWithRect:shutter];
    [accentColor setStroke];
    shutterPath.lineWidth = 0.85;
    [shutterPath stroke];

    // Slot line inside shutter
    NSBezierPath *slotPath = [NSBezierPath bezierPath];
    [slotPath moveToPoint:NSMakePoint(x + 4.0, y + h - 3.4)];
    [slotPath lineToPoint:NSMakePoint(x + 4.0, y + h - 1.5)];
    slotPath.lineWidth = 0.85;
    [accentColor setStroke];
    [slotPath stroke];

    // Label area at bottom
    NSRect label = NSMakeRect(x + 1.8, y + 1.5, w - 3.6, 3.4);
    NSBezierPath *labelPath = [NSBezierPath bezierPathWithRoundedRect:label xRadius:0.5 yRadius:0.5];
    [bodyColor setStroke];
    labelPath.lineWidth = 0.8;
    [labelPath stroke];
}

- (void)drawScrollButtonInRect:(NSRect)rect
                        isLeft:(BOOL)isLeft
                       enabled:(BOOL)enabled
                       hovered:(BOOL)hovered
                        isDark:(BOOL)isDark {
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:rect];

    NSColor *circleBg;
    if (hovered && enabled) {
        circleBg = isDark ? [NSColor colorWithCalibratedWhite:0.35 alpha:0.8]
                          : [NSColor colorWithCalibratedWhite:0.75 alpha:0.8];
    } else {
        circleBg = isDark ? [NSColor colorWithCalibratedWhite:0.20 alpha:0.6]
                          : [NSColor colorWithCalibratedWhite:0.84 alpha:0.6];
    }
    [circleBg setFill];
    [circle fill];

    // Chevron arrow color
    NSColor *chevronColor;
    if (!enabled) {
        chevronColor = isDark ? [NSColor colorWithCalibratedWhite:0.4 alpha:0.35]
                              : [NSColor colorWithCalibratedWhite:0.6 alpha:0.35];
    } else if (hovered) {
        chevronColor = isDark ? [NSColor whiteColor] : [NSColor blackColor];
    } else {
        chevronColor = isDark ? [NSColor colorWithCalibratedWhite:0.90 alpha:0.95]
                              : [NSColor colorWithCalibratedWhite:0.20 alpha:0.95];
    }

    CGFloat cx = rect.origin.x + rect.size.width / 2.0;
    CGFloat cy = rect.origin.y + rect.size.height / 2.0;

    NSBezierPath *chevron = [NSBezierPath bezierPath];
    chevron.lineWidth = 1.3;
    chevron.lineCapStyle = NSLineCapStyleRound;
    chevron.lineJoinStyle = NSLineJoinStyleRound;

    if (isLeft) {
        [chevron moveToPoint:NSMakePoint(cx + 1.8, cy + 3.2)];
        [chevron lineToPoint:NSMakePoint(cx - 1.8, cy)];
        [chevron lineToPoint:NSMakePoint(cx + 1.8, cy - 3.2)];
    } else {
        [chevron moveToPoint:NSMakePoint(cx - 1.8, cy + 3.2)];
        [chevron lineToPoint:NSMakePoint(cx + 1.8, cy)];
        [chevron lineToPoint:NSMakePoint(cx - 1.8, cy - 3.2)];
    }

    [chevronColor setStroke];
    [chevron stroke];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    BOOL dark = [self isDark];

    // 1. Tab Bar Background
    NSColor *barBg = dark ? [NSColor colorWithCalibratedRed:0.11 green:0.115 blue:0.125 alpha:1.0]
                          : [NSColor colorWithCalibratedWhite:0.93 alpha:1.0];
    [barBg setFill];
    NSRectFill(self.bounds);

    // Bottom border separating tabs from editor
    NSColor *bottomBorderColor =
        dark ? [NSColor colorWithCalibratedWhite:0.0 alpha:0.5] : [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
    [bottomBorderColor setFill];
    NSRectFill(NSMakeRect(0, 0, self.bounds.size.width, 1.0));

    BOOL hasScroll = [self canScrollTabs];
    CGFloat clipRight = [self availableWidthForTabs];

    // Clip tabs area so they don't bleed behind the scroll buttons
    [NSGraphicsContext saveGraphicsState];
    NSRect tabClipRect = NSMakeRect(0, 0, clipRight, self.bounds.size.height);
    [NSBezierPath clipRect:tabClipRect];

    // 2. Draw Tabs
    for (NSInteger i = 0; i < (NSInteger)self.tabs.count; i++) {
        NotepadTabItem *tab = self.tabs[i];
        NSRect tabRect = [self rectForTabAtIndex:i];

        // Skip drawing if outside visible bounds
        if (NSMaxX(tabRect) < 0 || tabRect.origin.x > clipRight) {
            continue;
        }

        BOOL isSelected = (i == self.selectedIndex);
        BOOL isHovered = (i == self.hoveredTabIndex);

        // Modern floating pill with 5.0 corner radius
        CGFloat r = 5.0;
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:tabRect xRadius:r yRadius:r];

        if (isSelected) {
            // Draw subtle drop shadow for active tab
            [NSGraphicsContext saveGraphicsState];
            NSShadow *shadow = [[NSShadow alloc] init];
            shadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:dark ? 0.40 : 0.15];
            shadow.shadowOffset = NSMakeSize(0, -1.0);
            shadow.shadowBlurRadius = 3.0;
            [shadow set];

            // Dynamic Active Tab Color from Preferences or Tab's random color
            PreferencesManager *prefs = [PreferencesManager sharedManager];
            NSColor *baseColor = (tab.tabColor && prefs.useRandomTabColors) ? tab.tabColor : [prefs activeTabColor];
            if (!baseColor) {
                baseColor = [NSColor colorWithCalibratedRed:0.85 green:0.51 blue:0.15 alpha:1.0];
            }

            NSColor *rgbColor = [baseColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] ?: baseColor;
            CGFloat cr = 0, cg = 0, cb = 0, ca = 1.0;
            [rgbColor getRed:&cr green:&cg blue:&cb alpha:&ca];

            NSColor *topColor, *bottomColor;
            if (dark) {
                topColor = [NSColor colorWithCalibratedRed:MIN(1.0, cr * 1.08)
                                                     green:MIN(1.0, cg * 1.08)
                                                      blue:MIN(1.0, cb * 1.08)
                                                     alpha:1.0];
                bottomColor = [NSColor colorWithCalibratedRed:MAX(0.0, cr * 0.72)
                                                        green:MAX(0.0, cg * 0.72)
                                                         blue:MAX(0.0, cb * 0.72)
                                                        alpha:1.0];
            } else {
                topColor = [NSColor colorWithCalibratedRed:MIN(1.0, cr * 1.12)
                                                     green:MIN(1.0, cg * 1.12)
                                                      blue:MIN(1.0, cb * 1.12)
                                                     alpha:1.0];
                bottomColor = [NSColor colorWithCalibratedRed:MAX(0.0, cr * 0.82)
                                                        green:MAX(0.0, cg * 0.82)
                                                         blue:MAX(0.0, cb * 0.82)
                                                        alpha:1.0];
            }

            NSGradient *tabGrad = [[NSGradient alloc] initWithStartingColor:topColor endingColor:bottomColor];
            [tabGrad drawInBezierPath:path angle:270];
            [NSGraphicsContext restoreGraphicsState];

            // Inner subtle border highlight for sleek chic depth
            NSColor *borderColor = [NSColor colorWithCalibratedWhite:1.0 alpha:dark ? 0.22 : 0.40];
            [borderColor setStroke];
            path.lineWidth = 0.75;
            [path stroke];
        } else {
            // Inactive Tab Background
            NSColor *inactiveBg;
            NSColor *inactiveBorder;
            if (dark) {
                inactiveBg = isHovered ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.10]
                                       : [NSColor colorWithCalibratedRed:0.15 green:0.155 blue:0.17 alpha:0.85];
                inactiveBorder = isHovered ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.18]
                                           : [NSColor colorWithCalibratedWhite:1.0 alpha:0.07];
            } else {
                inactiveBg = isHovered ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.95]
                                       : [NSColor colorWithCalibratedWhite:0.87 alpha:0.85];
                inactiveBorder = isHovered ? [NSColor colorWithCalibratedWhite:0.70 alpha:0.8]
                                           : [NSColor colorWithCalibratedWhite:0.78 alpha:0.6];
            }

            [inactiveBg setFill];
            [path fill];

            [inactiveBorder setStroke];
            path.lineWidth = 0.75;
            [path stroke];

            // If multi-color tabs enabled, draw chic top accent pill inside inactive tab
            if (tab.tabColor && [PreferencesManager sharedManager].useRandomTabColors) {
                NSRect accentRect =
                    NSMakeRect(tabRect.origin.x + 6.0, NSMaxY(tabRect) - 2.5, tabRect.size.width - 12.0, 1.8);
                NSBezierPath *accentPath = [NSBezierPath bezierPathWithRoundedRect:accentRect xRadius:0.9 yRadius:0.9];
                [tab.tabColor setFill];
                [accentPath fill];
            }
        }

        // 3. Tab Content
        CGFloat contentLeft = tabRect.origin.x + 7.0;

        // Draw Floppy Disk Icon 💾
        CGFloat diskSize = 12.0;
        CGFloat diskY = tabRect.origin.y + (tabRect.size.height - diskSize) / 2.0;
        NSRect diskRect = NSMakeRect(contentLeft, diskY, diskSize, diskSize);
        [self drawFloppyDiskInRect:diskRect isDirty:tab.isDirty isDark:dark isSelected:isSelected];
        contentLeft += diskSize + 6.0;

        // Close Button (✕) Rect
        NSRect closeRect = [self closeButtonRectForTabRect:tabRect];
        CGFloat titleMaxWidth = closeRect.origin.x - contentLeft - 3.0;

        // Tab Title Text
        NSColor *titleColor;
        if (isSelected) {
            titleColor = [NSColor whiteColor];
        } else {
            titleColor = dark ? (isHovered ? [NSColor colorWithCalibratedWhite:0.98 alpha:1.0]
                                           : [NSColor colorWithCalibratedWhite:0.76 alpha:1.0])
                              : (isHovered ? [NSColor colorWithCalibratedWhite:0.05 alpha:1.0]
                                           : [NSColor colorWithCalibratedWhite:0.25 alpha:1.0]);
        }

        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineBreakMode = NSLineBreakByTruncatingTail;
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:11.5
                                                   weight:isSelected ? NSFontWeightMedium : NSFontWeightRegular],
            NSForegroundColorAttributeName: titleColor,
            NSParagraphStyleAttributeName: style
        };

        NSAttributedString *titleStr = [[NSAttributedString alloc] initWithString:tab.title attributes:attrs];
        NSSize titleSize = [titleStr size];
        CGFloat titleY = tabRect.origin.y + (tabRect.size.height - titleSize.height) / 2.0;
        NSRect textRect = NSMakeRect(contentLeft, titleY, titleMaxWidth, titleSize.height);
        [titleStr drawInRect:textRect];

        // Close Button (✕)
        BOOL isCloseHover = (i == self.hoveredCloseIndex);
        if (isSelected || isHovered) {
            if (isCloseHover) {
                NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:closeRect];
                NSColor *circleBg = isSelected ? [NSColor colorWithCalibratedWhite:0.0 alpha:0.25]
                                               : (dark ? [NSColor colorWithCalibratedWhite:0.35 alpha:0.6]
                                                       : [NSColor colorWithCalibratedWhite:0.75 alpha:0.7]);
                [circleBg setFill];
                [circle fill];
            }

            NSColor *xColor = isSelected ? [NSColor whiteColor]
                                         : (isCloseHover ? (dark ? [NSColor whiteColor] : [NSColor blackColor])
                                                         : (dark ? [NSColor colorWithCalibratedWhite:0.75 alpha:1.0]
                                                                 : [NSColor colorWithCalibratedWhite:0.35 alpha:1.0]));

            CGFloat cx = closeRect.origin.x + closeRect.size.width / 2.0;
            CGFloat cy = closeRect.origin.y + closeRect.size.height / 2.0;
            CGFloat xr = 3.0;

            NSBezierPath *xPath = [NSBezierPath bezierPath];
            [xPath moveToPoint:NSMakePoint(cx - xr, cy - xr)];
            [xPath lineToPoint:NSMakePoint(cx + xr, cy + xr)];
            [xPath moveToPoint:NSMakePoint(cx - xr, cy + xr)];
            [xPath lineToPoint:NSMakePoint(cx + xr, cy - xr)];
            xPath.lineWidth = 1.25;
            xPath.lineCapStyle = NSLineCapStyleRound;
            [xColor setStroke];
            [xPath stroke];
        }
    }

    // 4. Draw [+] Plus Button (New Tab)
    NSRect plusRect = [self plusButtonRect];
    if (NSMaxX(plusRect) > 0 && plusRect.origin.x <= clipRight) {
        if (self.isPlusHovered) {
            NSBezierPath *plusBg = [NSBezierPath bezierPathWithRoundedRect:plusRect xRadius:4.0 yRadius:4.0];
            NSColor *hoverFill = dark ? [NSColor colorWithCalibratedWhite:0.25 alpha:0.6]
                                      : [NSColor colorWithCalibratedWhite:0.80 alpha:0.7];
            [hoverFill setFill];
            [plusBg fill];
        }

        NSColor *plusColor = self.isPlusHovered ? (dark ? [NSColor whiteColor] : [NSColor blackColor])
                                                : (dark ? [NSColor colorWithCalibratedWhite:0.68 alpha:1.0]
                                                        : [NSColor colorWithCalibratedWhite:0.38 alpha:1.0]);

        CGFloat pcx = plusRect.origin.x + plusRect.size.width / 2.0;
        CGFloat pcy = plusRect.origin.y + plusRect.size.height / 2.0;
        CGFloat pr = 4.2;

        NSBezierPath *plusPath = [NSBezierPath bezierPath];
        [plusPath moveToPoint:NSMakePoint(pcx - pr, pcy)];
        [plusPath lineToPoint:NSMakePoint(pcx + pr, pcy)];
        [plusPath moveToPoint:NSMakePoint(pcx, pcy - pr)];
        [plusPath lineToPoint:NSMakePoint(pcx, pcy + pr)];
        plusPath.lineWidth = 1.35;
        plusPath.lineCapStyle = NSLineCapStyleRound;
        [plusColor setStroke];
        [plusPath stroke];
    }

    [NSGraphicsContext restoreGraphicsState];

    // 5. Draw Right Scroll Controls (< and >) if overflow occurs
    if (hasScroll) {
        CGFloat fadeWidth = 16.0;
        CGFloat fadeX = clipRight - fadeWidth;
        NSRect fadeRect = NSMakeRect(fadeX, 0, fadeWidth, self.bounds.size.height);

        NSColor *fadeStart = dark ? [NSColor colorWithCalibratedRed:0.11 green:0.115 blue:0.125 alpha:0.0]
                                  : [NSColor colorWithCalibratedWhite:0.93 alpha:0.0];
        NSColor *fadeEnd = dark ? [NSColor colorWithCalibratedRed:0.11 green:0.115 blue:0.125 alpha:1.0]
                                : [NSColor colorWithCalibratedWhite:0.93 alpha:1.0];
        NSGradient *fadeGrad = [[NSGradient alloc] initWithStartingColor:fadeStart endingColor:fadeEnd];
        [fadeGrad drawInRect:fadeRect angle:0];

        NSRect buttonsBgRect = NSMakeRect(clipRight, 0, self.bounds.size.width - clipRight, self.bounds.size.height);
        [fadeEnd setFill];
        NSRectFill(buttonsBgRect);

        BOOL canScrollLeft = (_scrollOffset > 0.5);
        [self drawScrollButtonInRect:[self leftScrollButtonRect]
                              isLeft:YES
                             enabled:canScrollLeft
                             hovered:self.isLeftScrollHovered
                              isDark:dark];

        BOOL canScrollRight = (_scrollOffset < [self maxScrollOffset] - 0.5);
        [self drawScrollButtonInRect:[self rightScrollButtonRect]
                              isLeft:NO
                             enabled:canScrollRight
                             hovered:self.isRightScrollHovered
                              isDark:dark];
    }
}

@end
