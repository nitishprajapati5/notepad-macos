#import <Cocoa/Cocoa.h>
#import "ScintillaView.h"
#import "EmptyDocumentOverlayView.h"

NS_ASSUME_NONNULL_BEGIN

@interface NotepadTabItem : NSObject

@property (nonatomic, copy) NSString *tabId;
@property (nonatomic, copy, nullable) NSString *filePath;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) BOOL isDirty;
@property (nonatomic, assign) NSStringEncoding encoding;
@property (nonatomic, strong) ScintillaView *editor;
@property (nonatomic, strong) EmptyDocumentOverlayView *emptyOverlayView;

+ (instancetype)tabWithTitle:(NSString *)title filePath:(nullable NSString *)filePath;

- (void)updateTitleFromPathOrCount:(NSInteger)tabNumber;

@end

NS_ASSUME_NONNULL_END
