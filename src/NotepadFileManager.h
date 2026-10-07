#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class NotepadWindowController;

@interface NotepadFileManager : NSObject

+ (instancetype)sharedManager;

- (void)openDocumentInController:(NotepadWindowController *)controller;
- (BOOL)saveController:(NotepadWindowController *)controller;
- (BOOL)saveAsController:(NotepadWindowController *)controller;
- (BOOL)revertController:(NotepadWindowController *)controller;

@end

NS_ASSUME_NONNULL_END
