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
        item.title = title.length > 0 ? title : @"new 1";
    }

    item.editor = [[ScintillaView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    item.editor.autoresizesSubviews = YES;
    item.editor.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [item.editor np_applyDefaultTheme];

    item.emptyOverlayView = [[EmptyDocumentOverlayView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    item.emptyOverlayView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    if ([PreferencesManager sharedManager].useRandomTabColors) {
        item.tabColor = [PreferencesManager randomVibrantColor];
    }

    return item;
}

- (void)updateTitleFromPathOrCount:(NSInteger)tabNumber {
    if (self.filePath) {
        self.title = [self.filePath lastPathComponent];
    } else {
        self.title = [NSString stringWithFormat:@"new %ld", (long)tabNumber];
    }
}

@end
