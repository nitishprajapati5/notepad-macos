#import "ScintillaPrintView.h"
#import "PreferencesManager.h"
#import "Scintilla.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

@interface ScintillaPrintView () {
    ScintillaView *_editor;
    NSPrintInfo *_printInfo;
    NSMutableArray<NSNumber *> *_pageStarts;
    CGFloat _pageWidth;
    CGFloat _pageHeight;
    NSEdgeInsets _margins;
    CGFloat _headerHeight;
    CGFloat _footerHeight;
    sptr_t _textLength;
}
@end

@implementation ScintillaPrintView

- (instancetype)initWithEditor:(ScintillaView *)editor printInfo:(nullable NSPrintInfo *)printInfo {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _editor = editor;
        _printInfo = printInfo ?: [NSPrintInfo sharedPrintInfo];
        _pageStarts = [NSMutableArray array];
        _headerHeight = 26.0;
        _footerHeight = 26.0;

        NSSize paperSize = [_printInfo paperSize];
        _pageWidth = paperSize.width;
        _pageHeight = paperSize.height;

        _margins = NSEdgeInsetsMake([_printInfo topMargin], [_printInfo leftMargin], [_printInfo bottomMargin],
                                    [_printInfo rightMargin]);

        // Ensure standard comfortable margins (minimum 36pt = 0.5 inch)
        if (_margins.left < 36.0)
            _margins.left = 36.0;
        if (_margins.right < 36.0)
            _margins.right = 36.0;
        if (_margins.top < 36.0)
            _margins.top = 36.0;
        if (_margins.bottom < 36.0)
            _margins.bottom = 36.0;

        // Guard against overly large margins on small paper
        if (_margins.left + _margins.right >= _pageWidth - 40.0) {
            _margins.left = 36.0;
            _margins.right = 36.0;
        }
        if (_margins.top + _margins.bottom + _headerHeight + _footerHeight + 40.0 >= _pageHeight) {
            _margins.top = 36.0;
            _margins.bottom = 36.0;
        }

        [self paginate];
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (void)paginate {
    [_pageStarts removeAllObjects];
    [_pageStarts addObject:@(0)];

    if (!_editor)
        return;

    _textLength = [_editor message:SCI_GETLENGTH];
    if (_textLength <= 0) {
        [self setFrame:NSMakeRect(0, 0, _pageWidth, _pageHeight)];
        return;
    }

    // Configure Scintilla print options:
    // If dark mode is active, BlackOnWhite ensures maximum contrast and pure white background without toner waste.
    BOOL isDark = [[PreferencesManager sharedManager] isDarkModeActive];
    int printColourMode = isDark ? SC_PRINT_BLACKONWHITE : SC_PRINT_COLOURONWHITE;
    [_editor message:SCI_SETPRINTCOLOURMODE wParam:printColourMode];
    [_editor message:SCI_SETPRINTWRAPMODE wParam:SC_WRAP_WORD];

    // Create a dummy bitmap context for measurement
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef measureCtx =
        CGBitmapContextCreate(NULL, 16, 16, 8, 64, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);

    if (!measureCtx) {
        [self setFrame:NSMakeRect(0, 0, _pageWidth, _pageHeight)];
        return;
    }

    sptr_t startPos = 0;
    NSInteger pageIndex = 0;

    while (startPos < _textLength) {
        CGFloat pageTopY = pageIndex * _pageHeight;

        Sci_RangeToFormat fr;
        fr.hdc = (Sci_SurfaceID)measureCtx;
        fr.hdcTarget = (Sci_SurfaceID)measureCtx;

        fr.rcPage.left = 0;
        fr.rcPage.top = (int)pageTopY;
        fr.rcPage.right = (int)_pageWidth;
        fr.rcPage.bottom = (int)(pageTopY + _pageHeight);

        fr.rc.left = (int)_margins.left;
        fr.rc.top = (int)(pageTopY + _margins.top + _headerHeight + 8.0);
        fr.rc.right = (int)(_pageWidth - _margins.right);
        fr.rc.bottom = (int)(pageTopY + _pageHeight - _margins.bottom - _footerHeight - 8.0);

        fr.chrg.cpMin = (Sci_PositionCR)startPos;
        fr.chrg.cpMax = (Sci_PositionCR)_textLength;

        // draw = 0 (measure only)
        sptr_t nextPos = [_editor message:SCI_FORMATRANGE wParam:0 lParam:(sptr_t)&fr];

        if (nextPos <= startPos || nextPos >= _textLength) {
            break;
        }

        [_pageStarts addObject:@(nextPos)];
        startPos = nextPos;
        pageIndex++;
    }

    // Free resources used by SCI_FORMATRANGE
    [_editor message:SCI_FORMATRANGE wParam:0 lParam:0];

    CGContextRelease(measureCtx);

    NSInteger pageCount = MAX(1, (NSInteger)_pageStarts.count);
    [self setFrame:NSMakeRect(0, 0, _pageWidth, pageCount * _pageHeight)];
}

#pragma mark - Pagination API for NSPrintOperation

- (BOOL)knowsPageRange:(NSRangePointer)range {
    [self paginate];
    NSInteger pageCount = MAX(1, (NSInteger)_pageStarts.count);
    range->location = 1;
    range->length = pageCount;
    return YES;
}

- (NSRect)rectForPage:(NSInteger)page {
    if (page < 1)
        page = 1;
    return NSMakeRect(0, (page - 1) * _pageHeight, _pageWidth, _pageHeight);
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    NSInteger page = (NSInteger)floor(dirtyRect.origin.y / _pageHeight) + 1;
    if (page < 1)
        page = 1;
    if (page > (NSInteger)_pageStarts.count)
        page = (NSInteger)_pageStarts.count;

    CGFloat pageTopY = (page - 1) * _pageHeight;

    // 1. Draw Page Header
    NSRect headerRect =
        NSMakeRect(_margins.left, pageTopY + _margins.top, _pageWidth - _margins.left - _margins.right, _headerHeight);
    [self drawHeaderForPage:page inRect:headerRect];

    // 2. Render Text via Scintilla SCI_FORMATRANGE
    if (_textLength > 0 && _pageStarts.count > 0 && page <= (NSInteger)_pageStarts.count) {
        CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] CGContext];
        if (ctx) {
            Sci_RangeToFormat fr;
            fr.hdc = (Sci_SurfaceID)ctx;
            fr.hdcTarget = (Sci_SurfaceID)ctx;

            fr.rcPage.left = 0;
            fr.rcPage.top = (int)pageTopY;
            fr.rcPage.right = (int)_pageWidth;
            fr.rcPage.bottom = (int)(pageTopY + _pageHeight);

            fr.rc.left = (int)_margins.left;
            fr.rc.top = (int)(pageTopY + _margins.top + _headerHeight + 8.0);
            fr.rc.right = (int)(_pageWidth - _margins.right);
            fr.rc.bottom = (int)(pageTopY + _pageHeight - _margins.bottom - _footerHeight - 8.0);

            fr.chrg.cpMin = (Sci_PositionCR)[_pageStarts[page - 1] integerValue];
            fr.chrg.cpMax = (page < (NSInteger)_pageStarts.count) ? (Sci_PositionCR)[_pageStarts[page] integerValue]
                                                                  : (Sci_PositionCR)_textLength;

            // Render text to CGContext
            [_editor message:SCI_FORMATRANGE wParam:1 lParam:(sptr_t)&fr];

            // Clean up Scintilla formatting cache
            [_editor message:SCI_FORMATRANGE wParam:0 lParam:0];
        }
    }

    // 3. Draw Page Footer
    NSRect footerRect = NSMakeRect(_margins.left, pageTopY + _pageHeight - _margins.bottom - _footerHeight,
                                   _pageWidth - _margins.left - _margins.right, _footerHeight);
    [self drawFooterForPage:page totalPages:_pageStarts.count inRect:footerRect];
}

- (void)drawHeaderForPage:(NSInteger)page inRect:(NSRect)rect {
    NSString *title = self.documentTitle.length > 0 ? self.documentTitle : @"Untitled";

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    NSString *dateStr = [dateFormatter stringFromDate:[NSDate date]];

    NSDictionary *leftAttr = @{
        NSFontAttributeName: [NSFont fontWithName:@"Helvetica Neue" size:9.0] ?: [NSFont systemFontOfSize:9.0],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.2 alpha:1.0]
    };
    NSDictionary *rightAttr = @{
        NSFontAttributeName: [NSFont fontWithName:@"Helvetica Neue" size:9.0] ?: [NSFont systemFontOfSize:9.0],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.4 alpha:1.0]
    };

    // Document title on left
    [title drawAtPoint:NSMakePoint(rect.origin.x, rect.origin.y + 2.0) withAttributes:leftAttr];

    // Date/time on right
    NSSize dateSize = [dateStr sizeWithAttributes:rightAttr];
    [dateStr drawAtPoint:NSMakePoint(NSMaxX(rect) - dateSize.width, rect.origin.y + 2.0) withAttributes:rightAttr];

    // Separator line
    [[NSColor colorWithCalibratedWhite:0.75 alpha:1.0] setStroke];
    NSBezierPath *line = [NSBezierPath bezierPath];
    [line setLineWidth:0.5];
    [line moveToPoint:NSMakePoint(rect.origin.x, NSMaxY(rect) - 2.0)];
    [line lineToPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect) - 2.0)];
    [line stroke];
}

- (void)drawFooterForPage:(NSInteger)page totalPages:(NSInteger)totalPages inRect:(NSRect)rect {
    // Top separator line
    [[NSColor colorWithCalibratedWhite:0.75 alpha:1.0] setStroke];
    NSBezierPath *line = [NSBezierPath bezierPath];
    [line setLineWidth:0.5];
    [line moveToPoint:NSMakePoint(rect.origin.x, rect.origin.y + 2.0)];
    [line lineToPoint:NSMakePoint(NSMaxX(rect), rect.origin.y + 2.0)];
    [line stroke];

    NSString *leftStr = @"Notepad for macOS";
    NSString *pageStr = [NSString stringWithFormat:@"Page %ld of %ld", (long)page, (long)totalPages];

    NSDictionary *leftAttr = @{
        NSFontAttributeName: [NSFont fontWithName:@"Helvetica Neue" size:9.0] ?: [NSFont systemFontOfSize:9.0],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.5 alpha:1.0]
    };
    NSDictionary *rightAttr = @{
        NSFontAttributeName: [NSFont fontWithName:@"Helvetica Neue" size:9.0] ?: [NSFont systemFontOfSize:9.0],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.2 alpha:1.0]
    };

    [leftStr drawAtPoint:NSMakePoint(rect.origin.x, rect.origin.y + 8.0) withAttributes:leftAttr];

    NSSize pageSize = [pageStr sizeWithAttributes:rightAttr];
    [pageStr drawAtPoint:NSMakePoint(NSMaxX(rect) - pageSize.width, rect.origin.y + 8.0) withAttributes:rightAttr];
}

@end
