#import "EmptyDocumentOverlayView.h"

@interface EmptyDocumentOverlayView ()
@property (nonatomic, strong) NSStackView *stackView;
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

- (void)updateTheme {
    _titleLabel.textColor = [NSColor secondaryLabelColor];
    _shortcutsLabel.textColor = [NSColor secondaryLabelColor];
    _prefsLabel.textColor = [NSColor secondaryLabelColor];
    _fontsLabel.textColor = [NSColor secondaryLabelColor];
}

@end
