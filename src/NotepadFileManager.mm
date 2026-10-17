#import "NotepadFileManager.h"
#import "NotepadWindowController.h"
#import "AppDelegate.h"
#import "ScintillaView+Notepad.h"
#import "PreferencesManager.h"
#import "Scintilla.h"

@implementation NotepadFileManager

+ (instancetype)sharedManager {
    static NotepadFileManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[NotepadFileManager alloc] init]; });
    return instance;
}

- (void)openDocumentInController:(nullable NotepadWindowController *)controller {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;

    NSWindow *parentWindow = controller ? controller.window : [NSApp keyWindow];
    if (parentWindow) {
        [panel beginSheetModalForWindow:parentWindow
                      completionHandler:^(NSModalResponse result) {
                          if (result == NSModalResponseOK && panel.URL.path) {
                              [self openFileAtPath:panel.URL.path inController:controller];
                          }
                      }];
    } else {
        if ([panel runModal] == NSModalResponseOK && panel.URL.path) {
            [self openFileAtPath:panel.URL.path inController:controller];
        }
    }
}

#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>

- (void)openFileAtPath:(NSString *)path inController:(nullable NotepadWindowController *)controller {
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&readError];
    if (!data) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Could not open file";
        alert.informativeText =
            [NSString stringWithFormat:@"The file \"%@\" could not be read: %@", [path lastPathComponent],
                                       readError.localizedDescription ?: @"Unknown error"];
        [alert runModal];
        return;
    }

    NSStringEncoding detectedEncoding = NSUTF8StringEncoding;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger length = data.length;
    size_t contentOffset = 0;
    BOOL isDirectUTF8 = NO;
    NSData *convertedUTF8Data = nil;

    // 1. Check Byte Order Marks (BOM)
    if (length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        detectedEncoding = NSUTF8StringEncoding;
        contentOffset = 3;
        isDirectUTF8 = YES;
    } else if (length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
        detectedEncoding = NSUTF16LittleEndianStringEncoding;
        contentOffset = 2;
    } else if (length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
        detectedEncoding = NSUTF16BigEndianStringEncoding;
        contentOffset = 2;
    }

    // 2. If no BOM, test UTF-8 without copy (in-place zero-copy validation)
    if (contentOffset == 0) {
        NSString *utf8Test = [[NSString alloc] initWithBytesNoCopy:(void *)bytes
                                                            length:length
                                                          encoding:NSUTF8StringEncoding
                                                      freeWhenDone:NO];
        if (utf8Test) {
            detectedEncoding = NSUTF8StringEncoding;
            isDirectUTF8 = YES;
        }
    }

    // 3. Fallback to preferred or legacy encodings if not valid UTF-8
    if (!isDirectUTF8) {
        NSString *convertedString = nil;
        NSStringEncoding preferredEncoding = [PreferencesManager sharedManager].defaultEncoding;
        if (preferredEncoding != NSUTF8StringEncoding) {
            convertedString = [[NSString alloc] initWithBytes:(bytes + contentOffset)
                                                       length:(length - contentOffset)
                                                     encoding:preferredEncoding];
            if (convertedString) {
                detectedEncoding = preferredEncoding;
            }
        }
        if (!convertedString) {
            convertedString = [[NSString alloc] initWithBytes:(bytes + contentOffset)
                                                       length:(length - contentOffset)
                                                     encoding:NSWindowsCP1252StringEncoding];
            if (convertedString) {
                detectedEncoding = NSWindowsCP1252StringEncoding;
            } else {
                convertedString = [[NSString alloc] initWithBytes:(bytes + contentOffset)
                                                           length:(length - contentOffset)
                                                         encoding:NSISOLatin1StringEncoding];
                detectedEncoding = NSISOLatin1StringEncoding;
            }
        }
        if (convertedString) {
            convertedUTF8Data = [convertedString dataUsingEncoding:NSUTF8StringEncoding];
        }
    }

    // Determine target controller: reuse existing window or find active one
    NotepadWindowController *targetWC = controller;
    if (!targetWC) {
        NSWindowController *activeWC = [[NSApp keyWindow] windowController];
        if ([activeWC isKindOfClass:[NotepadWindowController class]]) {
            targetWC = (NotepadWindowController *)activeWC;
        } else {
            AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
            targetWC = [appDelegate.windowControllers firstObject];
        }
    }

    if (targetWC) {
        // If file is already open in a tab, simply switch to that tab
        for (NSInteger i = 0; i < (NSInteger)targetWC.tabs.count; i++) {
            if ([targetWC.tabs[i].filePath isEqualToString:path]) {
                [targetWC selectTabAtIndex:i];
                return;
            }
        }

        // If active tab is empty and unmodified, reuse it
        if (targetWC.filePath == nil && !targetWC.isDirty && [targetWC.editor message:SCI_GETLENGTH] == 0) {
            // Reuse active tab
        } else {
            // Otherwise open a new tab in this same window!
            [targetWC addNewTabWithFilePath:path];
        }
    } else {
        targetWC = [[NotepadWindowController alloc] initWithFilePath:path];
        AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
        [appDelegate addWindowController:targetWC];
        [targetWC showWindow:nil];
    }

    targetWC.filePath = path;
    targetWC.encoding = detectedEncoding;

    // Fast Line Ending Detection: sample first 64 KB instead of whole document
    long detectedEOL = SC_EOL_LF;
    size_t sampleLen = MIN((size_t)length, (size_t)65536);
    for (size_t i = contentOffset; i < sampleLen; i++) {
        if (bytes[i] == '\r') {
            if (i + 1 < sampleLen && bytes[i + 1] == '\n') {
                detectedEOL = SC_EOL_CRLF;
            } else {
                detectedEOL = SC_EOL_CR;
            }
            break;
        } else if (bytes[i] == '\n') {
            detectedEOL = SC_EOL_LF;
            break;
        }
    }

    // High performance direct buffer load into Scintilla
    ScintillaView *editor = targetWC.editor;
    [editor suspendDrawing:YES];
    [editor message:SCI_SETUNDOCOLLECTION wParam:0 lParam:0];
    [editor message:SCI_CLEARALL];

    if (isDirectUTF8) {
        size_t textLen = length - contentOffset;
        const char *textPtr = (const char *)(bytes + contentOffset);
        [editor message:SCI_ALLOCATE wParam:textLen lParam:0];
        [editor message:SCI_APPENDTEXT wParam:textLen lParam:(sptr_t)textPtr];
    } else if (convertedUTF8Data) {
        [editor message:SCI_ALLOCATE wParam:convertedUTF8Data.length lParam:0];
        [editor message:SCI_APPENDTEXT wParam:convertedUTF8Data.length lParam:(sptr_t)convertedUTF8Data.bytes];
    }

    [editor message:SCI_SETEOLMODE wParam:detectedEOL lParam:0];
    [editor message:SCI_SETUNDOCOLLECTION wParam:1 lParam:0];
    [editor message:SCI_EMPTYUNDOBUFFER];
    [editor message:SCI_SETSAVEPOINT];
    [editor suspendDrawing:NO];

    targetWC.isDirty = NO;
    [editor np_updateLineNumberMarginWidth];
    [targetWC updateWindowTitle];
    [targetWC updateStatusBar];
    [targetWC updateEmptyStateVisibility];

    // Note in Recent Documents
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:path]];
}

- (BOOL)saveController:(NotepadWindowController *)controller {
    if (!controller.filePath) {
        return [self saveAsController:controller];
    }

    NSString *path = controller.filePath;
    ScintillaView *editor = controller.editor;
    long totalLen = [editor message:SCI_GETLENGTH];

    // Backup on save if enabled in preferences
    PreferencesManager *prefs = [PreferencesManager sharedManager];
    if (prefs.backupOnSave && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSString *bakPath = [path stringByAppendingPathExtension:@"bak"];
        [[NSFileManager defaultManager] removeItemAtPath:bakPath error:nil];
        [[NSFileManager defaultManager] copyItemAtPath:path toPath:bakPath error:nil];
    }

    // High performance streaming write directly from Scintilla buffer in 1 MB chunks
    NSString *tempPath = [path stringByAppendingFormat:@".%@.tmp", [[NSUUID UUID] UUIDString]];
    int fd = open([tempPath UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd < 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Save Failed";
        alert.informativeText = [NSString stringWithFormat:@"Could not create temporary file: %s", strerror(errno)];
        [alert beginSheetModalForWindow:controller.window completionHandler:nil];
        return NO;
    }

    const size_t chunkSize = 1024 * 1024;  // 1 MB buffer
    char *buffer = (char *)malloc(chunkSize + 1);
    if (!buffer) {
        close(fd);
        unlink([tempPath UTF8String]);
        return NO;
    }

    long written = 0;
    BOOL writeFailed = NO;
    Sci_TextRange tr;

    while (written < totalLen) {
        long take = MIN((long)chunkSize, totalLen - written);
        tr.chrg.cpMin = written;
        tr.chrg.cpMax = written + take;
        tr.lpstrText = buffer;
        [editor message:SCI_GETTEXTRANGE wParam:0 lParam:(sptr_t)&tr];

        ssize_t res = write(fd, buffer, take);
        if (res < 0) {
            writeFailed = YES;
            break;
        }
        written += take;
    }

    free(buffer);
    close(fd);

    if (writeFailed) {
        unlink([tempPath UTF8String]);
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Save Failed";
        alert.informativeText = [NSString stringWithFormat:@"Write error: %s", strerror(errno)];
        [alert beginSheetModalForWindow:controller.window completionHandler:nil];
        return NO;
    }

    // Atomically replace original file
    NSError *replaceError = nil;
    NSURL *tempURL = [NSURL fileURLWithPath:tempPath];
    NSURL *destURL = [NSURL fileURLWithPath:path];
    BOOL success = [[NSFileManager defaultManager] replaceItemAtURL:destURL
                                                      withItemAtURL:tempURL
                                                     backupItemName:nil
                                                            options:0
                                                   resultingItemURL:nil
                                                              error:&replaceError];
    if (!success) {
        if (rename([tempPath UTF8String], [path UTF8String]) == 0) {
            success = YES;
        } else {
            unlink([tempPath UTF8String]);
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Save Failed";
            alert.informativeText = replaceError.localizedDescription ?: @"Could not save document.";
            [alert beginSheetModalForWindow:controller.window completionHandler:nil];
            return NO;
        }
    }

    [editor message:SCI_SETSAVEPOINT];
    controller.isDirty = NO;
    [controller updateWindowTitle];
    [controller updateStatusBar];
    [[NSDocumentController sharedDocumentController]
        noteNewRecentDocumentURL:[NSURL fileURLWithPath:controller.filePath]];
    return YES;
}

- (BOOL)saveAsController:(NotepadWindowController *)controller {
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.canCreateDirectories = YES;
    panel.allowedFileTypes = @[@"txt", @"text", @"md", @"log"];
    panel.allowsOtherFileTypes = YES;
    if (controller.filePath) {
        panel.directoryURL = [NSURL fileURLWithPath:[controller.filePath stringByDeletingLastPathComponent]];
        panel.nameFieldStringValue = [controller.filePath lastPathComponent];
    } else {
        panel.nameFieldStringValue = @"Untitled.txt";
    }

    NSModalResponse result = [panel runModal];
    if (result == NSModalResponseOK && panel.URL.path) {
        controller.filePath = panel.URL.path;
        return [self saveController:controller];
    }
    return NO;
}

- (void)revertController:(NotepadWindowController *)controller {
    if (!controller.filePath || !controller.isDirty) {
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText =
        [NSString stringWithFormat:@"Revert to saved version of \"%@\"?", [controller.filePath lastPathComponent]];
    alert.informativeText = @"All unsaved changes made since last save will be lost.";
    [alert addButtonWithTitle:@"Revert"];
    [alert addButtonWithTitle:@"Cancel"];

    [alert beginSheetModalForWindow:controller.window
                  completionHandler:^(NSModalResponse returnCode) {
                      if (returnCode == NSAlertFirstButtonReturn) {
                          [self openFileAtPath:controller.filePath inController:controller];
                      }
                  }];
}

@end
