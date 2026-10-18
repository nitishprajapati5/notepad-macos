#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class NotepadWindowController;
@class NotepadTabItem;

@interface SessionManager : NSObject

@property (nonatomic, assign) BOOL isAppTerminating;

+ (instancetype)sharedManager;

- (NSString *)sessionDirectoryPath;
- (NSString *)scratchpadsDirectoryPath;
- (NSString *)versionHistoryDirectoryPath;

- (BOOL)hasSavedSession;
- (void)saveCurrentSession;
- (BOOL)restoreSession;
- (void)clearSavedSession;

- (void)notifyTabContentChanged:(NotepadTabItem *)tab inController:(NotepadWindowController *)controller;
- (void)flushPendingAutoSaves;
- (void)discardScratchpadForTabId:(NSString *)tabId;

- (void)saveScratchpadForTab:(NotepadTabItem *)tab;
- (nullable NSString *)readScratchpadForTabId:(NSString *)tabId;

- (BOOL)saveSilentlyTab:(NotepadTabItem *)tab inController:(NotepadWindowController *)controller;

@end

NS_ASSUME_NONNULL_END
