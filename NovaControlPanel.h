#import <UIKit/UIKit.h>

@interface NovaControlPanel : UIView
@property (nonatomic, copy) dispatch_block_t closeHandler;
@property (nonatomic, copy) void (^floatingStyleChanged)(NSInteger style);
@property (nonatomic, copy) void (^floatingOpacityChanged)(CGFloat opacity);

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle modules:(NSArray<NSDictionary *> *)modules;
- (instancetype)initWithTitle:(NSString *)title modules:(NSArray<NSDictionary *> *)modules;
- (void)reloadModules:(NSArray<NSDictionary *> *)modules title:(NSString *)title subtitle:(NSString *)subtitle;
- (void)reloadModules:(NSArray<NSDictionary *> *)modules title:(NSString *)title;
- (void)present;
- (void)dismiss;
@end
