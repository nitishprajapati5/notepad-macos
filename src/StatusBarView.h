#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface StatusBarView : NSView

@property (nonatomic, copy) NSString *cursorPositionText;
@property (nonatomic, copy) NSString *zoomText;
@property (nonatomic, copy) NSString *eolText;
@property (nonatomic, copy) NSString *encodingText;

- (void)updateLine:(NSInteger)line column:(NSInteger)column;
- (void)updateZoom:(NSInteger)zoomPercent;
- (void)setEolModeName:(NSString *)eolMode;
- (void)setEncodingName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
