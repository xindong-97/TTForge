#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^NovaUIModuleHandler)(BOOL enabled);
typedef BOOL (^NovaUIStateProvider)(void);
typedef NSString * _Nonnull (^NovaUIValueProvider)(void);
typedef NSArray<NSDictionary *> * _Nonnull (^NovaUIOptionsProvider)(void);
typedef void (^NovaUISelectionHandler)(NSInteger index, id _Nullable value);
typedef void (^NovaUIActionHandler)(UIView *panelView, dispatch_block_t reloadBlock);

@interface NovaUIManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, copy) NSString *panelTitle;
@property (nonatomic, copy) NSString *panelSubtitle;

- (void)registerModule:(NSString *)key
                 title:(NSString *)title
              subtitle:(NSString *)subtitle
                  icon:(NSString *)icon
               handler:(NovaUIModuleHandler)handler;

- (void)registerSwitchModule:(NSString *)key
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                        icon:(NSString *)icon
               stateProvider:(NovaUIStateProvider)stateProvider
                     handler:(NovaUIModuleHandler)handler;

- (void)registerPickerModule:(NSString *)key
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                        icon:(NSString *)icon
               valueProvider:(NovaUIValueProvider)valueProvider
             optionsProvider:(NovaUIOptionsProvider)optionsProvider
            selectionHandler:(NovaUISelectionHandler)selectionHandler;

- (void)registerActionModule:(NSString *)key
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                        icon:(NSString *)icon
               valueProvider:(NovaUIValueProvider)valueProvider
               actionHandler:(NovaUIActionHandler)actionHandler;

- (void)registerSubmenuModule:(NSString *)key
                        title:(NSString *)title
                     subtitle:(NSString *)subtitle
                         icon:(NSString *)icon
                valueProvider:(NovaUIValueProvider)valueProvider
                itemsProvider:(NovaUIOptionsProvider)itemsProvider;

- (void)install;
- (void)showPanel;
- (void)hidePanel;
- (void)reloadPanel;

@end

NS_ASSUME_NONNULL_END
