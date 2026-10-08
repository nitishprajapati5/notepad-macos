#import <Cocoa/Cocoa.h>

static void drawNotepadIcon(CGContextRef ctx, CGFloat canvasSize) {
    // 1. Draw Apple HIG rounded squircle background
    // Standard icon grid: 824x824 inside 1024x1024, centered, radius 185
    CGFloat scale = canvasSize / 1024.0;
    CGFloat bgMargin = 100.0 * scale;
    CGFloat bgSize = canvasSize - (bgMargin * 2.0);
    CGFloat cornerRadius = 185.0 * scale;
    CGRect bgRect = CGRectMake(bgMargin, bgMargin, bgSize, bgSize);

    CGContextSaveGState(ctx);

    // Drop shadow under squircle
    CGColorRef shadowColor = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.28);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, -10.0 * scale), 24.0 * scale, shadowColor);
    CGColorRelease(shadowColor);

    // Rounded rectangle path for squircle
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:NSRectFromCGRect(bgRect)
                                                           xRadius:cornerRadius
                                                           yRadius:cornerRadius];

    // Background Gradient: Modern Apple Vibrant Cobalt/Sky Blue
    NSColor *topColor = [NSColor colorWithCalibratedRed:0.18 green:0.62 blue:0.98 alpha:1.0];   // #2E9EFA
    NSColor *bottomColor = [NSColor colorWithCalibratedRed:0.02 green:0.38 blue:0.86 alpha:1.0]; // #0561DB
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:bottomColor endingColor:topColor];
    [gradient drawInBezierPath:bgPath angle:90.0];

    CGContextRestoreGState(ctx);

    // Subtle inner border for depth
    [NSGraphicsContext saveGraphicsState];
    [bgPath setLineWidth:2.0 * scale];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.25] setStroke];
    [bgPath stroke];
    [NSGraphicsContext restoreGraphicsState];

    // 2. Draw the Lucide notepad-text icon in the center
    // Original viewBox: 24 x 24
    // We scale it to occupy ~520 x 520 in the center of 1024x1024 canvas
    CGFloat iconTargetSize = 520.0 * scale;
    CGFloat svgUnit = iconTargetSize / 24.0;
    CGFloat strokeWidth = 2.0 * svgUnit;

    // Origin in Cocoa coordinates (0,0 is bottom-left, SVG 0,0 is top-left)
    CGFloat iconStartX = (canvasSize - iconTargetSize) / 2.0;
    // In SVG, Y increases downwards. Center vertically:
    CGFloat iconStartY = (canvasSize - iconTargetSize) / 2.0;

    auto svgX = [&](CGFloat x) -> CGFloat { return iconStartX + (x * svgUnit); };
    auto svgY = [&](CGFloat y) -> CGFloat { return iconStartY + ((24.0 - y) * svgUnit); };

    // --- Notepad Page Body (rect width=16 height=18 x=4 y=4 rx=2) ---
    CGFloat rectX = svgX(4.0);
    CGFloat rectY = svgY(22.0); // bottom in Cocoa Y
    CGFloat rectW = 16.0 * svgUnit;
    CGFloat rectH = 18.0 * svgUnit;
    CGFloat rectRx = 2.0 * svgUnit;
    NSRect pageRect = NSMakeRect(rectX, rectY, rectW, rectH);
    NSBezierPath *pagePath = [NSBezierPath bezierPathWithRoundedRect:pageRect xRadius:rectRx yRadius:rectRx];

    // Fill the notepad page with clean pure white with soft inner glow
    [NSGraphicsContext saveGraphicsState];
    CGColorRef pageShadow = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.20);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, -6.0 * scale), 16.0 * scale, pageShadow);
    CGColorRelease(pageShadow);

    [[NSColor colorWithCalibratedWhite:0.98 alpha:1.0] setFill];
    [pagePath fill];
    [NSGraphicsContext restoreGraphicsState];

    // Outer stroke of the page (in matching cobalt blue)
    [NSGraphicsContext saveGraphicsState];
    [pagePath setLineWidth:strokeWidth];
    [pagePath setLineCapStyle:NSLineCapStyleRound];
    [pagePath setLineJoinStyle:NSLineJoinStyleRound];
    [[NSColor colorWithCalibratedRed:0.04 green:0.35 blue:0.80 alpha:1.0] setStroke];
    [pagePath stroke];
    [NSGraphicsContext restoreGraphicsState];

    // --- Top Clips: M8 2v4, M12 2v4, M16 2v4 ---
    CGFloat clipXCoords[] = { 8.0, 12.0, 16.0 };
    for (int i = 0; i < 3; i++) {
        CGFloat cx = clipXCoords[i];
        NSBezierPath *clip = [NSBezierPath bezierPath];
        [clip moveToPoint:NSMakePoint(svgX(cx), svgY(2.0))];
        [clip lineToPoint:NSMakePoint(svgX(cx), svgY(6.0))];
        clip.lineWidth = strokeWidth;
        clip.lineCapStyle = NSLineCapStyleRound;
        [[NSColor colorWithCalibratedRed:0.04 green:0.35 blue:0.80 alpha:1.0] setStroke];
        [clip stroke];
    }

    // --- Text Lines: M8 10h6, M8 14h8, M8 18h5 ---
    struct { CGFloat x1, y, x2; } lines[] = {
        { 8.0, 10.0, 14.0 },
        { 8.0, 14.0, 16.0 },
        { 8.0, 18.0, 13.0 }
    };
    for (int i = 0; i < 3; i++) {
        NSBezierPath *line = [NSBezierPath bezierPath];
        [line moveToPoint:NSMakePoint(svgX(lines[i].x1), svgY(lines[i].y))];
        [line lineToPoint:NSMakePoint(svgX(lines[i].x2), svgY(lines[i].y))];
        line.lineWidth = strokeWidth * 0.95;
        line.lineCapStyle = NSLineCapStyleRound;
        [[NSColor colorWithCalibratedRed:0.18 green:0.50 blue:0.85 alpha:1.0] setStroke];
        [line stroke];
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *outDir = @"resources/AppIcon.iconset";
        [[NSFileManager defaultManager] createDirectoryAtPath:outDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        // Apple iconset sizes
        struct IconSpec {
            int ptSize;
            int scale;
            const char *name;
        } specs[] = {
            { 16, 1, "icon_16x16.png" },
            { 16, 2, "icon_16x16@2x.png" },
            { 32, 1, "icon_32x32.png" },
            { 32, 2, "icon_32x32@2x.png" },
            { 128, 1, "icon_128x128.png" },
            { 128, 2, "icon_128x128@2x.png" },
            { 256, 1, "icon_256x256.png" },
            { 256, 2, "icon_256x256@2x.png" },
            { 512, 1, "icon_512x512.png" },
            { 512, 2, "icon_512x512@2x.png" },
            { 0, 0, NULL }
        };

        for (int i = 0; specs[i].name != NULL; i++) {
            int px = specs[i].ptSize * specs[i].scale;
            NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
                initWithBitmapDataPlanes:NULL
                              pixelsWide:px
                              pixelsHigh:px
                           bitsPerSample:8
                         samplesPerPixel:4
                                hasAlpha:YES
                                isPlanar:NO
                          colorSpaceName:NSDeviceRGBColorSpace
                             bytesPerRow:px * 4
                            bitsPerPixel:32];

            [NSGraphicsContext saveGraphicsState];
            NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
            [NSGraphicsContext setCurrentContext:gc];
            CGContextRef ctx = (CGContextRef)[gc CGContext];

            // Render
            drawNotepadIcon(ctx, (CGFloat)px);

            [NSGraphicsContext restoreGraphicsState];

            NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            NSString *filePath = [outDir stringByAppendingPathComponent:@(specs[i].name)];
            [pngData writeToFile:filePath atomically:YES];
        }

        NSLog(@"Generated all iconset PNG files in %@", outDir);
    }
    return 0;
}
