#import "SessionManager.h"
#import "NotepadWindowController.h"
#import "NotepadTabItem.h"
#import "AppDelegate.h"
#import "PreferencesManager.h"
#import "NotepadFileManager.h"
#import "ScintillaView+Notepad.h"
#import "Scintilla.h"

@interface SessionManager ()

@property (nonatomic, strong) NSTimer *autoSaveTimer;
@property (nonatomic, weak) NotepadTabItem *pendingTab;
@property (nonatomic, weak) NotepadWindowController *pendingController;

@end

@implementation SessionManager

+ (instancetype)sharedManager {
    static SessionManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[SessionManager alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isAppTerminating = NO;
        [self ensureDirectoriesExist];
    }
    return self;
}

#pragma mark - Directories

- (NSString *)baseSupportDirectoryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = [paths firstObject] ?: [@"~/Library/Application Support" stringByExpandingTildeInPath];
    NSString *appSupport = [base stringByAppendingPathComponent:@"Notepad"];
    return appSupport;
}

- (NSString *)sessionDirectoryPath {
    return [[self baseSupportDirectoryPath] stringByAppendingPathComponent:@"Session"];
}

- (NSString *)scratchpadsDirectoryPath {
    return [[self sessionDirectoryPath] stringByAppendingPathComponent:@"scratchpads"];
}

- (NSString *)versionHistoryDirectoryPath {
    return [[self baseSupportDirectoryPath] stringByAppendingPathComponent:@"VersionHistory"];
}

- (void)ensureDirectoriesExist {
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:[self sessionDirectoryPath] withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:[self scratchpadsDirectoryPath] withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:[self versionHistoryDirectoryPath]
        withIntermediateDirectories:YES
                         attributes:nil
                              error:nil];
}

- (NSString *)scratchpadPathForTabId:(NSString *)tabId {
    return
        [[self scratchpadsDirectoryPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.txt", tabId]];
}

#pragma mark - Tab Data Helpers

- (NSData *)dataForTab:(NotepadTabItem *)tab {
    if (!tab.editor) {
        return [NSData data];
    }
    long totalLen = [tab.editor message:SCI_GETLENGTH];
    if (totalLen <= 0) {
        return [NSData data];
    }

    NSMutableData *data = [NSMutableData dataWithLength:totalLen];
    Sci_TextRange tr;
    tr.chrg.cpMin = 0;
    tr.chrg.cpMax = totalLen;
    tr.lpstrText = (char *)data.mutableBytes;
    [tab.editor message:SCI_GETTEXTRANGE wParam:0 lParam:(sptr_t)&tr];
    return data;
}

- (void)saveScratchpadForTab:(NotepadTabItem *)tab {
    if (!tab || !tab.tabId) {
        return;
    }
    NSData *data = [self dataForTab:tab];
    NSString *filePath = [self scratchpadPathForTabId:tab.tabId];
    [data writeToFile:filePath atomically:YES];
}

- (nullable NSString *)readScratchpadForTabId:(NSString *)tabId {
    if (!tabId) {
        return nil;
    }
    NSString *path = [self scratchpadPathForTabId:tabId];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return nil;
    }
    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
    if (!content) {
        content = [NSString stringWithContentsOfFile:path encoding:NSISOLatin1StringEncoding error:nil];
    }
    return content;
}

- (void)discardScratchpadForTabId:(NSString *)tabId {
    if (!tabId) {
        return;
    }
    NSString *path = [self scratchpadPathForTabId:tabId];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

#pragma mark - Session State (Save & Restore)

- (BOOL)hasSavedSession {
    NSString *sessionFile = [[self sessionDirectoryPath] stringByAppendingPathComponent:@"session.plist"];
    return [[NSFileManager defaultManager] fileExistsAtPath:sessionFile];
}

- (void)clearSavedSession {
    NSString *sessionFile = [[self sessionDirectoryPath] stringByAppendingPathComponent:@"session.plist"];
    [[NSFileManager defaultManager] removeItemAtPath:sessionFile error:nil];
}

- (void)saveCurrentSession {
    AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
    NSArray<NotepadWindowController *> *controllers = [appDelegate.windowControllers copy];
    if (controllers.count == 0) {
        return;
    }

    NSMutableArray *windowList = [NSMutableArray array];
    for (NotepadWindowController *wc in controllers) {
        if (!wc.window || wc.tabs.count == 0) {
            continue;
        }

        NSMutableArray *tabsList = [NSMutableArray array];
        for (NotepadTabItem *tab in wc.tabs) {
            NSMutableDictionary *tabDict = [NSMutableDictionary dictionary];
            tabDict[@"tabId"] = tab.tabId ?: [[NSUUID UUID] UUIDString];
            tabDict[@"title"] = tab.title ?: @"new 1";
            if (tab.filePath) {
                tabDict[@"filePath"] = tab.filePath;
            }
            tabDict[@"isDirty"] = @(tab.isDirty);
            tabDict[@"encoding"] = @(tab.encoding);

            sptr_t curPos = 0;
            sptr_t firstLine = 0;
            if (tab.editor) {
                curPos = [tab.editor message:SCI_GETCURRENTPOS];
                firstLine = [tab.editor message:SCI_GETFIRSTVISIBLELINE];
            }
            tabDict[@"currentPos"] = @((long)curPos);
            tabDict[@"firstVisibleLine"] = @((long)firstLine);

            // Always write scratchpad for unsaved or modified documents
            if (!tab.filePath || tab.isDirty) {
                [self saveScratchpadForTab:tab];
                tabDict[@"hasScratchpad"] = @(YES);
            } else {
                tabDict[@"hasScratchpad"] = @(NO);
            }

            [tabsList addObject:tabDict];
        }

        NSMutableDictionary *winDict = [NSMutableDictionary dictionary];
        winDict[@"frame"] = NSStringFromRect(wc.window.frame);
        winDict[@"activeTabIndex"] = @(wc.currentTabIndex);
        winDict[@"tabs"] = tabsList;
        [windowList addObject:winDict];
    }

    if (windowList.count == 0) {
        return;
    }

    NSDictionary *session =
        @{@"version": @(1), @"timestamp": @([[NSDate date] timeIntervalSince1970]), @"windows": windowList};

    NSString *sessionFile = [[self sessionDirectoryPath] stringByAppendingPathComponent:@"session.plist"];
    [session writeToFile:sessionFile atomically:YES];
}

- (BOOL)restoreSession {
    NSString *sessionFile = [[self sessionDirectoryPath] stringByAppendingPathComponent:@"session.plist"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:sessionFile]) {
        return NO;
    }

    NSDictionary *session = [NSDictionary dictionaryWithContentsOfFile:sessionFile];
    if (!session || ![session[@"windows"] isKindOfClass:[NSArray class]]) {
        return NO;
    }

    NSArray *windowList = session[@"windows"];
    if (windowList.count == 0) {
        return NO;
    }

    AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
    BOOL anyRestored = NO;

    for (NSDictionary *winDict in windowList) {
        NSArray *tabsList = winDict[@"tabs"];
        if (![tabsList isKindOfClass:[NSArray class]] || tabsList.count == 0) {
            continue;
        }

        NSString *frameStr = winDict[@"frame"];
        NSInteger activeTabIndex = [winDict[@"activeTabIndex"] integerValue];

        NotepadWindowController *wc = nil;
        if (appDelegate.windowControllers.count > 0 && !anyRestored) {
            wc = [appDelegate.windowControllers firstObject];
            for (NotepadTabItem *item in wc.tabs) {
                [item.editor removeFromSuperview];
                [item.emptyOverlayView removeFromSuperview];
            }
            [wc.tabs removeAllObjects];
        } else {
            wc = [[NotepadWindowController alloc] initWithFilePath:nil];
            for (NotepadTabItem *item in wc.tabs) {
                [item.editor removeFromSuperview];
                [item.emptyOverlayView removeFromSuperview];
            }
            [wc.tabs removeAllObjects];
            [appDelegate addWindowController:wc];
        }

        if (frameStr.length > 0) {
            NSRect frame = NSRectFromString(frameStr);
            if (frame.size.width >= 400 && frame.size.height >= 250) {
                [wc.window setFrame:frame display:YES];
            }
        }

        for (NSDictionary *tabDict in tabsList) {
            NSString *tabId = tabDict[@"tabId"];
            NSString *title = tabDict[@"title"] ?: @"new 1";
            NSString *filePath = tabDict[@"filePath"];
            BOOL isDirty = [tabDict[@"isDirty"] boolValue];
            NSStringEncoding enc = [tabDict[@"encoding"] unsignedIntegerValue] ?: NSUTF8StringEncoding;
            sptr_t curPos = [tabDict[@"currentPos"] longValue];
            sptr_t firstLine = [tabDict[@"firstVisibleLine"] longValue];
            BOOL hasScratchpad = [tabDict[@"hasScratchpad"] boolValue];

            NotepadTabItem *item = [NotepadTabItem tabWithTitle:title filePath:filePath];
            if (tabId.length > 0) {
                item.tabId = tabId;
            }
            item.encoding = enc;

            NSString *scratchpadContent = nil;
            if (hasScratchpad) {
                scratchpadContent = [self readScratchpadForTabId:item.tabId];
            }

            if (scratchpadContent != nil) {
                [item.editor np_setText:scratchpadContent];
                item.isDirty = isDirty;
                if (!isDirty) {
                    [item.editor message:SCI_SETSAVEPOINT];
                }
            } else if (filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                NSData *fileData = [NSData dataWithContentsOfFile:filePath];
                if (fileData) {
                    NSString *str = [[NSString alloc] initWithData:fileData encoding:enc];
                    if (!str) {
                        str = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding] ?: @"";
                    }
                    [item.editor np_setText:str];
                    [item.editor message:SCI_SETSAVEPOINT];
                    item.isDirty = NO;
                }
            }

            if (curPos > 0) {
                [item.editor message:SCI_SETCURRENTPOS wParam:curPos];
                [item.editor message:SCI_SETSELECTIONSTART wParam:curPos];
                [item.editor message:SCI_SETSELECTIONEND wParam:curPos];
            }
            if (firstLine > 0) {
                [item.editor message:SCI_SETFIRSTVISIBLELINE wParam:firstLine];
            }

            [wc.tabs addObject:item];
            [wc.editorContainerView addSubview:item.editor];
            [wc.editorContainerView addSubview:item.emptyOverlayView];
        }

        wc.tabBarView.tabs = wc.tabs;
        NSInteger targetIndex = MAX(0, MIN(activeTabIndex, (NSInteger)wc.tabs.count - 1));
        [wc selectTabAtIndex:targetIndex];
        [wc showWindow:nil];
        anyRestored = YES;
    }

    return anyRestored;
}

#pragma mark - Continuous Auto-Save & Debouncing

- (void)notifyTabContentChanged:(NotepadTabItem *)tab inController:(NotepadWindowController *)controller {
    if (!tab) {
        return;
    }

    [self.autoSaveTimer invalidate];
    self.pendingTab = tab;
    self.pendingController = controller;

    // Debounce: wait 1.5 seconds of user idle time before auto-saving
    self.autoSaveTimer = [NSTimer scheduledTimerWithTimeInterval:1.5
                                                          target:self
                                                        selector:@selector(handleAutoSaveTimer:)
                                                        userInfo:nil
                                                         repeats:NO];
}

- (void)handleAutoSaveTimer:(NSTimer *)timer {
    [self flushPendingAutoSaves];
}

- (void)flushPendingAutoSaves {
    [self.autoSaveTimer invalidate];
    self.autoSaveTimer = nil;

    NotepadTabItem *tab = self.pendingTab;
    NotepadWindowController *controller = self.pendingController;
    if (!tab) {
        return;
    }

    // Always mirror unsaved content to scratchpad storage immediately
    [self saveScratchpadForTab:tab];

    // If file has a path on disk and Continuous Auto-Save is enabled, save silently!
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    if (prefs.continuousAutoSave && tab.filePath && tab.isDirty && controller) {
        [self saveSilentlyTab:tab inController:controller];
    }

    // Keep session plist in sync
    [self saveCurrentSession];
}

- (BOOL)saveSilentlyTab:(NotepadTabItem *)tab inController:(NotepadWindowController *)controller {
    if (!tab.filePath) {
        return NO;
    }

    NSData *data = [self dataForTab:tab];
    NSError *err = nil;
    BOOL ok = [data writeToFile:tab.filePath options:NSDataWritingAtomic error:&err];
    if (ok) {
        tab.isDirty = NO;
        if (tab.editor) {
            [tab.editor message:SCI_SETSAVEPOINT];
        }
        [controller.tabBarView reloadTabs];
        [controller updateWindowTitle];
        [controller updateStatusBar];

        // Record macOS Document Version snapshot
        [[NotepadFileManager sharedManager] recordVersionSnapshotForPath:tab.filePath];
    }
    return ok;
}

@end
