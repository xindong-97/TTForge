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

@interface NovaUIManager : NSObject
+ (instancetype)sharedManager;

@property (nonatomic, copy) NSString *panelTitle;
@property (nonatomic, copy) NSString *headerIcon;
@property (nonatomic, copy, nullable) NSString *floatingEntryIcon;
@property (nonatomic, assign) BOOL panicHideGestureEnabled;
@property (nonatomic, assign) BOOL magneticEdgeSnapEnabled;

// 一级与多级二级菜单注册接口 (Root & Multi-level Submenu Registration)
- (void)registerModule:(NSString *)key
                 title:(NSString *)title
              subtitle:(nullable NSString *)subtitle
                  icon:(nullable NSString *)icon
               handler:(nullable NovaUIModuleHandler)handler;

- (void)registerSubmenu:(NSString *)submenuKey
                  title:(NSString *)title
               subtitle:(nullable NSString *)subtitle
                   icon:(nullable NSString *)icon;

- (void)registerSubmenuWithParent:(nullable NSString *)parentKey
                              key:(NSString *)submenuKey
                            title:(NSString *)title
                         subtitle:(nullable NSString *)subtitle
                             icon:(nullable NSString *)icon;

- (void)registerSwitchInMenu:(nullable NSString *)menuKey
                         key:(NSString *)key
                       title:(NSString *)title
                    subtitle:(nullable NSString *)subtitle
                        icon:(nullable NSString *)icon
                defaultValue:(BOOL)defaultValue
                     handler:(nullable NovaUIModuleHandler)handler;

- (void)registerActionInMenu:(nullable NSString *)menuKey
                         key:(NSString *)key
                       title:(NSString *)title
                    subtitle:(nullable NSString *)subtitle
                        icon:(nullable NSString *)icon
                 buttonTitle:(nullable NSString *)buttonTitle
                     handler:(nullable dispatch_block_t)handler;

- (void)registerSliderInMenu:(nullable NSString *)menuKey
                         key:(NSString *)key
                       title:(NSString *)title
                    subtitle:(nullable NSString *)subtitle
                        icon:(nullable NSString *)icon
                    minValue:(CGFloat)minValue
                    maxValue:(CGFloat)maxValue
                defaultValue:(CGFloat)defaultValue
                        unit:(nullable NSString *)unit
                     handler:(nullable NovaUISliderHandler)handler;

- (void)registerStepperInMenu:(nullable NSString *)menuKey
                          key:(NSString *)key
                        title:(NSString *)title
                     subtitle:(nullable NSString *)subtitle
                         icon:(nullable NSString *)icon
                     minValue:(CGFloat)minValue
                     maxValue:(CGFloat)maxValue
                    stepValue:(CGFloat)stepValue
                 defaultValue:(CGFloat)defaultValue
                         unit:(nullable NSString *)unit
                      handler:(nullable NovaUISliderHandler)handler;

- (void)registerSelectInMenu:(nullable NSString *)menuKey
                         key:(NSString *)key
                       title:(NSString *)title
                    subtitle:(nullable NSString *)subtitle
                        icon:(nullable NSString *)icon
                     options:(NSArray<NSString *> *)options
                defaultIndex:(NSInteger)defaultIndex
                     handler:(nullable NovaUISelectHandler)handler;

- (void)registerInputInMenu:(nullable NSString *)menuKey
                        key:(NSString *)key
                      title:(NSString *)title
                   subtitle:(nullable NSString *)subtitle
                       icon:(nullable NSString *)icon
                placeholder:(nullable NSString *)placeholder
               defaultValue:(nullable NSString *)defaultValue
                    handler:(nullable NovaUIInputHandler)handler;

- (void)registerInfoInMenu:(nullable NSString *)menuKey
                       key:(NSString *)key
                     title:(NSString *)title
                 valueText:(NSString *)valueText
                      icon:(nullable NSString *)icon;

// 二级菜单与通用工具面板导航接口 (Submenu & Universal Utility Panel Navigation)
- (void)openSubmenu:(NSString *)submenuKey;
- (void)popSubmenu;
- (void)openConsoleLogPanel;
- (void)openConfigCenterPanel;

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

- (void)showToast:(NSString *)message;
- (void)showToast:(NSString *)message icon:(nullable NSString *)icon duration:(NSTimeInterval)duration;

// 状态读取、运行日志与配置导入导出接口 (Value Getters, Live Logs & Config Management)
- (BOOL)boolValueForKey:(NSString *)key;
- (CGFloat)floatValueForKey:(NSString *)key;
- (NSInteger)selectedIndexForKey:(NSString *)key;
- (nullable NSString *)stringValueForKey:(NSString *)key;

- (void)logMessage:(NSString *)message level:(nullable NSString *)level;
- (NSArray<NSDictionary *> *)recentLogs;
- (void)clearLogs;

- (NSString *)exportConfigurationJSON;
- (BOOL)importConfigurationJSON:(NSString *)jsonString;
- (void)resetAllConfiguration;

- (void)install;
- (void)showPanel;
- (void)hidePanel;
@end
NS_ASSUME_NONNULL_END
