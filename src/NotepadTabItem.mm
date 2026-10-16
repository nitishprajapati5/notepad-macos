#import "NotepadTabItem.h"
#import "PreferencesManager.h"
#import "ScintillaView+Notepad.h"

@implementation NotepadTabItem

+ (instancetype)tabWithTitle:(NSString *)title filePath:(nullable NSString *)filePath {
    NotepadTabItem *item = [[NotepadTabItem alloc] init];
    item.tabId = [[NSUUID UUID] UUIDString];
    item.filePath = [filePath copy];
    item.encoding = [PreferencesManager sharedManager].defaultEncoding;
    item.isDirty = NO;

    if (filePath) {
        item.title = [filePath lastPathComponent];
    } else {
        item.title = title.length > 0 ? title : @"Untitled";
    }

    item.editor = [[ScintillaView alloc] initWithFrame:NSZeroRect];
    item.editor.autoresizesSubviews = YES;
    item.editor.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [item.editor np_applyDefaultTheme];

    item.emptyOverlayView = [[EmptyDocumentOverlayView alloc] initWithFrame:NSZeroRect];
    item.emptyOverlayView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    return item;
}

- (void)updateTitleFromPathOrCount:(NSInteger)tabNumber {
    if (self.filePath) {
        self.title = [self.filePath lastPathComponent];
    } else if (tabNumber > 1) {
        self.title = [NSString stringWithFormat:@"Untitled %ld", (long)tabNumber];
    } else {
        self.title = @"Untitled";
    }
}

@end
