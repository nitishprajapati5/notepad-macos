#import "NotepadDocumentController.h"
#import "AppDelegate.h"

@implementation NotepadDocumentController

- (void)openDocumentWithContentsOfURL:(NSURL *)url display:(BOOL)display completionHandler:(void (^)(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error))completionHandler {
    if (url.path) {
        AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
        [appDelegate openFileAtPath:url.path];
    }
    if (completionHandler) {
        completionHandler(nil, NO, nil);
    }
}

@end
