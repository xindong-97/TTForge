#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@interface NovaFloatingButton : UIButton
@property (nonatomic, copy, nullable) dispatch_block_t tapHandler;
@property (nonatomic, copy, nullable) NSString *customIcon;
@property (nonatomic, assign) BOOL magneticEdgeSnap;
- (void)attachToAvailableWindow;
- (void)applyEntryStyle:(NSInteger)style;
- (void)applyCustomIcon:(nullable NSString *)icon;
@end
NS_ASSUME_NONNULL_END
