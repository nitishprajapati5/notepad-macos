#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class NotepadWindowController;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) NSMutableArray<NotepadWindowController *> *windowControllers;

- (void)createMainMenu;

- (void)newDocument:(nullable id)sender;
- (void)newWindow:(nullable id)sender;
- (void)openDocument:(nullable id)sender;
- (void)openFileAtPath:(NSString *)filePath;

- (void)addWindowController:(NotepadWindowController *)controller;
- (void)removeWindowController:(NotepadWindowController *)controller;

@end

NS_ASSUME_NONNULL_END
