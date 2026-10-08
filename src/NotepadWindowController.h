#import <Cocoa/Cocoa.h>
#import "ScintillaView.h"

#import "StatusBarView.h"

NS_ASSUME_NONNULL_BEGIN

@class FindReplaceController;
@class EmptyDocumentOverlayView;

@interface NotepadWindowController : NSWindowController <NSWindowDelegate, ScintillaNotificationProtocol, NSMenuItemValidation, StatusBarViewDelegate>

@property (nonatomic, strong) ScintillaView *editor;
@property (nonatomic, strong) StatusBarView *statusBar;
@property (nonatomic, strong) EmptyDocumentOverlayView *emptyOverlayView;
@property (nonatomic, strong, nullable) FindReplaceController *findReplaceController;
@property (nonatomic, copy, nullable) NSString *filePath;
@property (nonatomic, assign) BOOL isDirty;
@property (nonatomic, assign) NSStringEncoding encoding;

- (instancetype)initWithFilePath:(nullable NSString *)filePath;
- (void)loadFile:(NSString *)path;
- (void)updateWindowTitle;
- (void)updateStatusBar;
- (void)updateEmptyStateVisibility;

- (BOOL)saveFile;
- (BOOL)saveFileAs;

// Actions matching Windows Notepad
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
- (void)applyThemeAndAppearance;

@end

NS_ASSUME_NONNULL_END
