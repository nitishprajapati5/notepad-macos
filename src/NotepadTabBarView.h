#import <Cocoa/Cocoa.h>
#import "NotepadTabItem.h"

NS_ASSUME_NONNULL_BEGIN

@class NotepadTabBarView;

@protocol NotepadTabBarViewDelegate <NSObject>
- (void)tabBarView:(NotepadTabBarView *)tabBar didSelectTabAtIndex:(NSInteger)index;
- (void)tabBarView:(NotepadTabBarView *)tabBar didCloseTabAtIndex:(NSInteger)index;
- (void)tabBarViewDidClickNewTab:(NotepadTabBarView *)tabBar;
@end

@interface NotepadTabBarView : NSView

@property (nonatomic, weak) id<NotepadTabBarViewDelegate> delegate;
@property (nonatomic, strong) NSArray<NotepadTabItem *> *tabs;
@property (nonatomic, assign) NSInteger selectedIndex;

- (void)reloadTabs;
- (void)updateTheme;
- (void)ensureTabVisibleAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
