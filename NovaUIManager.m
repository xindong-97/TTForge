#import "NovaUIManager.h"
#import "NovaFloatingButton.h"
#import "NovaControlPanel.h"
#import <math.h>

static inline void NovaUIRunOnMainThread(dispatch_block_t block) {
    if (!block) return;
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

static inline CGFloat NovaUIClampOpacity(CGFloat value) {
    if (!isfinite(value)) return 1.0;
    return MAX(0.35, MIN(1.0, value));
}

static inline NSString *NovaUITrimmedString(NSString *input) {
    if (![input isKindOfClass:NSString.class]) return @"";
    return [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@interface NovaUIManager ()
@property (nonatomic, strong) NovaFloatingButton *floatingButton;
@property (nonatomic, strong) NovaControlPanel *panel;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *modules;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *logs;
@property (nonatomic, strong) UITapGestureRecognizer *panicGestureRecognizer;
@property (nonatomic, assign) BOOL isStealthHidden;
@property (nonatomic, assign) BOOL pendingInstallRetry;
@end

@implementation NovaUIManager
@synthesize panelTitle = _panelTitle;
@synthesize headerIcon = _headerIcon;
@synthesize floatingEntryIcon = _floatingEntryIcon;
@synthesize panicHideGestureEnabled = _panicHideGestureEnabled;
@synthesize magneticEdgeSnapEnabled = _magneticEdgeSnapEnabled;

+ (instancetype)sharedManager {
    static NovaUIManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [NovaUIManager new]; });
    return manager;
}

- (instancetype)init {
    if ((self = [super init])) {
        _panelTitle = @"NOVA 控制中心";
        NSString *savedHeader = NovaUITrimmedString([NSUserDefaults.standardUserDefaults stringForKey:@"NovaUI.headerIcon"]);
        if ([savedHeader isEqualToString:@"asterisk"]) savedHeader = @"nova.sakura";
        _headerIcon = savedHeader.length > 0 ? [savedHeader copy] : @"nova.sakura";
        NSString *savedEntryIcon = NovaUITrimmedString([NSUserDefaults.standardUserDefaults stringForKey:@"NovaUI.entryCustomIcon"]);
        _floatingEntryIcon = savedEntryIcon.length > 0 ? [savedEntryIcon copy] : nil;
        if ([NSUserDefaults.standardUserDefaults objectForKey:@"NovaUI.panicHideGesture"] != nil) {
            _panicHideGestureEnabled = [NSUserDefaults.standardUserDefaults boolForKey:@"NovaUI.panicHideGesture"];
        } else {
            _panicHideGestureEnabled = YES;
            [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"NovaUI.panicHideGesture"];
        }
        if ([NSUserDefaults.standardUserDefaults objectForKey:@"NovaUI.magneticEdgeSnap"] != nil) {
            _magneticEdgeSnapEnabled = [NSUserDefaults.standardUserDefaults boolForKey:@"NovaUI.magneticEdgeSnap"];
        } else {
            _magneticEdgeSnapEnabled = YES;
            [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"NovaUI.magneticEdgeSnap"];
        }
        _modules = [NSMutableArray array];
        _logs = [NSMutableArray array];
        [self logMessage:@"NovaDylibUI 控制中心初始化完成" level:@"INFO"];

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(reattachFloatingButton) name:UIApplicationDidBecomeActiveNotification object:nil];
        [nc addObserver:self selector:@selector(reattachFloatingButton) name:UIWindowDidBecomeKeyNotification object:nil];
        [nc addObserver:self selector:@selector(reattachFloatingButton) name:UIWindowDidBecomeVisibleNotification object:nil];
        [nc addObserver:self selector:@selector(reattachFloatingButton) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)panelTitle {
    @synchronized (self) {
        return _panelTitle ?: @"NOVA 控制中心";
    }
}

- (void)setPanelTitle:(NSString *)panelTitle {
    NSString *trimmed = NovaUITrimmedString(panelTitle);
    NSString *resolved = trimmed.length > 0 ? [trimmed copy] : @"NOVA 控制中心";
    @synchronized (self) {
        _panelTitle = resolved;
    }
    [self notifyPanelReload];
}

- (NSString *)headerIcon {
    @synchronized (self) {
        return _headerIcon ?: @"nova.sakura";
    }
}

- (void)setHeaderIcon:(NSString *)headerIcon {
    NSString *trimmed = NovaUITrimmedString(headerIcon);
    if ([trimmed isEqualToString:@"asterisk"]) trimmed = @"nova.sakura";
    NSString *resolved = trimmed.length > 0 ? [trimmed copy] : @"nova.sakura";
    @synchronized (self) {
        _headerIcon = resolved;
    }
    [NSUserDefaults.standardUserDefaults setObject:resolved forKey:@"NovaUI.headerIcon"];
    NovaUIRunOnMainThread(^{
        if (self.panel) {
            NSString *latestHeader = nil;
            @synchronized (self) {
                latestHeader = [_headerIcon copy] ?: @"nova.sakura";
            }
            [self.panel applyHeaderIcon:latestHeader];
        }
    });
}

- (NSString *)floatingEntryIcon {
    @synchronized (self) {
        return _floatingEntryIcon;
    }
}

- (void)setFloatingEntryIcon:(NSString *)floatingEntryIcon {
    NSString *trimmed = NovaUITrimmedString(floatingEntryIcon);
    NSString *resolved = trimmed.length > 0 ? [trimmed copy] : nil;
    @synchronized (self) {
        _floatingEntryIcon = resolved;
    }
    if (resolved) {
        [NSUserDefaults.standardUserDefaults setObject:resolved forKey:@"NovaUI.entryCustomIcon"];
    } else {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"NovaUI.entryCustomIcon"];
    }
    NovaUIRunOnMainThread(^{
        if (self.floatingButton) {
            NSString *latestIcon = nil;
            @synchronized (self) {
                latestIcon = [_floatingEntryIcon copy];
            }
            [self.floatingButton applyCustomIcon:latestIcon];
        }
    });
}

- (BOOL)panicHideGestureEnabled {
    @synchronized (self) {
        return _panicHideGestureEnabled;
    }
}

- (void)setPanicHideGestureEnabled:(BOOL)panicHideGestureEnabled {
    @synchronized (self) {
        _panicHideGestureEnabled = panicHideGestureEnabled;
    }
    [NSUserDefaults.standardUserDefaults setBool:panicHideGestureEnabled forKey:@"NovaUI.panicHideGesture"];
    NovaUIRunOnMainThread(^{
        self.panicGestureRecognizer.enabled = panicHideGestureEnabled;
        if (!panicHideGestureEnabled && self.isStealthHidden) {
            self.isStealthHidden = NO;
            self.floatingButton.hidden = NO;
        }
    });
}

- (BOOL)magneticEdgeSnapEnabled {
    @synchronized (self) {
        return _magneticEdgeSnapEnabled;
    }
}

- (void)setMagneticEdgeSnapEnabled:(BOOL)magneticEdgeSnapEnabled {
    @synchronized (self) {
        _magneticEdgeSnapEnabled = magneticEdgeSnapEnabled;
    }
    [NSUserDefaults.standardUserDefaults setBool:magneticEdgeSnapEnabled forKey:@"NovaUI.magneticEdgeSnap"];
    NovaUIRunOnMainThread(^{
        if (self.floatingButton) {
            self.floatingButton.magneticEdgeSnap = magneticEdgeSnapEnabled;
        }
    });
}

- (void)notifyPanelReload {
    NovaUIRunOnMainThread(^{
        if (self.panel) {
            NSArray<NSDictionary *> *snapshot = nil;
            NSString *latestTitle = nil;
            @synchronized (self) {
                snapshot = [self.modules copy];
                latestTitle = [_panelTitle copy] ?: @"NOVA 控制中心";
            }
            [self.panel reloadModules:snapshot title:latestTitle];
        }
    });
}

- (void)upsertItemDictionary:(NSDictionary *)item {
    if (![item isKindOfClass:NSDictionary.class]) return;
    NSString *safeKey = item[@"key"];
    NSString *parentKey = item[@"parentKey"] ?: @"";
    if (![safeKey isKindOfClass:NSString.class] || !safeKey.length) return;

    @synchronized (self) {
        NSUInteger index = [self.modules indexOfObjectPassingTest:^BOOL(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
            NSString *k = obj[@"key"] ?: @"";
            NSString *p = obj[@"parentKey"] ?: @"";
            return [k isEqualToString:safeKey] && [p isEqualToString:parentKey];
        }];
        if (index != NSNotFound) {
            [self.modules replaceObjectAtIndex:index withObject:item];
        } else {
            [self.modules addObject:item];
        }
    }
    [self notifyPanelReload];
}

#pragma mark - Menu & Submenu Registration APIs

- (void)registerModule:(NSString *)key
                 title:(NSString *)title
              subtitle:(NSString *)subtitle
                  icon:(NSString *)icon
               handler:(NovaUIModuleHandler)handler {
    [self registerSwitchInMenu:nil
                           key:key
                         title:title
                      subtitle:subtitle
                          icon:icon
                  defaultValue:NO
                       handler:handler];
}

- (void)registerSubmenu:(NSString *)submenuKey
                  title:(NSString *)title
               subtitle:(NSString *)subtitle
                   icon:(NSString *)icon {
    [self registerSubmenuWithParent:nil key:submenuKey title:title subtitle:subtitle icon:icon];
}

- (void)registerSubmenuWithParent:(NSString *)parentKey
                              key:(NSString *)submenuKey
                            title:(NSString *)title
                         subtitle:(NSString *)subtitle
                             icon:(NSString *)icon {
    NSString *trimmedKey = NovaUITrimmedString(submenuKey);
    NSString *trimmedTitle = NovaUITrimmedString(title);
    if (!trimmedKey.length || !trimmedTitle.length) return;

    NSString *safeParent = NovaUITrimmedString(parentKey);
    NSString *safeSubtitle = [subtitle isKindOfClass:NSString.class] ? [subtitle copy] : @"";
    NSString *trimmedIcon = NovaUITrimmedString(icon);
    NSString *safeIcon = trimmedIcon.length > 0 ? [trimmedIcon copy] : @"square.grid.2x2.fill";

    NSDictionary *item = @{
        @"key": [trimmedKey copy],
        @"parentKey": [safeParent copy],
        @"type": @"submenu",
        @"title": [trimmedTitle copy],
        @"subtitle": safeSubtitle,
        @"icon": safeIcon
    };
    [self upsertItemDictionary:item];
}

- (void)registerSwitchInMenu:(NSString *)menuKey
                         key:(NSString *)key
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                        icon:(NSString *)icon
                defaultValue:(BOOL)defaultValue
                     handler:(NovaUIModuleHandler)handler {
    NSString *trimmedKey = NovaUITrimmedString(key);
    NSString *trimmedTitle = NovaUITrimmedString(title);
    if (!trimmedKey.length || !trimmedTitle.length) return;

    NSString *safeParent = NovaUITrimmedString(menuKey);
    NSString *safeKey = [trimmedKey copy];
    NSString *safeTitle = [trimmedTitle copy];
    NSString *safeSubtitle = [subtitle isKindOfClass:NSString.class] ? [subtitle copy] : @"";
    NSString *trimmedIcon = NovaUITrimmedString(icon);
    NSString *safeIcon = trimmedIcon.length > 0 ? [trimmedIcon copy] : @"circle";

    NSString *defaultsKey = [@"NovaUI.module." stringByAppendingString:safeKey];
    if ([NSUserDefaults.standardUserDefaults objectForKey:defaultsKey] == nil && defaultValue) {
        [NSUserDefaults.standardUserDefaults setBool:defaultValue forKey:defaultsKey];
    }

    NSMutableDictionary *mutableItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        safeKey, @"key",
        [safeParent copy], @"parentKey",
        @"switch", @"type",
        safeTitle, @"title",
        safeSubtitle, @"subtitle",
        safeIcon, @"icon",
        @(defaultValue), @"defaultValue",
        nil];
    if (handler != nil && (id)handler != [NSNull null]) {
        mutableItem[@"handler"] = [handler copy];
    }
    [self upsertItemDictionary:[mutableItem copy]];
}

- (void)registerActionInMenu:(NSString *)menuKey
                         key:(NSString *)key
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                        icon:(NSString *)icon
                 buttonTitle:(NSString *)buttonTitle
                     handler:(dispatch_block_t)handler {
    NSString *trimmedKey = NovaUITrimmedString(key);
    NSString *trimmedTitle = NovaUITrimmedString(title);
    if (!trimmedKey.length || !trimmedTitle.length) return;

    NSString *safeParent = NovaUITrimmedString(menuKey);
    NSString *safeSubtitle = [subtitle isKindOfClass:NSString.class] ? [subtitle copy] : @"";
    NSString *trimmedIcon = NovaUITrimmedString(icon);
    NSString *safeIcon = trimmedIcon.length > 0 ? [trimmedIcon copy] : @"sparkles";
    NSString *trimmedBtn = NovaUITrimmedString(buttonTitle);
    NSString *safeBtn = trimmedBtn.length > 0 ? [trimmedBtn copy] : @"执行";

    NSMutableDictionary *mutableItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        [trimmedKey copy], @"key",
        [safeParent copy], @"parentKey",
        @"action", @"type",
        [trimmedTitle copy], @"title",
        safeSubtitle, @"subtitle",
        safeIcon, @"icon",
        safeBtn, @"buttonTitle",
        nil];
    if (handler != nil && (id)handler != [NSNull null]) {
        mutableItem[@"handler"] = [handler copy];
    }
    [self upsertItemDictionary:[mutableItem copy]];
}

- (void)registerSliderInMenu:(NSString *)menuKey
                         key:(NSString *)key
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                        icon:(NSString *)icon
                    minValue:(CGFloat)minValue
                    maxValue:(CGFloat)maxValue
                defaultValue:(CGFloat)defaultValue
                        unit:(NSString *)unit
                     handler:(NovaUISliderHandler)handler {
    NSString *trimmedKey = NovaUITrimmedString(key);
    NSString *trimmedTitle = NovaUITrimmedString(title);
    if (!trimmedKey.length || !trimmedTitle.length) return;

    CGFloat safeMin = isfinite(minValue) ? minValue : 0.0;
    CGFloat safeMax = (isfinite(maxValue) && maxValue > safeMin) ? maxValue : (safeMin + 100.0);
    CGFloat safeDef = isfinite(defaultValue) ? MAX(safeMin, MIN(safeMax, defaultValue)) : safeMin;
    NSString *defaultsKey = [@"NovaUI.slider." stringByAppendingString:trimmedKey];
    if ([NSUserDefaults.standardUserDefaults objectForKey:defaultsKey] == nil) {
        [NSUserDefaults.standardUserDefaults setFloat:safeDef forKey:defaultsKey];
    }

    NSString *safeParent = NovaUITrimmedString(menuKey);
    NSString *safeSubtitle = [subtitle isKindOfClass:NSString.class] ? [subtitle copy] : @"";
    NSString *trimmedIcon = NovaUITrimmedString(icon);
    NSString *safeIcon = trimmedIcon.length > 0 ? [trimmedIcon copy] : @"slider.horizontal.3";
    NSString *safeUnit = [unit isKindOfClass:NSString.class] ? [unit copy] : @"";

    NSMutableDictionary *mutableItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        [trimmedKey copy], @"key",
        [safeParent copy], @"parentKey",
        @"slider", @"type",
        [trimmedTitle copy], @"title",
        safeSubtitle, @"subtitle",
        safeIcon, @"icon",
        @(safeMin), @"minValue",
        @(safeMax), @"maxValue",
        @(safeDef), @"defaultValue",
        safeUnit, @"unit",
        nil];
    if (handler != nil && (id)handler != [NSNull null]) {
        mutableItem[@"handler"] = [handler copy];
    }
    [self upsertItemDictionary:[mutableItem copy]];
}

- (void)registerStepperInMenu:(NSString *)menuKey
                          key:(NSString *)key
                        title:(NSString *)title
                     subtitle:(NSString *)subtitle
                         icon:(NSString *)icon
                     minValue:(CGFloat)minValue
                     maxValue:(CGFloat)maxValue
                    stepValue:(CGFloat)stepValue
                 defaultValue:(CGFloat)defaultValue
                         unit:(NSString *)unit
                      handler:(NovaUISliderHandler)handler {
    NSString *trimmedKey = NovaUITrimmedString(key);
    NSString *trimmedTitle = NovaUITrimmedString(title);
    if (!trimmedKey.length || !trimmedTitle.length) return;

    CGFloat safeMin = isfinite(minValue) ? minValue : 0.0;
    CGFloat safeMax = (isfinite(maxValue) && maxValue > safeMin) ? maxValue : (safeMin + 10.0);
    CGFloat safeStep = (isfinite(stepValue) && stepValue > 0.0) ? stepValue : 1.0;
    CGFloat safeDef = isfinite(defaultValue) ? MAX(safeMin, MIN(safeMax, defaultValue)) : safeMin;
    NSString *defaultsKey = [@"NovaUI.slider." stringByAppendingString:trimmedKey];
    if ([NSUserDefaults.standardUserDefaults objectForKey:defaultsKey] == nil) {
        [NSUserDefaults.standardUserDefaults setFloat:safeDef forKey:defaultsKey];
    }

    NSString *safeParent = NovaUITrimmedString(menuKey);
    NSString *safeSubtitle = [subtitle isKindOfClass:NSString.class] ? [subtitle copy] : @"";
    NSString *trimmedIcon = NovaUITrimmedString(icon);
    NSString *safeIcon = trimmedIcon.length > 0 ? [trimmedIcon copy] : @"plus.forwardslash.minus";
    NSString *safeUnit = [unit isKindOfClass:NSString.class] ? [unit copy] : @"";

    NSMutableDictionary *mutableItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        [trimmedKey copy], @"key",
        [safeParent copy], @"parentKey",
        @"stepper", @"type",
        [trimmedTitle copy], @"title",
        safeSubtitle, @"subtitle",
        safeIcon, @"icon",
        @(safeMin), @"minValue",
        @(safeMax), @"maxValue",
        @(safeStep), @"stepValue",
        @(safeDef), @"defaultValue",
        safeUnit, @"unit",
        nil];
    if (handler != nil && (id)handler != [NSNull null]) {
        mutableItem[@"handler"] = [handler copy];
    }
    [self upsertItemDictionary:[mutableItem copy]];
}

- (void)registerSelectInMenu:(NSString *)menuKey
                         key:(NSString *)key
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                        icon:(NSString *)icon
                     options:(NSArray<NSString *> *)options
                defaultIndex:(NSInteger)defaultIndex
                     handler:(NovaUISelectHandler)handler {
    NSString *trimmedKey = NovaUITrimmedString(key);
    NSString *trimmedTitle = NovaUITrimmedString(title);
    if (!trimmedKey.length || !trimmedTitle.length) return;

    NSMutableArray<NSString *> *safeOptions = [NSMutableArray array];
    if ([options isKindOfClass:NSArray.class]) {
        for (id opt in options) {
            if ([opt isKindOfClass:NSString.class] && [opt length] > 0) {
                [safeOptions addObject:[opt copy]];
            }
        }
    }
    if (!safeOptions.count) {
        [safeOptions addObject:@"默认"];
    }
    NSInteger clampedIdx = (defaultIndex >= 0 && defaultIndex < (NSInteger)safeOptions.count) ? defaultIndex : 0;
    NSString *defaultsKey = [@"NovaUI.select." stringByAppendingString:trimmedKey];
    if ([NSUserDefaults.standardUserDefaults objectForKey:defaultsKey] == nil) {
        [NSUserDefaults.standardUserDefaults setInteger:clampedIdx forKey:defaultsKey];
    }

    NSString *safeParent = NovaUITrimmedString(menuKey);
    NSString *safeSubtitle = [subtitle isKindOfClass:NSString.class] ? [subtitle copy] : @"";
    NSString *trimmedIcon = NovaUITrimmedString(icon);
    NSString *safeIcon = trimmedIcon.length > 0 ? [trimmedIcon copy] : @"list.bullet.indent";

    NSMutableDictionary *mutableItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        [trimmedKey copy], @"key",
        [safeParent copy], @"parentKey",
        @"select", @"type",
        [trimmedTitle copy], @"title",
        safeSubtitle, @"subtitle",
        safeIcon, @"icon",
        [safeOptions copy], @"options",
        @(clampedIdx), @"defaultIndex",
        nil];
    if (handler != nil && (id)handler != [NSNull null]) {
        mutableItem[@"handler"] = [handler copy];
    }
    [self upsertItemDictionary:[mutableItem copy]];
}

- (void)registerInputInMenu:(NSString *)menuKey
                        key:(NSString *)key
                      title:(NSString *)title
                   subtitle:(NSString *)subtitle
                       icon:(NSString *)icon
                placeholder:(NSString *)placeholder
               defaultValue:(NSString *)defaultValue
                    handler:(NovaUIInputHandler)handler {
    NSString *trimmedKey = NovaUITrimmedString(key);
    NSString *trimmedTitle = NovaUITrimmedString(title);
    if (!trimmedKey.length || !trimmedTitle.length) return;

    NSString *safeDef = [defaultValue isKindOfClass:NSString.class] ? [defaultValue copy] : @"";
    NSString *defaultsKey = [@"NovaUI.input." stringByAppendingString:trimmedKey];
    if ([NSUserDefaults.standardUserDefaults objectForKey:defaultsKey] == nil && safeDef.length > 0) {
        [NSUserDefaults.standardUserDefaults setObject:safeDef forKey:defaultsKey];
    }

    NSString *safeParent = NovaUITrimmedString(menuKey);
    NSString *safeSubtitle = [subtitle isKindOfClass:NSString.class] ? [subtitle copy] : @"";
    NSString *trimmedIcon = NovaUITrimmedString(icon);
    NSString *safeIcon = trimmedIcon.length > 0 ? [trimmedIcon copy] : @"character.cursor.ibeam";
    NSString *safePlaceholder = [placeholder isKindOfClass:NSString.class] ? [placeholder copy] : @"请输入参数内容...";

    NSMutableDictionary *mutableItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        [trimmedKey copy], @"key",
        [safeParent copy], @"parentKey",
        @"input", @"type",
        [trimmedTitle copy], @"title",
        safeSubtitle, @"subtitle",
        safeIcon, @"icon",
        safePlaceholder, @"placeholder",
        safeDef, @"defaultValue",
        nil];
    if (handler != nil && (id)handler != [NSNull null]) {
        mutableItem[@"handler"] = [handler copy];
    }
    [self upsertItemDictionary:[mutableItem copy]];
}

- (void)registerInfoInMenu:(NSString *)menuKey
                       key:(NSString *)key
                     title:(NSString *)title
                 valueText:(NSString *)valueText
                      icon:(NSString *)icon {
    NSString *trimmedKey = NovaUITrimmedString(key);
    NSString *trimmedTitle = NovaUITrimmedString(title);
    if (!trimmedKey.length || !trimmedTitle.length) return;

    NSString *safeParent = NovaUITrimmedString(menuKey);
    NSString *safeVal = [valueText isKindOfClass:NSString.class] ? [valueText copy] : @"";
    NSString *trimmedIcon = NovaUITrimmedString(icon);
    NSString *safeIcon = trimmedIcon.length > 0 ? [trimmedIcon copy] : @"info.circle.fill";

    NSDictionary *item = @{
        @"key": [trimmedKey copy],
        @"parentKey": [safeParent copy],
        @"type": @"info",
        @"title": [trimmedTitle copy],
        @"subtitle": @"",
        @"valueText": safeVal,
        @"icon": safeIcon
    };
    [self upsertItemDictionary:item];
}

#pragma mark - Value Getters & Logs

- (BOOL)boolValueForKey:(NSString *)key {
    NSString *trimmed = NovaUITrimmedString(key);
    if (!trimmed.length) return NO;
    return [NSUserDefaults.standardUserDefaults boolForKey:[@"NovaUI.module." stringByAppendingString:trimmed]];
}

- (CGFloat)floatValueForKey:(NSString *)key {
    NSString *trimmed = NovaUITrimmedString(key);
    if (!trimmed.length) return 0.0;
    CGFloat v = [NSUserDefaults.standardUserDefaults floatForKey:[@"NovaUI.slider." stringByAppendingString:trimmed]];
    return isfinite(v) ? v : 0.0;
}

- (NSInteger)selectedIndexForKey:(NSString *)key {
    NSString *trimmed = NovaUITrimmedString(key);
    if (!trimmed.length) return 0;
    return [NSUserDefaults.standardUserDefaults integerForKey:[@"NovaUI.select." stringByAppendingString:trimmed]];
}

- (NSString *)stringValueForKey:(NSString *)key {
    NSString *trimmed = NovaUITrimmedString(key);
    if (!trimmed.length) return nil;
    return [NSUserDefaults.standardUserDefaults stringForKey:[@"NovaUI.input." stringByAppendingString:trimmed]];
}

- (void)logMessage:(NSString *)message level:(NSString *)level {
    NSString *trimmedMsg = NovaUITrimmedString(message);
    if (!trimmedMsg.length) return;
    NSString *safeLevel = NovaUITrimmedString(level);
    if (!safeLevel.length) safeLevel = @"INFO";

    NSDateFormatter *fmt = [NSDateFormatter new];
    fmt.dateFormat = @"HH:mm:ss";
    NSString *timeStr = [fmt stringFromDate:[NSDate date]] ?: @"00:00:00";

    NSDictionary *entry = @{
        @"time": timeStr,
        @"level": [safeLevel uppercaseString],
        @"message": [trimmedMsg copy]
    };
    @synchronized (self) {
        [self.logs addObject:entry];
        if (self.logs.count > 200) {
            [self.logs removeObjectAtIndex:0];
        }
    }
}

- (NSArray<NSDictionary *> *)recentLogs {
    @synchronized (self) {
        return [self.logs copy];
    }
}

- (void)clearLogs {
    @synchronized (self) {
        [self.logs removeAllObjects];
    }
    [self logMessage:@"日志已清空" level:@"INFO"];
}

#pragma mark - Configuration Export / Import / Reset

- (NSString *)exportConfigurationJSON {
    NSDictionary<NSString *, id> *all = [NSUserDefaults.standardUserDefaults dictionaryRepresentation];
    NSMutableDictionary<NSString *, id> *novaConfig = [NSMutableDictionary dictionary];
    for (NSString *k in all.allKeys) {
        if ([k hasPrefix:@"NovaUI."] && ![k hasSuffix:@"CustomImageData"]) {
            id val = all[k];
            if ([val isKindOfClass:NSString.class] || [val isKindOfClass:NSNumber.class]) {
                novaConfig[k] = val;
            }
        }
    }
    NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:novaConfig options:NSJSONWritingPrettyPrinted error:&err];
    if (!data || err) return @"{}";
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}

- (BOOL)importConfigurationJSON:(NSString *)jsonString {
    NSString *trimmed = NovaUITrimmedString(jsonString);
    if (!trimmed.length) return NO;
    NSData *data = [trimmed dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return NO;
    NSError *err = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    if (![obj isKindOfClass:NSDictionary.class] || err) return NO;
    NSDictionary *dict = (NSDictionary *)obj;
    NSInteger importedCount = 0;
    for (id k in dict.allKeys) {
        if ([k isKindOfClass:NSString.class] && [k hasPrefix:@"NovaUI."]) {
            id val = dict[k];
            if ([val isKindOfClass:NSString.class] || [val isKindOfClass:NSNumber.class]) {
                [NSUserDefaults.standardUserDefaults setObject:val forKey:k];
                importedCount++;
            }
        }
    }
    if (importedCount <= 0) return NO;
    [self logMessage:[NSString stringWithFormat:@"成功导入 %ld 项配置参数", (long)importedCount] level:@"ACTION"];
    NovaUIRunOnMainThread(^{
        if (self.floatingButton) {
            NSInteger style = [NSUserDefaults.standardUserDefaults integerForKey:@"NovaUI.entryStyle"];
            [self.floatingButton applyEntryStyle:style];
            NSString *customEntry = [NSUserDefaults.standardUserDefaults stringForKey:@"NovaUI.entryCustomIcon"];
            [self.floatingButton applyCustomIcon:customEntry];
            if ([NSUserDefaults.standardUserDefaults objectForKey:@"NovaUI.entryOpacity"] != nil) {
                self.floatingButton.alpha = NovaUIClampOpacity([NSUserDefaults.standardUserDefaults floatForKey:@"NovaUI.entryOpacity"]);
            }
        }
        [self notifyPanelReload];
    });
    return YES;
}

- (void)resetAllConfiguration {
    NSDictionary<NSString *, id> *all = [NSUserDefaults.standardUserDefaults dictionaryRepresentation];
    for (NSString *k in [all.allKeys copy]) {
        if ([k hasPrefix:@"NovaUI."]) {
            [NSUserDefaults.standardUserDefaults removeObjectForKey:k];
        }
    }
    @synchronized (self) {
        _headerIcon = @"nova.sakura";
        _floatingEntryIcon = nil;
        _panicHideGestureEnabled = YES;
        _magneticEdgeSnapEnabled = YES;
    }
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"NovaUI.panicHideGesture"];
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"NovaUI.magneticEdgeSnap"];
    [self logMessage:@"已恢复全部默认配置" level:@"WARN"];
    NovaUIRunOnMainThread(^{
        if (self.floatingButton) {
            self.floatingButton.magneticEdgeSnap = YES;
            [self.floatingButton applyCustomIcon:nil];
            [self.floatingButton applyEntryStyle:0];
            self.floatingButton.alpha = 1.0;
        }
        if (self.panel) {
            [self.panel applyHeaderIcon:@"nova.sakura"];
        }
        [self notifyPanelReload];
    });
}

#pragma mark - Panel Creation, Submenu & Modal Forwarding

- (void)ensurePanelCreatedOnMainThread {
    if (self.panel) return;
    NSArray<NSDictionary *> *snapshot = nil;
    NSString *currentTitle = nil;
    @synchronized (self) {
        snapshot = [self.modules copy];
        currentTitle = [_panelTitle copy] ?: @"NOVA 控制中心";
    }
    self.panel = [[NovaControlPanel alloc] initWithTitle:currentTitle modules:snapshot];
    __weak typeof(self) weakSelf = self;
    self.panel.floatingStyleChanged = ^(NSInteger style) {
        [weakSelf.floatingButton applyEntryStyle:style];
    };
    self.panel.floatingIconChanged = ^(NSString *icon) {
        NovaUIManager *strongSelf = weakSelf;
        if (!strongSelf) return;
        NSString *trimmed = NovaUITrimmedString(icon);
        @synchronized (strongSelf) {
            strongSelf->_floatingEntryIcon = trimmed.length > 0 ? [trimmed copy] : nil;
        }
        [strongSelf.floatingButton applyCustomIcon:icon];
    };
    self.panel.headerIconChanged = ^(NSString *icon) {
        NovaUIManager *strongSelf = weakSelf;
        if (!strongSelf) return;
        NSString *trimmed = NovaUITrimmedString(icon);
        @synchronized (strongSelf) {
            strongSelf->_headerIcon = trimmed.length > 0 ? [trimmed copy] : @"nova.sakura";
        }
    };
    self.panel.floatingOpacityChanged = ^(CGFloat opacity) {
        weakSelf.floatingButton.alpha = NovaUIClampOpacity(opacity);
    };
    self.panel.logsProvider = ^NSArray<NSDictionary *> *(void) {
        return [weakSelf recentLogs] ?: @[];
    };
    self.panel.clearLogsHandler = ^{
        [weakSelf clearLogs];
    };
    self.panel.logEventHandler = ^(NSString *message, NSString *level) {
        [weakSelf logMessage:message level:level];
    };
    self.panel.exportConfigHandler = ^NSString *(void) {
        return [weakSelf exportConfigurationJSON] ?: @"{}";
    };
    self.panel.importConfigHandler = ^BOOL(NSString *jsonString) {
        return [weakSelf importConfigurationJSON:jsonString];
    };
    self.panel.resetConfigHandler = ^{
        [weakSelf resetAllConfiguration];
    };
}

- (void)openSubmenu:(NSString *)submenuKey {
    NovaUIRunOnMainThread(^{
        [self showPanel];
        [self.panel pushSubmenuWithKey:submenuKey];
    });
}

- (void)popSubmenu {
    NovaUIRunOnMainThread(^{
        [self.panel popSubmenu];
    });
}

- (void)openConsoleLogPanel {
    NovaUIRunOnMainThread(^{
        [self showPanel];
        [self.panel openConsoleLogInspector];
    });
}

- (void)openConfigCenterPanel {
    NovaUIRunOnMainThread(^{
        [self showPanel];
        [self.panel openConfigCenterInspector];
    });
}

- (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
              confirmTitle:(NSString *)confirmTitle
               cancelTitle:(NSString *)cancelTitle
                   handler:(NovaUIAlertHandler)handler {
    NovaUIRunOnMainThread(^{
        [self showPanel];
        [self.panel showAlertWithTitle:title
                               message:message
                          confirmTitle:confirmTitle
                           cancelTitle:cancelTitle
                               handler:handler];
    });
}

- (void)showPromptWithTitle:(NSString *)title
                    message:(NSString *)message
                placeholder:(NSString *)placeholder
               defaultValue:(NSString *)defaultValue
               confirmTitle:(NSString *)confirmTitle
                    handler:(NovaUIPromptHandler)handler {
    NovaUIRunOnMainThread(^{
        [self showPanel];
        [self.panel showPromptWithTitle:title
                                message:message
                            placeholder:placeholder
                           defaultValue:defaultValue
                           confirmTitle:confirmTitle
                                handler:handler];
    });
}

- (void)showSelectionSheetWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                            options:(NSArray<NSString *> *)options
                      selectedIndex:(NSInteger)selectedIndex
                            handler:(NovaUISelectHandler)handler {
    NovaUIRunOnMainThread(^{
        [self showPanel];
        [self.panel showSelectionSheetWithTitle:title
                                       subtitle:subtitle
                                        options:options
                                  selectedIndex:selectedIndex
                                        handler:handler];
    });
}

- (void)showDetailModalWithTitle:(NSString *)title
                        subtitle:(NSString *)subtitle
                       badgeText:(NSString *)badgeText
                          fields:(NSArray<NSDictionary *> *)fields
              primaryActionTitle:(NSString *)primaryTitle
                  primaryHandler:(dispatch_block_t)primaryHandler {
    NovaUIRunOnMainThread(^{
        [self showPanel];
        [self.panel showDetailModalWithTitle:title
                                    subtitle:subtitle
                                   badgeText:badgeText
                                      fields:fields
                          primaryActionTitle:primaryTitle
                              primaryHandler:primaryHandler];
    });
}

- (void)showToast:(NSString *)message {
    [self showToast:message icon:@"sparkles" duration:2.0];
}

- (void)showToast:(NSString *)message icon:(NSString *)icon duration:(NSTimeInterval)duration {
    NovaUIRunOnMainThread(^{
        [self ensurePanelCreatedOnMainThread];
        [self.panel showToast:message icon:icon duration:duration];
    });
}

#pragma mark - Window Attachment & 3-Finger Stealth Gesture

- (void)handlePanicHideGesture:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    if (!self.panicHideGestureEnabled) return;
    self.isStealthHidden = !self.isStealthHidden;
    if (self.isStealthHidden) {
        [self.panel dismiss];
        self.floatingButton.hidden = YES;
        [self logMessage:@"已触发三指隐蔽手势：隐藏悬浮球与面板" level:@"WARN"];
    } else {
        self.floatingButton.hidden = NO;
        [self logMessage:@"已触发三指隐蔽手势：恢复显示悬浮球" level:@"INFO"];
        [self showToast:@"已恢复显示 NOVA 悬浮球" icon:@"eye.fill" duration:1.6];
    }
}

- (void)attachPanicGestureIfNeededToWindow:(UIWindow *)window {
    if (!window) return;
    if (!self.panicGestureRecognizer) {
        self.panicGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanicHideGesture:)];
        self.panicGestureRecognizer.numberOfTouchesRequired = 3;
        self.panicGestureRecognizer.numberOfTapsRequired = 1;
        self.panicGestureRecognizer.cancelsTouchesInView = NO;
        self.panicGestureRecognizer.delaysTouchesBegan = NO;
        self.panicGestureRecognizer.delaysTouchesEnded = NO;
    }
    self.panicGestureRecognizer.enabled = self.panicHideGestureEnabled;
    if (self.panicGestureRecognizer.view != window) {
        [self.panicGestureRecognizer.view removeGestureRecognizer:self.panicGestureRecognizer];
        [window addGestureRecognizer:self.panicGestureRecognizer];
    }
}

- (void)scheduleAttachRetryWithRemainingAttempts:(NSInteger)attempts {
    if (attempts <= 0 || self.pendingInstallRetry || self.floatingButton.superview) return;
    self.pendingInstallRetry = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NovaUIManager *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.pendingInstallRetry = NO;
        [strongSelf reattachFloatingButton];
        if (!strongSelf.floatingButton.superview) {
            [strongSelf scheduleAttachRetryWithRemainingAttempts:attempts - 1];
        }
    });
}

- (void)install {
    NovaUIRunOnMainThread(^{
        if (!self.floatingButton) {
            CGRect screenBounds = UIScreen.mainScreen.bounds;
            CGFloat w = (isfinite(screenBounds.size.width) && screenBounds.size.width > 0) ? screenBounds.size.width : 390.0;
            CGFloat h = (isfinite(screenBounds.size.height) && screenBounds.size.height > 0) ? screenBounds.size.height : 844.0;
            CGFloat initX = w > 72 ? (w - 72) : 16;
            CGFloat initY = h > 100 ? (h * 0.55) : 100;
            self.floatingButton = [[NovaFloatingButton alloc] initWithFrame:CGRectMake(initX, initY, 54, 54)];
            self.floatingButton.magneticEdgeSnap = self.magneticEdgeSnapEnabled;
            __weak typeof(self) weakSelf = self;
            self.floatingButton.tapHandler = ^{ [weakSelf showPanel]; };
        }
        [self.floatingButton attachToAvailableWindow];
        if ([self.floatingButton.superview isKindOfClass:UIWindow.class]) {
            [self attachPanicGestureIfNeededToWindow:(UIWindow *)self.floatingButton.superview];
        }
        if (!self.floatingButton.superview) {
            [self scheduleAttachRetryWithRemainingAttempts:8];
        }
        if (self.panel.superview && self.panel.superview == self.floatingButton.superview) {
            [self.panel.superview bringSubviewToFront:self.panel];
        }
    });
}

- (void)reattachFloatingButton {
    NovaUIRunOnMainThread(^{
        if (self.floatingButton) {
            [self.floatingButton attachToAvailableWindow];
            self.floatingButton.hidden = self.isStealthHidden;
            if ([self.floatingButton.superview isKindOfClass:UIWindow.class]) {
                [self attachPanicGestureIfNeededToWindow:(UIWindow *)self.floatingButton.superview];
            }
        }
        if (self.panel.superview) {
            self.panel.frame = self.panel.superview.bounds;
            [self.panel.superview bringSubviewToFront:self.panel];
        }
    });
}

- (void)showPanel {
    NovaUIRunOnMainThread(^{
        self.isStealthHidden = NO;
        self.floatingButton.hidden = NO;
        NSArray<NSDictionary *> *snapshot = nil;
        NSString *currentTitle = nil;
        @synchronized (self) {
            snapshot = [self.modules copy];
            currentTitle = [_panelTitle copy] ?: @"NOVA 控制中心";
        }
        if (!self.panel) {
            [self ensurePanelCreatedOnMainThread];
        } else {
            [self.panel reloadModules:snapshot title:currentTitle];
        }
        [self.panel present];
    });
}

- (void)hidePanel {
    NovaUIRunOnMainThread(^{
        [self.panel dismiss];
    });
}

@end
