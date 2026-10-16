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
    if (self.window && (self.window.styleMask & NSWindowStyleMaskFullSizeContentView)) {
        return 76.0; // Space for macOS window traffic lights in full-size mode
    }
    return 8.0; // Standard left margin when titlebar is separate
}

- (CGFloat)tabWidth {
    if (self.tabs.count == 0) return 140.0;
    CGFloat available = self.bounds.size.width - [self leftOffset] - 50.0;
    CGFloat w = (available / self.tabs.count) - 3.0;
    return MAX(110.0, MIN(175.0, w));
}

- (NSRect)rectForTabAtIndex:(NSInteger)index {
    CGFloat tWidth = [self tabWidth];
    CGFloat x = [self leftOffset] + index * (tWidth + 3.0);
    return NSMakeRect(x, 1.0, tWidth, self.bounds.size.height - 1.0);
}

- (NSRect)closeButtonRectForTabRect:(NSRect)tabRect {
    CGFloat sz = 16.0;
    CGFloat x = NSMaxX(tabRect) - sz - 8.0;
    CGFloat y = tabRect.origin.y + (tabRect.size.height - sz) / 2.0;
    return NSMakeRect(x, y, sz, sz);
}

- (NSRect)plusButtonRect {
    CGFloat tWidth = [self tabWidth];
    CGFloat x = [self leftOffset] + self.tabs.count * (tWidth + 3.0) + 6.0;
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
        bodyColor = [NSColor colorWithCalibratedRed:0.96 green:0.28 blue:0.24 alpha:1.0];
        accentColor = [NSColor colorWithCalibratedRed:0.96 green:0.28 blue:0.24 alpha:1.0];
    } else if (isSelected) {
        // Active tab: Crisp white icon matching the screenshot
        bodyColor = [NSColor colorWithCalibratedWhite:0.96 alpha:0.95];
        accentColor = [NSColor colorWithCalibratedWhite:0.96 alpha:0.95];
    } else {
        // Inactive tabs: Subtle light gray body with electric blue/cyan shutter!
        bodyColor = isDark ?
            [NSColor colorWithCalibratedWhite:0.72 alpha:0.9] :
            [NSColor colorWithCalibratedWhite:0.35 alpha:0.9];
        accentColor = [NSColor colorWithCalibratedRed:0.26 green:0.78 blue:1.0 alpha:1.0];
    }

    // Outer floppy body path with notch at top-right
    NSBezierPath *body = [NSBezierPath bezierPath];
    CGFloat r = 1.2;
    CGFloat notch = 3.0;

    [body moveToPoint:NSMakePoint(x + r, y)];
    [body lineToPoint:NSMakePoint(x + w - r, y)];
    [body appendBezierPathWithArcWithCenter:NSMakePoint(x + w - r, y + r) radius:r startAngle:270 endAngle:0 clockwise:NO];
    [body lineToPoint:NSMakePoint(x + w, y + h - notch)];
    [body lineToPoint:NSMakePoint(x + w - notch, y + h)];
    [body lineToPoint:NSMakePoint(x + r, y + h)];
    [body appendBezierPathWithArcWithCenter:NSMakePoint(x + r, y + h - r) radius:r startAngle:90 endAngle:180 clockwise:NO];
    [body lineToPoint:NSMakePoint(x, y + r)];
    [body appendBezierPathWithArcWithCenter:NSMakePoint(x + r, y + r) radius:r startAngle:180 endAngle:270 clockwise:NO];
    [body closePath];

    body.lineWidth = 1.1;
    [bodyColor setStroke];
    [body stroke];

    // Metal shutter at top
    NSRect shutter = NSMakeRect(x + 3.0, y + h - 5.0, w - 6.0, 4.0);
    NSBezierPath *shutterPath = [NSBezierPath bezierPathWithRect:shutter];
    [accentColor setStroke];
    shutterPath.lineWidth = 0.9;
    [shutterPath stroke];

    // Slot line inside shutter
    NSBezierPath *slotPath = [NSBezierPath bezierPath];
    [slotPath moveToPoint:NSMakePoint(x + 5.2, y + h - 4.2)];
    [slotPath lineToPoint:NSMakePoint(x + 5.2, y + h - 1.8)];
    slotPath.lineWidth = 0.9;
    [accentColor setStroke];
    [slotPath stroke];

    // Label area at bottom
    NSRect label = NSMakeRect(x + 2.5, y + 2.0, w - 5.0, 4.2);
    NSBezierPath *labelPath = [NSBezierPath bezierPathWithRoundedRect:label xRadius:0.5 yRadius:0.5];
    [bodyColor setStroke];
    labelPath.lineWidth = 0.8;
    [labelPath stroke];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    BOOL dark = [self isDark];

    // 1. Tab Bar Background
    NSColor *barBg = dark ?
        [NSColor colorWithCalibratedRed:0.09 green:0.095 blue:0.105 alpha:1.0] :
        [NSColor colorWithCalibratedWhite:0.91 alpha:1.0];
    [barBg setFill];
    NSRectFill(self.bounds);

    // Bottom border separating tabs from editor
    NSColor *bottomBorderColor = dark ?
        [NSColor colorWithCalibratedRed:0.18 green:0.18 blue:0.20 alpha:1.0] :
        [NSColor colorWithCalibratedWhite:0.78 alpha:1.0];
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
            // Iconic Notepad++ Active Tab: Warm amber/orange gradient fill
            NSColor *topColor, *bottomColor;
            if (dark) {
                topColor = [NSColor colorWithCalibratedRed:0.75 green:0.43 blue:0.16 alpha:1.0];
                bottomColor = [NSColor colorWithCalibratedRed:0.52 green:0.28 blue:0.10 alpha:1.0];
            } else {
                topColor = [NSColor colorWithCalibratedRed:0.88 green:0.54 blue:0.22 alpha:1.0];
                bottomColor = [NSColor colorWithCalibratedRed:0.70 green:0.40 blue:0.14 alpha:1.0];
            }

            NSGradient *amberGrad = [[NSGradient alloc] initWithStartingColor:topColor endingColor:bottomColor];
            [amberGrad drawInBezierPath:path angle:270];

            // Top highlight border
            NSColor *amberBorder = dark ?
                [NSColor colorWithCalibratedRed:0.86 green:0.54 blue:0.22 alpha:0.8] :
                [NSColor colorWithCalibratedRed:0.95 green:0.62 blue:0.28 alpha:0.9];
            [amberBorder setStroke];
            path.lineWidth = 1.0;
            [path stroke];
        } else {
            // Inactive Tab Background
            NSColor *inactiveBg;
            if (dark) {
                inactiveBg = isHovered ?
                    [NSColor colorWithCalibratedRed:0.18 green:0.19 blue:0.22 alpha:1.0] :
                    [NSColor colorWithCalibratedRed:0.13 green:0.135 blue:0.155 alpha:1.0];
            } else {
                inactiveBg = isHovered ?
                    [NSColor colorWithCalibratedWhite:0.95 alpha:1.0] :
                    [NSColor colorWithCalibratedWhite:0.86 alpha:1.0];
            }
            [inactiveBg setFill];
            [path fill];

            // Inactive Tab Border
            NSColor *inactiveBorder = dark ?
                [NSColor colorWithCalibratedRed:0.22 green:0.23 blue:0.26 alpha:1.0] :
                [NSColor colorWithCalibratedWhite:0.76 alpha:1.0];
            [inactiveBorder setStroke];
            path.lineWidth = 1.0;
            [path stroke];
        }

        // 3. Tab Content
        CGFloat contentLeft = tabRect.origin.x + 8.0;

        // Draw Floppy Disk Icon 💾
        CGFloat diskSize = 14.0;
        CGFloat diskY = tabRect.origin.y + (tabRect.size.height - diskSize) / 2.0;
        NSRect diskRect = NSMakeRect(contentLeft, diskY, diskSize, diskSize);
        [self drawFloppyDiskInRect:diskRect isDirty:tab.isDirty isDark:dark isSelected:isSelected];
        contentLeft += diskSize + 7.0;

        // Close Button (✕) Rect
        NSRect closeRect = [self closeButtonRectForTabRect:tabRect];
        CGFloat titleMaxWidth = closeRect.origin.x - contentLeft - 4.0;

        // Tab Title Text (Crisp white on active amber tab; high-contrast on inactive tabs)
        NSColor *titleColor;
        if (isSelected) {
            titleColor = [NSColor whiteColor];
        } else {
            titleColor = dark ?
                (isHovered ? [NSColor colorWithCalibratedWhite:0.95 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.72 alpha:1.0]) :
                (isHovered ? [NSColor colorWithCalibratedWhite:0.05 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.22 alpha:1.0]);
        }

        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineBreakMode = NSLineBreakByTruncatingTail;
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:12.5 weight:isSelected ? NSFontWeightSemibold : NSFontWeightRegular],
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
                NSColor *circleBg = isSelected ?
                    [NSColor colorWithCalibratedWhite:0.0 alpha:0.25] :
                    (dark ? [NSColor colorWithCalibratedWhite:0.35 alpha:0.5] : [NSColor colorWithCalibratedWhite:0.75 alpha:0.6]);
                [circleBg setFill];
                [circle fill];
            }

            NSDictionary *xAttrs = @{
                NSFontAttributeName: [NSFont systemFontOfSize:10.5 weight:NSFontWeightBold],
                NSForegroundColorAttributeName: isSelected ?
                    [NSColor whiteColor] :
                    (dark ? [NSColor colorWithCalibratedWhite:0.75 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.35 alpha:1.0])
            };
            NSAttributedString *xStr = [[NSAttributedString alloc] initWithString:@"✕" attributes:xAttrs];
            NSSize xSize = [xStr size];
            NSRect xRect = NSMakeRect(closeRect.origin.x + (closeRect.size.width - xSize.width) / 2.0,
                                      closeRect.origin.y + (closeRect.size.height - xSize.height) / 2.0,
                                      xSize.width, xSize.height);
            [xStr drawInRect:xRect];
        }
    }

    // 4. Draw [+] Plus Button (New Tab)
    NSRect plusRect = [self plusButtonRect];
    if (self.isPlusHovered) {
        NSBezierPath *plusBg = [NSBezierPath bezierPathWithRoundedRect:plusRect xRadius:4.0 yRadius:4.0];
        NSColor *hoverFill = dark ?
            [NSColor colorWithCalibratedWhite:0.25 alpha:0.6] :
            [NSColor colorWithCalibratedWhite:0.80 alpha:0.7];
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
