#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class NotepadWindowController;

@interface VersionHistoryWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, weak) NotepadWindowController *sourceWindowController;

- (instancetype)initWithFilePath:(NSString *)filePath sourceController:(NotepadWindowController *)controller;
- (void)showVersionHistoryWindow;

@end

NS_ASSUME_NONNULL_END
