#import "NotepadTabBarView.h"
#import "PreferencesManager.h"

@interface NotepadTabBarView ()

@property (nonatomic, assign) NSInteger hoveredTabIndex;
@property (nonatomic, assign) NSInteger hoveredCloseIndex;
@property (nonatomic, assign) BOOL isPlusHovered;
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
        self.wantsLayer = YES;
    }
    return self;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.trackingArea) {
        [self removeTrackingArea:self.trackingArea];
    }
    NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited |
                                    NSTrackingMouseMoved |
                                    NSTrackingActiveAlways |
                                    NSTrackingInVisibleRect;
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                     options:options
                                                       owner:self
                                                    userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

- (BOOL)isDark {
    return [[PreferencesManager sharedManager] isDarkModeActive];
}

- (CGFloat)leftOffset {
    return 76.0; // Space for macOS window traffic lights
}

- (CGFloat)tabWidth {
    if (self.tabs.count == 0) return 140.0;
    CGFloat available = self.bounds.size.width - [self leftOffset] - 50.0;
    CGFloat w = (available / self.tabs.count) - 2.0;
    return MAX(110.0, MIN(180.0, w));
}

- (NSRect)rectForTabAtIndex:(NSInteger)index {
    CGFloat tWidth = [self tabWidth];
    CGFloat x = [self leftOffset] + index * (tWidth + 2.0);
    return NSMakeRect(x, 2.0, tWidth, self.bounds.size.height - 2.0);
}

- (NSRect)closeButtonRectForTabRect:(NSRect)tabRect {
    CGFloat sz = 16.0;
    CGFloat x = NSMaxX(tabRect) - sz - 8.0;
    CGFloat y = tabRect.origin.y + (tabRect.size.height - sz) / 2.0;
    return NSMakeRect(x, y, sz, sz);
}

- (NSRect)plusButtonRect {
    CGFloat tWidth = [self tabWidth];
    CGFloat x = [self leftOffset] + self.tabs.count * (tWidth + 2.0) + 4.0;
    CGFloat sz = 22.0;
    CGFloat y = (self.bounds.size.height - sz) / 2.0;
    return NSMakeRect(x, y, sz, sz);
}

- (void)reloadTabs {
    [self setNeedsDisplay:YES];
}

- (void)updateTheme {
    [self setNeedsDisplay:YES];
}

#pragma mark - Mouse Events

- (void)mouseMoved:(NSEvent *)event {
    NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger oldHoverTab = self.hoveredTabIndex;
    NSInteger oldHoverClose = self.hoveredCloseIndex;
    BOOL oldPlusHover = self.isPlusHovered;

    self.hoveredTabIndex = -1;
    self.hoveredCloseIndex = -1;
    self.isPlusHovered = NO;

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

    if (oldHoverTab != self.hoveredTabIndex ||
        oldHoverClose != self.hoveredCloseIndex ||
        oldPlusHover != self.isPlusHovered) {
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseExited:(NSEvent *)event {
    self.hoveredTabIndex = -1;
    self.hoveredCloseIndex = -1;
    self.isPlusHovered = NO;
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];

    // Check plus button
    if (NSPointInRect(location, [self plusButtonRect])) {
        if ([self.delegate respondsToSelector:@selector(tabBarViewDidClickNewTab:)]) {
            [self.delegate tabBarViewDidClickNewTab:self];
        }
        return;
    }

    // Check tabs
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

    // Double click on empty tab bar area opens new tab (Notepad++ feature)
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

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    BOOL dark = [self isDark];

    // 1. Tab Bar Background
    NSColor *barBg = dark ?
        [NSColor colorWithCalibratedRed:0.09 green:0.09 blue:0.10 alpha:1.0] : // #17171A
        [NSColor colorWithCalibratedWhite:0.92 alpha:1.0];
    [barBg setFill];
    NSRectFill(self.bounds);

    // Bottom border separating tabs from editor
    NSColor *bottomBorderColor = dark ?
        [NSColor colorWithCalibratedRed:0.18 green:0.18 blue:0.20 alpha:1.0] :
        [NSColor colorWithCalibratedWhite:0.80 alpha:1.0];
    [bottomBorderColor setFill];
    NSRectFill(NSMakeRect(0, 0, self.bounds.size.width, 1.0));

    // 2. Draw Tabs
    for (NSInteger i = 0; i < (NSInteger)self.tabs.count; i++) {
        NotepadTabItem *tab = self.tabs[i];
        NSRect tabRect = [self rectForTabAtIndex:i];
        BOOL isSelected = (i == self.selectedIndex);
        BOOL isHovered = (i == self.hoveredTabIndex);

        // Tab Pill Path with Rounded Top Corners
        CGFloat r = 6.0;
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(tabRect.origin.x, tabRect.origin.y)];
        [path lineToPoint:NSMakePoint(tabRect.origin.x, NSMaxY(tabRect) - r)];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(tabRect.origin.x + r, NSMaxY(tabRect) - r)
                                         radius:r
                                     startAngle:180
                                       endAngle:90
                                      clockwise:YES];
        [path lineToPoint:NSMakePoint(NSMaxX(tabRect) - r, NSMaxY(tabRect))];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(tabRect) - r, NSMaxY(tabRect) - r)
                                         radius:r
                                     startAngle:90
                                       endAngle:0
                                      clockwise:YES];
        [path lineToPoint:NSMakePoint(NSMaxX(tabRect), tabRect.origin.y)];
        [path closePath];

        if (isSelected) {
            // Selected tab background matches editor canvas
            NSColor *activeTabColor = dark ?
                [NSColor colorWithCalibratedRed:0.125 green:0.125 blue:0.125 alpha:1.0] : // #202020
                [NSColor whiteColor];
            [activeTabColor setFill];
            [path fill];

            // Top active accent line (Windows 11 Notepad / Notepad++ blue accent)
            NSRect accentRect = NSMakeRect(tabRect.origin.x + 4.0, NSMaxY(tabRect) - 2.0, tabRect.size.width - 8.0, 2.0);
            [[NSColor colorWithCalibratedRed:0.04 green:0.52 blue:1.0 alpha:1.0] setFill];
            NSRectFill(accentRect);
        } else {
            if (isHovered) {
                NSColor *hoverColor = dark ?
                    [NSColor colorWithCalibratedWhite:0.16 alpha:1.0] :
                    [NSColor colorWithCalibratedWhite:0.86 alpha:1.0];
                [hoverColor setFill];
                [path fill];
            }
            // Vertical divider between unselected tabs
            if (i < (NSInteger)self.tabs.count - 1 && i + 1 != self.selectedIndex) {
                NSColor *divColor = dark ?
                    [NSColor colorWithCalibratedWhite:0.22 alpha:1.0] :
                    [NSColor colorWithCalibratedWhite:0.78 alpha:1.0];
                [divColor setFill];
                NSRectFill(NSMakeRect(NSMaxX(tabRect), 8.0, 1.0, tabRect.size.height - 14.0));
            }
        }

        // Draw Tab Content
        CGFloat contentLeft = tabRect.origin.x + 10.0;
        NSRect closeRect = [self closeButtonRectForTabRect:tabRect];
        CGFloat titleMaxWidth = closeRect.origin.x - contentLeft - 6.0;

        // Dirty Dot Indicator (●)
        if (tab.isDirty) {
            CGFloat dotSize = 6.0;
            CGFloat dotY = tabRect.origin.y + (tabRect.size.height - dotSize) / 2.0;
            NSRect dotRect = NSMakeRect(contentLeft, dotY, dotSize, dotSize);
            NSBezierPath *dotPath = [NSBezierPath bezierPathWithOvalInRect:dotRect];
            NSColor *dotColor = dark ?
                [NSColor colorWithCalibratedRed:1.0 green:0.65 blue:0.2 alpha:1.0] :
                [NSColor colorWithCalibratedRed:0.9 green:0.4 blue:0.0 alpha:1.0];
            [dotColor setFill];
            [dotPath fill];
            contentLeft += dotSize + 6.0;
            titleMaxWidth -= (dotSize + 6.0);
        }

        // Tab Title Text
        NSColor *titleColor;
        if (isSelected) {
            titleColor = dark ? [NSColor colorWithCalibratedWhite:0.95 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.10 alpha:1.0];
        } else {
            titleColor = dark ? [NSColor colorWithCalibratedWhite:0.65 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.35 alpha:1.0];
        }

        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineBreakMode = NSLineBreakByTruncatingTail;
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:12.0 weight:isSelected ? NSFontWeightMedium : NSFontWeightRegular],
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
                NSColor *circleBg = dark ? [NSColor colorWithCalibratedWhite:0.30 alpha:0.5] : [NSColor colorWithCalibratedWhite:0.75 alpha:0.6];
                [circleBg setFill];
                [circle fill];
            }

            NSDictionary *xAttrs = @{
                NSFontAttributeName: [NSFont systemFontOfSize:10.5 weight:NSFontWeightBold],
                NSForegroundColorAttributeName: isCloseHover ?
                    (dark ? [NSColor whiteColor] : [NSColor blackColor]) :
                    (dark ? [NSColor colorWithCalibratedWhite:0.7 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.4 alpha:1.0])
            };
            NSAttributedString *xStr = [[NSAttributedString alloc] initWithString:@"✕" attributes:xAttrs];
            NSSize xSize = [xStr size];
            NSRect xRect = NSMakeRect(closeRect.origin.x + (closeRect.size.width - xSize.width) / 2.0,
                                      closeRect.origin.y + (closeRect.size.height - xSize.height) / 2.0,
                                      xSize.width, xSize.height);
            [xStr drawInRect:xRect];
        }
    }

    // 3. Draw [+] Plus Button (New Tab)
    NSRect plusRect = [self plusButtonRect];
    if (self.isPlusHovered) {
        NSBezierPath *plusBg = [NSBezierPath bezierPathWithRoundedRect:plusRect xRadius:4.0 yRadius:4.0];
        NSColor *hoverFill = dark ? [NSColor colorWithCalibratedWhite:0.25 alpha:0.6] : [NSColor colorWithCalibratedWhite:0.80 alpha:0.7];
        [hoverFill setFill];
        [plusBg fill];
    }

    NSDictionary *plusAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:14.0 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: self.isPlusHovered ?
            (dark ? [NSColor whiteColor] : [NSColor blackColor]) :
            (dark ? [NSColor colorWithCalibratedWhite:0.65 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.35 alpha:1.0])
    };
    NSAttributedString *plusStr = [[NSAttributedString alloc] initWithString:@"+" attributes:plusAttrs];
    NSSize plusSize = [plusStr size];
    NSRect plusDrawRect = NSMakeRect(plusRect.origin.x + (plusRect.size.width - plusSize.width) / 2.0,
                                     plusRect.origin.y + (plusRect.size.height - plusSize.height) / 2.0,
                                     plusSize.width, plusSize.height);
    [plusStr drawInRect:plusDrawRect];
}

@end
