#import "NotepadFileManager.h"
#import "NotepadWindowController.h"

@implementation NotepadFileManager

+ (instancetype)sharedManager {
    static NotepadFileManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NotepadFileManager alloc] init];
    });
    return instance;
}

- (void)openDocumentInController:(NotepadWindowController *)controller {
    [controller openDocument:nil];
}

- (BOOL)saveController:(NotepadWindowController *)controller {
    return [controller saveFile];
}

- (BOOL)saveAsController:(NotepadWindowController *)controller {
    return [controller saveFileAs];
}

- (BOOL)revertController:(NotepadWindowController *)controller {
    if (!controller.filePath) {
        return NO;
    }
    // Re-trigger load if path exists
    return YES;
}

@end
