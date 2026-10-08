#import "EmptyDocumentOverlayView.h"

@interface EmptyDocumentOverlayView ()
@property (nonatomic, strong) NSStackView *stackView;
@property (nonatomic, strong) NSImageView *iconView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *shortcutsLabel;
@property (nonatomic, strong) NSTextField *prefsLabel;
@property (nonatomic, strong) NSTextField *fontsLabel;
@end

@implementation EmptyDocumentOverlayView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor clearColor].CGColor;
        [self setupUI];
    }
    return self;
}

- (NSView *)hitTest:(NSPoint)point {
    // Pass all mouse events through to the underlying ScintillaView / editor
    return nil;
}

- (void)setupUI {
    _stackView = [[NSStackView alloc] initWithFrame:NSZeroRect];
    _stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    _stackView.alignment = NSLayoutAttributeCenterX;
    _stackView.spacing = 10.0;
    _stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_stackView];

    // Icon: Lucide Notepad-Text vector symbol
    _iconView = [NSImageView imageViewWithImage:[self createLucideNotepadIconWithSize:NSMakeSize(48, 48)]];
    _iconView.contentTintColor = [NSColor tertiaryLabelColor];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [_stackView addArrangedSubview:_iconView];
    [_stackView setCustomSpacing:12.0 afterView:_iconView];

    // 1. "Empty document"
    _titleLabel = [self makeLabelWithText:@"Empty document"
                                     size:15.0
                                   weight:NSFontWeightMedium
                                    color:[NSColor secondaryLabelColor]];
    [_stackView addArrangedSubview:_titleLabel];
    [_stackView setCustomSpacing:14.0 afterView:_titleLabel];

    // 2. "Zoom In  ⌘ +    Zoom Out  ⌘ –    ⌃ + Mouse Wheel"
    _shortcutsLabel = [self makeLabelWithText:@"Zoom In  ⌘ +    Zoom Out  ⌘ –    ⌃ + Mouse Wheel"
                                         size:13.0
                                       weight:NSFontWeightRegular
                                        color:[NSColor secondaryLabelColor]];
    [_stackView addArrangedSubview:_shortcutsLabel];
    [_stackView setCustomSpacing:10.0 afterView:_shortcutsLabel];

    // 3. "Adjust appearance and Dark mode in Preferences"
    _prefsLabel = [self makeLabelWithText:@"Adjust appearance and Dark mode in Preferences"
                                     size:13.0
                                   weight:NSFontWeightRegular
                                    color:[NSColor secondaryLabelColor]];
    [_stackView addArrangedSubview:_prefsLabel];
    [_stackView setCustomSpacing:10.0 afterView:_prefsLabel];

    // 4. "Change Fonts in Style Configurator"
    _fontsLabel = [self makeLabelWithText:@"Change Fonts in Style Configurator"
                                     size:13.0
                                   weight:NSFontWeightRegular
                                    color:[NSColor secondaryLabelColor]];
    [_stackView addArrangedSubview:_fontsLabel];

    // Pin stack view dead-center in this overlay view across any screen size & window dimension
    [NSLayoutConstraint activateConstraints:@[
        [_stackView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_stackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_stackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:20.0],
        [_stackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-20.0],
        [_stackView.topAnchor constraintGreaterThanOrEqualToAnchor:self.topAnchor constant:10.0],
        [_stackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-10.0]
    ]];
}

- (NSTextField *)makeLabelWithText:(NSString *)text size:(CGFloat)size weight:(NSFontWeight)weight color:(NSColor *)color {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.alignment = NSTextAlignmentCenter;
    label.selectable = NO;
    label.editable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [label setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
    return label;
}

- (NSImage *)createLucideNotepadIconWithSize:(NSSize)size {
    NSImage *image = [NSImage imageWithSize:size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        CGFloat w = dstRect.size.width;
        CGFloat unit = w / 24.0;
        CGFloat strokeW = 1.75 * unit;

        auto svgX = [&](CGFloat x) { return x * unit; };
        auto svgY = [&](CGFloat y) { return (24.0 - y) * unit; };

        // Outer notepad body rect: rect width=16 height=18 x=4 y=4 rx=2
        NSRect r = NSMakeRect(svgX(4.0), svgY(22.0), 16.0 * unit, 18.0 * unit);
        NSBezierPath *page = [NSBezierPath bezierPathWithRoundedRect:r xRadius:2.0 * unit yRadius:2.0 * unit];
        page.lineWidth = strokeW;
        page.lineCapStyle = NSLineCapStyleRound;
        page.lineJoinStyle = NSLineJoinStyleRound;
        [[NSColor secondaryLabelColor] setStroke];
        [page stroke];

        // Top clips: M8 2v4, M12 2v4, M16 2v4
        CGFloat clips[] = { 8.0, 12.0, 16.0 };
        for (int i = 0; i < 3; i++) {
            NSBezierPath *clip = [NSBezierPath bezierPath];
            [clip moveToPoint:NSMakePoint(svgX(clips[i]), svgY(2.0))];
            [clip lineToPoint:NSMakePoint(svgX(clips[i]), svgY(6.0))];
            clip.lineWidth = strokeW;
            clip.lineCapStyle = NSLineCapStyleRound;
            [[NSColor secondaryLabelColor] setStroke];
            [clip stroke];
        }

        // Text lines: M8 10h6, M8 14h8, M8 18h5
        struct { CGFloat x1, y, x2; } textLines[] = {
            { 8.0, 10.0, 14.0 },
            { 8.0, 14.0, 16.0 },
            { 8.0, 18.0, 13.0 }
        };
        for (int i = 0; i < 3; i++) {
            NSBezierPath *tl = [NSBezierPath bezierPath];
            [tl moveToPoint:NSMakePoint(svgX(textLines[i].x1), svgY(textLines[i].y))];
            [tl lineToPoint:NSMakePoint(svgX(textLines[i].x2), svgY(textLines[i].y))];
            tl.lineWidth = strokeW;
            tl.lineCapStyle = NSLineCapStyleRound;
            [[NSColor secondaryLabelColor] setStroke];
            [tl stroke];
        }

        return YES;
    }];
    [image setTemplate:YES];
    return image;
}

- (void)updateTheme {
    _iconView.contentTintColor = [NSColor tertiaryLabelColor];
    _titleLabel.textColor = [NSColor secondaryLabelColor];
    _shortcutsLabel.textColor = [NSColor secondaryLabelColor];
    _prefsLabel.textColor = [NSColor secondaryLabelColor];
    _fontsLabel.textColor = [NSColor secondaryLabelColor];
}

@end
