#import "NovaFloatingButton.h"
#import <QuartzCore/QuartzCore.h>

@implementation NovaFloatingButton

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.layer.cornerRadius = frame.size.width / 2.0;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 1.4;
        self.layer.shadowOpacity = 0.48;
        self.layer.shadowRadius = 13;
        self.layer.shadowOffset = CGSizeZero;
        self.titleLabel.font = [UIFont systemFontOfSize:25 weight:UIFontWeightMedium];
        [self addTarget:self action:@selector(didTap) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
        [self addGestureRecognizer:pan];
        self.accessibilityLabel = @"打开控制面板";
        [self applyEntryStyle:[NSUserDefaults.standardUserDefaults integerForKey:@"NovaUI.entryStyle"]];
        CGFloat opacity = [NSUserDefaults.standardUserDefaults objectForKey:@"NovaUI.entryOpacity"] ? [NSUserDefaults.standardUserDefaults floatForKey:@"NovaUI.entryOpacity"] : 1.0;
        self.alpha = MAX(0.35, MIN(1.0, opacity));
    }
    return self;
}

- (void)applyEntryStyle:(NSInteger)style {
    UIColor *pink = [UIColor colorWithRed:0.95 green:0.22 blue:0.68 alpha:1];
    self.layer.shadowColor = pink.CGColor;
    self.layer.borderWidth = 1.4;
    self.layer.shadowOpacity = 0.48;
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.75].CGColor;
    self.backgroundColor = [pink colorWithAlphaComponent:0.94];
    [self setImage:nil forState:UIControlStateNormal];
    switch (style) {
        case 1:
            self.backgroundColor = [UIColor colorWithRed:0.72 green:0.80 blue:1 alpha:0.55];
            self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.85].CGColor;
            self.layer.shadowColor = [UIColor colorWithRed:0.56 green:0.72 blue:1 alpha:1].CGColor;
            if (@available(iOS 13.0, *)) [self setImage:[UIImage systemImageNamed:@"circle.fill"] forState:UIControlStateNormal];
            self.tintColor = UIColor.whiteColor;
            break;
        case 2:
            self.backgroundColor = [UIColor colorWithWhite:0.035 alpha:1];
            self.layer.borderWidth = 3;
            self.layer.borderColor = pink.CGColor;
            self.layer.shadowOpacity = 0.9;
            if (@available(iOS 13.0, *)) [self setImage:[UIImage systemImageNamed:@"circle.circle.fill"] forState:UIControlStateNormal];
            self.tintColor = pink;
            break;
        case 3:
            self.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.95];
            self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
            if (@available(iOS 13.0, *)) [self setImage:[UIImage systemImageNamed:@"circle.grid.2x2.fill"] forState:UIControlStateNormal];
            self.tintColor = UIColor.whiteColor;
            break;
        case 4:
            if (@available(iOS 13.0, *)) [self setImage:[UIImage systemImageNamed:@"pawprint.fill"] forState:UIControlStateNormal];
            self.tintColor = UIColor.whiteColor;
            break;
        default:
            if (@available(iOS 13.0, *)) [self setImage:[UIImage systemImageNamed:@"asterisk"] forState:UIControlStateNormal];
            self.tintColor = UIColor.whiteColor;
            break;
    }
}

- (void)didTap {
    if (self.tapHandler) self.tapHandler();
}

- (void)didPan:(UIPanGestureRecognizer *)gesture {
    UIView *parent = self.superview;
    if (!parent) return;
    CGPoint delta = [gesture translationInView:parent];
    if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint center = CGPointMake(self.center.x + delta.x, self.center.y + delta.y);
        CGFloat halfW = self.bounds.size.width / 2, halfH = self.bounds.size.height / 2;
        center.x = MAX(halfW, MIN(parent.bounds.size.width - halfW, center.x));
        center.y = MAX(halfH + 8, MIN(parent.bounds.size.height - halfH - 8, center.y));
        self.center = center;
        [gesture setTranslation:CGPointZero inView:parent];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        [defaults setDouble:self.center.x / MAX(parent.bounds.size.width, 1) forKey:@"NovaUI.floatingX"];
        [defaults setDouble:self.center.y / MAX(parent.bounds.size.height, 1) forKey:@"NovaUI.floatingY"];
    }
}

- (void)attachToAvailableWindow {
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
                if (candidate.isKeyWindow && candidate.windowLevel == UIWindowLevelNormal) { window = candidate; break; }
            }
            if (!window) {
                for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
                    if (!candidate.hidden && candidate.rootViewController && candidate.windowLevel == UIWindowLevelNormal) { window = candidate; break; }
                }
            }
            if (window) break;
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (!window) {
        for (UIWindow *w in UIApplication.sharedApplication.windows) {
            if (!w.hidden && w.rootViewController && w.windowLevel == UIWindowLevelNormal) { window = w; break; }
        }
    }
    if (!window) {
        UIWindow *kw = UIApplication.sharedApplication.keyWindow;
        if (kw && kw.rootViewController) window = kw;
    }
#pragma clang diagnostic pop
    if (!window) {
        static int sRetry = 0;
        if (sRetry++ < 25) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self attachToAvailableWindow];
            });
        }
        return;
    }
    if (self.superview == window) {
        [window bringSubviewToFront:self];
        return;
    }
    [self removeFromSuperview];
    CGFloat x = [NSUserDefaults.standardUserDefaults doubleForKey:@"NovaUI.floatingX"];
    CGFloat y = [NSUserDefaults.standardUserDefaults doubleForKey:@"NovaUI.floatingY"];
    if (x > 0 && x <= 1 && y > 0 && y <= 1) self.center = CGPointMake(x * window.bounds.size.width, y * window.bounds.size.height);
    else self.center = CGPointMake(window.bounds.size.width - 44, window.bounds.size.height * 0.55);
    [window addSubview:self];
    [window bringSubviewToFront:self];
}

@end
