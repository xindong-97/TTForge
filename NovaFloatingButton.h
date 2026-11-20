#import <UIKit/UIKit.h>

@interface NovaFloatingButton : UIButton
@property (nonatomic, copy) dispatch_block_t tapHandler;
- (void)attachToAvailableWindow;
- (void)applyEntryStyle:(NSInteger)style;
@end
