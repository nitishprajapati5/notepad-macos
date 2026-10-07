#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class NotepadWindowController;

@interface NotepadFileManager : NSObject

+ (instancetype)sharedManager;

- (void)openDocumentInController:(nullable NotepadWindowController *)controller;
- (void)openFileAtPath:(NSString *)path inController:(nullable NotepadWindowController *)controller;
- (BOOL)saveController:(NotepadWindowController *)controller;
- (BOOL)saveAsController:(NotepadWindowController *)controller;
- (void)revertController:(NotepadWindowController *)controller;

@end

NS_ASSUME_NONNULL_END
