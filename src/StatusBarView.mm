#import "StatusBarView.h"

@interface StatusBarSegmentButton : NSButton
@property (nonatomic, assign) BOOL isHovered;
@property (nonatomic, assign) BOOL monospaced;
@property (nonatomic, assign) NSTextAlignment textAlignment;
@end

@implementation StatusBarSegmentButton

- (instancetype)initWithTitle:(NSString *)title alignment:(NSTextAlignment)alignment monospaced:(BOOL)monospaced {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        self.bordered = NO;
        self.buttonType = NSButtonTypeMomentaryChange;
        self.title = title;
        self.textAlignment = alignment;
        self.monospaced = monospaced;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [self setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    }
    return self;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas) {
        [self removeTrackingArea:area];
    }
    NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect;
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:self.bounds options:options owner:self userInfo:nil];
    [self addTrackingArea:area];
}

- (void)mouseEntered:(NSEvent *)event {
    _isHovered = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event {
    _isHovered = NO;
    [self setNeedsDisplay:YES];
}

- (void)resetCursorRects {
    [self addCursorRect:self.bounds cursor:[NSCursor pointingHandCursor]];
}

- (void)drawRect:(NSRect)dirtyRect {
    if (_isHovered) {
        NSRect pillRect = NSInsetRect(self.bounds, 1.0, 2.0);
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:pillRect xRadius:4.0 yRadius:4.0];
        [[NSColor colorWithCalibratedWhite:0.5 alpha:0.15] setFill];
        [path fill];
    }

    NSFont *font = _monospaced ?
        [NSFont monospacedDigitSystemFontOfSize:11.0 weight:NSFontWeightRegular] :
        [NSFont systemFontOfSize:11.0 weight:NSFontWeightRegular];

    NSColor *textColor = _isHovered ? [NSColor controlTextColor] : [NSColor secondaryLabelColor];

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = _textAlignment;
    style.lineBreakMode = NSLineBreakByTruncatingTail;

    NSDictionary *attrs = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: textColor,
        NSParagraphStyleAttributeName: style
    };

    NSAttributedString *attrTitle = [[NSAttributedString alloc] initWithString:self.title attributes:attrs];
    NSSize textSize = [attrTitle size];
    CGFloat y = (self.bounds.size.height - textSize.height) / 2.0;

    NSRect textRect;
    if (_textAlignment == NSTextAlignmentLeft) {
        textRect = NSMakeRect(4.0, y, self.bounds.size.width - 8.0, textSize.height);
    } else {
        textRect = NSMakeRect(0.0, y, self.bounds.size.width, textSize.height);
    }

    [attrTitle drawInRect:textRect];
}

@end

@interface StatusBarView ()
@property (nonatomic, strong) StatusBarSegmentButton *posButton;
@property (nonatomic, strong) StatusBarSegmentButton *zoomButton;
@property (nonatomic, strong) StatusBarSegmentButton *eolButton;
@property (nonatomic, strong) StatusBarSegmentButton *encButton;
@property (nonatomic, strong) NSBox *sep1;
@property (nonatomic, strong) NSBox *sep2;
@property (nonatomic, strong) NSBox *sep3;
@end

@implementation StatusBarView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _cursorPositionText = @"Ln 1, Col 1";
        _zoomText = @"100%";
        _eolText = @"Unix (LF)";
        _encodingText = @"UTF-8";

        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    _posButton = [[StatusBarSegmentButton alloc] initWithTitle:_cursorPositionText alignment:NSTextAlignmentLeft monospaced:YES];
    _posButton.target = self;
    _posButton.action = @selector(posClicked:);
    _posButton.toolTip = @"Line and column number. Click to Go to Line (⌘L)";

    _zoomButton = [[StatusBarSegmentButton alloc] initWithTitle:_zoomText alignment:NSTextAlignmentCenter monospaced:YES];
    _zoomButton.target = self;
    _zoomButton.action = @selector(zoomClicked:);
    _zoomButton.toolTip = @"Current zoom level. Click to adjust zoom";

    _eolButton = [[StatusBarSegmentButton alloc] initWithTitle:_eolText alignment:NSTextAlignmentCenter monospaced:NO];
    _eolButton.target = self;
    _eolButton.action = @selector(eolClicked:);
    _eolButton.toolTip = @"Line ending format. Click to convert line endings";

    _encButton = [[StatusBarSegmentButton alloc] initWithTitle:_encodingText alignment:NSTextAlignmentCenter monospaced:NO];
    _encButton.target = self;
    _encButton.action = @selector(encClicked:);
    _encButton.toolTip = @"Character encoding. Click to change encoding";

    _sep1 = [self makeSeparator];
    _sep2 = [self makeSeparator];
    _sep3 = [self makeSeparator];

    [self addSubview:_posButton];
    [self addSubview:_sep1];
    [self addSubview:_zoomButton];
    [self addSubview:_sep2];
    [self addSubview:_eolButton];
    [self addSubview:_sep3];
    [self addSubview:_encButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.heightAnchor constraintEqualToConstant:24.0],

        // 1. Position Button (flexible left section)
        [_posButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10.0],
        [_posButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_posButton.heightAnchor constraintEqualToAnchor:self.heightAnchor constant:-2.0],
        [_posButton.trailingAnchor constraintEqualToAnchor:_sep1.leadingAnchor constant:-6.0],

        // Separator 1
        [_sep1.trailingAnchor constraintEqualToAnchor:_zoomButton.leadingAnchor constant:-6.0],
        [_sep1.topAnchor constraintEqualToAnchor:self.topAnchor constant:4.0],
        [_sep1.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4.0],
        [_sep1.widthAnchor constraintEqualToConstant:1.0],

        // 2. Zoom Button (fixed width 64pt)
        [_zoomButton.widthAnchor constraintEqualToConstant:64.0],
        [_zoomButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_zoomButton.heightAnchor constraintEqualToAnchor:self.heightAnchor constant:-2.0],
        [_zoomButton.trailingAnchor constraintEqualToAnchor:_sep2.leadingAnchor constant:-6.0],

        // Separator 2
        [_sep2.trailingAnchor constraintEqualToAnchor:_eolButton.leadingAnchor constant:-6.0],
        [_sep2.topAnchor constraintEqualToAnchor:self.topAnchor constant:4.0],
        [_sep2.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4.0],
        [_sep2.widthAnchor constraintEqualToConstant:1.0],

        // 3. EOL Button (fixed width 120pt)
        [_eolButton.widthAnchor constraintEqualToConstant:120.0],
        [_eolButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_eolButton.heightAnchor constraintEqualToAnchor:self.heightAnchor constant:-2.0],
        [_eolButton.trailingAnchor constraintEqualToAnchor:_sep3.leadingAnchor constant:-6.0],

        // Separator 3
        [_sep3.trailingAnchor constraintEqualToAnchor:_encButton.leadingAnchor constant:-6.0],
        [_sep3.topAnchor constraintEqualToAnchor:self.topAnchor constant:4.0],
        [_sep3.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4.0],
        [_sep3.widthAnchor constraintEqualToConstant:1.0],

        // 4. Encoding Button (fixed width 100pt)
        [_encButton.widthAnchor constraintEqualToConstant:100.0],
        [_encButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_encButton.heightAnchor constraintEqualToAnchor:self.heightAnchor constant:-2.0],
        [_encButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10.0]
    ]];
}

- (NSBox *)makeSeparator {
    NSBox *box = [[NSBox alloc] init];
    box.boxType = NSBoxSeparator;
    box.translatesAutoresizingMaskIntoConstraints = NO;
    return box;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    [[NSColor windowBackgroundColor] setFill];
    NSRectFill(dirtyRect);

    // Subtle 1px top border line
    [[NSColor separatorColor] setStroke];
    NSBezierPath *topBorder = [NSBezierPath bezierPath];
    CGFloat y = NSMaxY(self.bounds) - 0.5;
    [topBorder moveToPoint:NSMakePoint(dirtyRect.origin.x, y)];
    [topBorder lineToPoint:NSMakePoint(NSMaxX(dirtyRect), y)];
    [topBorder setLineWidth:1.0];
    [topBorder stroke];
}

#pragma mark - Segment Click Handlers

- (void)posClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(statusBarDidClickPosition:)]) {
        [self.delegate statusBarDidClickPosition:self];
    }
}

- (void)zoomClicked:(id)sender {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Zoom"];
    NSMenuItem *itemIn = [menu addItemWithTitle:@"Zoom In (⌘+)" action:@selector(zoomInAction:) keyEquivalent:@""];
    itemIn.target = self;
    NSMenuItem *itemOut = [menu addItemWithTitle:@"Zoom Out (⌘-)" action:@selector(zoomOutAction:) keyEquivalent:@""];
    itemOut.target = self;
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *itemReset = [menu addItemWithTitle:@"Reset to 100% (⌘0)" action:@selector(zoomResetAction:) keyEquivalent:@""];
    itemReset.target = self;

    NSPoint location = NSMakePoint(0, _zoomButton.bounds.size.height + 2.0);
    [menu popUpMenuPositioningItem:nil atLocation:location inView:_zoomButton];
}

- (void)zoomInAction:(id)sender {
    if ([self.delegate respondsToSelector:@selector(statusBarDidRequestZoomIn:)]) {
        [self.delegate statusBarDidRequestZoomIn:self];
    } else {
        [NSApp sendAction:@selector(zoomIn:) to:nil from:self];
    }
}

- (void)zoomOutAction:(id)sender {
    if ([self.delegate respondsToSelector:@selector(statusBarDidRequestZoomOut:)]) {
        [self.delegate statusBarDidRequestZoomOut:self];
    } else {
        [NSApp sendAction:@selector(zoomOut:) to:nil from:self];
    }
}

- (void)zoomResetAction:(id)sender {
    if ([self.delegate respondsToSelector:@selector(statusBarDidRequestZoomReset:)]) {
        [self.delegate statusBarDidRequestZoomReset:self];
    } else {
        [NSApp sendAction:@selector(restoreDefaultZoom:) to:nil from:self];
    }
}

- (void)eolClicked:(id)sender {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Line Endings"];
    NSArray *modes = @[
        @{@"title": @"Windows (CRLF)", @"tag": @(0)},
        @{@"title": @"Macintosh (CR)", @"tag": @(1)},
        @{@"title": @"Unix (LF)", @"tag": @(2)}
    ];
    for (NSDictionary *m in modes) {
        NSString *title = m[@"title"];
        NSInteger tag = [m[@"tag"] integerValue];
        NSMenuItem *item = [menu addItemWithTitle:title action:@selector(eolSelected:) keyEquivalent:@""];
        item.target = self;
        item.tag = tag;
        if ([title isEqualToString:_eolText]) {
            item.state = NSControlStateValueOn;
        }
    }

    NSPoint location = NSMakePoint(0, _eolButton.bounds.size.height + 2.0);
    [menu popUpMenuPositioningItem:nil atLocation:location inView:_eolButton];
}

- (void)eolSelected:(NSMenuItem *)item {
    if ([self.delegate respondsToSelector:@selector(statusBar:didSelectEolMode:)]) {
        [self.delegate statusBar:self didSelectEolMode:item.tag];
    }
}

- (void)encClicked:(id)sender {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Encoding"];
    NSArray *encodings = @[
        @{@"title": @"UTF-8", @"tag": @(NSUTF8StringEncoding)},
        @{@"title": @"UTF-16 LE", @"tag": @(NSUTF16LittleEndianStringEncoding)},
        @{@"title": @"UTF-16 BE", @"tag": @(NSUTF16BigEndianStringEncoding)},
        @{@"title": @"ANSI (Windows-1252)", @"tag": @(NSWindowsCP1252StringEncoding)}
    ];
    for (NSDictionary *e in encodings) {
        NSString *title = e[@"title"];
        NSUInteger tag = [e[@"tag"] unsignedIntegerValue];
        NSMenuItem *item = [menu addItemWithTitle:title action:@selector(encSelected:) keyEquivalent:@""];
        item.target = self;
        item.tag = tag;
        if ([_encodingText hasPrefix:title] || [title hasPrefix:_encodingText]) {
            item.state = NSControlStateValueOn;
        }
    }

    NSPoint location = NSMakePoint(0, _encButton.bounds.size.height + 2.0);
    [menu popUpMenuPositioningItem:nil atLocation:location inView:_encButton];
}

- (void)encSelected:(NSMenuItem *)item {
    if ([self.delegate respondsToSelector:@selector(statusBar:didSelectEncoding:)]) {
        [self.delegate statusBar:self didSelectEncoding:(NSStringEncoding)item.tag];
    }
}

#pragma mark - Updates

- (void)updateLine:(NSInteger)line column:(NSInteger)column {
    _cursorPositionText = [NSString stringWithFormat:@"Ln %ld, Col %ld", (long)line, (long)column];
    _posButton.title = _cursorPositionText;
}

- (void)updateLine:(NSInteger)line column:(NSInteger)column selectedChars:(NSInteger)selectedChars selectedLines:(NSInteger)selectedLines {
    if (selectedChars <= 0) {
        [self updateLine:line column:column];
        return;
    }
    if (selectedLines > 1) {
        _cursorPositionText = [NSString stringWithFormat:@"Ln %ld, Col %ld (%ld lines, %ld chars selected)",
                               (long)line, (long)column, (long)selectedLines, (long)selectedChars];
    } else {
        _cursorPositionText = [NSString stringWithFormat:@"Ln %ld, Col %ld (%ld selected)",
                               (long)line, (long)column, (long)selectedChars];
    }
    _posButton.title = _cursorPositionText;
}

- (void)updateZoom:(NSInteger)zoomPercent {
    _zoomText = [NSString stringWithFormat:@"%ld%%", (long)zoomPercent];
    _zoomButton.title = _zoomText;
}

- (void)setEolModeName:(NSString *)eolMode {
    _eolText = [eolMode copy];
    _eolButton.title = _eolText;
}

- (void)setEncodingName:(NSString *)name {
    _encodingText = [name copy];
    _encButton.title = _encodingText;
}

@end
