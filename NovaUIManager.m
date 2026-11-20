#import "NovaUIManager.h"
#import "NovaFloatingButton.h"
#import "NovaControlPanel.h"

@interface NovaUIManager ()
@property (nonatomic, strong) NovaFloatingButton *floatingButton;
@property (nonatomic, strong) NovaControlPanel *panel;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *modules;
@end

@implementation NovaUIManager

+ (instancetype)sharedManager {
    static NovaUIManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [NovaUIManager new]; });
    return manager;
}

- (instancetype)init {
    if ((self = [super init])) {
        _panelTitle = @"TTForge 控制中心";
        _panelSubtitle = @"PLUGIN CONTROL CENTER  ·  v7.32";
        _modules = [NSMutableArray array];
    }
    return self;
}

- (void)upsertModuleItem:(NSDictionary *)item forKey:(NSString *)key {
    NSUInteger index = [self.modules indexOfObjectPassingTest:^BOOL(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
        return [obj[@"key"] isEqualToString:key];
    }];
    if (index != NSNotFound) [self.modules replaceObjectAtIndex:index withObject:item];
    else [self.modules addObject:item];
}

- (void)registerModule:(NSString *)key title:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)icon handler:(NovaUIModuleHandler)handler {
    if (!key.length || !title.length) return;
    NSMutableDictionary *item = [@{
        @"type": @"switch",
        @"key": key,
        @"title": title,
        @"subtitle": subtitle ?: @"",
        @"icon": icon ?: @"circle"
    } mutableCopy];
    if (handler) item[@"handler"] = [handler copy];
    [self upsertModuleItem:item forKey:key];
}

- (void)registerSwitchModule:(NSString *)key title:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)icon stateProvider:(NovaUIStateProvider)stateProvider handler:(NovaUIModuleHandler)handler {
    if (!key.length || !title.length) return;
    NSMutableDictionary *item = [@{
        @"type": @"switch",
        @"key": key,
        @"title": title,
        @"subtitle": subtitle ?: @"",
        @"icon": icon ?: @"circle"
    } mutableCopy];
    if (stateProvider) item[@"stateProvider"] = [stateProvider copy];
    if (handler) item[@"handler"] = [handler copy];
    [self upsertModuleItem:item forKey:key];
}

- (void)registerPickerModule:(NSString *)key title:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)icon valueProvider:(NovaUIValueProvider)valueProvider optionsProvider:(NovaUIOptionsProvider)optionsProvider selectionHandler:(NovaUISelectionHandler)selectionHandler {
    if (!key.length || !title.length) return;
    NSMutableDictionary *item = [@{
        @"type": @"picker",
        @"key": key,
        @"title": title,
        @"subtitle": subtitle ?: @"",
        @"icon": icon ?: @"circle"
    } mutableCopy];
    if (valueProvider) item[@"valueProvider"] = [valueProvider copy];
    if (optionsProvider) item[@"optionsProvider"] = [optionsProvider copy];
    if (selectionHandler) item[@"selectionHandler"] = [selectionHandler copy];
    [self upsertModuleItem:item forKey:key];
}

- (void)registerActionModule:(NSString *)key title:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)icon valueProvider:(NovaUIValueProvider)valueProvider actionHandler:(NovaUIActionHandler)actionHandler {
    if (!key.length || !title.length) return;
    NSMutableDictionary *item = [@{
        @"type": @"action",
        @"key": key,
        @"title": title,
        @"subtitle": subtitle ?: @"",
        @"icon": icon ?: @"circle"
    } mutableCopy];
    if (valueProvider) item[@"valueProvider"] = [valueProvider copy];
    if (actionHandler) item[@"actionHandler"] = [actionHandler copy];
    [self upsertModuleItem:item forKey:key];
}

- (void)registerSubmenuModule:(NSString *)key title:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)icon valueProvider:(NovaUIValueProvider)valueProvider itemsProvider:(NovaUIOptionsProvider)itemsProvider {
    if (!key.length || !title.length) return;
    NSMutableDictionary *item = [@{
        @"type": @"submenu",
        @"key": key,
        @"title": title,
        @"subtitle": subtitle ?: @"",
        @"icon": icon ?: @"circle"
    } mutableCopy];
    if (valueProvider) item[@"valueProvider"] = [valueProvider copy];
    if (itemsProvider) item[@"itemsProvider"] = [itemsProvider copy];
    [self upsertModuleItem:item forKey:key];
}

- (void)install {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.floatingButton) {
            self.floatingButton = [[NovaFloatingButton alloc] initWithFrame:CGRectMake(UIScreen.mainScreen.bounds.size.width - 72, UIScreen.mainScreen.bounds.size.height * 0.55, 54, 54)];
            __weak typeof(self) weakSelf = self;
            self.floatingButton.tapHandler = ^{
                if (weakSelf.panel && weakSelf.panel.superview) [weakSelf hidePanel];
                else [weakSelf showPanel];
            };
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reattachFloatingButton) name:UIApplicationDidBecomeActiveNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reattachFloatingButton) name:UIWindowDidBecomeKeyNotification object:nil];
        }
        [self.floatingButton attachToAvailableWindow];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self reattachFloatingButton];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self reattachFloatingButton];
        });
    });
}

- (void)reattachFloatingButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.floatingButton) [self.floatingButton attachToAvailableWindow];
    });
}

- (void)showPanel {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.panel) {
            self.panel = [[NovaControlPanel alloc] initWithTitle:self.panelTitle subtitle:self.panelSubtitle modules:self.modules];
            __weak typeof(self) weakSelf = self;
            self.panel.floatingStyleChanged = ^(NSInteger style) { [weakSelf.floatingButton applyEntryStyle:style]; };
            self.panel.floatingOpacityChanged = ^(CGFloat opacity) { weakSelf.floatingButton.alpha = opacity; };
        } else {
            [self.panel reloadModules:self.modules title:self.panelTitle subtitle:self.panelSubtitle];
        }
        [self.panel present];
        if (self.floatingButton.superview) [self.floatingButton.superview bringSubviewToFront:self.floatingButton];
    });
}

- (void)hidePanel {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.panel dismiss];
    });
}

- (void)reloadPanel {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.panel) [self.panel reloadModules:self.modules title:self.panelTitle subtitle:self.panelSubtitle];
    });
}

@end
