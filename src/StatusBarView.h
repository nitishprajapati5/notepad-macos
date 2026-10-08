#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class StatusBarView;

@protocol StatusBarViewDelegate <NSObject>
@optional
- (void)statusBarDidClickPosition:(StatusBarView *)statusBar;
- (void)statusBarDidClickZoom:(StatusBarView *)statusBar;
- (void)statusBarDidRequestZoomIn:(StatusBarView *)statusBar;
- (void)statusBarDidRequestZoomOut:(StatusBarView *)statusBar;
- (void)statusBarDidRequestZoomReset:(StatusBarView *)statusBar;
- (void)statusBar:(StatusBarView *)statusBar didSelectEolMode:(NSInteger)eolMode;
- (void)statusBar:(StatusBarView *)statusBar didSelectEncoding:(NSStringEncoding)encoding;
@end

@interface StatusBarView : NSView

@property (nonatomic, weak, nullable) id<StatusBarViewDelegate> delegate;

@property (nonatomic, copy) NSString *cursorPositionText;
@property (nonatomic, copy) NSString *zoomText;
@property (nonatomic, copy) NSString *eolText;
@property (nonatomic, copy) NSString *encodingText;

- (void)updateLine:(NSInteger)line column:(NSInteger)column;
- (void)updateLine:(NSInteger)line column:(NSInteger)column selectedChars:(NSInteger)selectedChars selectedLines:(NSInteger)selectedLines;
- (void)updateZoom:(NSInteger)zoomPercent;
- (void)setEolModeName:(NSString *)eolMode;
- (void)setEncodingName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
