#import "StatusBarView.h"

@interface StatusBarView ()
@property (nonatomic, strong) NSTextField *posLabel;
@property (nonatomic, strong) NSTextField *zoomLabel;
@property (nonatomic, strong) NSTextField *eolLabel;
@property (nonatomic, strong) NSTextField *encLabel;
@end

@implementation StatusBarView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _cursorPositionText = @"Ln 1, Col 1";
        _zoomText = @"100%";
        _eolText = @"Windows (CRLF)";
        _encodingText = @"UTF-8";
        _eolText = @"Unix (LF)";

        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.wantsLayer = YES;

    _posLabel = [self makeLabelWithText:_cursorPositionText alignment:NSTextAlignmentLeft];
    _zoomLabel = [self makeLabelWithText:_zoomText alignment:NSTextAlignmentCenter];
    _eolLabel = [self makeLabelWithText:_eolText alignment:NSTextAlignmentCenter];
    _encLabel = [self makeLabelWithText:_encodingText alignment:NSTextAlignmentRight];

    NSStackView *stack = [NSStackView stackViewWithViews:@[_posLabel, _zoomLabel, _eolLabel, _encLabel]];
    stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stack.distribution = NSStackViewDistributionFillProportionally;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.edgeInsets = NSEdgeInsetsMake(2, 16, 2, 16);

    [self addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.heightAnchor constraintEqualToConstant:24.0]
    ]];
}

- (NSTextField *)makeLabelWithText:(NSString *)text alignment:(NSTextAlignment)alignment {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightRegular];
    label.textColor = [NSColor secondaryLabelColor];
    label.alignment = alignment;
    return label;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    [[NSColor windowBackgroundColor] setFill];
    NSRectFill(dirtyRect);

    // Top border separator line
    [[NSColor separatorColor] setStroke];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(dirtyRect.origin.x, NSMaxY(self.bounds) - 0.5)
                              toPoint:NSMakePoint(NSMaxX(dirtyRect), NSMaxY(self.bounds) - 0.5)];
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
