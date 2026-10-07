#import "NotepadFileManager.h"
#import "NotepadWindowController.h"
#import "AppDelegate.h"
#import "ScintillaView+Notepad.h"
#import "Scintilla.h"

@implementation NotepadFileManager

+ (instancetype)sharedManager {
    static NotepadFileManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NotepadFileManager alloc] init];
    });
    return instance;
}

- (void)openDocumentInController:(nullable NotepadWindowController *)controller {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;

    NSWindow *parentWindow = controller ? controller.window : [NSApp keyWindow];
    if (parentWindow) {
        [panel beginSheetModalForWindow:parentWindow completionHandler:^(NSModalResponse result) {
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

- (void)openFileAtPath:(NSString *)path inController:(nullable NotepadWindowController *)controller {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Could not open file";
        alert.informativeText = [NSString stringWithFormat:@"The file \"%@\" could not be read.", [path lastPathComponent]];
        [alert runModal];
        return;
    }

    NSStringEncoding detectedEncoding = NSUTF8StringEncoding;
    NSString *content = nil;

    // 1. Check Byte Order Marks (BOM)
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger length = data.length;

    if (length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
        detectedEncoding = NSUTF16LittleEndianStringEncoding;
        content = [[NSString alloc] initWithData:data encoding:detectedEncoding];
    } else if (length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
        detectedEncoding = NSUTF16BigEndianStringEncoding;
        content = [[NSString alloc] initWithData:data encoding:detectedEncoding];
    } else if (length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        detectedEncoding = NSUTF8StringEncoding;
        content = [[NSString alloc] initWithData:data encoding:detectedEncoding];
    }

    // 2. Try UTF-8 without BOM
    if (!content) {
        content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (content) {
            detectedEncoding = NSUTF8StringEncoding;
        }
    }

    // 3. Fallback to Windows-1252 / ANSI
    if (!content) {
        content = [[NSString alloc] initWithData:data encoding:NSWindowsCP1252StringEncoding];
        if (content) {
            detectedEncoding = NSWindowsCP1252StringEncoding;
        } else {
            content = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
            detectedEncoding = NSISOLatin1StringEncoding;
        }
    }

    if (!content) {
        content = @"";
    }

    // Determine target controller: reuse existing if reverting/reloading or untitled & unmodified & empty
    NotepadWindowController *targetWC = controller;
    BOOL canReuse = NO;
    if (targetWC) {
        if ([targetWC.filePath isEqualToString:path]) {
            canReuse = YES;
        } else if (targetWC.filePath == nil && !targetWC.isDirty && [targetWC.editor np_text].length == 0) {
            canReuse = YES;
        }
    }

    if (!canReuse) {
        targetWC = [[NotepadWindowController alloc] initWithFilePath:nil];
        AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
        [appDelegate addWindowController:targetWC];
        [targetWC showWindow:nil];
    }

    targetWC.filePath = path;
    targetWC.encoding = detectedEncoding;
    [targetWC.editor np_setText:content];

    // Detect and preserve Line Endings
    if ([content containsString:@"\r\n"]) {
        [targetWC.editor message:SCI_SETEOLMODE wParam:SC_EOL_CRLF lParam:0];
    } else if ([content containsString:@"\n"]) {
        [targetWC.editor message:SCI_SETEOLMODE wParam:SC_EOL_LF lParam:0];
    } else if ([content containsString:@"\r"]) {
        [targetWC.editor message:SCI_SETEOLMODE wParam:SC_EOL_CR lParam:0];
    }

    [targetWC.editor message:SCI_SETSAVEPOINT];
    targetWC.isDirty = NO;
    [targetWC updateWindowTitle];
    [targetWC updateStatusBar];

    // Note in Recent Documents
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:path]];
}

- (BOOL)saveController:(NotepadWindowController *)controller {
    if (!controller.filePath) {
        return [self saveAsController:controller];
    }

    NSString *content = [controller.editor np_text];
    NSError *error = nil;

    // Convert EOL mode to disk representation if needed
    long eolMode = [controller.editor getGeneralProperty:SCI_GETEOLMODE];
    NSString *eolString = @"\n";
    if (eolMode == SC_EOL_CRLF) {
        eolString = @"\r\n";
    } else if (eolMode == SC_EOL_CR) {
        eolString = @"\r";
    }

    // Normalize line endings to chosen EOL mode
    NSString *normalizedContent = content;
    if (eolMode == SC_EOL_CRLF) {
        normalizedContent = [content stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
        normalizedContent = [normalizedContent stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
        normalizedContent = [normalizedContent stringByReplacingOccurrencesOfString:@"\n" withString:@"\r\n"];
    }

    BOOL success = [normalizedContent writeToFile:controller.filePath
                                      atomically:YES
                                        encoding:controller.encoding
                                           error:&error];

    if (success) {
        [controller.editor message:SCI_SETSAVEPOINT];
        controller.isDirty = NO;
        [controller updateWindowTitle];
        [controller updateStatusBar];
        [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:controller.filePath]];
        return YES;
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Save Failed";
        alert.informativeText = error.localizedDescription ?: @"Could not save document.";
        [alert beginSheetModalForWindow:controller.window completionHandler:nil];
        return NO;
    }
}

- (BOOL)saveAsController:(NotepadWindowController *)controller {
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.canCreateDirectories = YES;
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
    alert.messageText = [NSString stringWithFormat:@"Revert to saved version of \"%@\"?",
                         [controller.filePath lastPathComponent]];
    alert.informativeText = @"All unsaved changes made since last save will be lost.";
    [alert addButtonWithTitle:@"Revert"];
    [alert addButtonWithTitle:@"Cancel"];

    [alert beginSheetModalForWindow:controller.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self openFileAtPath:controller.filePath inController:controller];
        }
    }];
}

@end
