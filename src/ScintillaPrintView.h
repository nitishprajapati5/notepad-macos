#import <Cocoa/Cocoa.h>
#import "ScintillaView.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScintillaPrintView : NSView

@property (nonatomic, copy, nullable) NSString *documentTitle;

- (instancetype)initWithEditor:(ScintillaView *)editor printInfo:(nullable NSPrintInfo *)printInfo;

@end

NS_ASSUME_NONNULL_END
