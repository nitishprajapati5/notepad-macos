#import "VersionHistoryWindowController.h"
#import "NotepadWindowController.h"
#import "NotepadFileManager.h"
#import "PreferencesManager.h"
#import "ScintillaView+Notepad.h"
#import "Scintilla.h"

@interface VersionHistoryWindowController ()

@property (nonatomic, strong) NSArray<NSDictionary<NSString *, id> *> *versions;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSTextView *previewTextView;
@property (nonatomic, strong) NSButton *restoreButton;
@property (nonatomic, strong) NSButton *exportButton;
@property (nonatomic, strong) NSButton *deleteButton;
@property (nonatomic, strong) NSTextField *headerLabel;
@property (nonatomic, strong) NSTextField *emptyLabel;

@end

@implementation VersionHistoryWindowController

- (instancetype)initWithFilePath:(NSString *)filePath sourceController:(NotepadWindowController *)controller {
    NSWindow *window =
        [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 840, 520)
                                    styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                               NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable)
                                      backing:NSBackingStoreBuffered
                                        defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        _filePath = [filePath copy];
        _sourceWindowController = controller;
        [self setupUI];
        [self loadVersions];
    }
    return self;
}

- (void)showVersionHistoryWindow {
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
}

- (void)setupUI {
    self.window.title =
        [NSString stringWithFormat:@"Version History — %@", [self.filePath lastPathComponent] ?: @"Document"];
    self.window.minSize = NSMakeSize(700, 420);

    NSView *contentView = self.window.contentView;
    contentView.wantsLayer = YES;

    // Header label
    self.headerLabel = [[NSTextField alloc]
        initWithFrame:NSMakeRect(20, contentView.bounds.size.height - 48, contentView.bounds.size.width - 40, 32)];
    self.headerLabel.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    self.headerLabel.editable = NO;
    self.headerLabel.bordered = NO;
    self.headerLabel.drawsBackground = NO;
    self.headerLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    self.headerLabel.stringValue = [NSString stringWithFormat:@"Saved Snapshots for: %@", self.filePath ?: @""];
    [contentView addSubview:self.headerLabel];

    CGFloat contentTop = contentView.bounds.size.height - 56;
    CGFloat contentBottom = 60;
    CGFloat contentHeight = contentTop - contentBottom;
    CGFloat leftWidth = 280;

    // Left: TableView for versions list
    NSScrollView *tableScrollView =
        [[NSScrollView alloc] initWithFrame:NSMakeRect(20, contentBottom, leftWidth, contentHeight)];
    tableScrollView.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    tableScrollView.hasVerticalScroller = YES;
    tableScrollView.borderType = NSBezelBorder;

    self.tableView = [[NSTableView alloc] initWithFrame:tableScrollView.bounds];
    self.tableView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.tableView.headerView = nil;
    self.tableView.rowHeight = 52.0;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"VersionColumn"];
    column.width = leftWidth - 20;
    [self.tableView addTableColumn:column];

    tableScrollView.documentView = self.tableView;
    [contentView addSubview:tableScrollView];

    // Right: Preview TextView
    CGFloat rightX = 20 + leftWidth + 14;
    CGFloat rightWidth = contentView.bounds.size.width - rightX - 20;
    NSScrollView *textScrollView =
        [[NSScrollView alloc] initWithFrame:NSMakeRect(rightX, contentBottom, rightWidth, contentHeight)];
    textScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    textScrollView.hasVerticalScroller = YES;
    textScrollView.hasHorizontalScroller = YES;
    textScrollView.borderType = NSBezelBorder;

    self.previewTextView = [[NSTextView alloc] initWithFrame:textScrollView.bounds];
    self.previewTextView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.previewTextView.editable = NO;
    self.previewTextView.font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];
    self.previewTextView.backgroundColor = [NSColor textBackgroundColor];
    self.previewTextView.textColor = [NSColor textColor];

    textScrollView.documentView = self.previewTextView;
    [contentView addSubview:textScrollView];

    // Empty state overlay
    self.emptyLabel = [[NSTextField alloc]
        initWithFrame:NSMakeRect(rightX + 40, contentBottom + (contentHeight / 2) - 20, rightWidth - 80, 40)];
    self.emptyLabel.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin;
    self.emptyLabel.editable = NO;
    self.emptyLabel.bordered = NO;
    self.emptyLabel.drawsBackground = NO;
    self.emptyLabel.alignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [NSColor secondaryLabelColor];
    self.emptyLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightRegular];
    self.emptyLabel.stringValue =
        @"No saved snapshots recorded yet.\nSnapshots are automatically created when saving files.";
    self.emptyLabel.hidden = YES;
    [contentView addSubview:self.emptyLabel];

    // Bottom Action Bar
    self.deleteButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, 16, 120, 32)];
    self.deleteButton.title = @"Delete Version";
    self.deleteButton.target = self;
    self.deleteButton.action = @selector(deleteSelectedVersion:);
    self.deleteButton.bezelStyle = NSBezelStyleRounded;
    self.deleteButton.enabled = NO;
    [contentView addSubview:self.deleteButton];

    self.exportButton = [[NSButton alloc] initWithFrame:NSMakeRect(contentView.bounds.size.width - 320, 16, 140, 32)];
    self.exportButton.autoresizingMask = NSViewMinXMargin;
    self.exportButton.title = @"Export Copy…";
    self.exportButton.target = self;
    self.exportButton.action = @selector(exportSelectedVersion:);
    self.exportButton.bezelStyle = NSBezelStyleRounded;
    self.exportButton.enabled = NO;
    [contentView addSubview:self.exportButton];

    self.restoreButton = [[NSButton alloc] initWithFrame:NSMakeRect(contentView.bounds.size.width - 170, 16, 150, 32)];
    self.restoreButton.autoresizingMask = NSViewMinXMargin;
    self.restoreButton.title = @"Restore This Version";
    self.restoreButton.target = self;
    self.restoreButton.action = @selector(restoreSelectedVersion:);
    self.restoreButton.bezelStyle = NSBezelStyleRounded;
    self.restoreButton.keyEquivalent = @"\r";  // Enter key
    self.restoreButton.enabled = NO;
    [contentView addSubview:self.restoreButton];
}

- (void)loadVersions {
    self.versions = [[NotepadFileManager sharedManager] savedVersionsForPath:self.filePath];
    [self.tableView reloadData];

    if (self.versions.count > 0) {
        self.emptyLabel.hidden = YES;
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        [self updatePreviewForSelectedRow];
    } else {
        self.emptyLabel.hidden = NO;
        self.previewTextView.string = @"";
        self.restoreButton.enabled = NO;
        self.exportButton.enabled = NO;
        self.deleteButton.enabled = NO;
    }
}

- (void)updatePreviewForSelectedRow {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.versions.count) {
        self.previewTextView.string = @"";
        self.restoreButton.enabled = NO;
        self.exportButton.enabled = NO;
        self.deleteButton.enabled = NO;
        return;
    }

    NSDictionary *ver = self.versions[row];
    NSString *vPath = ver[@"path"];
    if (vPath) {
        NSData *data = [NSData dataWithContentsOfFile:vPath];
        if (data) {
            NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!content) {
                content = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding] ?: @"";
            }
            self.previewTextView.string = content;
        } else {
            self.previewTextView.string = @"[Unable to read snapshot contents]";
        }
    }

    self.restoreButton.enabled = YES;
    self.exportButton.enabled = YES;
    self.deleteButton.enabled = YES;
}

#pragma mark - Actions

- (void)restoreSelectedVersion:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.versions.count)
        return;

    NSDictionary *ver = self.versions[row];
    NSString *vPath = ver[@"path"];
    if (!vPath || !self.sourceWindowController)
        return;

    NSData *data = [NSData dataWithContentsOfFile:vPath];
    if (!data)
        return;

    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!content) {
        content = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding] ?: @"";
    }

    // Snapshot current state first before restoring
    if (self.sourceWindowController.filePath) {
        [[NotepadFileManager sharedManager] recordVersionSnapshotForPath:self.sourceWindowController.filePath];
    }

    // Set restored text into editor
    [self.sourceWindowController.editor np_setText:content];
    [self.sourceWindowController.editor message:SCI_SETSAVEPOINT];
    self.sourceWindowController.isDirty = NO;
    [self.sourceWindowController updateWindowTitle];
    [self.sourceWindowController updateStatusBar];

    // Close window
    [self close];
}

- (void)exportSelectedVersion:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.versions.count)
        return;

    NSDictionary *ver = self.versions[row];
    NSString *vPath = ver[@"path"];
    if (!vPath)
        return;

    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.nameFieldStringValue = [NSString stringWithFormat:@"Restored_%@", [self.filePath lastPathComponent]];
    if ([savePanel runModal] == NSModalResponseOK && savePanel.URL) {
        [[NSFileManager defaultManager] copyItemAtPath:vPath toPath:savePanel.URL.path error:nil];
    }
}

- (void)deleteSelectedVersion:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.versions.count)
        return;

    NSDictionary *ver = self.versions[row];
    NSString *vPath = ver[@"path"];
    if (vPath) {
        [[NotepadFileManager sharedManager] deleteVersionAtPath:vPath];
    }

    [self loadVersions];
}

#pragma mark - Table View Data Source & Delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.versions.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.versions.count)
        return nil;

    NSDictionary *ver = self.versions[row];
    NSDate *date = ver[@"date"] ?: [NSDate date];
    unsigned long long size = [ver[@"size"] unsignedLongLongValue];

    static NSString *cellId = @"VersionCellId";
    NSTableCellView *cell = [tableView makeViewWithIdentifier:cellId owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, 52)];
        cell.identifier = cellId;

        NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 26, tableColumn.width - 20, 20)];
        titleLabel.tag = 1001;
        titleLabel.editable = NO;
        titleLabel.bordered = NO;
        titleLabel.drawsBackground = NO;
        titleLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        [cell addSubview:titleLabel];

        NSTextField *subLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 6, tableColumn.width - 20, 18)];
        subLabel.tag = 1002;
        subLabel.editable = NO;
        subLabel.bordered = NO;
        subLabel.drawsBackground = NO;
        subLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
        subLabel.textColor = [NSColor secondaryLabelColor];
        [cell addSubview:subLabel];
    }

    NSTextField *titleLabel = [cell viewWithTag:1001];
    NSTextField *subLabel = [cell viewWithTag:1002];

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateStyle = NSDateFormatterMediumStyle;
    df.timeStyle = NSDateFormatterMediumStyle;
    titleLabel.stringValue = [df stringFromDate:date];

    NSString *sizeStr = [NSByteCountFormatter stringFromByteCount:size countStyle:NSByteCountFormatterCountStyleFile];
    subLabel.stringValue = [NSString stringWithFormat:@"Size: %@", sizeStr];

    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self updatePreviewForSelectedRow];
}

@end
