#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
#ifndef NOVA_UI_MODULE_HANDLER_DEFINED
#define NOVA_UI_MODULE_HANDLER_DEFINED
typedef void (^NovaUIModuleHandler)(BOOL enabled);
typedef void (^NovaUISliderHandler)(CGFloat value);
typedef void (^NovaUISelectHandler)(NSInteger selectedIndex, NSString *selectedOption);
typedef void (^NovaUIInputHandler)(NSString *text);
typedef void (^NovaUIAlertHandler)(BOOL confirmed);
typedef void (^NovaUIPromptHandler)(NSString * _Nullable text, BOOL confirmed);
#endif

@interface NovaControlPanel : UIView
@property (nonatomic, copy, nullable) dispatch_block_t closeHandler;
@property (nonatomic, copy, nullable) void (^floatingStyleChanged)(NSInteger style);
@property (nonatomic, copy, nullable) void (^floatingIconChanged)(NSString * _Nullable icon);
@property (nonatomic, copy, nullable) void (^headerIconChanged)(NSString *icon);
@property (nonatomic, copy, nullable) void (^floatingOpacityChanged)(CGFloat opacity);
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> * _Nonnull (^logsProvider)(void);
@property (nonatomic, copy, nullable) void (^clearLogsHandler)(void);
@property (nonatomic, copy, nullable) void (^logEventHandler)(NSString *message, NSString *level);
@property (nonatomic, copy, nullable) NSString * _Nonnull (^exportConfigHandler)(void);
@property (nonatomic, copy, nullable) BOOL (^importConfigHandler)(NSString *jsonString);
@property (nonatomic, copy, nullable) void (^resetConfigHandler)(void);

- (instancetype)initWithTitle:(NSString *)title modules:(NSArray<NSDictionary *> *)modules;
- (void)reloadModules:(NSArray<NSDictionary *> *)modules title:(NSString *)title;
- (void)applyHeaderIcon:(nullable NSString *)icon;

// 二级菜单与通用内置工具面板导航 (Submenu & Universal Utility Panel Navigation)
- (void)pushSubmenuWithKey:(NSString *)submenuKey;
- (void)popSubmenu;
- (void)popToRootMenu;
- (void)openConsoleLogInspector;
- (void)openConfigCenterInspector;

// 主题同步弹窗与轻提示接口 (Theme-Synced Modals, Prompts, Sheets & Toasts)
- (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
              confirmTitle:(nullable NSString *)confirmTitle
               cancelTitle:(nullable NSString *)cancelTitle
                   handler:(nullable NovaUIAlertHandler)handler;

- (void)showPromptWithTitle:(NSString *)title
                    message:(nullable NSString *)message
                placeholder:(nullable NSString *)placeholder
               defaultValue:(nullable NSString *)defaultValue
               confirmTitle:(nullable NSString *)confirmTitle
                    handler:(nullable NovaUIPromptHandler)handler;

- (void)showSelectionSheetWithTitle:(NSString *)title
                           subtitle:(nullable NSString *)subtitle
                            options:(NSArray<NSString *> *)options
                      selectedIndex:(NSInteger)selectedIndex
                            handler:(nullable NovaUISelectHandler)handler;

- (void)showDetailModalWithTitle:(NSString *)title
                        subtitle:(nullable NSString *)subtitle
                       badgeText:(nullable NSString *)badgeText
                          fields:(NSArray<NSDictionary *> *)fields
              primaryActionTitle:(nullable NSString *)primaryTitle
                  primaryHandler:(nullable dispatch_block_t)primaryHandler;

- (void)showToast:(NSString *)message icon:(nullable NSString *)icon duration:(NSTimeInterval)duration;

- (void)present;
- (void)dismiss;
@end
NS_ASSUME_NONNULL_END
