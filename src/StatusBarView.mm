#import "StatusBarView.h"

@interface StatusBarView ()
@property (nonatomic, strong) NSTextField *posLabel;
@property (nonatomic, strong) NSTextField *zoomLabel;
@property (nonatomic, strong) NSTextField *eolLabel;
@property (nonatomic, strong) NSTextField *encLabel;
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
    self.wantsLayer = YES;

    _posLabel = [self makeLabelWithText:_cursorPositionText alignment:NSTextAlignmentLeft monospaced:YES];
    _zoomLabel = [self makeLabelWithText:_zoomText alignment:NSTextAlignmentCenter monospaced:YES];
    _eolLabel = [self makeLabelWithText:_eolText alignment:NSTextAlignmentCenter monospaced:NO];
    _encLabel = [self makeLabelWithText:_encodingText alignment:NSTextAlignmentCenter monospaced:NO];

    _sep1 = [self makeSeparator];
    _sep2 = [self makeSeparator];
    _sep3 = [self makeSeparator];

    [self addSubview:_posLabel];
    [self addSubview:_sep1];
    [self addSubview:_zoomLabel];
    [self addSubview:_sep2];
    [self addSubview:_eolLabel];
    [self addSubview:_sep3];
    [self addSubview:_encLabel];

    [NSLayoutConstraint activateConstraints:@[
        // Status Bar fixed height
        [self.heightAnchor constraintEqualToConstant:24.0],

        // 1. Position Label (flexible left section)
        [_posLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14.0],
        [_posLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_posLabel.trailingAnchor constraintEqualToAnchor:_sep1.leadingAnchor constant:-8.0],

        // Separator 1
        [_sep1.trailingAnchor constraintEqualToAnchor:_zoomLabel.leadingAnchor constant:-8.0],
        [_sep1.topAnchor constraintEqualToAnchor:self.topAnchor constant:4.0],
        [_sep1.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4.0],
        [_sep1.widthAnchor constraintEqualToConstant:1.0],

        // 2. Zoom Label (fixed width 64pt)
        [_zoomLabel.widthAnchor constraintEqualToConstant:64.0],
        [_zoomLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_zoomLabel.trailingAnchor constraintEqualToAnchor:_sep2.leadingAnchor constant:-8.0],

        // Separator 2
        [_sep2.trailingAnchor constraintEqualToAnchor:_eolLabel.leadingAnchor constant:-8.0],
        [_sep2.topAnchor constraintEqualToAnchor:self.topAnchor constant:4.0],
        [_sep2.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4.0],
        [_sep2.widthAnchor constraintEqualToConstant:1.0],

        // 3. EOL Mode Label (fixed width 120pt)
        [_eolLabel.widthAnchor constraintEqualToConstant:120.0],
        [_eolLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_eolLabel.trailingAnchor constraintEqualToAnchor:_sep3.leadingAnchor constant:-8.0],

        // Separator 3
        [_sep3.trailingAnchor constraintEqualToAnchor:_encLabel.leadingAnchor constant:-8.0],
        [_sep3.topAnchor constraintEqualToAnchor:self.topAnchor constant:4.0],
        [_sep3.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4.0],
        [_sep3.widthAnchor constraintEqualToConstant:1.0],

        // 4. Encoding Label (fixed width 96pt)
        [_encLabel.widthAnchor constraintEqualToConstant:96.0],
        [_encLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_encLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14.0]
    ]];
}

- (NSTextField *)makeLabelWithText:(NSString *)text alignment:(NSTextAlignment)alignment monospaced:(BOOL)monospaced {
    NSTextField *label = [NSTextField labelWithString:text];
    if (monospaced) {
        if (@available(macOS 10.15, *)) {
            label.font = [NSFont monospacedDigitSystemFontOfSize:11.0 weight:NSFontWeightRegular];
        } else {
            label.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightRegular];
        }
    } else {
        label.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightRegular];
    }
    label.textColor = [NSColor secondaryLabelColor];
    label.alignment = alignment;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
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

- (void)updateLine:(NSInteger)line column:(NSInteger)column {
    _cursorPositionText = [NSString stringWithFormat:@"Ln %ld, Col %ld", (long)line, (long)column];
    _posLabel.stringValue = _cursorPositionText;
}

- (void)updateZoom:(NSInteger)zoomPercent {
    _zoomText = [NSString stringWithFormat:@"%ld%%", (long)zoomPercent];
    _zoomLabel.stringValue = _zoomText;
}

- (void)setEolModeName:(NSString *)eolMode {
    _eolText = [eolMode copy];
    _eolLabel.stringValue = _eolText;
}

- (void)setEncodingName:(NSString *)name {
    _encodingText = [name copy];
    _encLabel.stringValue = _encodingText;
}

@end
