#import <Cocoa/Cocoa.h>
#import "ScintillaView.h"
#import "StatusBarView.h"
#import "NotepadTabBarView.h"
#import "NotepadTabItem.h"

NS_ASSUME_NONNULL_BEGIN

@class FindReplaceController;
@class EmptyDocumentOverlayView;

@interface NotepadWindowController
    : NSWindowController <NSWindowDelegate, ScintillaNotificationProtocol, NSMenuItemValidation, StatusBarViewDelegate,
                          NotepadTabBarViewDelegate>

@property (nonatomic, strong) NSMutableArray<NotepadTabItem *> *tabs;
@property (nonatomic, assign) NSInteger currentTabIndex;
@property (nonatomic, readonly, nullable) NotepadTabItem *currentTab;

@property (nonatomic, strong) NotepadTabBarView *tabBarView;
@property (nonatomic, strong) NSView *editorContainerView;
@property (nonatomic, strong) StatusBarView *statusBar;
@property (nonatomic, strong, nullable) FindReplaceController *findReplaceController;

// Convenience dynamic accessors mapping to the active tab
@property (nonatomic, readonly, nullable) ScintillaView *editor;
@property (nonatomic, readonly, nullable) EmptyDocumentOverlayView *emptyOverlayView;
@property (nonatomic, copy, nullable) NSString *filePath;
@property (nonatomic, assign) BOOL isDirty;
@property (nonatomic, assign) NSStringEncoding encoding;

- (instancetype)initWithFilePath:(nullable NSString *)filePath;

// Multi-Tab management (Notepad++ / Windows 11 style)
- (void)addNewTabWithFilePath:(nullable NSString *)path;
- (void)closeTabAtIndex:(NSInteger)index;
- (void)selectTabAtIndex:(NSInteger)index;
- (IBAction)newTab:(nullable id)sender;
- (IBAction)closeTab:(nullable id)sender;
- (IBAction)nextTab:(nullable id)sender;
- (IBAction)previousTab:(nullable id)sender;

- (void)loadFile:(NSString *)path;
- (void)updateWindowTitle;
- (void)updateStatusBar;
- (void)updateEmptyStateVisibility;

- (BOOL)saveFile;
- (BOOL)saveFileAs;

// Actions matching Windows Notepad & Notepad++
- (IBAction)newDocument:(nullable id)sender;
- (IBAction)newWindow:(nullable id)sender;
- (IBAction)openDocument:(nullable id)sender;
- (IBAction)saveDocument:(nullable id)sender;
- (IBAction)saveDocumentAs:(nullable id)sender;
- (IBAction)revertDocument:(nullable id)sender;
- (IBAction)runPageSpec:(nullable id)sender;
- (IBAction)runPageLayout:(nullable id)sender;
- (IBAction)printDocument:(nullable id)sender;

- (IBAction)undo:(nullable id)sender;
- (IBAction)redo:(nullable id)sender;
- (IBAction)cut:(nullable id)sender;
- (IBAction)copy:(nullable id)sender;
- (IBAction)paste:(nullable id)sender;
- (IBAction)delete:(nullable id)sender;
- (IBAction)selectAll:(nullable id)sender;

- (IBAction)showFind:(nullable id)sender;
- (IBAction)showReplace:(nullable id)sender;
- (IBAction)findNext:(nullable id)sender;
- (IBAction)findPrevious:(nullable id)sender;
- (IBAction)goToLine:(nullable id)sender;
- (IBAction)insertTimeDate:(nullable id)sender;

- (IBAction)toggleWordWrap:(nullable id)sender;
- (IBAction)chooseFont:(nullable id)sender;

- (IBAction)zoomIn:(nullable id)sender;
- (IBAction)zoomOut:(nullable id)sender;
- (IBAction)restoreDefaultZoom:(nullable id)sender;
- (IBAction)toggleStatusBar:(nullable id)sender;
- (IBAction)toggleLineNumbers:(nullable id)sender;

- (IBAction)setThemeLight:(nullable id)sender;
- (IBAction)setThemeDark:(nullable id)sender;
- (IBAction)setThemeSystem:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
