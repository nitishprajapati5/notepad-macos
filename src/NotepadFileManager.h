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

// macOS Document Versioning & Time Machine snapshots
- (void)recordVersionSnapshotForPath:(NSString *)path;
- (NSArray<NSDictionary<NSString *, id> *> *)savedVersionsForPath:(NSString *)path;
- (BOOL)restoreVersionAtPath:(NSString *)versionPath toOriginalPath:(NSString *)originalPath;
- (void)deleteVersionAtPath:(NSString *)versionPath;

@end

NS_ASSUME_NONNULL_END
