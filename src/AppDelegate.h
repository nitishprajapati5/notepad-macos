#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) NSMutableArray *windowControllers;

- (void)createMainMenu;

@end

NS_ASSUME_NONNULL_END
