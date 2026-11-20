#import "NovaControlPanel.h"
#import <objc/runtime.h>
#import <math.h>

static const void * const kNovaModuleKey = &kNovaModuleKey;
static const void * const kNovaModuleHandlerKey = &kNovaModuleHandlerKey;
static const void * const kNovaItemDictKey = &kNovaItemDictKey;
static const void * const kNovaValueLabelKey = &kNovaValueLabelKey;

static inline CGFloat NovaPanelClampOpacity(CGFloat value) {
    if (!isfinite(value)) return 1.0;
    return MAX(0.35, MIN(1.0, value));
}

static inline NSInteger NovaPanelNormalizeTheme(NSInteger theme) {
    return (theme >= 0 && theme <= 4) ? theme : 0;
}

static inline NSInteger NovaPanelNormalizeStyle(NSInteger style) {
    return (style >= 0 && style <= 4) ? style : 0;
}

static inline BOOL NovaPanelIsValidDimension(CGFloat v) {
    return isfinite(v) && v > 0.0;
}

static inline NSString *NovaPanelTrimmedString(NSString *input) {
    if (![input isKindOfClass:NSString.class]) return @"";
    return [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static inline CGRect NovaPanelSanitizeFrame(CGRect frame) {
    if (!CGRectIsNull(frame) && !CGRectIsInfinite(frame) &&
        isfinite(frame.origin.x) && isfinite(frame.origin.y) &&
        NovaPanelIsValidDimension(frame.size.width) && NovaPanelIsValidDimension(frame.size.height)) {
        return frame;
    }
    CGRect screen = UIScreen.mainScreen.bounds;
    if (!CGRectIsNull(screen) && !CGRectIsInfinite(screen) &&
        NovaPanelIsValidDimension(screen.size.width) && NovaPanelIsValidDimension(screen.size.height)) {
        return CGRectMake(0, 0, screen.size.width, screen.size.height);
    }
    return CGRectMake(0, 0, 390, 844);
}

// Center-crops and scales any non-square photo from the system Photo Library to a crisp square
static UIImage *NovaPanelCenterCropSquareImage(UIImage *source, CGFloat sideLength) {
    if (!source || sideLength <= 0) return nil;
    CGSize srcSize = source.size;
    if (!NovaPanelIsValidDimension(srcSize.width) || !NovaPanelIsValidDimension(srcSize.height)) {
        return source;
    }
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = MAX(2.0, UIScreen.mainScreen.scale);
    fmt.opaque = NO;
    CGSize targetSize = CGSizeMake(sideLength, sideLength);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:fmt];
    UIImage *rendered = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGFloat scale = MAX(sideLength / srcSize.width, sideLength / srcSize.height);
        CGFloat drawW = srcSize.width * scale;
        CGFloat drawH = srcSize.height * scale;
        CGRect drawRect = CGRectMake((sideLength - drawW) / 2.0, (sideLength - drawH) / 2.0, drawW, drawH);
        [source drawInRect:drawRect];
    }];
    return [rendered imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

static BOOL NovaPanelIsIOS26OrLater(void) {
    if (@available(iOS 13.0, *)) {
        NSOperatingSystemVersion ver = [NSProcessInfo processInfo].operatingSystemVersion;
        return (ver.majorVersion >= 26);
    }
    return NO;
}

static UIVisualEffect *NovaPanelCreateLiquidGlassEffect(BOOL isDark) {
    if (NovaPanelIsIOS26OrLater()) {
        Class glassCls = NSClassFromString(@"UIGlassEffect");
        if (glassCls) {
            SEL sel = NSSelectorFromString(@"effectWithStyle:");
            if ([glassCls respondsToSelector:sel]) {
                typedef UIVisualEffect *(*GlassEffectFn)(id, SEL, NSInteger);
                GlassEffectFn fn = (GlassEffectFn)[glassCls methodForSelector:sel];
                if (fn) {
                    UIVisualEffect *glass = fn(glassCls, sel, 0);
                    if (glass) return glass;
                }
            }
            SEL newSel = NSSelectorFromString(@"new");
            if ([glassCls respondsToSelector:newSel]) {
                typedef UIVisualEffect *(*GlassNewFn)(id, SEL);
                GlassNewFn fn = (GlassNewFn)[glassCls methodForSelector:newSel];
                if (fn) {
                    UIVisualEffect *glass = fn(glassCls, newSel);
                    if (glass) return glass;
                }
            }
        }
    }
    if (@available(iOS 13.0, *)) {
        return [UIBlurEffect effectWithStyle:isDark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight];
    }
    return [UIBlurEffect effectWithStyle:isDark ? UIBlurEffectStyleDark : UIBlurEffectStyleExtraLight];
}

static BOOL NovaPanelIsUsableWindow(UIWindow *candidate) {
    if (!candidate || candidate.isHidden || candidate.alpha <= 0.01) return NO;
    NSString *clsName = NSStringFromClass(candidate.class) ?: @"";
    if ([clsName containsString:@"Keyboard"] || [clsName containsString:@"TextEffects"]) return NO;
    return YES;
}

static NSCache<NSString *, UIImage *> *NovaPanelIconCache(void) {
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSCache new];
        cache.countLimit = 128;
    });
    return cache;
}

static UIImage *NovaPanelDrawCustomVectorIcon(NSString *identifier, CGFloat pointSize) {
    if (![identifier hasPrefix:@"nova."]) return nil;
    CGFloat box = MAX(18.0, pointSize * 1.38);
    CGSize size = CGSizeMake(box, box);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    UIImage *img = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef cg = ctx.CGContext;
        CGFloat cx = box / 2.0;
        CGFloat cy = box / 2.0;
        CGFloat r = box * 0.44;
        [UIColor.whiteColor setFill];
        [UIColor.whiteColor setStroke];

        if ([identifier isEqualToString:@"nova.sakura"]) {
            for (int i = 0; i < 5; i++) {
                CGContextSaveGState(cg);
                CGContextTranslateCTM(cg, cx, cy);
                CGContextRotateCTM(cg, i * (2.0 * M_PI / 5.0));

                UIBezierPath *petal = [UIBezierPath bezierPath];
                [petal moveToPoint:CGPointMake(0, -r * 0.12)];
                [petal addCurveToPoint:CGPointMake(-r * 0.16, -r * 0.96)
                         controlPoint1:CGPointMake(-r * 0.42, -r * 0.28)
                         controlPoint2:CGPointMake(-r * 0.44, -r * 0.78)];
                [petal addLineToPoint:CGPointMake(0, -r * 0.78)];
                [petal addLineToPoint:CGPointMake(r * 0.16, -r * 0.96)];
                [petal addCurveToPoint:CGPointMake(0, -r * 0.12)
                         controlPoint1:CGPointMake(r * 0.44, -r * 0.78)
                         controlPoint2:CGPointMake(r * 0.42, -r * 0.28)];
                [petal closePath];
                [petal fill];
                CGContextRestoreGState(cg);
            }
            CGContextSaveGState(cg);
            CGContextSetBlendMode(cg, kCGBlendModeDestinationOut);
            UIBezierPath *centerHole = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r * 0.24 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
            [centerHole fill];
            CGContextRestoreGState(cg);

            UIBezierPath *pistil = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r * 0.10 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
            [pistil fill];
            for (int i = 0; i < 5; i++) {
                CGFloat a = (i * 2.0 * M_PI / 5.0) - M_PI_2;
                CGPoint p1 = CGPointMake(cx + cos(a) * r * 0.12, cy + sin(a) * r * 0.12);
                CGPoint p2 = CGPointMake(cx + cos(a) * r * 0.34, cy + sin(a) * r * 0.34);
                UIBezierPath *stamen = [UIBezierPath bezierPath];
                stamen.lineWidth = MAX(0.9, box * 0.042);
                [stamen moveToPoint:p1];
                [stamen addLineToPoint:p2];
                [stamen stroke];
                UIBezierPath *tip = [UIBezierPath bezierPathWithArcCenter:p2 radius:r * 0.055 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
                [tip fill];
            }
        } else if ([identifier isEqualToString:@"nova.claw.slash"]) {
            CGFloat w = box;
            CGFloat h = box;
            UIBezierPath *s1 = [UIBezierPath bezierPath];
            [s1 moveToPoint:CGPointMake(w * 0.10, h * 0.25)];
            [s1 addCurveToPoint:CGPointMake(w * 0.42, h * 0.52)
                  controlPoint1:CGPointMake(w * 0.24, h * 0.32)
                  controlPoint2:CGPointMake(w * 0.35, h * 0.44)];
            [s1 addLineToPoint:CGPointMake(w * 0.38, h * 0.56)];
            [s1 addCurveToPoint:CGPointMake(w * 0.72, h * 0.90)
                  controlPoint1:CGPointMake(w * 0.50, h * 0.68)
                  controlPoint2:CGPointMake(w * 0.62, h * 0.82)];
            [s1 addCurveToPoint:CGPointMake(w * 0.34, h * 0.60)
                  controlPoint1:CGPointMake(w * 0.56, h * 0.80)
                  controlPoint2:CGPointMake(w * 0.44, h * 0.70)];
            [s1 addLineToPoint:CGPointMake(w * 0.37, h * 0.55)];
            [s1 addCurveToPoint:CGPointMake(w * 0.10, h * 0.25)
                  controlPoint1:CGPointMake(w * 0.26, h * 0.45)
                  controlPoint2:CGPointMake(w * 0.16, h * 0.34)];
            [s1 closePath];
            [s1 fill];

            UIBezierPath *s2 = [UIBezierPath bezierPath];
            [s2 moveToPoint:CGPointMake(w * 0.16, h * 0.07)];
            [s2 addCurveToPoint:CGPointMake(w * 0.55, h * 0.43)
                  controlPoint1:CGPointMake(w * 0.32, h * 0.18)
                  controlPoint2:CGPointMake(w * 0.46, h * 0.32)];
            [s2 addLineToPoint:CGPointMake(w * 0.51, h * 0.47)];
            [s2 addCurveToPoint:CGPointMake(w * 0.86, h * 0.93)
                  controlPoint1:CGPointMake(w * 0.66, h * 0.62)
                  controlPoint2:CGPointMake(w * 0.78, h * 0.78)];
            [s2 addCurveToPoint:CGPointMake(w * 0.44, h * 0.55)
                  controlPoint1:CGPointMake(w * 0.70, h * 0.79)
                  controlPoint2:CGPointMake(w * 0.56, h * 0.67)];
            [s2 addLineToPoint:CGPointMake(w * 0.48, h * 0.50)];
            [s2 addCurveToPoint:CGPointMake(w * 0.16, h * 0.07)
                  controlPoint1:CGPointMake(w * 0.36, h * 0.38)
                  controlPoint2:CGPointMake(w * 0.24, h * 0.22)];
            [s2 closePath];
            [s2 fill];

            UIBezierPath *s3 = [UIBezierPath bezierPath];
            [s3 moveToPoint:CGPointMake(w * 0.32, h * 0.10)];
            [s3 addCurveToPoint:CGPointMake(w * 0.68, h * 0.40)
                  controlPoint1:CGPointMake(w * 0.46, h * 0.20)
                  controlPoint2:CGPointMake(w * 0.58, h * 0.30)];
            [s3 addLineToPoint:CGPointMake(w * 0.64, h * 0.44)];
            [s3 addCurveToPoint:CGPointMake(w * 0.93, h * 0.76)
                  controlPoint1:CGPointMake(w * 0.76, h * 0.56)
                  controlPoint2:CGPointMake(w * 0.86, h * 0.66)];
            [s3 addCurveToPoint:CGPointMake(w * 0.57, h * 0.47)
                  controlPoint1:CGPointMake(w * 0.78, h * 0.64)
                  controlPoint2:CGPointMake(w * 0.67, h * 0.56)];
            [s3 addLineToPoint:CGPointMake(w * 0.60, h * 0.42)];
            [s3 addCurveToPoint:CGPointMake(w * 0.32, h * 0.10)
                  controlPoint1:CGPointMake(w * 0.48, h * 0.31)
                  controlPoint2:CGPointMake(w * 0.39, h * 0.20)];
            [s3 closePath];
            [s3 fill];
        } else if ([identifier isEqualToString:@"nova.glass.orb"]) {
            UIBezierPath *ring = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r * 0.90 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
            ring.lineWidth = MAX(1.2, box * 0.065);
            [ring stroke];

            UIBezierPath *crescent = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r * 0.64 startAngle:M_PI * 1.12 endAngle:M_PI * 1.72 clockwise:YES];
            crescent.lineWidth = MAX(1.8, box * 0.095);
            crescent.lineCapStyle = kCGLineCapRound;
            [crescent stroke];

            UIBezierPath *caustic = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r * 0.66 startAngle:M_PI * 0.15 endAngle:M_PI * 0.52 clockwise:YES];
            caustic.lineWidth = MAX(1.0, box * 0.05);
            caustic.lineCapStyle = kCGLineCapRound;
            [caustic stroke];

            UIBezierPath *spark = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx - r * 0.22, cy - r * 0.48) radius:r * 0.09 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
            [spark fill];
        } else if ([identifier isEqualToString:@"nova.neon.ring"]) {
            for (int seg = 0; seg < 2; seg++) {
                CGFloat startA = seg * M_PI + 0.28;
                CGFloat endA = startA + M_PI - 0.56;
                UIBezierPath *arc = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r * 0.92 startAngle:startA endAngle:endA clockwise:YES];
                arc.lineWidth = MAX(1.6, box * 0.08);
                arc.lineCapStyle = kCGLineCapRound;
                [arc stroke];
            }
            UIBezierPath *innerRing = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r * 0.56 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
            innerRing.lineWidth = MAX(1.1, box * 0.05);
            [innerRing stroke];

            UIBezierPath *diamond = [UIBezierPath bezierPath];
            CGFloat dr = r * 0.28;
            [diamond moveToPoint:CGPointMake(cx, cy - dr)];
            [diamond addLineToPoint:CGPointMake(cx + dr, cy)];
            [diamond addLineToPoint:CGPointMake(cx, cy + dr)];
            [diamond addLineToPoint:CGPointMake(cx - dr, cy)];
            [diamond closePath];
            [diamond fill];
        } else if ([identifier isEqualToString:@"nova.minimal.core"]) {
            UIBezierPath *star = [UIBezierPath bezierPath];
            CGFloat sr = r * 0.92;
            CGFloat ctrl = r * 0.18;
            [star moveToPoint:CGPointMake(cx, cy - sr)];
            [star addQuadCurveToPoint:CGPointMake(cx + sr, cy) controlPoint:CGPointMake(cx + ctrl, cy - ctrl)];
            [star addQuadCurveToPoint:CGPointMake(cx, cy + sr) controlPoint:CGPointMake(cx + ctrl, cy + ctrl)];
            [star addQuadCurveToPoint:CGPointMake(cx - sr, cy) controlPoint:CGPointMake(cx - ctrl, cy + ctrl)];
            [star addQuadCurveToPoint:CGPointMake(cx, cy - sr) controlPoint:CGPointMake(cx - ctrl, cy - ctrl)];
            [star closePath];
            [star fill];

            for (int i = 0; i < 4; i++) {
                CGFloat a = (i * M_PI_2) + M_PI_4;
                CGPoint pt = CGPointMake(cx + cos(a) * r * 0.62, cy + sin(a) * r * 0.62);
                UIBezierPath *dot = [UIBezierPath bezierPathWithArcCenter:pt radius:r * 0.09 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
                [dot fill];
            }
        }
    }];
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

static UIImage *NovaPanelRenderTextIcon(NSString *text, CGFloat pointSize) {
    if (!text.length) return nil;
    NSString *clipped = text.length > 3 ? [text substringToIndex:3] : text;
    BOOL isASCII = [clipped canBeConvertedToEncoding:NSASCIIStringEncoding];
    CGFloat box = MAX(20.0, pointSize * 1.45);
    CGSize canvasSize = CGSizeMake(box, box);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:canvasSize];
    UIImage *rendered = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGFloat fontSize = clipped.length == 1 ? pointSize : (clipped.length == 2 ? pointSize * 0.78 : pointSize * 0.62);
        UIFont *font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightBold];
        NSDictionary *attrs = @{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: UIColor.whiteColor
        };
        CGSize textSize = [clipped sizeWithAttributes:attrs];
        CGRect drawRect = CGRectMake((canvasSize.width - textSize.width) / 2.0,
                                     (canvasSize.height - textSize.height) / 2.0,
                                     textSize.width,
                                     textSize.height);
        [clipped drawInRect:drawRect withAttributes:attrs];
    }];
    return [rendered imageWithRenderingMode:isASCII ? UIImageRenderingModeAlwaysTemplate : UIImageRenderingModeAlwaysOriginal];
}

static BOOL NovaPanelLooksLikeSymbolIdentifier(NSString *str) {
    if (!str.length) return NO;
    if (![str canBeConvertedToEncoding:NSASCIIStringEncoding]) return NO;
    if ([str containsString:@"."] || str.length > 4) return YES;
    return NO;
}

static UIImage *NovaPanelSymbol(NSString *primary, NSString *fallback, CGFloat pointSize) {
    NSString *trimmed = NovaPanelTrimmedString(primary);
    NSString *cacheKey = [NSString stringWithFormat:@"%@|%@|%.1f", trimmed, fallback ?: @"", pointSize];
    UIImage *cached = [NovaPanelIconCache() objectForKey:cacheKey];
    if (cached) return cached;

    CGFloat resolvedSize = pointSize > 0 ? pointSize : 16.0;
    UIImage *img = nil;
    if ([trimmed hasPrefix:@"nova."]) {
        img = NovaPanelDrawCustomVectorIcon(trimmed, resolvedSize);
    }
    if (!img && [fallback hasPrefix:@"nova."] && !trimmed.length) {
        img = NovaPanelDrawCustomVectorIcon(fallback, resolvedSize);
    }

    if (!img && @available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = pointSize > 0
            ? [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:UIFontWeightSemibold]
            : nil;
        if (trimmed.length > 0 && ![trimmed hasPrefix:@"nova."]) {
            img = config ? [UIImage systemImageNamed:trimmed withConfiguration:config] : [UIImage systemImageNamed:trimmed];
            if (!img && [trimmed hasSuffix:@".filled"]) {
                NSString *legacyName = [[trimmed substringToIndex:trimmed.length - 7] stringByAppendingString:@".fill"];
                img = config ? [UIImage systemImageNamed:legacyName withConfiguration:config] : [UIImage systemImageNamed:legacyName];
            }
            if (!img && !NovaPanelLooksLikeSymbolIdentifier(trimmed)) {
                img = NovaPanelRenderTextIcon(trimmed, resolvedSize);
            }
        }
        if (!img && fallback.length) {
            if ([fallback hasPrefix:@"nova."]) {
                img = NovaPanelDrawCustomVectorIcon(fallback, resolvedSize);
            } else {
                img = config ? [UIImage systemImageNamed:fallback withConfiguration:config] : [UIImage systemImageNamed:fallback];
            }
        }
        if (!img && trimmed.length > 0 && ![trimmed hasPrefix:@"nova."]) {
            img = NovaPanelRenderTextIcon(trimmed, resolvedSize);
        }
        if (!img) {
            img = NovaPanelDrawCustomVectorIcon(@"nova.sakura", resolvedSize) ?: (config ? [UIImage systemImageNamed:@"circle.fill" withConfiguration:config] : [UIImage systemImageNamed:@"circle.fill"]);
        }
    }
    if (img) {
        [NovaPanelIconCache() setObject:img forKey:cacheKey];
    }
    return img;
}

@interface NovaTouchScrollView : UIScrollView
@end

@implementation NovaTouchScrollView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.delaysContentTouches = NO;
        self.canCancelContentTouches = YES;
        self.alwaysBounceVertical = YES;
        self.directionalLockEnabled = YES;
        self.showsVerticalScrollIndicator = YES;
    }
    return self;
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if ([view isKindOfClass:UISlider.class]) {
        return NO;
    }
    return YES;
}
@end

@interface NovaModuleSwitch : UISwitch
@end

@implementation NovaModuleSwitch
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGRect expandedBounds = CGRectInset(self.bounds, -14.0, -10.0);
    return CGRectContainsPoint(expandedBounds, point);
}
@end

@interface NovaChoiceButton : UIButton
@property (nonatomic, assign) BOOL verticalStackLayout;
@end

@implementation NovaChoiceButton
- (CGRect)imageRectForContentRect:(CGRect)contentRect {
    CGFloat w = contentRect.size.width;
    CGFloat h = contentRect.size.height;
    if (!NovaPanelIsValidDimension(w) || !NovaPanelIsValidDimension(h)) return CGRectZero;
    if (self.verticalStackLayout) {
        CGFloat iconSize = MIN(16.0, MAX(12.0, h * 0.32));
        return CGRectMake((w - iconSize) / 2.0, 7.0, iconSize, iconSize);
    } else {
        CGFloat iconSize = 11.0;
        CGFloat leftPad = MAX(3.0, (w - 40.0) * 0.35);
        return CGRectMake(leftPad, (h - iconSize) / 2.0, iconSize, iconSize);
    }
}

- (CGRect)titleRectForContentRect:(CGRect)contentRect {
    CGFloat w = contentRect.size.width;
    CGFloat h = contentRect.size.height;
    if (!NovaPanelIsValidDimension(w) || !NovaPanelIsValidDimension(h)) return CGRectZero;
    if (self.verticalStackLayout) {
        return CGRectMake(2.0, 9.0, MAX(0.0, w - 4.0), MAX(0.0, h - 11.0));
    } else {
        CGFloat iconSize = 11.0;
        CGFloat leftPad = MAX(3.0, (w - 40.0) * 0.35);
        CGFloat titleX = MAX(0.0, leftPad + iconSize - 2.0);
        return CGRectMake(titleX, 0.0, MAX(0.0, w - titleX - 2.0), h);
    }
}
@end

@interface NovaControlPanel () <UIGestureRecognizerDelegate, UITextFieldDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>
@property (nonatomic, copy) NSString *panelTitle;
@property (nonatomic, copy) NSString *headerIconName;
@property (nonatomic, copy) NSArray<NSDictionary *> *modules;
@property (nonatomic, strong) NSMutableArray<NSString *> *submenuStack;
@property (nonatomic, copy) NSString *searchKeyword;
@property (nonatomic, assign) BOOL photoPickerTargetIsHeader;

@property (nonatomic, strong) UIVisualEffectView *backdrop;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIVisualEffectView *cardBlurView;
@property (nonatomic, strong) CAGradientLayer *cardGlassSheenLayer;
@property (nonatomic, strong) UIView *headerIcon;
@property (nonatomic, strong) UIImageView *headerBrandImageView;
@property (nonatomic, strong) UIImageView *headerCustomPhotoView;
@property (nonatomic, strong) UILabel *heading;
@property (nonatomic, strong) UILabel *subheading;
@property (nonatomic, strong) UIButton *settingsButton;
@property (nonatomic, strong) UIButton *closeButton;

@property (nonatomic, strong) UIView *statusPill;
@property (nonatomic, strong) UILabel *statusTextLabel;
@property (nonatomic, strong) UIButton *quickLogsButton;
@property (nonatomic, strong) UIButton *quickConfigButton;

@property (nonatomic, strong) UIView *searchContainer;
@property (nonatomic, strong) UIImageView *searchIconView;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *clearSearchButton;

@property (nonatomic, strong) UIView *sectionHeaderBar;
@property (nonatomic, strong) UIButton *submenuBackButton;
@property (nonatomic, strong) UILabel *sectionLabel;
@property (nonatomic, strong) UILabel *sectionCountLabel;

@property (nonatomic, strong) UIStackView *moduleStack;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *themeHeader;
@property (nonatomic, strong) UILabel *themeLabel;
@property (nonatomic, strong) UILabel *themeHint;
@property (nonatomic, strong) UIStackView *themeStack;
@property (nonatomic, strong) UIView *accentLine;
@property (nonatomic, assign) NSInteger currentTheme;

@property (nonatomic, strong) UIScrollView *appearanceOverlay;
@property (nonatomic, strong) UIStackView *appearanceThemeStack;
@property (nonatomic, strong) UIStackView *headerIconStack;
@property (nonatomic, strong) UITextField *customHeaderIconField;
@property (nonatomic, strong) UIButton *applyHeaderIconButton;
@property (nonatomic, strong) UIButton *chooseHeaderPhotoButton;
@property (nonatomic, strong) UIStackView *entryStyleStack;
@property (nonatomic, strong) UIStackView *entryIconStack;
@property (nonatomic, strong) UITextField *customIconField;
@property (nonatomic, strong) UIButton *applyEntryIconButton;
@property (nonatomic, strong) UIButton *chooseEntryPhotoButton;
@property (nonatomic, strong) UISlider *opacitySlider;
@property (nonatomic, strong) UILabel *opacityValueLabel;

// Theme-Synced Modal & Toast Overlays
@property (nonatomic, strong) UIView *modalHostView;
@property (nonatomic, strong) UIView *modalCard;
@property (nonatomic, strong) UIVisualEffectView *modalBlurView;
@property (nonatomic, strong) CAGradientLayer *modalGlassSheenLayer;
@property (nonatomic, strong) UITextField *activeModalPromptField;
@property (nonatomic, copy, nullable) NovaUIAlertHandler activeAlertHandler;
@property (nonatomic, copy, nullable) NovaUIPromptHandler activePromptHandler;
@property (nonatomic, copy, nullable) NovaUISelectHandler activeSelectHandler;
@property (nonatomic, copy, nullable) NSArray<NSString *> *activeSelectOptions;
@property (nonatomic, copy, nullable) dispatch_block_t activeDetailPrimaryHandler;

@property (nonatomic, strong) UIView *toastBanner;
@property (nonatomic, strong) UIVisualEffectView *toastBlurView;
@property (nonatomic, strong) UIImageView *toastIconView;
@property (nonatomic, strong) UILabel *toastMessageLabel;
@property (nonatomic, assign) NSUInteger toastGeneration;

@property (nonatomic, assign) BOOL isDismissing;
@property (nonatomic, assign) NSUInteger animationGeneration;
@end

@implementation NovaControlPanel

+ (NSArray<NSString *> *)presetHeaderIconSymbols {
    return @[@"nova.sakura", @"nova.claw.slash", @"nova.minimal.core", @"crown.fill", @"bolt.fill"];
}

+ (NSArray<NSString *> *)presetEntryIconSymbols {
    return @[@"", @"nova.sakura", @"nova.claw.slash", @"crown.fill", @"flame.fill"];
}

- (instancetype)initWithFrame:(CGRect)frame {
    CGRect resolved = NovaPanelSanitizeFrame(frame);
    if ((self = [super initWithFrame:resolved])) {
        [self setupWithTitle:@"NOVA 控制中心" modules:@[]];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        if (!NovaPanelIsValidDimension(self.bounds.size.width) || !NovaPanelIsValidDimension(self.bounds.size.height)) {
            self.frame = NovaPanelSanitizeFrame(CGRectZero);
        }
        [self setupWithTitle:@"NOVA 控制中心" modules:@[]];
    }
    return self;
}

- (instancetype)initWithTitle:(NSString *)title modules:(NSArray<NSDictionary *> *)modules {
    CGRect initialFrame = NovaPanelSanitizeFrame(UIScreen.mainScreen.bounds);
    if ((self = [super initWithFrame:initialFrame])) {
        [self setupWithTitle:title modules:modules];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.cardGlassSheenLayer && self.cardBlurView) {
        self.cardGlassSheenLayer.frame = self.cardBlurView.bounds;
    }
    if (self.modalGlassSheenLayer && self.modalBlurView) {
        self.modalGlassSheenLayer.frame = self.modalBlurView.bounds;
    }
}

- (void)setupWithTitle:(NSString *)title modules:(NSArray<NSDictionary *> *)modules {
    if (_card) return;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    NSString *trimmedTitle = NovaPanelTrimmedString(title);
    _panelTitle = trimmedTitle.length > 0 ? [trimmedTitle copy] : @"NOVA 控制中心";
    NSString *savedHeaderIcon = NovaPanelTrimmedString([NSUserDefaults.standardUserDefaults stringForKey:@"NovaUI.headerIcon"]);
    if ([savedHeaderIcon isEqualToString:@"asterisk"] || !savedHeaderIcon.length) {
        savedHeaderIcon = @"nova.sakura";
    }
    _headerIconName = [savedHeaderIcon copy];
    _modules = [modules isKindOfClass:NSArray.class] ? [modules copy] : @[];
    _submenuStack = [NSMutableArray array];
    _searchKeyword = @"";
    _currentTheme = NovaPanelNormalizeTheme([NSUserDefaults.standardUserDefaults integerForKey:@"NovaUI.theme"]);
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.42];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    _backdrop = [[UIVisualEffectView alloc] initWithEffect:blur];
    _backdrop.translatesAutoresizingMaskIntoConstraints = NO;
    _backdrop.alpha = 0.72;
    [self addSubview:_backdrop];
    [NSLayoutConstraint activateConstraints:@[
        [_backdrop.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_backdrop.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_backdrop.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_backdrop.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];

    UITapGestureRecognizer *outside = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(outsideTap:)];
    outside.cancelsTouchesInView = NO;
    outside.delaysTouchesBegan = NO;
    outside.delaysTouchesEnded = NO;
    outside.delegate = self;
    [self addGestureRecognizer:outside];

    _card = [UIView new];
    _card.translatesAutoresizingMaskIntoConstraints = NO;
    _card.layer.cornerRadius = 30;
    _card.layer.cornerCurve = kCACornerCurveContinuous;
    _card.layer.borderWidth = 1;
    _card.layer.shadowColor = UIColor.blackColor.CGColor;
    _card.layer.shadowOpacity = 0.34;
    _card.layer.shadowRadius = 32;
    _card.layer.shadowOffset = CGSizeMake(0, 16);
    _card.clipsToBounds = NO;
    [self addSubview:_card];

    _cardBlurView = [[UIVisualEffectView alloc] initWithEffect:NovaPanelCreateLiquidGlassEffect(NO)];
    _cardBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardBlurView.userInteractionEnabled = NO;
    _cardBlurView.layer.cornerRadius = 30;
    _cardBlurView.layer.cornerCurve = kCACornerCurveContinuous;
    _cardBlurView.clipsToBounds = YES;
    [_card addSubview:_cardBlurView];
    [NSLayoutConstraint activateConstraints:@[
        [_cardBlurView.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],
        [_cardBlurView.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor],
        [_cardBlurView.topAnchor constraintEqualToAnchor:_card.topAnchor],
        [_cardBlurView.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor]
    ]];

    _cardGlassSheenLayer = [CAGradientLayer layer];
    _cardGlassSheenLayer.startPoint = CGPointMake(0.0, 0.0);
    _cardGlassSheenLayer.endPoint = CGPointMake(1.0, 1.0);
    _cardGlassSheenLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.55].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.14].CGColor,
        (id)[UIColor colorWithRed:0.82 green:0.93 blue:1.0 alpha:0.06].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.38].CGColor
    ];
    _cardGlassSheenLayer.locations = @[@0.0, @0.28, @0.68, @1.0];
    [_cardBlurView.contentView.layer addSublayer:_cardGlassSheenLayer];

    CGFloat maxWidth = 390;
    NSLayoutConstraint *cardWidthMax = [_card.widthAnchor constraintLessThanOrEqualToConstant:maxWidth];
    cardWidthMax.priority = UILayoutPriorityRequired - 1;
    NSLayoutConstraint *cardWidthFill = [_card.widthAnchor constraintEqualToAnchor:self.widthAnchor constant:-32];
    cardWidthFill.priority = UILayoutPriorityDefaultHigh;

    NSLayoutConstraint *cardHeightMax = [_card.heightAnchor constraintLessThanOrEqualToAnchor:self.heightAnchor constant:-44];
    cardHeightMax.priority = UILayoutPriorityRequired - 1;
    NSLayoutConstraint *cardHeightMin = [_card.heightAnchor constraintGreaterThanOrEqualToConstant:380];
    cardHeightMin.priority = UILayoutPriorityDefaultHigh + 100;
    NSLayoutConstraint *cardHeightPref = [_card.heightAnchor constraintEqualToConstant:540];
    cardHeightPref.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [_card.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_card.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        cardWidthMax,
        cardWidthFill,
        cardHeightMax,
        cardHeightMin,
        cardHeightPref
    ]];

    _accentLine = [UIView new];
    _accentLine.translatesAutoresizingMaskIntoConstraints = NO;
    _accentLine.layer.cornerRadius = 2;
    [_card addSubview:_accentLine];
    [NSLayoutConstraint activateConstraints:@[
        [_accentLine.topAnchor constraintEqualToAnchor:_card.topAnchor constant:7],
        [_accentLine.centerXAnchor constraintEqualToAnchor:_card.centerXAnchor],
        [_accentLine.widthAnchor constraintEqualToConstant:40],
        [_accentLine.heightAnchor constraintEqualToConstant:4]
    ]];

    _headerIcon = [UIView new];
    _headerIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _headerIcon.layer.cornerRadius = 14;
    _headerIcon.layer.cornerCurve = kCACornerCurveContinuous;
    _headerIcon.layer.borderWidth = 1.0;
    _headerIcon.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.32].CGColor;
    _headerIcon.clipsToBounds = YES;
    [_card addSubview:_headerIcon];

    // Full-bleed custom photo view inside _headerIcon (fixes small icon sizing when user chooses an album photo!)
    _headerCustomPhotoView = [UIImageView new];
    _headerCustomPhotoView.translatesAutoresizingMaskIntoConstraints = NO;
    _headerCustomPhotoView.contentMode = UIViewContentModeScaleAspectFill;
    _headerCustomPhotoView.clipsToBounds = YES;
    _headerCustomPhotoView.layer.cornerRadius = 12.5;
    _headerCustomPhotoView.layer.cornerCurve = kCACornerCurveContinuous;
    _headerCustomPhotoView.hidden = YES;
    [_headerIcon addSubview:_headerCustomPhotoView];

    UIImageView *brand = [[UIImageView alloc] initWithImage:nil];
    brand.translatesAutoresizingMaskIntoConstraints = NO;
    brand.tintColor = UIColor.whiteColor;
    brand.contentMode = UIViewContentModeScaleAspectFit;
    [_headerIcon addSubview:brand];
    _headerBrandImageView = brand;

    [NSLayoutConstraint activateConstraints:@[
        [_headerIcon.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:20],
        [_headerIcon.topAnchor constraintEqualToAnchor:_card.topAnchor constant:22],
        [_headerIcon.widthAnchor constraintEqualToConstant:42],
        [_headerIcon.heightAnchor constraintEqualToConstant:42],
        [_headerCustomPhotoView.leadingAnchor constraintEqualToAnchor:_headerIcon.leadingAnchor constant:1.5],
        [_headerCustomPhotoView.trailingAnchor constraintEqualToAnchor:_headerIcon.trailingAnchor constant:-1.5],
        [_headerCustomPhotoView.topAnchor constraintEqualToAnchor:_headerIcon.topAnchor constant:1.5],
        [_headerCustomPhotoView.bottomAnchor constraintEqualToAnchor:_headerIcon.bottomAnchor constant:-1.5],
        [brand.centerXAnchor constraintEqualToAnchor:_headerIcon.centerXAnchor],
        [brand.centerYAnchor constraintEqualToAnchor:_headerIcon.centerYAnchor],
        [brand.widthAnchor constraintEqualToConstant:22],
        [brand.heightAnchor constraintEqualToConstant:22]
    ]];
    [self refreshHeaderIconViews];

    _heading = [UILabel new];
    _heading.translatesAutoresizingMaskIntoConstraints = NO;
    _heading.text = _panelTitle;
    _heading.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [_card addSubview:_heading];

    _subheading = [UILabel new];
    _subheading.translatesAutoresizingMaskIntoConstraints = NO;
    _subheading.text = NovaPanelIsIOS26OrLater() ? @"UNIVERSAL PLUGIN ENGINE · LIQUID GLASS" : @"UNIVERSAL PLUGIN ENGINE · v1.2";
    _subheading.font = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];
    _subheading.adjustsFontSizeToFitWidth = YES;
    [_card addSubview:_subheading];

    UIButton *settings = [UIButton buttonWithType:UIButtonTypeSystem];
    settings.translatesAutoresizingMaskIntoConstraints = NO;
    settings.layer.cornerRadius = 15;
    [settings setImage:NovaPanelSymbol(@"slider.horizontal.3", @"gearshape", 13) forState:UIControlStateNormal];
    settings.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.10];
    [settings addTarget:self action:@selector(toggleAppearanceSettings) forControlEvents:UIControlEventTouchUpInside];
    [_card addSubview:settings];
    _settingsButton = settings;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    close.layer.cornerRadius = 15;
    [close setImage:NovaPanelSymbol(@"xmark", @"multiply", 13) forState:UIControlStateNormal];
    close.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.10];
    [close addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [_card addSubview:close];
    _closeButton = close;

    [NSLayoutConstraint activateConstraints:@[
        [_heading.leadingAnchor constraintEqualToAnchor:_headerIcon.trailingAnchor constant:12],
        [_heading.trailingAnchor constraintLessThanOrEqualToAnchor:settings.leadingAnchor constant:-8],
        [_heading.topAnchor constraintEqualToAnchor:_headerIcon.topAnchor constant:2],
        [_subheading.leadingAnchor constraintEqualToAnchor:_heading.leadingAnchor],
        [_subheading.trailingAnchor constraintEqualToAnchor:_heading.trailingAnchor],
        [_subheading.topAnchor constraintEqualToAnchor:_heading.bottomAnchor constant:3],
        [close.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-18],
        [close.centerYAnchor constraintEqualToAnchor:_headerIcon.centerYAnchor],
        [settings.trailingAnchor constraintEqualToAnchor:close.leadingAnchor constant:-7],
        [settings.centerYAnchor constraintEqualToAnchor:_headerIcon.centerYAnchor],
        [settings.widthAnchor constraintEqualToConstant:30],
        [settings.heightAnchor constraintEqualToConstant:30],
        [close.widthAnchor constraintEqualToConstant:30],
        [close.heightAnchor constraintEqualToConstant:30]
    ]];

    // Status pill + Universal Quick Utility Buttons (运行日志 & 配置中心)
    UIView *statusPill = [UIView new];
    statusPill.translatesAutoresizingMaskIntoConstraints = NO;
    statusPill.layer.cornerRadius = 11;
    statusPill.backgroundColor = [UIColor colorWithRed:0.18 green:0.80 blue:0.55 alpha:0.14];
    [_card addSubview:statusPill];
    _statusPill = statusPill;

    UIView *statusDot = [UIView new];
    statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    statusDot.backgroundColor = [UIColor colorWithRed:0.16 green:0.82 blue:0.54 alpha:1];
    statusDot.layer.cornerRadius = 3;
    [statusPill addSubview:statusDot];

    UILabel *statusText = [UILabel new];
    statusText.translatesAutoresizingMaskIntoConstraints = NO;
    statusText.text = @"运行中";
    statusText.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    statusText.textColor = [UIColor colorWithRed:0.14 green:0.76 blue:0.50 alpha:1];
    [statusPill addSubview:statusText];
    _statusTextLabel = statusText;

    _quickConfigButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _quickConfigButton.translatesAutoresizingMaskIntoConstraints = NO;
    _quickConfigButton.layer.cornerRadius = 11;
    _quickConfigButton.layer.borderWidth = 0.8;
    _quickConfigButton.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    [_quickConfigButton setImage:NovaPanelSymbol(@"archivebox.fill", @"folder.fill", 10) forState:UIControlStateNormal];
    [_quickConfigButton setTitle:@" 配置" forState:UIControlStateNormal];
    [_quickConfigButton addTarget:self action:@selector(openConfigCenterInspector) forControlEvents:UIControlEventTouchUpInside];
    [_card addSubview:_quickConfigButton];

    _quickLogsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _quickLogsButton.translatesAutoresizingMaskIntoConstraints = NO;
    _quickLogsButton.layer.cornerRadius = 11;
    _quickLogsButton.layer.borderWidth = 0.8;
    _quickLogsButton.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    [_quickLogsButton setImage:NovaPanelSymbol(@"doc.text.magnifyingglass", @"list.bullet", 10) forState:UIControlStateNormal];
    [_quickLogsButton setTitle:@" 日志" forState:UIControlStateNormal];
    [_quickLogsButton addTarget:self action:@selector(openConsoleLogInspector) forControlEvents:UIControlEventTouchUpInside];
    [_card addSubview:_quickLogsButton];

    [NSLayoutConstraint activateConstraints:@[
        [statusPill.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:20],
        [statusPill.topAnchor constraintEqualToAnchor:_headerIcon.bottomAnchor constant:12],
        [statusPill.heightAnchor constraintEqualToConstant:24],
        [statusDot.leadingAnchor constraintEqualToAnchor:statusPill.leadingAnchor constant:9],
        [statusDot.centerYAnchor constraintEqualToAnchor:statusPill.centerYAnchor],
        [statusDot.widthAnchor constraintEqualToConstant:6],
        [statusDot.heightAnchor constraintEqualToConstant:6],
        [statusText.leadingAnchor constraintEqualToAnchor:statusDot.trailingAnchor constant:6],
        [statusText.trailingAnchor constraintEqualToAnchor:statusPill.trailingAnchor constant:-9],
        [statusText.centerYAnchor constraintEqualToAnchor:statusPill.centerYAnchor],
        [_quickConfigButton.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-18],
        [_quickConfigButton.centerYAnchor constraintEqualToAnchor:statusPill.centerYAnchor],
        [_quickConfigButton.widthAnchor constraintEqualToConstant:54],
        [_quickConfigButton.heightAnchor constraintEqualToConstant:24],
        [_quickLogsButton.trailingAnchor constraintEqualToAnchor:_quickConfigButton.leadingAnchor constant:-6],
        [_quickLogsButton.centerYAnchor constraintEqualToAnchor:statusPill.centerYAnchor],
        [_quickLogsButton.widthAnchor constraintEqualToConstant:54],
        [_quickLogsButton.heightAnchor constraintEqualToConstant:24]
    ]];

    // Search & Filter Bar
    _searchContainer = [UIView new];
    _searchContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _searchContainer.layer.cornerRadius = 12;
    _searchContainer.layer.cornerCurve = kCACornerCurveContinuous;
    _searchContainer.layer.borderWidth = 0.8;
    [_card addSubview:_searchContainer];

    _searchIconView = [[UIImageView alloc] initWithImage:NovaPanelSymbol(@"magnifyingglass", @"circle", 12)];
    _searchIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _searchIconView.contentMode = UIViewContentModeScaleAspectFit;
    [_searchContainer addSubview:_searchIconView];

    _searchField = [UITextField new];
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.placeholder = @"搜索功能模块、二级菜单或关键词...";
    _searchField.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    _searchField.returnKeyType = UIReturnKeySearch;
    _searchField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _searchField.autocorrectionType = UITextAutocorrectionTypeNo;
    _searchField.delegate = self;
    [_searchField addTarget:self action:@selector(searchFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_searchContainer addSubview:_searchField];

    _clearSearchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _clearSearchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_clearSearchButton setImage:NovaPanelSymbol(@"xmark.circle.fill", @"multiply", 12) forState:UIControlStateNormal];
    _clearSearchButton.hidden = YES;
    [_clearSearchButton addTarget:self action:@selector(clearSearchTapped) forControlEvents:UIControlEventTouchUpInside];
    [_searchContainer addSubview:_clearSearchButton];

    [NSLayoutConstraint activateConstraints:@[
        [_searchContainer.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:16],
        [_searchContainer.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-16],
        [_searchContainer.topAnchor constraintEqualToAnchor:statusPill.bottomAnchor constant:10],
        [_searchContainer.heightAnchor constraintEqualToConstant:32],
        [_searchIconView.leadingAnchor constraintEqualToAnchor:_searchContainer.leadingAnchor constant:10],
        [_searchIconView.centerYAnchor constraintEqualToAnchor:_searchContainer.centerYAnchor],
        [_searchIconView.widthAnchor constraintEqualToConstant:14],
        [_searchIconView.heightAnchor constraintEqualToConstant:14],
        [_searchField.leadingAnchor constraintEqualToAnchor:_searchIconView.trailingAnchor constant:7],
        [_searchField.trailingAnchor constraintEqualToAnchor:_clearSearchButton.leadingAnchor constant:-4],
        [_searchField.topAnchor constraintEqualToAnchor:_searchContainer.topAnchor],
        [_searchField.bottomAnchor constraintEqualToAnchor:_searchContainer.bottomAnchor],
        [_clearSearchButton.trailingAnchor constraintEqualToAnchor:_searchContainer.trailingAnchor constant:-8],
        [_clearSearchButton.centerYAnchor constraintEqualToAnchor:_searchContainer.centerYAnchor],
        [_clearSearchButton.widthAnchor constraintEqualToConstant:20],
        [_clearSearchButton.heightAnchor constraintEqualToConstant:20]
    ]];

    // Section / Submenu Breadcrumb Header Bar
    _sectionHeaderBar = [UIView new];
    _sectionHeaderBar.translatesAutoresizingMaskIntoConstraints = NO;
    [_card addSubview:_sectionHeaderBar];

    _submenuBackButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _submenuBackButton.translatesAutoresizingMaskIntoConstraints = NO;
    _submenuBackButton.layer.cornerRadius = 9;
    _submenuBackButton.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    [_submenuBackButton setImage:NovaPanelSymbol(@"chevron.left", @"arrow.left", 10) forState:UIControlStateNormal];
    [_submenuBackButton setTitle:@" 返回上级" forState:UIControlStateNormal];
    _submenuBackButton.hidden = YES;
    [_submenuBackButton addTarget:self action:@selector(popSubmenu) forControlEvents:UIControlEventTouchUpInside];
    [_sectionHeaderBar addSubview:_submenuBackButton];

    _sectionLabel = [UILabel new];
    _sectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _sectionLabel.text = @"功能模块";
    _sectionLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [_sectionHeaderBar addSubview:_sectionLabel];

    _sectionCountLabel = [UILabel new];
    _sectionCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _sectionCountLabel.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightSemibold];
    _sectionCountLabel.textAlignment = NSTextAlignmentRight;
    [_sectionHeaderBar addSubview:_sectionCountLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_sectionHeaderBar.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:20],
        [_sectionHeaderBar.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-20],
        [_sectionHeaderBar.topAnchor constraintEqualToAnchor:_searchContainer.bottomAnchor constant:10],
        [_sectionHeaderBar.heightAnchor constraintEqualToConstant:22],
        [_submenuBackButton.leadingAnchor constraintEqualToAnchor:_sectionHeaderBar.leadingAnchor],
        [_submenuBackButton.centerYAnchor constraintEqualToAnchor:_sectionHeaderBar.centerYAnchor],
        [_submenuBackButton.heightAnchor constraintEqualToConstant:22],
        [_sectionLabel.leadingAnchor constraintEqualToAnchor:_sectionHeaderBar.leadingAnchor],
        [_sectionLabel.centerYAnchor constraintEqualToAnchor:_sectionHeaderBar.centerYAnchor],
        [_sectionCountLabel.trailingAnchor constraintEqualToAnchor:_sectionHeaderBar.trailingAnchor],
        [_sectionCountLabel.centerYAnchor constraintEqualToAnchor:_sectionHeaderBar.centerYAnchor]
    ]];

    _scrollView = [NovaTouchScrollView new];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.contentInset = UIEdgeInsetsMake(2, 0, 8, 0);
    [_card addSubview:_scrollView];

    _moduleStack = [UIStackView new];
    _moduleStack.translatesAutoresizingMaskIntoConstraints = NO;
    _moduleStack.axis = UILayoutConstraintAxisVertical;
    _moduleStack.spacing = 8;
    [_scrollView addSubview:_moduleStack];

    UIView *themeHeader = [UIView new];
    themeHeader.translatesAutoresizingMaskIntoConstraints = NO;
    [_card addSubview:themeHeader];
    _themeHeader = themeHeader;
    UITapGestureRecognizer *appearanceTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleAppearanceSettings)];
    [themeHeader addGestureRecognizer:appearanceTap];

    UILabel *themeLabel = [UILabel new];
    themeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    themeLabel.text = @"外观与风格";
    themeLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [themeHeader addSubview:themeLabel];
    _themeLabel = themeLabel;

    UILabel *themeHint = [UILabel new];
    themeHint.translatesAutoresizingMaskIntoConstraints = NO;
    themeHint.text = @"主题 · 相册图标 · 液态玻璃 ›";
    themeHint.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    [themeHeader addSubview:themeHint];
    _themeHint = themeHint;

    _themeStack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    _themeStack.translatesAutoresizingMaskIntoConstraints = NO;
    _themeStack.axis = UILayoutConstraintAxisHorizontal;
    _themeStack.hidden = YES;
    _themeStack.distribution = UIStackViewDistributionFillEqually;
    _themeStack.spacing = 7;
    [_card addSubview:_themeStack];
    NSArray *names = @[@"暗粉", @"浅色", @"玻璃", @"极简", @"霓虹"];
    NSArray *symbols = @[@"moon.stars.fill", @"sun.max.fill", @"nova.glass.orb", @"circle.lefthalf.filled", @"bolt.fill"];
    NSArray *fallbacks = @[@"moon.fill", @"sun.max.fill", @"drop.triangle.fill", @"circle.lefthalf.fill", @"bolt.fill"];
    for (NSInteger i = 0; i < names.count; i++) {
        NovaChoiceButton *themeButton = [NovaChoiceButton buttonWithType:UIButtonTypeSystem];
        themeButton.verticalStackLayout = NO;
        themeButton.tag = i;
        themeButton.layer.cornerRadius = 12;
        themeButton.layer.borderWidth = 1;
        themeButton.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        themeButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        themeButton.titleLabel.minimumScaleFactor = 0.75;
        [themeButton setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
        [themeButton setImage:NovaPanelSymbol(symbols[i], fallbacks[i], 11) forState:UIControlStateNormal];
        [themeButton setTitle:[@"  " stringByAppendingString:names[i]] forState:UIControlStateNormal];
        [themeButton addTarget:self action:@selector(themeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_themeStack addArrangedSubview:themeButton];
    }

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:_sectionHeaderBar.bottomAnchor constant:6],
        [_scrollView.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:0],
        [_scrollView.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:0],
        [_scrollView.bottomAnchor constraintEqualToAnchor:themeHeader.topAnchor constant:-8],
        [_moduleStack.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor],
        [_moduleStack.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor constant:16],
        [_moduleStack.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor constant:-16],
        [_moduleStack.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor],
        [_moduleStack.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor constant:-32],
        [themeHeader.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:20],
        [themeHeader.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-20],
        [themeHeader.bottomAnchor constraintEqualToAnchor:_themeStack.topAnchor constant:-8],
        [themeHeader.heightAnchor constraintEqualToConstant:24],
        [themeLabel.leadingAnchor constraintEqualToAnchor:themeHeader.leadingAnchor],
        [themeLabel.centerYAnchor constraintEqualToAnchor:themeHeader.centerYAnchor],
        [themeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:themeHint.leadingAnchor constant:-8],
        [themeHint.trailingAnchor constraintEqualToAnchor:themeHeader.trailingAnchor],
        [themeHint.centerYAnchor constraintEqualToAnchor:themeHeader.centerYAnchor],
        [_themeStack.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:16],
        [_themeStack.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-16],
        [_themeStack.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-14],
        [_themeStack.heightAnchor constraintEqualToConstant:0]
    ]];

    [self buildAppearanceOverlay];
    [self buildModalAndToastOverlays];
    [self rebuildRows];
    [self applyTheme:_currentTheme];
}

#pragma mark - Header Icon & System Photo Library Picker

- (void)refreshHeaderIconViews {
    NSData *customData = [NSUserDefaults.standardUserDefaults dataForKey:@"NovaUI.headerCustomImageData"];
    if (customData.length > 0 && [self.headerIconName isEqualToString:@"__custom_image__"]) {
        UIImage *raw = [UIImage imageWithData:customData];
        if (raw) {
            UIImage *cropped = NovaPanelCenterCropSquareImage(raw, 84.0);
            self.headerCustomPhotoView.image = cropped ?: raw;
            self.headerCustomPhotoView.hidden = NO;
            self.headerBrandImageView.hidden = YES;
            return;
        }
    }
    self.headerCustomPhotoView.hidden = YES;
    self.headerCustomPhotoView.image = nil;
    self.headerBrandImageView.hidden = NO;
    NSString *effective = (!self.headerIconName.length || [self.headerIconName isEqualToString:@"asterisk"]) ? @"nova.sakura" : self.headerIconName;
    self.headerBrandImageView.image = NovaPanelSymbol(effective, @"nova.sakura", 18);
}

- (void)buildAppearanceOverlay {
    self.appearanceOverlay = [NovaTouchScrollView new];
    self.appearanceOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.appearanceOverlay.hidden = YES;
    self.appearanceOverlay.showsVerticalScrollIndicator = YES;
    self.appearanceOverlay.clipsToBounds = YES;
    self.appearanceOverlay.layer.cornerRadius = 24;
    self.appearanceOverlay.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    [self.card addSubview:self.appearanceOverlay];

    UITapGestureRecognizer *dismissKeyboardTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissAppearanceKeyboard)];
    dismissKeyboardTap.cancelsTouchesInView = NO;
    dismissKeyboardTap.delegate = self;
    [self.appearanceOverlay addGestureRecognizer:dismissKeyboardTap];

    UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
    back.translatesAutoresizingMaskIntoConstraints = NO;
    [back setImage:NovaPanelSymbol(@"chevron.left", @"arrow.left", 12) forState:UIControlStateNormal];
    [back setTitle:@"  返回控制面板" forState:UIControlStateNormal];
    back.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    back.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [back addTarget:self action:@selector(toggleAppearanceSettings) forControlEvents:UIControlEventTouchUpInside];
    [self.appearanceOverlay addSubview:back];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"外观与风格";
    title.font = [UIFont systemFontOfSize:21 weight:UIFontWeightBold];
    [self.appearanceOverlay addSubview:title];
    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = NovaPanelIsIOS26OrLater()
        ? @"已启用 iOS 26+ 液态玻璃 · 支持直调系统相册选图"
        : @"自定义面板主题、相册图标与悬浮球样式";
    subtitle.font = [UIFont systemFontOfSize:11];
    [self.appearanceOverlay addSubview:subtitle];

    // 1. 面板主题
    UILabel *themeTitle = [UILabel new];
    themeTitle.translatesAutoresizingMaskIntoConstraints = NO;
    themeTitle.text = @"面板主题（二级菜单与弹窗自动同步）";
    themeTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [self.appearanceOverlay addSubview:themeTitle];
    self.appearanceThemeStack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    self.appearanceThemeStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.appearanceThemeStack.axis = UILayoutConstraintAxisHorizontal;
    self.appearanceThemeStack.distribution = UIStackViewDistributionFillEqually;
    self.appearanceThemeStack.spacing = 7;
    [self.appearanceOverlay addSubview:self.appearanceThemeStack];
    NSArray *names = @[@"暗粉", @"浅色", @"玻璃", @"极简", @"霓虹"];
    NSArray *symbols = @[@"moon.stars.fill", @"sun.max.fill", @"nova.glass.orb", @"circle.lefthalf.filled", @"bolt.fill"];
    NSArray *fallbacks = @[@"moon.fill", @"sun.max.fill", @"drop.triangle.fill", @"circle.lefthalf.fill", @"bolt.fill"];
    for (NSInteger i = 0; i < names.count; i++) {
        NovaChoiceButton *b = [NovaChoiceButton buttonWithType:UIButtonTypeSystem];
        b.verticalStackLayout = NO;
        b.tag = i; b.layer.cornerRadius = 12; b.layer.borderWidth = 1;
        b.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        b.titleLabel.adjustsFontSizeToFitWidth = YES;
        b.titleLabel.minimumScaleFactor = 0.75;
        [b setImage:NovaPanelSymbol(symbols[i], fallbacks[i], 11) forState:UIControlStateNormal];
        [b setTitle:[@"  " stringByAppendingString:names[i]] forState:UIControlStateNormal];
        [b addTarget:self action:@selector(themeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.appearanceThemeStack addArrangedSubview:b];
    }

    // 2. 顶部插件图标更换与相册选图
    UILabel *headerIconTitle = [UILabel new];
    headerIconTitle.translatesAutoresizingMaskIntoConstraints = NO;
    headerIconTitle.text = @"顶部标题图标（预设 / 符号 / 相册选图）";
    headerIconTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [self.appearanceOverlay addSubview:headerIconTitle];
    self.headerIconStack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    self.headerIconStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerIconStack.axis = UILayoutConstraintAxisHorizontal;
    self.headerIconStack.distribution = UIStackViewDistributionFillEqually;
    self.headerIconStack.spacing = 7;
    [self.appearanceOverlay addSubview:self.headerIconStack];
    NSArray *headerIconNames = @[@"樱花", @"撕裂爪", @"星芒核", @"皇冠", @"闪电"];
    NSArray *headerIconSymbols = [NovaControlPanel presetHeaderIconSymbols];
    NSArray *headerIconFallbacks = @[@"nova.sakura", @"nova.claw.slash", @"nova.minimal.core", @"star.fill", @"bolt.fill"];
    for (NSInteger i = 0; i < headerIconNames.count; i++) {
        NovaChoiceButton *b = [NovaChoiceButton buttonWithType:UIButtonTypeSystem];
        b.verticalStackLayout = YES;
        b.tag = i; b.layer.cornerRadius = 12; b.layer.borderWidth = 1;
        b.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        b.titleLabel.adjustsFontSizeToFitWidth = YES;
        b.titleLabel.minimumScaleFactor = 0.75;
        [b setImage:NovaPanelSymbol(headerIconSymbols[i], headerIconFallbacks[i], 14) forState:UIControlStateNormal];
        [b setTitle:[@"\n" stringByAppendingString:headerIconNames[i]] forState:UIControlStateNormal];
        b.titleLabel.numberOfLines = 2;
        b.titleLabel.textAlignment = NSTextAlignmentCenter;
        [b addTarget:self action:@selector(headerIconButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.headerIconStack addArrangedSubview:b];
    }

    self.customHeaderIconField = [UITextField new];
    self.customHeaderIconField.translatesAutoresizingMaskIntoConstraints = NO;
    self.customHeaderIconField.placeholder = @"输入 Emoji(🌸)/文字/SF符号";
    self.customHeaderIconField.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.customHeaderIconField.layer.cornerRadius = 10;
    self.customHeaderIconField.layer.borderWidth = 1;
    self.customHeaderIconField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    self.customHeaderIconField.leftViewMode = UITextFieldViewModeAlways;
    self.customHeaderIconField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.customHeaderIconField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.customHeaderIconField.returnKeyType = UIReturnKeyDone;
    self.customHeaderIconField.delegate = self;
    if (_headerIconName.length > 0 && ![headerIconSymbols containsObject:_headerIconName] && ![_headerIconName isEqualToString:@"__custom_image__"]) {
        self.customHeaderIconField.text = _headerIconName;
    }
    [self.appearanceOverlay addSubview:self.customHeaderIconField];

    self.applyHeaderIconButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.applyHeaderIconButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.applyHeaderIconButton.layer.cornerRadius = 10;
    self.applyHeaderIconButton.layer.borderWidth = 1;
    self.applyHeaderIconButton.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    [self.applyHeaderIconButton setTitle:@"应用文字" forState:UIControlStateNormal];
    [self.applyHeaderIconButton addTarget:self action:@selector(applyCustomHeaderIconTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.appearanceOverlay addSubview:self.applyHeaderIconButton];

    self.chooseHeaderPhotoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.chooseHeaderPhotoButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.chooseHeaderPhotoButton.layer.cornerRadius = 10;
    self.chooseHeaderPhotoButton.layer.borderWidth = 1;
    self.chooseHeaderPhotoButton.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    [self.chooseHeaderPhotoButton setImage:NovaPanelSymbol(@"photo.on.rectangle", @"photo", 11) forState:UIControlStateNormal];
    [self.chooseHeaderPhotoButton setTitle:@" 相册选图" forState:UIControlStateNormal];
    [self.chooseHeaderPhotoButton addTarget:self action:@selector(chooseHeaderPhotoTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.appearanceOverlay addSubview:self.chooseHeaderPhotoButton];

    // 3. 悬浮入口样式
    UILabel *entryTitle = [UILabel new];
    entryTitle.translatesAutoresizingMaskIntoConstraints = NO;
    entryTitle.text = @"悬浮球底座材质样式";
    entryTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [self.appearanceOverlay addSubview:entryTitle];
    self.entryStyleStack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    self.entryStyleStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.entryStyleStack.axis = UILayoutConstraintAxisHorizontal;
    self.entryStyleStack.distribution = UIStackViewDistributionFillEqually;
    self.entryStyleStack.spacing = 7;
    [self.appearanceOverlay addSubview:self.entryStyleStack];
    NSArray *entryNames = @[@"樱花", @"玻璃球", @"霓虹环", @"极简", @"爪印"];
    NSArray *entrySymbols = @[@"nova.sakura", @"nova.glass.orb", @"nova.neon.ring", @"nova.minimal.core", @"nova.claw.slash"];
    for (NSInteger i = 0; i < entryNames.count; i++) {
        NovaChoiceButton *b = [NovaChoiceButton buttonWithType:UIButtonTypeSystem];
        b.verticalStackLayout = YES;
        b.tag = i; b.layer.cornerRadius = 12; b.layer.borderWidth = 1;
        b.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        b.titleLabel.adjustsFontSizeToFitWidth = YES;
        b.titleLabel.minimumScaleFactor = 0.75;
        [b setImage:NovaPanelSymbol(entrySymbols[i], entrySymbols[i], 14) forState:UIControlStateNormal];
        [b setTitle:[@"\n" stringByAppendingString:entryNames[i]] forState:UIControlStateNormal];
        b.titleLabel.numberOfLines = 2;
        b.titleLabel.textAlignment = NSTextAlignmentCenter;
        [b addTarget:self action:@selector(entryStyleButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.entryStyleStack addArrangedSubview:b];
    }

    // 4. 悬浮入口图标自定义与相册选图
    UILabel *entryIconTitle = [UILabel new];
    entryIconTitle.translatesAutoresizingMaskIntoConstraints = NO;
    entryIconTitle.text = @"悬浮球图标（预设 / 符号 / 相册选图）";
    entryIconTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [self.appearanceOverlay addSubview:entryIconTitle];
    self.entryIconStack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    self.entryIconStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.entryIconStack.axis = UILayoutConstraintAxisHorizontal;
    self.entryIconStack.distribution = UIStackViewDistributionFillEqually;
    self.entryIconStack.spacing = 7;
    [self.appearanceOverlay addSubview:self.entryIconStack];
    NSArray *customEntryNames = @[@"默认", @"樱花", @"撕裂爪", @"皇冠", @"火焰"];
    NSArray *customEntrySymbols = @[@"circle.dashed", @"nova.sakura", @"nova.claw.slash", @"crown.fill", @"flame.fill"];
    NSArray *customEntryFallbacks = @[@"circle", @"nova.sakura", @"nova.claw.slash", @"star.fill", @"heart.fill"];
    for (NSInteger i = 0; i < customEntryNames.count; i++) {
        NovaChoiceButton *b = [NovaChoiceButton buttonWithType:UIButtonTypeSystem];
        b.verticalStackLayout = YES;
        b.tag = i; b.layer.cornerRadius = 12; b.layer.borderWidth = 1;
        b.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        b.titleLabel.adjustsFontSizeToFitWidth = YES;
        b.titleLabel.minimumScaleFactor = 0.75;
        [b setImage:NovaPanelSymbol(customEntrySymbols[i], customEntryFallbacks[i], 14) forState:UIControlStateNormal];
        [b setTitle:[@"\n" stringByAppendingString:customEntryNames[i]] forState:UIControlStateNormal];
        b.titleLabel.numberOfLines = 2;
        b.titleLabel.textAlignment = NSTextAlignmentCenter;
        [b addTarget:self action:@selector(entryIconPresetButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.entryIconStack addArrangedSubview:b];
    }

    self.customIconField = [UITextField new];
    self.customIconField.translatesAutoresizingMaskIntoConstraints = NO;
    self.customIconField.placeholder = @"输入 Emoji(🌸)/文字/SF符号";
    self.customIconField.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.customIconField.layer.cornerRadius = 10;
    self.customIconField.layer.borderWidth = 1;
    self.customIconField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    self.customIconField.leftViewMode = UITextFieldViewModeAlways;
    self.customIconField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.customIconField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.customIconField.returnKeyType = UIReturnKeyDone;
    self.customIconField.delegate = self;
    NSString *savedCustomEntry = NovaPanelTrimmedString([NSUserDefaults.standardUserDefaults stringForKey:@"NovaUI.entryCustomIcon"]);
    if (savedCustomEntry.length > 0 && ![savedCustomEntry isEqualToString:@"__custom_image__"]) {
        self.customIconField.text = savedCustomEntry;
    }
    [self.appearanceOverlay addSubview:self.customIconField];

    self.applyEntryIconButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.applyEntryIconButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.applyEntryIconButton.layer.cornerRadius = 10;
    self.applyEntryIconButton.layer.borderWidth = 1;
    self.applyEntryIconButton.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    [self.applyEntryIconButton setTitle:@"应用文字" forState:UIControlStateNormal];
    [self.applyEntryIconButton addTarget:self action:@selector(applyCustomEntryIconTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.appearanceOverlay addSubview:self.applyEntryIconButton];

    self.chooseEntryPhotoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.chooseEntryPhotoButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.chooseEntryPhotoButton.layer.cornerRadius = 10;
    self.chooseEntryPhotoButton.layer.borderWidth = 1;
    self.chooseEntryPhotoButton.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    [self.chooseEntryPhotoButton setImage:NovaPanelSymbol(@"photo.on.rectangle", @"photo", 11) forState:UIControlStateNormal];
    [self.chooseEntryPhotoButton setTitle:@" 相册选图" forState:UIControlStateNormal];
    [self.chooseEntryPhotoButton addTarget:self action:@selector(chooseEntryPhotoTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.appearanceOverlay addSubview:self.chooseEntryPhotoButton];

    // 5. 悬浮入口透明度
    UILabel *opacityTitle = [UILabel new];
    opacityTitle.translatesAutoresizingMaskIntoConstraints = NO;
    opacityTitle.text = @"悬浮球不透明度";
    opacityTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [self.appearanceOverlay addSubview:opacityTitle];
    self.opacityValueLabel = [UILabel new];
    self.opacityValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    BOOL hasOpacity = ([NSUserDefaults.standardUserDefaults objectForKey:@"NovaUI.entryOpacity"] != nil);
    CGFloat rawOpacity = hasOpacity ? [NSUserDefaults.standardUserDefaults floatForKey:@"NovaUI.entryOpacity"] : 1.0;
    CGFloat savedOpacity = NovaPanelClampOpacity(rawOpacity);
    self.opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)round(savedOpacity * 100)];
    self.opacityValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
    self.opacityValueLabel.textAlignment = NSTextAlignmentRight;
    [self.appearanceOverlay addSubview:self.opacityValueLabel];
    self.opacitySlider = [UISlider new];
    self.opacitySlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.opacitySlider.minimumValue = 0.35; self.opacitySlider.maximumValue = 1.0;
    self.opacitySlider.value = savedOpacity;
    self.opacitySlider.minimumTrackTintColor = [UIColor colorWithRed:0.95 green:0.22 blue:0.68 alpha:1];
    [self.opacitySlider addTarget:self action:@selector(opacitySliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.appearanceOverlay addSubview:self.opacitySlider];

    UILayoutGuide *contentGuide = self.appearanceOverlay.contentLayoutGuide;
    UILayoutGuide *frameGuide = self.appearanceOverlay.frameLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [self.appearanceOverlay.topAnchor constraintEqualToAnchor:self.headerIcon.bottomAnchor constant:8],
        [self.appearanceOverlay.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:1],
        [self.appearanceOverlay.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-1],
        [self.appearanceOverlay.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-1],
        [contentGuide.widthAnchor constraintEqualToAnchor:frameGuide.widthAnchor],
        [back.topAnchor constraintEqualToAnchor:contentGuide.topAnchor constant:8],
        [back.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor constant:20],
        [back.heightAnchor constraintEqualToConstant:26],
        [title.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor constant:20],
        [title.topAnchor constraintEqualToAnchor:back.bottomAnchor constant:4],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:3],
        [themeTitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [themeTitle.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:12],
        [self.appearanceThemeStack.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor constant:16],
        [self.appearanceThemeStack.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor constant:-16],
        [self.appearanceThemeStack.topAnchor constraintEqualToAnchor:themeTitle.bottomAnchor constant:6],
        [self.appearanceThemeStack.heightAnchor constraintEqualToConstant:36],
        [headerIconTitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [headerIconTitle.topAnchor constraintEqualToAnchor:self.appearanceThemeStack.bottomAnchor constant:12],
        [self.headerIconStack.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor constant:16],
        [self.headerIconStack.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor constant:-16],
        [self.headerIconStack.topAnchor constraintEqualToAnchor:headerIconTitle.bottomAnchor constant:6],
        [self.headerIconStack.heightAnchor constraintEqualToConstant:50],
        [self.customHeaderIconField.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor constant:16],
        [self.customHeaderIconField.topAnchor constraintEqualToAnchor:self.headerIconStack.bottomAnchor constant:8],
        [self.customHeaderIconField.heightAnchor constraintEqualToConstant:32],
        [self.applyHeaderIconButton.leadingAnchor constraintEqualToAnchor:self.customHeaderIconField.trailingAnchor constant:6],
        [self.applyHeaderIconButton.centerYAnchor constraintEqualToAnchor:self.customHeaderIconField.centerYAnchor],
        [self.applyHeaderIconButton.widthAnchor constraintEqualToConstant:56],
        [self.applyHeaderIconButton.heightAnchor constraintEqualToConstant:32],
        [self.chooseHeaderPhotoButton.leadingAnchor constraintEqualToAnchor:self.applyHeaderIconButton.trailingAnchor constant:6],
        [self.chooseHeaderPhotoButton.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor constant:-16],
        [self.chooseHeaderPhotoButton.centerYAnchor constraintEqualToAnchor:self.customHeaderIconField.centerYAnchor],
        [self.chooseHeaderPhotoButton.widthAnchor constraintEqualToConstant:70],
        [self.chooseHeaderPhotoButton.heightAnchor constraintEqualToConstant:32],
        [entryTitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [entryTitle.topAnchor constraintEqualToAnchor:self.customHeaderIconField.bottomAnchor constant:12],
        [self.entryStyleStack.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor constant:16],
        [self.entryStyleStack.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor constant:-16],
        [self.entryStyleStack.topAnchor constraintEqualToAnchor:entryTitle.bottomAnchor constant:6],
        [self.entryStyleStack.heightAnchor constraintEqualToConstant:50],
        [entryIconTitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [entryIconTitle.topAnchor constraintEqualToAnchor:self.entryStyleStack.bottomAnchor constant:12],
        [self.entryIconStack.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor constant:16],
        [self.entryIconStack.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor constant:-16],
        [self.entryIconStack.topAnchor constraintEqualToAnchor:entryIconTitle.bottomAnchor constant:6],
        [self.entryIconStack.heightAnchor constraintEqualToConstant:50],
        [self.customIconField.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor constant:16],
        [self.customIconField.topAnchor constraintEqualToAnchor:self.entryIconStack.bottomAnchor constant:8],
        [self.customIconField.heightAnchor constraintEqualToConstant:32],
        [self.applyEntryIconButton.leadingAnchor constraintEqualToAnchor:self.customIconField.trailingAnchor constant:6],
        [self.applyEntryIconButton.centerYAnchor constraintEqualToAnchor:self.customIconField.centerYAnchor],
        [self.applyEntryIconButton.widthAnchor constraintEqualToConstant:56],
        [self.applyEntryIconButton.heightAnchor constraintEqualToConstant:32],
        [self.chooseEntryPhotoButton.leadingAnchor constraintEqualToAnchor:self.applyEntryIconButton.trailingAnchor constant:6],
        [self.chooseEntryPhotoButton.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor constant:-16],
        [self.chooseEntryPhotoButton.centerYAnchor constraintEqualToAnchor:self.customIconField.centerYAnchor],
        [self.chooseEntryPhotoButton.widthAnchor constraintEqualToConstant:70],
        [self.chooseEntryPhotoButton.heightAnchor constraintEqualToConstant:32],
        [opacityTitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [opacityTitle.topAnchor constraintEqualToAnchor:self.customIconField.bottomAnchor constant:12],
        [self.opacityValueLabel.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor constant:-20],
        [self.opacityValueLabel.centerYAnchor constraintEqualToAnchor:opacityTitle.centerYAnchor],
        [self.opacitySlider.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.opacitySlider.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor constant:-20],
        [self.opacitySlider.topAnchor constraintEqualToAnchor:opacityTitle.bottomAnchor constant:6],
        [self.opacitySlider.bottomAnchor constraintEqualToAnchor:contentGuide.bottomAnchor constant:-16]
    ]];
}

#pragma mark - Theme-Synced Modal & Toast Overlays

- (void)buildModalAndToastOverlays {
    // Modal host inside _card so it inherits _card's bounds and syncs with _currentTheme
    self.modalHostView = [UIView new];
    self.modalHostView.translatesAutoresizingMaskIntoConstraints = NO;
    self.modalHostView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.42];
    self.modalHostView.layer.cornerRadius = 30;
    self.modalHostView.layer.cornerCurve = kCACornerCurveContinuous;
    self.modalHostView.clipsToBounds = YES;
    self.modalHostView.hidden = YES;
    self.modalHostView.alpha = 0.0;
    [self.card addSubview:self.modalHostView];

    self.modalCard = [UIView new];
    self.modalCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.modalCard.layer.cornerRadius = 22;
    self.modalCard.layer.cornerCurve = kCACornerCurveContinuous;
    self.modalCard.layer.borderWidth = 1.2;
    self.modalCard.layer.shadowColor = UIColor.blackColor.CGColor;
    self.modalCard.layer.shadowOpacity = 0.35;
    self.modalCard.layer.shadowRadius = 20;
    self.modalCard.layer.shadowOffset = CGSizeMake(0, 10);
    [self.modalHostView addSubview:self.modalCard];

    self.modalBlurView = [[UIVisualEffectView alloc] initWithEffect:NovaPanelCreateLiquidGlassEffect(NO)];
    self.modalBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.modalBlurView.userInteractionEnabled = NO;
    self.modalBlurView.layer.cornerRadius = 22;
    self.modalBlurView.layer.cornerCurve = kCACornerCurveContinuous;
    self.modalBlurView.clipsToBounds = YES;
    [self.modalCard addSubview:self.modalBlurView];

    self.modalGlassSheenLayer = [CAGradientLayer layer];
    self.modalGlassSheenLayer.startPoint = CGPointMake(0.0, 0.0);
    self.modalGlassSheenLayer.endPoint = CGPointMake(1.0, 1.0);
    self.modalGlassSheenLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.55].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.14].CGColor,
        (id)[UIColor colorWithRed:0.82 green:0.93 blue:1.0 alpha:0.06].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.38].CGColor
    ];
    self.modalGlassSheenLayer.locations = @[@0.0, @0.28, @0.68, @1.0];
    [self.modalBlurView.contentView.layer addSublayer:self.modalGlassSheenLayer];

    // Toast Banner at top of _card
    self.toastBanner = [UIView new];
    self.toastBanner.translatesAutoresizingMaskIntoConstraints = NO;
    self.toastBanner.layer.cornerRadius = 17;
    self.toastBanner.layer.cornerCurve = kCACornerCurveContinuous;
    self.toastBanner.layer.borderWidth = 1.0;
    self.toastBanner.layer.shadowColor = UIColor.blackColor.CGColor;
    self.toastBanner.layer.shadowOpacity = 0.25;
    self.toastBanner.layer.shadowRadius = 10;
    self.toastBanner.layer.shadowOffset = CGSizeMake(0, 4);
    self.toastBanner.userInteractionEnabled = NO;
    self.toastBanner.hidden = YES;
    self.toastBanner.alpha = 0.0;
    [self.card addSubview:self.toastBanner];

    self.toastBlurView = [[UIVisualEffectView alloc] initWithEffect:NovaPanelCreateLiquidGlassEffect(NO)];
    self.toastBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.toastBlurView.userInteractionEnabled = NO;
    self.toastBlurView.layer.cornerRadius = 17;
    self.toastBlurView.layer.cornerCurve = kCACornerCurveContinuous;
    self.toastBlurView.clipsToBounds = YES;
    [self.toastBanner addSubview:self.toastBlurView];

    self.toastIconView = [[UIImageView alloc] initWithImage:NovaPanelSymbol(@"sparkles", @"circle.fill", 13)];
    self.toastIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.toastIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.toastBanner addSubview:self.toastIconView];

    self.toastMessageLabel = [UILabel new];
    self.toastMessageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.toastMessageLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    self.toastMessageLabel.numberOfLines = 1;
    [self.toastBanner addSubview:self.toastMessageLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.modalHostView.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor],
        [self.modalHostView.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor],
        [self.modalHostView.topAnchor constraintEqualToAnchor:self.card.topAnchor],
        [self.modalHostView.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor],
        [self.modalCard.centerXAnchor constraintEqualToAnchor:self.modalHostView.centerXAnchor],
        [self.modalCard.centerYAnchor constraintEqualToAnchor:self.modalHostView.centerYAnchor],
        [self.modalCard.widthAnchor constraintEqualToAnchor:self.modalHostView.widthAnchor constant:-36],
        [self.modalBlurView.leadingAnchor constraintEqualToAnchor:self.modalCard.leadingAnchor],
        [self.modalBlurView.trailingAnchor constraintEqualToAnchor:self.modalCard.trailingAnchor],
        [self.modalBlurView.topAnchor constraintEqualToAnchor:self.modalCard.topAnchor],
        [self.modalBlurView.bottomAnchor constraintEqualToAnchor:self.modalCard.bottomAnchor],
        [self.toastBanner.centerXAnchor constraintEqualToAnchor:self.card.centerXAnchor],
        [self.toastBanner.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:16],
        [self.toastBanner.widthAnchor constraintLessThanOrEqualToAnchor:self.card.widthAnchor constant:-36],
        [self.toastBanner.heightAnchor constraintEqualToConstant:34],
        [self.toastBlurView.leadingAnchor constraintEqualToAnchor:self.toastBanner.leadingAnchor],
        [self.toastBlurView.trailingAnchor constraintEqualToAnchor:self.toastBanner.trailingAnchor],
        [self.toastBlurView.topAnchor constraintEqualToAnchor:self.toastBanner.topAnchor],
        [self.toastBlurView.bottomAnchor constraintEqualToAnchor:self.toastBanner.bottomAnchor],
        [self.toastIconView.leadingAnchor constraintEqualToAnchor:self.toastBanner.leadingAnchor constant:12],
        [self.toastIconView.centerYAnchor constraintEqualToAnchor:self.toastBanner.centerYAnchor],
        [self.toastIconView.widthAnchor constraintEqualToConstant:15],
        [self.toastIconView.heightAnchor constraintEqualToConstant:15],
        [self.toastMessageLabel.leadingAnchor constraintEqualToAnchor:self.toastIconView.trailingAnchor constant:7],
        [self.toastMessageLabel.trailingAnchor constraintEqualToAnchor:self.toastBanner.trailingAnchor constant:-14],
        [self.toastMessageLabel.centerYAnchor constraintEqualToAnchor:self.toastBanner.centerYAnchor]
    ]];
}

- (void)clearModalCardContent {
    for (UIView *sub in [self.modalCard.subviews copy]) {
        if (sub != self.modalBlurView) {
            [sub removeFromSuperview];
        }
    }
    self.activeModalPromptField = nil;
}

- (void)presentModalHostAnimated {
    [self.card bringSubviewToFront:self.modalHostView];
    [self.card bringSubviewToFront:self.toastBanner];
    [self applyTheme:self.currentTheme];
    self.modalHostView.hidden = NO;
    self.modalCard.transform = CGAffineTransformMakeScale(0.94, 0.94);
    [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.84 initialSpringVelocity:0.3 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.modalHostView.alpha = 1.0;
        self.modalCard.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)dismissModalHostAnimatedWithCompletion:(dispatch_block_t)completion {
    [self endEditing:YES];
    [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.modalHostView.alpha = 0.0;
        self.modalCard.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL finished) {
        self.modalHostView.hidden = YES;
        self.modalCard.transform = CGAffineTransformIdentity;
        [self clearModalCardContent];
        if (completion) completion();
    }];
}

- (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
              confirmTitle:(NSString *)confirmTitle
               cancelTitle:(NSString *)cancelTitle
                   handler:(NovaUIAlertHandler)handler {
    [self clearModalCardContent];
    self.activeAlertHandler = handler;

    UILabel *titleLbl = [UILabel new];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text = NovaPanelTrimmedString(title).length > 0 ? title : @"提示";
    titleLbl.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    titleLbl.numberOfLines = 2;
    [self.modalCard addSubview:titleLbl];

    UILabel *msgLbl = [UILabel new];
    msgLbl.translatesAutoresizingMaskIntoConstraints = NO;
    msgLbl.text = [message isKindOfClass:NSString.class] ? message : @"";
    msgLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    msgLbl.tag = 111;
    msgLbl.numberOfLines = 0;
    [self.modalCard addSubview:msgLbl];

    UIStackView *btnStack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    btnStack.translatesAutoresizingMaskIntoConstraints = NO;
    btnStack.axis = UILayoutConstraintAxisHorizontal;
    btnStack.distribution = UIStackViewDistributionFillEqually;
    btnStack.spacing = 10;
    [self.modalCard addSubview:btnStack];

    NSString *trimmedCancel = NovaPanelTrimmedString(cancelTitle);
    if (trimmedCancel.length > 0) {
        UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        cancelBtn.layer.cornerRadius = 12;
        cancelBtn.layer.borderWidth = 1.0;
        cancelBtn.tag = 500;
        cancelBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        [cancelBtn setTitle:trimmedCancel forState:UIControlStateNormal];
        [cancelBtn addTarget:self action:@selector(modalAlertCancelTapped) forControlEvents:UIControlEventTouchUpInside];
        [btnStack addArrangedSubview:cancelBtn];
    }

    UIButton *confirmBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmBtn.layer.cornerRadius = 12;
    confirmBtn.layer.borderWidth = 1.0;
    confirmBtn.tag = 501;
    confirmBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    NSString *trimmedConfirm = NovaPanelTrimmedString(confirmTitle);
    [confirmBtn setTitle:trimmedConfirm.length > 0 ? trimmedConfirm : @"确定" forState:UIControlStateNormal];
    [confirmBtn addTarget:self action:@selector(modalAlertConfirmTapped) forControlEvents:UIControlEventTouchUpInside];
    [btnStack addArrangedSubview:confirmBtn];

    [NSLayoutConstraint activateConstraints:@[
        [titleLbl.topAnchor constraintEqualToAnchor:self.modalCard.topAnchor constant:20],
        [titleLbl.leadingAnchor constraintEqualToAnchor:self.modalCard.leadingAnchor constant:20],
        [titleLbl.trailingAnchor constraintEqualToAnchor:self.modalCard.trailingAnchor constant:-20],
        [msgLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:8],
        [msgLbl.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [msgLbl.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
        [btnStack.topAnchor constraintEqualToAnchor:msgLbl.bottomAnchor constant:18],
        [btnStack.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [btnStack.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
        [btnStack.heightAnchor constraintEqualToConstant:38],
        [btnStack.bottomAnchor constraintEqualToAnchor:self.modalCard.bottomAnchor constant:-18]
    ]];

    [self presentModalHostAnimated];
}

- (void)modalAlertCancelTapped {
    NovaUIAlertHandler handler = self.activeAlertHandler;
    self.activeAlertHandler = nil;
    [self dismissModalHostAnimatedWithCompletion:^{
        if (handler) handler(NO);
    }];
}

- (void)modalAlertConfirmTapped {
    NovaUIAlertHandler handler = self.activeAlertHandler;
    self.activeAlertHandler = nil;
    [self dismissModalHostAnimatedWithCompletion:^{
        if (handler) handler(YES);
    }];
}

- (void)showPromptWithTitle:(NSString *)title
                    message:(NSString *)message
                placeholder:(NSString *)placeholder
               defaultValue:(NSString *)defaultValue
               confirmTitle:(NSString *)confirmTitle
                    handler:(NovaUIPromptHandler)handler {
    [self clearModalCardContent];
    self.activePromptHandler = handler;

    UILabel *titleLbl = [UILabel new];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text = NovaPanelTrimmedString(title).length > 0 ? title : @"输入参数";
    titleLbl.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self.modalCard addSubview:titleLbl];

    UILabel *msgLbl = [UILabel new];
    msgLbl.translatesAutoresizingMaskIntoConstraints = NO;
    msgLbl.text = [message isKindOfClass:NSString.class] ? message : @"";
    msgLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    msgLbl.tag = 111;
    msgLbl.numberOfLines = 2;
    [self.modalCard addSubview:msgLbl];

    UITextField *inputField = [UITextField new];
    inputField.translatesAutoresizingMaskIntoConstraints = NO;
    inputField.placeholder = [placeholder isKindOfClass:NSString.class] && placeholder.length > 0 ? placeholder : @"请输入...";
    inputField.text = [defaultValue isKindOfClass:NSString.class] ? defaultValue : @"";
    inputField.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    inputField.layer.cornerRadius = 11;
    inputField.layer.borderWidth = 1.0;
    inputField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 10)];
    inputField.leftViewMode = UITextFieldViewModeAlways;
    inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    inputField.autocorrectionType = UITextAutocorrectionTypeNo;
    inputField.returnKeyType = UIReturnKeyDone;
    inputField.delegate = self;
    [self.modalCard addSubview:inputField];
    self.activeModalPromptField = inputField;

    UIStackView *btnStack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    btnStack.translatesAutoresizingMaskIntoConstraints = NO;
    btnStack.axis = UILayoutConstraintAxisHorizontal;
    btnStack.distribution = UIStackViewDistributionFillEqually;
    btnStack.spacing = 10;
    [self.modalCard addSubview:btnStack];

    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelBtn.layer.cornerRadius = 12;
    cancelBtn.layer.borderWidth = 1.0;
    cancelBtn.tag = 500;
    cancelBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [cancelBtn setTitle:@"取消" forState:UIControlStateNormal];
    [cancelBtn addTarget:self action:@selector(modalPromptCancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [btnStack addArrangedSubview:cancelBtn];

    UIButton *confirmBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmBtn.layer.cornerRadius = 12;
    confirmBtn.layer.borderWidth = 1.0;
    confirmBtn.tag = 501;
    confirmBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    NSString *trimmedConfirm = NovaPanelTrimmedString(confirmTitle);
    [confirmBtn setTitle:trimmedConfirm.length > 0 ? trimmedConfirm : @"保存" forState:UIControlStateNormal];
    [confirmBtn addTarget:self action:@selector(modalPromptConfirmTapped) forControlEvents:UIControlEventTouchUpInside];
    [btnStack addArrangedSubview:confirmBtn];

    [NSLayoutConstraint activateConstraints:@[
        [titleLbl.topAnchor constraintEqualToAnchor:self.modalCard.topAnchor constant:20],
        [titleLbl.leadingAnchor constraintEqualToAnchor:self.modalCard.leadingAnchor constant:20],
        [titleLbl.trailingAnchor constraintEqualToAnchor:self.modalCard.trailingAnchor constant:-20],
        [msgLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:6],
        [msgLbl.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [msgLbl.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
        [inputField.topAnchor constraintEqualToAnchor:msgLbl.bottomAnchor constant:12],
        [inputField.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [inputField.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
        [inputField.heightAnchor constraintEqualToConstant:36],
        [btnStack.topAnchor constraintEqualToAnchor:inputField.bottomAnchor constant:16],
        [btnStack.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [btnStack.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
        [btnStack.heightAnchor constraintEqualToConstant:38],
        [btnStack.bottomAnchor constraintEqualToAnchor:self.modalCard.bottomAnchor constant:-18]
    ]];

    [self presentModalHostAnimated];
}

- (void)modalPromptCancelTapped {
    NovaUIPromptHandler handler = self.activePromptHandler;
    self.activePromptHandler = nil;
    [self dismissModalHostAnimatedWithCompletion:^{
        if (handler) handler(nil, NO);
    }];
}

- (void)modalPromptConfirmTapped {
    NSString *val = [self.activeModalPromptField.text copy] ?: @"";
    NovaUIPromptHandler handler = self.activePromptHandler;
    self.activePromptHandler = nil;
    [self dismissModalHostAnimatedWithCompletion:^{
        if (handler) handler(val, YES);
    }];
}

- (void)showSelectionSheetWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                            options:(NSArray<NSString *> *)options
                      selectedIndex:(NSInteger)selectedIndex
                            handler:(NovaUISelectHandler)handler {
    [self clearModalCardContent];
    self.activeSelectHandler = handler;
    NSMutableArray<NSString *> *safeOpts = [NSMutableArray array];
    for (id o in options) {
        if ([o isKindOfClass:NSString.class]) [safeOpts addObject:o];
    }
    if (!safeOpts.count) [safeOpts addObject:@"默认"];
    self.activeSelectOptions = [safeOpts copy];

    UILabel *titleLbl = [UILabel new];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text = NovaPanelTrimmedString(title).length > 0 ? title : @"选择选项";
    titleLbl.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self.modalCard addSubview:titleLbl];

    UILabel *subLbl = [UILabel new];
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;
    subLbl.text = [subtitle isKindOfClass:NSString.class] ? subtitle : @"点击下方选项立即生效";
    subLbl.font = [UIFont systemFontOfSize:11];
    subLbl.tag = 111;
    [self.modalCard addSubview:subLbl];

    UIStackView *optStack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    optStack.translatesAutoresizingMaskIntoConstraints = NO;
    optStack.axis = UILayoutConstraintAxisVertical;
    optStack.spacing = 7;
    [self.modalCard addSubview:optStack];

    for (NSInteger i = 0; i < (NSInteger)safeOpts.count; i++) {
        UIButton *optBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        optBtn.tag = i;
        optBtn.layer.cornerRadius = 12;
        optBtn.layer.borderWidth = 1.0;
        optBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        optBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:(i == selectedIndex) ? UIFontWeightBold : UIFontWeightMedium];
        NSString *prefix = (i == selectedIndex) ? @"   ●  " : @"   ○  ";
        [optBtn setTitle:[prefix stringByAppendingString:safeOpts[i]] forState:UIControlStateNormal];
        [optBtn.heightAnchor constraintEqualToConstant:36].active = YES;
        [optBtn addTarget:self action:@selector(modalSelectionOptionTapped:) forControlEvents:UIControlEventTouchUpInside];
        [optStack addArrangedSubview:optBtn];
    }

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    closeBtn.layer.cornerRadius = 12;
    closeBtn.layer.borderWidth = 1.0;
    closeBtn.tag = 500;
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [closeBtn setTitle:@"关闭" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(modalSelectionCancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.modalCard addSubview:closeBtn];

    [NSLayoutConstraint activateConstraints:@[
        [titleLbl.topAnchor constraintEqualToAnchor:self.modalCard.topAnchor constant:18],
        [titleLbl.leadingAnchor constraintEqualToAnchor:self.modalCard.leadingAnchor constant:20],
        [titleLbl.trailingAnchor constraintEqualToAnchor:self.modalCard.trailingAnchor constant:-20],
        [subLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:4],
        [subLbl.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [subLbl.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
        [optStack.topAnchor constraintEqualToAnchor:subLbl.bottomAnchor constant:12],
        [optStack.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [optStack.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
        [closeBtn.topAnchor constraintEqualToAnchor:optStack.bottomAnchor constant:12],
        [closeBtn.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [closeBtn.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
        [closeBtn.heightAnchor constraintEqualToConstant:34],
        [closeBtn.bottomAnchor constraintEqualToAnchor:self.modalCard.bottomAnchor constant:-16]
    ]];

    [self presentModalHostAnimated];
}

- (void)modalSelectionOptionTapped:(UIButton *)sender {
    if (!sender) return;
    NSInteger idx = sender.tag;
    NSArray<NSString *> *opts = self.activeSelectOptions ?: @[];
    NSString *chosen = (idx >= 0 && idx < (NSInteger)opts.count) ? opts[idx] : @"";
    NovaUISelectHandler handler = self.activeSelectHandler;
    self.activeSelectHandler = nil;
    [self dismissModalHostAnimatedWithCompletion:^{
        if (handler) handler(idx, chosen);
    }];
}

- (void)modalSelectionCancelTapped {
    self.activeSelectHandler = nil;
    [self dismissModalHostAnimatedWithCompletion:nil];
}

- (void)showDetailModalWithTitle:(NSString *)title
                        subtitle:(NSString *)subtitle
                       badgeText:(NSString *)badgeText
                          fields:(NSArray<NSDictionary *> *)fields
              primaryActionTitle:(NSString *)primaryTitle
                  primaryHandler:(dispatch_block_t)primaryHandler {
    [self clearModalCardContent];
    self.activeDetailPrimaryHandler = primaryHandler;

    UILabel *titleLbl = [UILabel new];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text = NovaPanelTrimmedString(title).length > 0 ? title : @"详情信息";
    titleLbl.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self.modalCard addSubview:titleLbl];

    UILabel *subLbl = [UILabel new];
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;
    subLbl.text = [subtitle isKindOfClass:NSString.class] ? subtitle : @"";
    subLbl.font = [UIFont systemFontOfSize:11];
    subLbl.tag = 111;
    [self.modalCard addSubview:subLbl];

    UILabel *badgeLbl = [UILabel new];
    badgeLbl.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLbl.text = [badgeText isKindOfClass:NSString.class] && badgeText.length > 0 ? [NSString stringWithFormat:@"  %@  ", badgeText] : @"";
    badgeLbl.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    badgeLbl.layer.cornerRadius = 8;
    badgeLbl.clipsToBounds = YES;
    badgeLbl.hidden = (badgeLbl.text.length == 0);
    [self.modalCard addSubview:badgeLbl];

    UIStackView *fieldStack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    fieldStack.translatesAutoresizingMaskIntoConstraints = NO;
    fieldStack.axis = UILayoutConstraintAxisVertical;
    fieldStack.spacing = 6;
    [self.modalCard addSubview:fieldStack];

    if ([fields isKindOfClass:NSArray.class]) {
        for (NSDictionary *f in fields) {
            if (![f isKindOfClass:NSDictionary.class]) continue;
            UIView *itemRow = [UIView new];
            itemRow.translatesAutoresizingMaskIntoConstraints = NO;
            itemRow.layer.cornerRadius = 10;
            itemRow.tag = 510;
            [itemRow.heightAnchor constraintEqualToConstant:32].active = YES;

            UILabel *kLbl = [UILabel new];
            kLbl.translatesAutoresizingMaskIntoConstraints = NO;
            kLbl.text = [f[@"label"] isKindOfClass:NSString.class] ? f[@"label"] : @"字段";
            kLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
            kLbl.tag = 111;
            [itemRow addSubview:kLbl];

            UILabel *vLbl = [UILabel new];
            vLbl.translatesAutoresizingMaskIntoConstraints = NO;
            vLbl.text = [f[@"value"] isKindOfClass:NSString.class] ? f[@"value"] : @"";
            vLbl.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
            vLbl.textAlignment = NSTextAlignmentRight;
            [itemRow addSubview:vLbl];

            [NSLayoutConstraint activateConstraints:@[
                [kLbl.leadingAnchor constraintEqualToAnchor:itemRow.leadingAnchor constant:12],
                [kLbl.centerYAnchor constraintEqualToAnchor:itemRow.centerYAnchor],
                [vLbl.trailingAnchor constraintEqualToAnchor:itemRow.trailingAnchor constant:-12],
                [vLbl.leadingAnchor constraintGreaterThanOrEqualToAnchor:kLbl.trailingAnchor constant:8],
                [vLbl.centerYAnchor constraintEqualToAnchor:itemRow.centerYAnchor]
            ]];
            [fieldStack addArrangedSubview:itemRow];
        }
    }

    UIStackView *btnStack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    btnStack.translatesAutoresizingMaskIntoConstraints = NO;
    btnStack.axis = UILayoutConstraintAxisHorizontal;
    btnStack.distribution = UIStackViewDistributionFillEqually;
    btnStack.spacing = 10;
    [self.modalCard addSubview:btnStack];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.layer.cornerRadius = 12;
    closeBtn.layer.borderWidth = 1.0;
    closeBtn.tag = 500;
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [closeBtn setTitle:@"关闭" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(modalSelectionCancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [btnStack addArrangedSubview:closeBtn];

    NSString *trimmedPri = NovaPanelTrimmedString(primaryTitle);
    if (trimmedPri.length > 0) {
        UIButton *priBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        priBtn.layer.cornerRadius = 12;
        priBtn.layer.borderWidth = 1.0;
        priBtn.tag = 501;
        priBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        [priBtn setTitle:trimmedPri forState:UIControlStateNormal];
        [priBtn addTarget:self action:@selector(modalDetailPrimaryTapped) forControlEvents:UIControlEventTouchUpInside];
        [btnStack addArrangedSubview:priBtn];
    }

    [NSLayoutConstraint activateConstraints:@[
        [titleLbl.topAnchor constraintEqualToAnchor:self.modalCard.topAnchor constant:18],
        [titleLbl.leadingAnchor constraintEqualToAnchor:self.modalCard.leadingAnchor constant:20],
        [badgeLbl.trailingAnchor constraintEqualToAnchor:self.modalCard.trailingAnchor constant:-20],
        [badgeLbl.centerYAnchor constraintEqualToAnchor:titleLbl.centerYAnchor],
        [badgeLbl.heightAnchor constraintEqualToConstant:20],
        [titleLbl.trailingAnchor constraintLessThanOrEqualToAnchor:badgeLbl.leadingAnchor constant:-8],
        [subLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:4],
        [subLbl.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [subLbl.trailingAnchor constraintEqualToAnchor:self.modalCard.trailingAnchor constant:-20],
        [fieldStack.topAnchor constraintEqualToAnchor:subLbl.bottomAnchor constant:12],
        [fieldStack.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [fieldStack.trailingAnchor constraintEqualToAnchor:self.modalCard.trailingAnchor constant:-20],
        [btnStack.topAnchor constraintEqualToAnchor:fieldStack.bottomAnchor constant:14],
        [btnStack.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [btnStack.trailingAnchor constraintEqualToAnchor:self.modalCard.trailingAnchor constant:-20],
        [btnStack.heightAnchor constraintEqualToConstant:36],
        [btnStack.bottomAnchor constraintEqualToAnchor:self.modalCard.bottomAnchor constant:-16]
    ]];

    [self presentModalHostAnimated];
}

- (void)modalDetailPrimaryTapped {
    dispatch_block_t handler = self.activeDetailPrimaryHandler;
    self.activeDetailPrimaryHandler = nil;
    [self dismissModalHostAnimatedWithCompletion:^{
        if (handler) handler();
    }];
}

- (void)showToast:(NSString *)message icon:(NSString *)icon duration:(NSTimeInterval)duration {
    NSString *trimmed = NovaPanelTrimmedString(message);
    if (!trimmed.length) return;
    self.toastMessageLabel.text = trimmed;
    NSString *iconName = NovaPanelTrimmedString(icon);
    self.toastIconView.image = NovaPanelSymbol(iconName.length > 0 ? iconName : @"sparkles", @"circle.fill", 13);
    [self applyTheme:self.currentTheme];
    [self.card bringSubviewToFront:self.toastBanner];

    NSUInteger gen = ++self.toastGeneration;
    self.toastBanner.hidden = NO;
    self.toastBanner.transform = CGAffineTransformMakeTranslation(0, -10);
    [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.80 initialSpringVelocity:0.3 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.toastBanner.alpha = 1.0;
        self.toastBanner.transform = CGAffineTransformIdentity;
    } completion:nil];

    NSTimeInterval effectiveDuration = (isfinite(duration) && duration >= 0.6) ? duration : 2.0;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(effectiveDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NovaControlPanel *strongSelf = weakSelf;
        if (!strongSelf || strongSelf.toastGeneration != gen) return;
        [UIView animateWithDuration:0.18 animations:^{
            strongSelf.toastBanner.alpha = 0.0;
            strongSelf.toastBanner.transform = CGAffineTransformMakeTranslation(0, -8);
        } completion:^(BOOL finished) {
            if (strongSelf.toastGeneration == gen) {
                strongSelf.toastBanner.hidden = YES;
            }
        }];
    });
}

#pragma mark - System Photo Library Picker Integration

- (UIViewController *)discoverTopPresentableViewController {
    UIWindow *win = self.window ?: [self discoverTargetWindow];
    UIViewController *vc = win.rootViewController;
    while (vc.presentedViewController && !vc.presentedViewController.isBeingDismissed) {
        vc = vc.presentedViewController;
    }
    return vc;
}

- (void)presentPhotoLibraryPickerForHeader:(BOOL)forHeader {
    [self endEditing:YES];
    self.photoPickerTargetIsHeader = forHeader;
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        [self showToast:@"当前宿主环境不支持调取系统相册" icon:@"exclamationmark.triangle.fill" duration:2.2];
        return;
    }
    UIViewController *topVC = [self discoverTopPresentableViewController];
    if (!topVC) {
        [self showToast:@"未找到可用宿主视图控制器" icon:@"exclamationmark.triangle.fill" duration:2.2];
        return;
    }
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = YES;
    picker.delegate = self;
    [topVC presentViewController:picker animated:YES completion:nil];
}

- (void)chooseHeaderPhotoTapped {
    [self presentPhotoLibraryPickerForHeader:YES];
}

- (void)chooseEntryPhotoTapped {
    [self presentPhotoLibraryPickerForHeader:NO];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *picked = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (![picked isKindOfClass:UIImage.class]) return;

    // Center-crop and scale to a crisp 256x256 square PNG so non-square photos never stretch or look tiny
    UIImage *squareImg = NovaPanelCenterCropSquareImage(picked, 256.0);
    NSData *pngData = UIImagePNGRepresentation(squareImg ?: picked);
    if (!pngData.length) return;

    if (self.photoPickerTargetIsHeader) {
        [NSUserDefaults.standardUserDefaults setObject:pngData forKey:@"NovaUI.headerCustomImageData"];
        self.customHeaderIconField.text = @"[相册图片]";
        [self applyHeaderIcon:@"__custom_image__"];
        [self showToast:@"已从系统相册更新顶部图标" icon:@"photo.fill" duration:2.0];
    } else {
        [NSUserDefaults.standardUserDefaults setObject:pngData forKey:@"NovaUI.entryCustomImageData"];
        [NSUserDefaults.standardUserDefaults setObject:@"__custom_image__" forKey:@"NovaUI.entryCustomIcon"];
        self.customIconField.text = @"[相册图片]";
        [self applyTheme:self.currentTheme];
        if (self.floatingIconChanged) {
            self.floatingIconChanged(@"__custom_image__");
        }
        [self showToast:@"已从系统相册更新悬浮球图标" icon:@"photo.fill" duration:2.0];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Search & Submenu Navigation Stack

- (void)searchFieldDidChange:(UITextField *)sender {
    self.searchKeyword = NovaPanelTrimmedString(sender.text);
    self.clearSearchButton.hidden = (self.searchKeyword.length == 0);
    [self rebuildRows];
}

- (void)clearSearchTapped {
    self.searchField.text = @"";
    self.searchKeyword = @"";
    self.clearSearchButton.hidden = YES;
    [self.searchField resignFirstResponder];
    [self rebuildRows];
}

- (NSString *)currentSubmenuKey {
    return self.submenuStack.lastObject ?: @"";
}

- (void)pushSubmenuWithKey:(NSString *)submenuKey {
    NSString *trimmed = NovaPanelTrimmedString(submenuKey);
    if (!trimmed.length) return;
    [self endEditing:YES];
    if (self.appearanceOverlay && !self.appearanceOverlay.hidden) {
        [self toggleAppearanceSettings];
    }
    if (![self.currentSubmenuKey isEqualToString:trimmed]) {
        [self.submenuStack addObject:[trimmed copy]];
    }
    self.scrollView.contentOffset = CGPointZero;
    [self rebuildRows];
}

- (void)popSubmenu {
    [self endEditing:YES];
    if (self.submenuStack.count > 0) {
        [self.submenuStack removeLastObject];
    }
    self.scrollView.contentOffset = CGPointZero;
    [self rebuildRows];
}

- (void)popToRootMenu {
    [self endEditing:YES];
    [self.submenuStack removeAllObjects];
    self.scrollView.contentOffset = CGPointZero;
    [self rebuildRows];
}

- (void)openConsoleLogInspector {
    [self pushSubmenuWithKey:@"__nova_logs__"];
}

- (void)openConfigCenterInspector {
    [self pushSubmenuWithKey:@"__nova_config__"];
}

#pragma mark - Appearance & Icon Controls

- (void)dismissAppearanceKeyboard {
    [self endEditing:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if (textField == self.customHeaderIconField) {
        [self applyCustomHeaderIconTapped];
    } else if (textField == self.customIconField) {
        [self applyCustomEntryIconTapped];
    } else if (textField == self.activeModalPromptField) {
        [self modalPromptConfirmTapped];
    }
    return YES;
}

- (void)toggleAppearanceSettings {
    [self endEditing:YES];
    BOOL showOverlay = self.appearanceOverlay.hidden;
    if (showOverlay) {
        self.appearanceOverlay.contentOffset = CGPointZero;
    }
    self.appearanceOverlay.hidden = !showOverlay;
    self.statusPill.hidden = showOverlay;
    self.quickLogsButton.hidden = showOverlay;
    self.quickConfigButton.hidden = showOverlay;
    self.searchContainer.hidden = showOverlay;
    self.sectionHeaderBar.hidden = showOverlay;
    self.scrollView.hidden = showOverlay;
    self.themeHeader.hidden = showOverlay;
    [self applyTheme:self.currentTheme];
}

- (void)applyHeaderIcon:(NSString *)icon {
    NSString *trimmed = NovaPanelTrimmedString(icon);
    self.headerIconName = trimmed.length > 0 ? [trimmed copy] : @"nova.sakura";
    if (![self.headerIconName isEqualToString:@"__custom_image__"]) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"NovaUI.headerCustomImageData"];
    }
    [NSUserDefaults.standardUserDefaults setObject:self.headerIconName forKey:@"NovaUI.headerIcon"];
    [self refreshHeaderIconViews];
    [self applyTheme:self.currentTheme];
    if (self.headerIconChanged) {
        self.headerIconChanged(self.headerIconName);
    }
}

- (void)headerIconButtonTapped:(UIButton *)sender {
    if (!sender) return;
    [self endEditing:YES];
    NSArray<NSString *> *symbols = [NovaControlPanel presetHeaderIconSymbols];
    NSInteger idx = (sender.tag >= 0 && sender.tag < (NSInteger)symbols.count) ? sender.tag : 0;
    self.customHeaderIconField.text = @"";
    [self applyHeaderIcon:symbols[idx]];
}

- (void)applyCustomHeaderIconTapped {
    [self endEditing:YES];
    NSString *trimmed = NovaPanelTrimmedString(self.customHeaderIconField.text);
    if ([trimmed isEqualToString:@"[相册图片]"]) return;
    self.customHeaderIconField.text = trimmed;
    [self applyHeaderIcon:trimmed.length > 0 ? trimmed : @"nova.sakura"];
}

- (void)entryStyleButtonTapped:(UIButton *)sender {
    if (!sender) return;
    [self endEditing:YES];
    NSInteger style = NovaPanelNormalizeStyle(sender.tag);
    [NSUserDefaults.standardUserDefaults setInteger:style forKey:@"NovaUI.entryStyle"];
    [self applyTheme:self.currentTheme];
    if (self.floatingStyleChanged) self.floatingStyleChanged(style);
}

- (void)entryIconPresetButtonTapped:(UIButton *)sender {
    if (!sender) return;
    [self endEditing:YES];
    NSArray<NSString *> *presets = [NovaControlPanel presetEntryIconSymbols];
    NSInteger idx = (sender.tag >= 0 && sender.tag < (NSInteger)presets.count) ? sender.tag : 0;
    NSString *chosen = presets[idx];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"NovaUI.entryCustomImageData"];
    if (chosen.length > 0) {
        [NSUserDefaults.standardUserDefaults setObject:chosen forKey:@"NovaUI.entryCustomIcon"];
        self.customIconField.text = [chosen hasPrefix:@"nova."] ? @"" : chosen;
    } else {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"NovaUI.entryCustomIcon"];
        self.customIconField.text = @"";
    }
    [self applyTheme:self.currentTheme];
    if (self.floatingIconChanged) {
        self.floatingIconChanged(chosen.length > 0 ? chosen : nil);
    }
}

- (void)applyCustomEntryIconTapped {
    [self endEditing:YES];
    NSString *trimmed = NovaPanelTrimmedString(self.customIconField.text);
    if ([trimmed isEqualToString:@"[相册图片]"]) return;
    self.customIconField.text = trimmed;
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"NovaUI.entryCustomImageData"];
    if (trimmed.length > 0) {
        [NSUserDefaults.standardUserDefaults setObject:trimmed forKey:@"NovaUI.entryCustomIcon"];
    } else {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"NovaUI.entryCustomIcon"];
    }
    [self applyTheme:self.currentTheme];
    if (self.floatingIconChanged) {
        self.floatingIconChanged(trimmed.length > 0 ? trimmed : nil);
    }
}

- (void)opacitySliderChanged:(UISlider *)sender {
    if (!sender) return;
    CGFloat opacity = NovaPanelClampOpacity(sender.value);
    sender.value = opacity;
    self.opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)round(opacity * 100)];
    [NSUserDefaults.standardUserDefaults setFloat:opacity forKey:@"NovaUI.entryOpacity"];
    if (self.floatingOpacityChanged) self.floatingOpacityChanged(opacity);
}

#pragma mark - Universal Module & Submenu Row Builder

- (NSArray<NSDictionary *> *)syntheticItemsForUtilitySubmenu:(NSString *)menuKey {
    if ([menuKey isEqualToString:@"__nova_logs__"]) {
        NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown.bundle";
        NSString *osVer = [[UIDevice currentDevice] systemVersion] ?: @"iOS";
        [items addObject:@{
            @"key": @"__log_env_bundle",
            @"parentKey": @"__nova_logs__",
            @"type": @"info",
            @"title": @"宿主应用 Bundle ID",
            @"valueText": bundleID,
            @"icon": @"app.badge.fill"
        }];
        [items addObject:@{
            @"key": @"__log_env_os",
            @"parentKey": @"__nova_logs__",
            @"type": @"info",
            @"title": @"系统与渲染管线",
            @"valueText": NovaPanelIsIOS26OrLater() ? [NSString stringWithFormat:@"iOS %@ · Liquid Glass", osVer] : [NSString stringWithFormat:@"iOS %@ · Optical Blur", osVer],
            @"icon": @"cpu.fill"
        }];
        __weak typeof(self) weakSelf = self;
        [items addObject:@{
            @"key": @"__log_copy_all",
            @"parentKey": @"__nova_logs__",
            @"type": @"action",
            @"title": @"导出运行日志",
            @"subtitle": @"将全部时间戳日志复制到系统剪贴板",
            @"icon": @"doc.on.doc.fill",
            @"buttonTitle": @"复制日志",
            @"handler": ^{
                NovaControlPanel *strongSelf = weakSelf;
                if (!strongSelf) return;
                NSArray<NSDictionary *> *logs = strongSelf.logsProvider ? strongSelf.logsProvider() : @[];
                NSMutableString *buf = [NSMutableString string];
                for (NSDictionary *entry in logs) {
                    [buf appendFormat:@"[%@] [%@] %@\n", entry[@"time"] ?: @"", entry[@"level"] ?: @"INFO", entry[@"message"] ?: @""];
                }
                UIPasteboard.generalPasteboard.string = buf.length > 0 ? buf : @"[暂无日志]";
                [strongSelf showToast:@"已复制运行日志到剪贴板" icon:@"checkmark.circle.fill" duration:1.8];
            }
        }];
        [items addObject:@{
            @"key": @"__log_clear_all",
            @"parentKey": @"__nova_logs__",
            @"type": @"action",
            @"title": @"清空日志记录",
            @"subtitle": @"清理当前会话缓存的调试日志",
            @"icon": @"trash.fill",
            @"buttonTitle": @"清空",
            @"handler": ^{
                NovaControlPanel *strongSelf = weakSelf;
                if (!strongSelf) return;
                if (strongSelf.clearLogsHandler) strongSelf.clearLogsHandler();
                [strongSelf rebuildRows];
                [strongSelf showToast:@"日志记录已清空" icon:@"sparkles" duration:1.6];
            }
        }];
        NSArray<NSDictionary *> *logs = self.logsProvider ? self.logsProvider() : @[];
        for (NSInteger i = (NSInteger)logs.count - 1; i >= 0; i--) {
            NSDictionary *entry = logs[i];
            NSString *timeStr = entry[@"time"] ?: @"00:00:00";
            NSString *lvl = entry[@"level"] ?: @"INFO";
            NSString *msg = entry[@"message"] ?: @"";
            [items addObject:@{
                @"key": [NSString stringWithFormat:@"__log_item_%ld", (long)i],
                @"parentKey": @"__nova_logs__",
                @"type": @"info",
                @"title": msg,
                @"valueText": [NSString stringWithFormat:@"%@ · %@", lvl, timeStr],
                @"icon": @"terminal.fill"
            }];
        }
        return items;
    } else if ([menuKey isEqualToString:@"__nova_config__"]) {
        __weak typeof(self) weakSelf = self;
        return @[
            @{
                @"key": @"panicHideGesture",
                @"parentKey": @"__nova_config__",
                @"type": @"switch",
                @"title": @"三指轻触屏幕隐藏/召唤悬浮球",
                @"subtitle": @"防截屏/录屏时三指轻触任意位置隐藏全部插件 UI",
                @"icon": @"hand.tap.fill",
                @"customDefaultsKey": @"NovaUI.panicHideGesture",
                @"handler": ^(BOOL enabled) {
                    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:@"NovaUI.panicHideGesture"];
                    [weakSelf showToast:enabled ? @"已开启三指隐蔽手势" : @"已关闭三指隐蔽手势" icon:@"hand.tap.fill" duration:1.8];
                }
            },
            @{
                @"key": @"magneticEdgeSnap",
                @"parentKey": @"__nova_config__",
                @"type": @"switch",
                @"title": @"悬浮球松手自动贴边吸附",
                @"subtitle": @"拖动悬浮球松手后使用弹簧物理自动吸附至屏幕左右边缘",
                @"icon": @"arrow.left.and.right.circle.fill",
                @"customDefaultsKey": @"NovaUI.magneticEdgeSnap",
                @"handler": ^(BOOL enabled) {
                    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:@"NovaUI.magneticEdgeSnap"];
                    [weakSelf showToast:enabled ? @"已开启悬浮球自动贴边" : @"已允许悬浮球自由停靠" icon:@"sparkles" duration:1.8];
                }
            },
            @{
                @"key": @"__cfg_export",
                @"parentKey": @"__nova_config__",
                @"type": @"action",
                @"title": @"导出配置参数 (JSON)",
                @"subtitle": @"将全部开关、滑块、主题设置导出到系统剪贴板",
                @"icon": @"square.and.arrow.up.fill",
                @"buttonTitle": @"导出配置",
                @"handler": ^{
                    NovaControlPanel *strongSelf = weakSelf;
                    if (!strongSelf) return;
                    NSString *json = strongSelf.exportConfigHandler ? strongSelf.exportConfigHandler() : @"{}";
                    UIPasteboard.generalPasteboard.string = json;
                    [strongSelf showToast:@"配置 JSON 已复制到剪贴板" icon:@"checkmark.circle.fill" duration:2.0];
                }
            },
            @{
                @"key": @"__cfg_import",
                @"parentKey": @"__nova_config__",
                @"type": @"action",
                @"title": @"从剪贴板导入配置 (JSON)",
                @"subtitle": @"读取系统剪贴板中的 JSON 配置并立即应用",
                @"icon": @"square.and.arrow.down.fill",
                @"buttonTitle": @"导入配置",
                @"handler": ^{
                    NovaControlPanel *strongSelf = weakSelf;
                    if (!strongSelf) return;
                    NSString *pb = NovaPanelTrimmedString(UIPasteboard.generalPasteboard.string);
                    BOOL ok = (strongSelf.importConfigHandler && pb.length > 0) ? strongSelf.importConfigHandler(pb) : NO;
                    if (ok) {
                        [strongSelf syncStateFromDefaults];
                        [strongSelf rebuildRows];
                        [strongSelf showToast:@"配置导入成功并已实时生效" icon:@"checkmark.circle.fill" duration:2.0];
                    } else {
                        [strongSelf showToast:@"剪贴板中未检测到有效配置 JSON" icon:@"exclamationmark.triangle.fill" duration:2.2];
                    }
                }
            },
            @{
                @"key": @"__cfg_reset",
                @"parentKey": @"__nova_config__",
                @"type": @"action",
                @"title": @"恢复出厂默认设置",
                @"subtitle": @"重置所有开关、滑块、图标与主题参数",
                @"icon": @"arrow.counterclockwise.circle.fill",
                @"buttonTitle": @"重置默认",
                @"handler": ^{
                    NovaControlPanel *strongSelf = weakSelf;
                    if (!strongSelf) return;
                    [strongSelf showAlertWithTitle:@"确认恢复默认设置？"
                                           message:@"该操作将清空所有已保存的开关、滑块、自定义相册图标与主题装扮配置。"
                                      confirmTitle:@"确认重置"
                                       cancelTitle:@"取消"
                                           handler:^(BOOL confirmed) {
                        if (confirmed && strongSelf.resetConfigHandler) {
                            strongSelf.resetConfigHandler();
                            [strongSelf syncStateFromDefaults];
                            [strongSelf rebuildRows];
                            [strongSelf showToast:@"已恢复全部出厂默认设置" icon:@"sparkles" duration:2.0];
                        }
                    }];
                }
            }
        ];
    }
    return @[];
}

- (NSUInteger)countChildItemsForSubmenuKey:(NSString *)submenuKey {
    if (!submenuKey.length) return 0;
    NSUInteger count = 0;
    for (NSDictionary *m in self.modules) {
        if (![m isKindOfClass:NSDictionary.class]) continue;
        NSString *p = m[@"parentKey"] ?: @"";
        if ([p isEqualToString:submenuKey]) count++;
    }
    return count;
}

- (NSString *)titleForSubmenuKey:(NSString *)submenuKey {
    if ([submenuKey isEqualToString:@"__nova_logs__"]) return @"运行日志与诊断";
    if ([submenuKey isEqualToString:@"__nova_config__"]) return @"配置与手势中心";
    for (NSDictionary *m in self.modules) {
        if (![m isKindOfClass:NSDictionary.class]) continue;
        if ([m[@"key"] isEqualToString:submenuKey] && [m[@"type"] isEqualToString:@"submenu"]) {
            return m[@"title"] ?: submenuKey;
        }
    }
    return submenuKey;
}

- (void)rowTapped:(UITapGestureRecognizer *)gesture {
    if (gesture && gesture.state != UIGestureRecognizerStateEnded) return;
    UIView *row = gesture.view;
    if (!row) return;
    NSDictionary *item = objc_getAssociatedObject(row, kNovaItemDictKey);
    NSString *type = [item isKindOfClass:NSDictionary.class] ? (item[@"type"] ?: @"switch") : @"switch";

    if ([type isEqualToString:@"submenu"]) {
        NSString *subKey = item[@"key"];
        if (subKey.length > 0) {
            [self pushSubmenuWithKey:subKey];
        }
        return;
    } else if ([type isEqualToString:@"select"]) {
        [self handleSelectRowActivated:item];
        return;
    } else if ([type isEqualToString:@"input"]) {
        [self handleInputRowActivated:item];
        return;
    } else if ([type isEqualToString:@"action"]) {
        dispatch_block_t handler = item[@"handler"];
        if (handler) handler();
        return;
    }

    for (UIView *sub in row.subviews) {
        if ([sub isKindOfClass:UISwitch.class]) {
            UISwitch *toggle = (UISwitch *)sub;
            [toggle setOn:!toggle.isOn animated:YES];
            [self toggleChanged:toggle];
            break;
        }
    }
}

- (void)handleSelectRowActivated:(NSDictionary *)item {
    NSString *key = item[@"key"] ?: @"";
    NSString *title = item[@"title"] ?: @"选择选项";
    NSString *subtitle = item[@"subtitle"] ?: @"";
    NSArray<NSString *> *options = [item[@"options"] isKindOfClass:NSArray.class] ? item[@"options"] : @[@"默认"];
    NSString *defaultsKey = [@"NovaUI.select." stringByAppendingString:key];
    NSInteger currentIdx = [NSUserDefaults.standardUserDefaults integerForKey:defaultsKey];
    if (currentIdx < 0 || currentIdx >= (NSInteger)options.count) currentIdx = 0;

    __weak typeof(self) weakSelf = self;
    [self showSelectionSheetWithTitle:title
                             subtitle:subtitle
                              options:options
                        selectedIndex:currentIdx
                              handler:^(NSInteger selectedIndex, NSString *selectedOption) {
        NovaControlPanel *strongSelf = weakSelf;
        if (!strongSelf) return;
        [NSUserDefaults.standardUserDefaults setInteger:selectedIndex forKey:defaultsKey];
        NovaUISelectHandler handler = item[@"handler"];
        if (handler) handler(selectedIndex, selectedOption);
        if (strongSelf.logEventHandler) {
            strongSelf.logEventHandler([NSString stringWithFormat:@"%@ 切换为 [%@]", title, selectedOption], @"ACTION");
        }
        [strongSelf rebuildRows];
    }];
}

- (void)handleInputRowActivated:(NSDictionary *)item {
    NSString *key = item[@"key"] ?: @"";
    NSString *title = item[@"title"] ?: @"参数配置";
    NSString *subtitle = item[@"subtitle"] ?: @"";
    NSString *placeholder = item[@"placeholder"] ?: @"请输入参数...";
    NSString *defaultsKey = [@"NovaUI.input." stringByAppendingString:key];
    NSString *currentVal = [NSUserDefaults.standardUserDefaults stringForKey:defaultsKey] ?: (item[@"defaultValue"] ?: @"");

    __weak typeof(self) weakSelf = self;
    [self showPromptWithTitle:title
                      message:subtitle
                  placeholder:placeholder
                 defaultValue:currentVal
                 confirmTitle:@"保存参数"
                      handler:^(NSString *text, BOOL confirmed) {
        NovaControlPanel *strongSelf = weakSelf;
        if (!strongSelf || !confirmed) return;
        NSString *safeText = text ?: @"";
        [NSUserDefaults.standardUserDefaults setObject:safeText forKey:defaultsKey];
        NovaUIInputHandler handler = item[@"handler"];
        if (handler) handler(safeText);
        if (strongSelf.logEventHandler) {
            strongSelf.logEventHandler([NSString stringWithFormat:@"%@ 更新为 \"%@\"", title, safeText], @"ACTION");
        }
        [strongSelf rebuildRows];
    }];
}

- (void)actionRowButtonTapped:(UIButton *)sender {
    if (!sender) return;
    NSDictionary *item = objc_getAssociatedObject(sender, kNovaItemDictKey);
    if (![item isKindOfClass:NSDictionary.class]) return;
    NSString *type = item[@"type"] ?: @"action";
    if ([type isEqualToString:@"select"]) {
        [self handleSelectRowActivated:item];
    } else if ([type isEqualToString:@"input"]) {
        [self handleInputRowActivated:item];
    } else if ([type isEqualToString:@"submenu"]) {
        [self pushSubmenuWithKey:item[@"key"] ?: @""];
    } else {
        dispatch_block_t handler = item[@"handler"];
        if (handler) handler();
        if (self.logEventHandler) {
            self.logEventHandler([NSString stringWithFormat:@"执行动作: %@", item[@"title"] ?: @""], @"ACTION");
        }
    }
}

- (void)moduleSliderChanged:(UISlider *)sender {
    if (!sender) return;
    NSDictionary *item = objc_getAssociatedObject(sender, kNovaItemDictKey);
    UILabel *valLbl = objc_getAssociatedObject(sender, kNovaValueLabelKey);
    if (![item isKindOfClass:NSDictionary.class]) return;
    NSString *key = item[@"key"] ?: @"";
    NSString *unit = item[@"unit"] ?: @"";
    CGFloat val = sender.value;
    if (valLbl) {
        valLbl.text = [NSString stringWithFormat:@"%.2f%@", val, unit];
    }
    if (key.length > 0) {
        [NSUserDefaults.standardUserDefaults setFloat:val forKey:[@"NovaUI.slider." stringByAppendingString:key]];
    }
    NovaUISliderHandler handler = item[@"handler"];
    if (handler) handler(val);
}

- (void)stepperMinusTapped:(UIButton *)sender {
    [self adjustStepperForButton:sender direction:-1.0];
}

- (void)stepperPlusTapped:(UIButton *)sender {
    [self adjustStepperForButton:sender direction:1.0];
}

- (void)adjustStepperForButton:(UIButton *)sender direction:(CGFloat)dir {
    if (!sender) return;
    NSDictionary *item = objc_getAssociatedObject(sender, kNovaItemDictKey);
    UILabel *valLbl = objc_getAssociatedObject(sender, kNovaValueLabelKey);
    if (![item isKindOfClass:NSDictionary.class]) return;
    NSString *key = item[@"key"] ?: @"";
    CGFloat minV = [item[@"minValue"] doubleValue];
    CGFloat maxV = [item[@"maxValue"] doubleValue];
    CGFloat step = [item[@"stepValue"] doubleValue];
    if (step <= 0) step = 1.0;
    NSString *unit = item[@"unit"] ?: @"";
    NSString *defaultsKey = [@"NovaUI.slider." stringByAppendingString:key];
    CGFloat cur = [NSUserDefaults.standardUserDefaults floatForKey:defaultsKey];
    CGFloat next = MAX(minV, MIN(maxV, cur + dir * step));
    [NSUserDefaults.standardUserDefaults setFloat:next forKey:defaultsKey];
    if (valLbl) {
        BOOL isIntStep = (fabs(step - round(step)) < 1e-4);
        valLbl.text = isIntStep
            ? [NSString stringWithFormat:@"%ld%@", (long)llround(next), unit]
            : [NSString stringWithFormat:@"%.2f%@", next, unit];
    }
    NovaUISliderHandler handler = item[@"handler"];
    if (handler) handler(next);
}

- (void)rebuildRows {
    NSArray<UIView *> *existingRows = [self.moduleStack.arrangedSubviews copy];
    for (UIView *view in existingRows) {
        [self.moduleStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSString *activeMenuKey = [self currentSubmenuKey];
    BOOL inSubmenu = (activeMenuKey.length > 0);
    self.submenuBackButton.hidden = !inSubmenu;
    if (inSubmenu) {
        self.sectionLabel.text = [NSString stringWithFormat:@"                  ›  %@", [self titleForSubmenuKey:activeMenuKey]];
    } else {
        self.sectionLabel.text = @"功能模块";
    }

    NSArray<NSDictionary *> *sourceItems = nil;
    if ([activeMenuKey isEqualToString:@"__nova_logs__"] || [activeMenuKey isEqualToString:@"__nova_config__"]) {
        sourceItems = [self syntheticItemsForUtilitySubmenu:activeMenuKey];
    } else {
        sourceItems = self.modules;
    }

    NSMutableArray<NSDictionary *> *filteredItems = [NSMutableArray array];
    NSString *kw = [self.searchKeyword lowercaseString];
    NSUInteger activeSwitchCount = 0;

    for (NSDictionary *m in self.modules) {
        if (![m isKindOfClass:NSDictionary.class]) continue;
        NSString *t = m[@"type"] ?: @"switch";
        NSString *k = m[@"key"] ?: @"";
        if ([t isEqualToString:@"switch"] && k.length > 0) {
            if ([NSUserDefaults.standardUserDefaults boolForKey:[@"NovaUI.module." stringByAppendingString:k]]) {
                activeSwitchCount++;
            }
        }
    }
    self.statusTextLabel.text = activeSwitchCount > 0
        ? [NSString stringWithFormat:@"运行中 · 已开启 %lu 项", (unsigned long)activeSwitchCount]
        : @"运行中";

    for (NSDictionary *m in sourceItems) {
        if (![m isKindOfClass:NSDictionary.class]) continue;
        NSString *parentKey = m[@"parentKey"] ?: @"";
        if (kw.length > 0) {
            // When searching, search across all levels!
            NSString *titleLower = [(m[@"title"] ?: @"") lowercaseString];
            NSString *subLower = [(m[@"subtitle"] ?: @"") lowercaseString];
            NSString *keyLower = [(m[@"key"] ?: @"") lowercaseString];
            if (![titleLower containsString:kw] && ![subLower containsString:kw] && ![keyLower containsString:kw]) {
                continue;
            }
        } else {
            if (![parentKey isEqualToString:activeMenuKey]) {
                continue;
            }
        }
        [filteredItems addObject:m];
    }

    self.sectionCountLabel.text = [NSString stringWithFormat:@"%lu 项", (unsigned long)filteredItems.count];

    for (NSDictionary *module in filteredItems) {
        NSString *key = [module[@"key"] isKindOfClass:NSString.class] ? module[@"key"] : @"";
        NSString *type = [module[@"type"] isKindOfClass:NSString.class] ? module[@"type"] : @"switch";
        NSString *titleText = ([module[@"title"] isKindOfClass:NSString.class] && [module[@"title"] length] > 0) ? module[@"title"] : @"未命名模块";
        NSString *subtitleText = [module[@"subtitle"] isKindOfClass:NSString.class] ? module[@"subtitle"] : @"";
        NSString *iconName = ([module[@"icon"] isKindOfClass:NSString.class] && [module[@"icon"] length] > 0) ? module[@"icon"] : @"circle";

        UIView *row = [UIView new];
        row.translatesAutoresizingMaskIntoConstraints = NO;
        row.layer.cornerRadius = 16;
        row.layer.cornerCurve = kCACornerCurveContinuous;
        objc_setAssociatedObject(row, kNovaItemDictKey, module, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        CGFloat rowHeight = [type isEqualToString:@"slider"] ? 78.0 : ([type isEqualToString:@"info"] ? 52.0 : 62.0);
        [row.heightAnchor constraintEqualToConstant:rowHeight].active = YES;

        UITapGestureRecognizer *rowTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rowTapped:)];
        rowTap.cancelsTouchesInView = NO;
        rowTap.delegate = self;
        [row addGestureRecognizer:rowTap];

        UIView *iconTile = [UIView new];
        iconTile.translatesAutoresizingMaskIntoConstraints = NO;
        iconTile.layer.cornerRadius = 12;
        iconTile.tag = 112;
        [row addSubview:iconTile];
        UIImageView *icon = [[UIImageView alloc] initWithImage:NovaPanelSymbol(iconName, @"circle", 16)];
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        [iconTile addSubview:icon];

        UILabel *title = [UILabel new];
        title.translatesAutoresizingMaskIntoConstraints = NO;
        title.text = titleText;
        title.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        title.lineBreakMode = NSLineBreakByTruncatingTail;
        [row addSubview:title];

        UILabel *subtitle = [UILabel new];
        subtitle.translatesAutoresizingMaskIntoConstraints = NO;
        subtitle.text = subtitleText;
        subtitle.font = [UIFont systemFontOfSize:10];
        subtitle.tag = 111;
        subtitle.numberOfLines = 1;
        subtitle.lineBreakMode = NSLineBreakByTruncatingTail;
        subtitle.hidden = (subtitleText.length == 0);
        [row addSubview:subtitle];

        [NSLayoutConstraint activateConstraints:@[
            [iconTile.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:10],
            [iconTile.topAnchor constraintEqualToAnchor:row.topAnchor constant:[type isEqualToString:@"info"] ? 8.0 : 11.0],
            [iconTile.widthAnchor constraintEqualToConstant:[type isEqualToString:@"info"] ? 36.0 : 40.0],
            [iconTile.heightAnchor constraintEqualToConstant:[type isEqualToString:@"info"] ? 36.0 : 40.0],
            [icon.centerXAnchor constraintEqualToAnchor:iconTile.centerXAnchor],
            [icon.centerYAnchor constraintEqualToAnchor:iconTile.centerYAnchor],
            [icon.widthAnchor constraintEqualToConstant:18],
            [icon.heightAnchor constraintEqualToConstant:18],
            [title.leadingAnchor constraintEqualToAnchor:iconTile.trailingAnchor constant:11]
        ]];

        if ([type isEqualToString:@"slider"]) {
            CGFloat minV = [module[@"minValue"] doubleValue];
            CGFloat maxV = [module[@"maxValue"] doubleValue];
            if (maxV <= minV) maxV = minV + 100.0;
            NSString *unit = module[@"unit"] ?: @"";
            NSString *defaultsKey = [@"NovaUI.slider." stringByAppendingString:key];
            CGFloat curVal = ([NSUserDefaults.standardUserDefaults objectForKey:defaultsKey] != nil)
                ? [NSUserDefaults.standardUserDefaults floatForKey:defaultsKey]
                : [module[@"defaultValue"] doubleValue];
            curVal = MAX(minV, MIN(maxV, isfinite(curVal) ? curVal : minV));

            UILabel *valBadge = [UILabel new];
            valBadge.translatesAutoresizingMaskIntoConstraints = NO;
            valBadge.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightBold];
            valBadge.text = [NSString stringWithFormat:@"%.2f%@", curVal, unit];
            valBadge.tag = 113;
            [row addSubview:valBadge];

            UISlider *slider = [UISlider new];
            slider.translatesAutoresizingMaskIntoConstraints = NO;
            slider.minimumValue = minV;
            slider.maximumValue = maxV;
            slider.value = curVal;
            objc_setAssociatedObject(slider, kNovaItemDictKey, module, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(slider, kNovaValueLabelKey, valBadge, OBJC_ASSOCIATION_ASSIGN);
            [slider addTarget:self action:@selector(moduleSliderChanged:) forControlEvents:UIControlEventValueChanged];
            [row addSubview:slider];

            [NSLayoutConstraint activateConstraints:@[
                [title.topAnchor constraintEqualToAnchor:row.topAnchor constant:11],
                [valBadge.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
                [valBadge.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
                [title.trailingAnchor constraintLessThanOrEqualToAnchor:valBadge.leadingAnchor constant:-8],
                [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
                [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:valBadge.leadingAnchor constant:-8],
                [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],
                [slider.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
                [slider.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
                [slider.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-8],
                [slider.heightAnchor constraintEqualToConstant:24]
            ]];
        } else if ([type isEqualToString:@"stepper"]) {
            CGFloat step = [module[@"stepValue"] doubleValue];
            if (step <= 0) step = 1.0;
            NSString *unit = module[@"unit"] ?: @"";
            NSString *defaultsKey = [@"NovaUI.slider." stringByAppendingString:key];
            CGFloat curVal = ([NSUserDefaults.standardUserDefaults objectForKey:defaultsKey] != nil)
                ? [NSUserDefaults.standardUserDefaults floatForKey:defaultsKey]
                : [module[@"defaultValue"] doubleValue];
            BOOL isIntStep = (fabs(step - round(step)) < 1e-4);

            UIButton *minusBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            minusBtn.translatesAutoresizingMaskIntoConstraints = NO;
            minusBtn.layer.cornerRadius = 8;
            minusBtn.layer.borderWidth = 1.0;
            minusBtn.tag = 114;
            minusBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
            [minusBtn setTitle:@"-" forState:UIControlStateNormal];
            [row addSubview:minusBtn];

            UILabel *valLbl = [UILabel new];
            valLbl.translatesAutoresizingMaskIntoConstraints = NO;
            valLbl.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightBold];
            valLbl.textAlignment = NSTextAlignmentCenter;
            valLbl.text = isIntStep
                ? [NSString stringWithFormat:@"%ld%@", (long)llround(curVal), unit]
                : [NSString stringWithFormat:@"%.2f%@", curVal, unit];
            valLbl.tag = 113;
            [row addSubview:valLbl];

            UIButton *plusBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            plusBtn.translatesAutoresizingMaskIntoConstraints = NO;
            plusBtn.layer.cornerRadius = 8;
            plusBtn.layer.borderWidth = 1.0;
            plusBtn.tag = 114;
            plusBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
            [plusBtn setTitle:@"+" forState:UIControlStateNormal];
            [row addSubview:plusBtn];

            objc_setAssociatedObject(minusBtn, kNovaItemDictKey, module, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(minusBtn, kNovaValueLabelKey, valLbl, OBJC_ASSOCIATION_ASSIGN);
            objc_setAssociatedObject(plusBtn, kNovaItemDictKey, module, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(plusBtn, kNovaValueLabelKey, valLbl, OBJC_ASSOCIATION_ASSIGN);
            [minusBtn addTarget:self action:@selector(stepperMinusTapped:) forControlEvents:UIControlEventTouchUpInside];
            [plusBtn addTarget:self action:@selector(stepperPlusTapped:) forControlEvents:UIControlEventTouchUpInside];

            NSLayoutConstraint *titleVertical = subtitleText.length > 0
                ? [title.topAnchor constraintEqualToAnchor:row.topAnchor constant:13]
                : [title.centerYAnchor constraintEqualToAnchor:row.centerYAnchor];
            [NSLayoutConstraint activateConstraints:@[
                titleVertical,
                [title.trailingAnchor constraintLessThanOrEqualToAnchor:minusBtn.leadingAnchor constant:-6],
                [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
                [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:minusBtn.leadingAnchor constant:-6],
                [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:3],
                [plusBtn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-10],
                [plusBtn.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
                [plusBtn.widthAnchor constraintEqualToConstant:26],
                [plusBtn.heightAnchor constraintEqualToConstant:26],
                [valLbl.trailingAnchor constraintEqualToAnchor:plusBtn.leadingAnchor constant:-4],
                [valLbl.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
                [valLbl.widthAnchor constraintGreaterThanOrEqualToConstant:42],
                [minusBtn.trailingAnchor constraintEqualToAnchor:valLbl.leadingAnchor constant:-4],
                [minusBtn.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
                [minusBtn.widthAnchor constraintEqualToConstant:26],
                [minusBtn.heightAnchor constraintEqualToConstant:26]
            ]];
        } else if ([type isEqualToString:@"submenu"] || [type isEqualToString:@"action"] || [type isEqualToString:@"select"] || [type isEqualToString:@"input"]) {
            UIButton *rightBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            rightBtn.translatesAutoresizingMaskIntoConstraints = NO;
            rightBtn.layer.cornerRadius = 10;
            rightBtn.layer.borderWidth = 1.0;
            rightBtn.tag = 114;
            rightBtn.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
            objc_setAssociatedObject(rightBtn, kNovaItemDictKey, module, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [rightBtn addTarget:self action:@selector(actionRowButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

            NSString *btnText = @"执行";
            if ([type isEqualToString:@"submenu"]) {
                NSUInteger childCnt = [self countChildItemsForSubmenuKey:key];
                btnText = childCnt > 0 ? [NSString stringWithFormat:@" %lu 项 › ", (unsigned long)childCnt] : @" 进入 › ";
            } else if ([type isEqualToString:@"select"]) {
                NSArray<NSString *> *opts = [module[@"options"] isKindOfClass:NSArray.class] ? module[@"options"] : @[@"默认"];
                NSInteger idx = [NSUserDefaults.standardUserDefaults integerForKey:[@"NovaUI.select." stringByAppendingString:key]];
                if (idx < 0 || idx >= (NSInteger)opts.count) idx = 0;
                btnText = [NSString stringWithFormat:@" %@ ▾ ", opts[idx]];
            } else if ([type isEqualToString:@"input"]) {
                NSString *savedStr = [NSUserDefaults.standardUserDefaults stringForKey:[@"NovaUI.input." stringByAppendingString:key]] ?: (module[@"defaultValue"] ?: @"");
                NSString *shortStr = savedStr.length > 7 ? [[savedStr substringToIndex:7] stringByAppendingString:@"…"] : (savedStr.length > 0 ? savedStr : @"设置");
                btnText = [NSString stringWithFormat:@" %@ ✎ ", shortStr];
            } else {
                btnText = [NSString stringWithFormat:@" %@ ", module[@"buttonTitle"] ?: @"执行"];
            }
            [rightBtn setTitle:btnText forState:UIControlStateNormal];
            [row addSubview:rightBtn];

            NSLayoutConstraint *titleVertical = subtitleText.length > 0
                ? [title.topAnchor constraintEqualToAnchor:row.topAnchor constant:13]
                : [title.centerYAnchor constraintEqualToAnchor:row.centerYAnchor];
            [NSLayoutConstraint activateConstraints:@[
                titleVertical,
                [title.trailingAnchor constraintLessThanOrEqualToAnchor:rightBtn.leadingAnchor constant:-8],
                [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
                [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:rightBtn.leadingAnchor constant:-8],
                [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:3],
                [rightBtn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-10],
                [rightBtn.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
                [rightBtn.heightAnchor constraintEqualToConstant:28],
                [rightBtn.widthAnchor constraintGreaterThanOrEqualToConstant:58]
            ]];
        } else if ([type isEqualToString:@"info"]) {
            UILabel *infoVal = [UILabel new];
            infoVal.translatesAutoresizingMaskIntoConstraints = NO;
            infoVal.text = [module[@"valueText"] isKindOfClass:NSString.class] ? module[@"valueText"] : @"";
            infoVal.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightSemibold];
            infoVal.textAlignment = NSTextAlignmentRight;
            infoVal.tag = 113;
            [row addSubview:infoVal];

            [NSLayoutConstraint activateConstraints:@[
                [title.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
                [infoVal.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
                [infoVal.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
                [title.trailingAnchor constraintLessThanOrEqualToAnchor:infoVal.leadingAnchor constant:-8]
            ]];
        } else {
            // Default: Switch Row
            NSString *customDefKey = module[@"customDefaultsKey"];
            NSString *defaultsKey = customDefKey.length > 0 ? customDefKey : [@"NovaUI.module." stringByAppendingString:key];
            NovaModuleSwitch *toggle = [NovaModuleSwitch new];
            toggle.translatesAutoresizingMaskIntoConstraints = NO;
            toggle.on = key.length > 0 ? [NSUserDefaults.standardUserDefaults boolForKey:defaultsKey] : NO;
            toggle.onTintColor = [UIColor colorWithRed:0.95 green:0.22 blue:0.68 alpha:1];
            toggle.transform = CGAffineTransformMakeScale(0.80, 0.80);
            [toggle setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
            [toggle setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
            [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
            [row addSubview:toggle];

            objc_setAssociatedObject(toggle, kNovaModuleKey, defaultsKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
            objc_setAssociatedObject(toggle, kNovaItemDictKey, module, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            id handlerObj = module[@"handler"];
            if (handlerObj && handlerObj != [NSNull null]) {
                objc_setAssociatedObject(toggle, kNovaModuleHandlerKey, handlerObj, OBJC_ASSOCIATION_COPY_NONATOMIC);
            }

            NSLayoutConstraint *titleVertical = subtitleText.length > 0
                ? [title.topAnchor constraintEqualToAnchor:row.topAnchor constant:13]
                : [title.centerYAnchor constraintEqualToAnchor:row.centerYAnchor];

            [NSLayoutConstraint activateConstraints:@[
                [title.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-8],
                titleVertical,
                [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
                [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-8],
                [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:3],
                [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-9],
                [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
            ]];
        }
        [self.moduleStack addArrangedSubview:row];
    }
    [self applyTheme:self.currentTheme];
}

- (void)reloadModules:(NSArray<NSDictionary *> *)modules title:(NSString *)title {
    self.modules = [modules isKindOfClass:NSArray.class] ? [modules copy] : @[];
    NSString *trimmedTitle = NovaPanelTrimmedString(title);
    self.panelTitle = trimmedTitle.length > 0 ? [trimmedTitle copy] : @"NOVA 控制中心";
    self.heading.text = self.panelTitle;
    [self rebuildRows];
}

- (void)themeButtonTapped:(UIButton *)sender {
    if (!sender) return;
    [self endEditing:YES];
    self.currentTheme = NovaPanelNormalizeTheme(sender.tag);
    [NSUserDefaults.standardUserDefaults setInteger:self.currentTheme forKey:@"NovaUI.theme"];
    [self applyTheme:self.currentTheme];
}

#pragma mark - Unified Theme Synchronization Engine (Main Card + Submenus + Modals + Toasts)

- (void)applyTheme:(NSInteger)theme {
    theme = NovaPanelNormalizeTheme(theme);
    self.currentTheme = theme;
    BOOL isIOS26 = NovaPanelIsIOS26OrLater();
    UIColor *pink = [UIColor colorWithRed:0.95 green:0.22 blue:0.68 alpha:1];
    UIColor *textColor, *secondary, *cardColor, *rowColor, *iconTileColor, *borderColor, *rowBorderColor;
    CGFloat rowBorderWidth = 0.0;
    BOOL isLightGlass = NO;

    switch (theme) {
        case 1: // 浅色 (Light)
            cardColor = [UIColor colorWithWhite:0.98 alpha:isIOS26 ? 0.82 : 0.96];
            textColor = [UIColor colorWithWhite:0.10 alpha:1];
            secondary = [UIColor colorWithWhite:0.43 alpha:1];
            rowColor = [UIColor colorWithWhite:0.92 alpha:isIOS26 ? 0.72 : 1.0];
            iconTileColor = [UIColor colorWithRed:1 green:0.84 blue:0.94 alpha:1];
            borderColor = [UIColor colorWithWhite:0.86 alpha:1];
            rowBorderColor = [UIColor colorWithWhite:1.0 alpha:0.5];
            isLightGlass = YES;
            self.backdrop.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
            self.backdrop.alpha = 0.45;
            self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
            self.cardBlurView.hidden = !isIOS26;
            self.cardBlurView.effect = NovaPanelCreateLiquidGlassEffect(NO);
            self.cardGlassSheenLayer.hidden = !isIOS26;
            break;
        case 2: // 玻璃 / 液态玻璃 (Real Optical Frosted & iOS 26+ Liquid Glass)
            cardColor = [UIColor colorWithRed:0.92 green:0.97 blue:1.0 alpha:0.16];
            textColor = [UIColor colorWithRed:0.06 green:0.10 blue:0.18 alpha:0.95];
            secondary = [UIColor colorWithRed:0.18 green:0.26 blue:0.38 alpha:0.78];
            rowColor = [UIColor colorWithWhite:1.0 alpha:0.36];
            iconTileColor = [UIColor colorWithWhite:1.0 alpha:0.52];
            borderColor = [UIColor colorWithWhite:1.0 alpha:0.84];
            rowBorderColor = [UIColor colorWithWhite:1.0 alpha:0.65];
            rowBorderWidth = 0.9;
            pink = [UIColor colorWithRed:0.08 green:0.48 blue:0.96 alpha:1.0];
            isLightGlass = YES;
            self.backdrop.effect = nil;
            self.backdrop.alpha = 0.0;
            self.backgroundColor = [UIColor colorWithRed:0.04 green:0.08 blue:0.16 alpha:0.18];
            self.cardBlurView.hidden = NO;
            self.cardBlurView.effect = NovaPanelCreateLiquidGlassEffect(NO);
            self.cardGlassSheenLayer.hidden = NO;
            break;
        case 3: // 极简 (Minimal Obsidian)
            cardColor = [UIColor colorWithWhite:0.03 alpha:isIOS26 ? 0.78 : 0.98];
            textColor = UIColor.whiteColor;
            secondary = [UIColor colorWithWhite:1 alpha:0.55];
            rowColor = [UIColor colorWithWhite:1 alpha:0.045];
            iconTileColor = [UIColor colorWithWhite:1 alpha:0.08];
            borderColor = [UIColor colorWithWhite:1 alpha:0.14];
            rowBorderColor = [UIColor colorWithWhite:1 alpha:0.08];
            self.backdrop.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            self.backdrop.alpha = 0.68;
            self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.44];
            self.cardBlurView.hidden = !isIOS26;
            self.cardBlurView.effect = NovaPanelCreateLiquidGlassEffect(YES);
            self.cardGlassSheenLayer.hidden = !isIOS26;
            break;
        case 4: // 霓虹 (Cyber Neon Cyan)
            cardColor = [UIColor colorWithRed:0.015 green:0.035 blue:0.09 alpha:isIOS26 ? 0.76 : 0.98];
            textColor = UIColor.whiteColor;
            secondary = [UIColor colorWithRed:0.50 green:0.84 blue:1 alpha:1];
            rowColor = [UIColor colorWithRed:0.02 green:0.12 blue:0.20 alpha:0.85];
            iconTileColor = [UIColor colorWithRed:0.02 green:0.25 blue:0.34 alpha:0.9];
            borderColor = [UIColor colorWithRed:0.0 green:0.88 blue:1 alpha:0.82];
            rowBorderColor = [UIColor colorWithRed:0.0 green:0.88 blue:1 alpha:0.28];
            rowBorderWidth = 0.6;
            pink = [UIColor colorWithRed:0.0 green:0.88 blue:1 alpha:1];
            self.backdrop.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            self.backdrop.alpha = 0.72;
            self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.46];
            self.cardBlurView.hidden = !isIOS26;
            self.cardBlurView.effect = NovaPanelCreateLiquidGlassEffect(YES);
            self.cardGlassSheenLayer.hidden = !isIOS26;
            break;
        default: // 暗粉 (Dark Pink)
            cardColor = [UIColor colorWithRed:0.055 green:0.065 blue:0.12 alpha:isIOS26 ? 0.76 : 0.96];
            textColor = UIColor.whiteColor;
            secondary = [UIColor colorWithWhite:1 alpha:0.58];
            rowColor = [UIColor colorWithWhite:1 alpha:0.06];
            iconTileColor = [UIColor colorWithRed:0.30 green:0.12 blue:0.31 alpha:0.82];
            borderColor = [pink colorWithAlphaComponent:0.62];
            rowBorderColor = [UIColor colorWithWhite:1 alpha:0.08];
            self.backdrop.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            self.backdrop.alpha = 0.70;
            self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.44];
            self.cardBlurView.hidden = !isIOS26;
            self.cardBlurView.effect = NovaPanelCreateLiquidGlassEffect(YES);
            self.cardGlassSheenLayer.hidden = !isIOS26;
            break;
    }

    BOOL overlayVisible = (self.appearanceOverlay && !self.appearanceOverlay.hidden);
    self.card.backgroundColor = cardColor;
    self.card.layer.borderWidth = (theme == 2) ? 1.4 : 1.0;
    self.card.layer.borderColor = borderColor.CGColor;
    self.accentLine.backgroundColor = pink;
    self.headerIcon.backgroundColor = [pink colorWithAlphaComponent:0.86];
    self.headerIcon.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.42].CGColor;
    self.headerBrandImageView.tintColor = UIColor.whiteColor;
    self.heading.textColor = textColor;
    self.subheading.textColor = secondary;

    for (UIButton *qBtn in @[self.quickLogsButton ?: [NSNull null], self.quickConfigButton ?: [NSNull null]]) {
        if (![qBtn isKindOfClass:UIButton.class]) continue;
        qBtn.backgroundColor = [pink colorWithAlphaComponent:0.14];
        qBtn.layer.borderColor = [pink colorWithAlphaComponent:0.45].CGColor;
        qBtn.tintColor = pink;
        [qBtn setTitleColor:pink forState:UIControlStateNormal];
    }

    self.searchContainer.backgroundColor = rowColor;
    self.searchContainer.layer.borderColor = borderColor.CGColor;
    self.searchIconView.tintColor = secondary;
    self.searchField.textColor = textColor;
    self.searchField.tintColor = pink;
    self.clearSearchButton.tintColor = secondary;
    if (self.searchField.placeholder.length > 0) {
        self.searchField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.searchField.placeholder attributes:@{
            NSForegroundColorAttributeName: [secondary colorWithAlphaComponent:0.65]
        }];
    }

    self.submenuBackButton.backgroundColor = [pink colorWithAlphaComponent:0.15];
    self.submenuBackButton.tintColor = pink;
    [self.submenuBackButton setTitleColor:pink forState:UIControlStateNormal];
    self.sectionLabel.textColor = secondary;
    self.sectionCountLabel.textColor = [secondary colorWithAlphaComponent:0.80];

    self.settingsButton.tintColor = overlayVisible ? pink : secondary;
    self.settingsButton.backgroundColor = overlayVisible ? [pink colorWithAlphaComponent:0.18] : [UIColor colorWithWhite:(theme == 1 || theme == 2) ? 0.2 : 0.8 alpha:0.10];
    self.closeButton.tintColor = secondary;
    self.closeButton.backgroundColor = [UIColor colorWithWhite:(theme == 1 || theme == 2) ? 0.2 : 0.8 alpha:0.10];
    self.themeLabel.textColor = secondary;
    self.themeHint.textColor = [secondary colorWithAlphaComponent:0.75];
    self.opacitySlider.minimumTrackTintColor = pink;

    // Style all module & submenu rows
    for (UIView *row in self.moduleStack.arrangedSubviews) {
        row.backgroundColor = rowColor;
        row.layer.borderWidth = rowBorderWidth;
        row.layer.borderColor = rowBorderColor ? rowBorderColor.CGColor : UIColor.clearColor.CGColor;
        for (UIView *sub in row.subviews) {
            if ([sub isKindOfClass:UILabel.class]) {
                if (sub.tag == 111) {
                    ((UILabel *)sub).textColor = secondary;
                } else if (sub.tag == 113) {
                    ((UILabel *)sub).textColor = pink;
                } else {
                    ((UILabel *)sub).textColor = textColor;
                }
            } else if ([sub isKindOfClass:UISwitch.class]) {
                ((UISwitch *)sub).onTintColor = pink;
            } else if ([sub isKindOfClass:UISlider.class]) {
                ((UISlider *)sub).minimumTrackTintColor = pink;
            } else if ([sub isKindOfClass:UIButton.class] && sub.tag == 114) {
                UIButton *actBtn = (UIButton *)sub;
                actBtn.backgroundColor = [pink colorWithAlphaComponent:0.16];
                actBtn.layer.borderColor = [pink colorWithAlphaComponent:0.55].CGColor;
                actBtn.tintColor = pink;
                [actBtn setTitleColor:pink forState:UIControlStateNormal];
            } else if (sub.tag == 112) {
                sub.backgroundColor = iconTileColor;
                for (UIView *inner in sub.subviews) {
                    if ([inner isKindOfClass:UIImageView.class]) {
                        ((UIImageView *)inner).tintColor = pink;
                    }
                }
            }
        }
    }

    // Synchronize Modal Dialog & Toast Banner with active theme!
    if (self.modalCard) {
        self.modalCard.backgroundColor = (theme == 2) ? [UIColor colorWithRed:0.94 green:0.98 blue:1.0 alpha:0.26] : [cardColor colorWithAlphaComponent:0.96];
        self.modalCard.layer.borderColor = borderColor.CGColor;
        self.modalBlurView.effect = NovaPanelCreateLiquidGlassEffect(!isLightGlass);
        self.modalGlassSheenLayer.hidden = (theme != 2 && !isIOS26);
        for (UIView *sub in self.modalCard.subviews) {
            if ([sub isKindOfClass:UILabel.class]) {
                UILabel *l = (UILabel *)sub;
                if (l.layer.cornerRadius > 0) {
                    l.backgroundColor = [pink colorWithAlphaComponent:0.18];
                    l.textColor = pink;
                } else {
                    l.textColor = (l.tag == 111) ? secondary : textColor;
                }
            } else if ([sub isKindOfClass:UITextField.class]) {
                UITextField *tf = (UITextField *)sub;
                tf.backgroundColor = rowColor;
                tf.textColor = textColor;
                tf.tintColor = pink;
                tf.layer.borderColor = borderColor.CGColor;
            } else if ([sub isKindOfClass:UIButton.class]) {
                UIButton *b = (UIButton *)sub;
                BOOL isPrimary = (b.tag == 501);
                b.backgroundColor = isPrimary ? [pink colorWithAlphaComponent:0.20] : rowColor;
                b.layer.borderColor = (isPrimary ? pink : borderColor).CGColor;
                [b setTitleColor:isPrimary ? pink : textColor forState:UIControlStateNormal];
            } else if ([sub isKindOfClass:UIStackView.class]) {
                for (UIView *arranged in ((UIStackView *)sub).arrangedSubviews) {
                    if ([arranged isKindOfClass:UIButton.class]) {
                        UIButton *b = (UIButton *)arranged;
                        BOOL isPrimary = (b.tag == 501);
                        b.backgroundColor = isPrimary ? [pink colorWithAlphaComponent:0.22] : rowColor;
                        b.layer.borderColor = (isPrimary ? pink : borderColor).CGColor;
                        [b setTitleColor:isPrimary ? pink : textColor forState:UIControlStateNormal];
                    } else if (arranged.tag == 510) {
                        arranged.backgroundColor = rowColor;
                        for (UIView *inner in arranged.subviews) {
                            if ([inner isKindOfClass:UILabel.class]) {
                                ((UILabel *)inner).textColor = (inner.tag == 111) ? secondary : textColor;
                            }
                        }
                    }
                }
            }
        }
    }

    if (self.toastBanner) {
        self.toastBanner.backgroundColor = (theme == 2) ? [UIColor colorWithWhite:1.0 alpha:0.35] : [cardColor colorWithAlphaComponent:0.92];
        self.toastBanner.layer.borderColor = [pink colorWithAlphaComponent:0.65].CGColor;
        self.toastBlurView.effect = NovaPanelCreateLiquidGlassEffect(!isLightGlass);
        self.toastIconView.tintColor = pink;
        self.toastMessageLabel.textColor = textColor;
    }

    for (UIButton *button in self.themeStack.arrangedSubviews) {
        BOOL selected = (button.tag == theme);
        button.backgroundColor = selected ? [pink colorWithAlphaComponent:0.18] : [UIColor colorWithWhite:(theme != 1 && theme != 2 ? 1 : 0) alpha:0.035];
        button.layer.borderColor = selected ? pink.CGColor : borderColor.CGColor;
        button.tintColor = selected ? pink : secondary;
        [button setTitleColor:selected ? pink : secondary forState:UIControlStateNormal];
    }
    for (UIView *view in self.appearanceOverlay.subviews) {
        if ([view isKindOfClass:UILabel.class]) {
            UILabel *label = (UILabel *)view;
            label.textColor = (label.font.pointSize >= 20) ? textColor : secondary;
        }
        if ([view isKindOfClass:UIButton.class]) {
            UIButton *button = (UIButton *)view;
            if (button == self.applyEntryIconButton || button == self.applyHeaderIconButton ||
                button == self.chooseEntryPhotoButton || button == self.chooseHeaderPhotoButton) {
                button.backgroundColor = [pink colorWithAlphaComponent:0.16];
                button.layer.borderColor = pink.CGColor;
                button.tintColor = pink;
                [button setTitleColor:pink forState:UIControlStateNormal];
            } else {
                button.tintColor = pink;
                [button setTitleColor:pink forState:UIControlStateNormal];
            }
        }
    }
    for (UITextField *tf in @[self.customHeaderIconField ?: [NSNull null], self.customIconField ?: [NSNull null]]) {
        if (![tf isKindOfClass:UITextField.class]) continue;
        tf.backgroundColor = rowColor;
        tf.textColor = textColor;
        tf.tintColor = pink;
        tf.layer.borderColor = borderColor.CGColor;
        if (tf.placeholder.length > 0) {
            tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:tf.placeholder attributes:@{
                NSForegroundColorAttributeName: [secondary colorWithAlphaComponent:0.65]
            }];
        }
    }
    self.appearanceOverlay.backgroundColor = UIColor.clearColor;
    for (UIButton *button in self.appearanceThemeStack.arrangedSubviews) {
        BOOL selected = (button.tag == theme);
        button.layer.borderColor = (selected ? pink : borderColor).CGColor;
        button.backgroundColor = selected ? [pink colorWithAlphaComponent:0.20] : rowColor;
        [button setTitleColor:selected ? pink : secondary forState:UIControlStateNormal];
        button.tintColor = selected ? pink : secondary;
    }

    NSArray<NSString *> *headerPresets = [NovaControlPanel presetHeaderIconSymbols];
    NSString *activeHeader = self.headerIconName.length > 0 ? self.headerIconName : @"nova.sakura";
    if ([activeHeader isEqualToString:@"asterisk"]) activeHeader = @"nova.sakura";
    for (UIButton *button in self.headerIconStack.arrangedSubviews) {
        NSString *presetSym = (button.tag >= 0 && button.tag < (NSInteger)headerPresets.count) ? headerPresets[button.tag] : @"";
        BOOL selected = [activeHeader isEqualToString:presetSym];
        button.layer.borderColor = (selected ? pink : borderColor).CGColor;
        button.backgroundColor = selected ? [pink colorWithAlphaComponent:0.20] : rowColor;
        [button setTitleColor:selected ? pink : secondary forState:UIControlStateNormal];
        button.tintColor = selected ? pink : secondary;
    }

    NSInteger activeEntryStyle = NovaPanelNormalizeStyle([NSUserDefaults.standardUserDefaults integerForKey:@"NovaUI.entryStyle"]);
    for (UIButton *button in self.entryStyleStack.arrangedSubviews) {
        BOOL selected = (activeEntryStyle == button.tag);
        button.layer.borderColor = (selected ? pink : borderColor).CGColor;
        button.backgroundColor = selected ? [pink colorWithAlphaComponent:0.20] : rowColor;
        [button setTitleColor:selected ? pink : secondary forState:UIControlStateNormal];
        button.tintColor = selected ? pink : secondary;
    }

    NSArray<NSString *> *entryIconPresets = [NovaControlPanel presetEntryIconSymbols];
    NSString *savedCustomEntry = NovaPanelTrimmedString([NSUserDefaults.standardUserDefaults stringForKey:@"NovaUI.entryCustomIcon"]);
    for (UIButton *button in self.entryIconStack.arrangedSubviews) {
        NSString *presetSym = (button.tag >= 0 && button.tag < (NSInteger)entryIconPresets.count) ? entryIconPresets[button.tag] : @"";
        BOOL selected = [savedCustomEntry isEqualToString:presetSym];
        button.layer.borderColor = (selected ? pink : borderColor).CGColor;
        button.backgroundColor = selected ? [pink colorWithAlphaComponent:0.20] : rowColor;
        [button setTitleColor:selected ? pink : secondary forState:UIControlStateNormal];
        button.tintColor = selected ? pink : secondary;
    }
}

- (void)toggleChanged:(UISwitch *)sender {
    if (![sender isKindOfClass:UISwitch.class]) return;
    NSString *defaultsKey = objc_getAssociatedObject(sender, kNovaModuleKey);
    NSDictionary *item = objc_getAssociatedObject(sender, kNovaItemDictKey);
    NovaUIModuleHandler handler = objc_getAssociatedObject(sender, kNovaModuleHandlerKey);
    if (defaultsKey.length > 0) {
        [NSUserDefaults.standardUserDefaults setBool:sender.isOn forKey:defaultsKey];
    }
    if (handler) handler(sender.isOn);
    if (self.logEventHandler && [item isKindOfClass:NSDictionary.class]) {
        self.logEventHandler([NSString stringWithFormat:@"%@ -> %@", item[@"title"] ?: defaultsKey, sender.isOn ? @"ON" : @"OFF"], @"ACTION");
    }
    [self rebuildRows];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer.view == self) {
        if (touch.view && [touch.view isDescendantOfView:self.card]) {
            return NO;
        }
        return YES;
    }
    UIView *v = touch.view;
    while (v && v != gestureRecognizer.view) {
        if ([v isKindOfClass:UIControl.class]) {
            return NO;
        }
        v = v.superview;
    }
    return YES;
}

- (void)outsideTap:(UITapGestureRecognizer *)gesture {
    if (gesture && gesture.state != UIGestureRecognizerStateEnded) return;
    CGPoint cardPoint = [gesture locationInView:self.card];
    if (![self.card pointInside:cardPoint withEvent:nil]) {
        [self endEditing:YES];
        [self dismiss];
    }
}

- (UIWindow *)discoverTargetWindow {
    UIWindow *fgKeyWindow = nil;
    UIWindow *anyKeyWindow = nil;
    UIWindow *fgNormalWindow = nil;
    UIWindow *fgAnyWindow = nil;
    UIWindow *anyFallbackWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication.sharedApplication.connectedScenes copy]) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            BOOL isForeground = (ws.activationState == UISceneActivationStateForegroundActive ||
                                 ws.activationState == UISceneActivationStateForegroundInactive);
            for (UIWindow *candidate in [ws.windows copy]) {
                if (!NovaPanelIsUsableWindow(candidate)) continue;
                if (candidate.isKeyWindow) {
                    if (isForeground) { fgKeyWindow = candidate; break; }
                    if (!anyKeyWindow) anyKeyWindow = candidate;
                } else if (candidate.windowLevel == UIWindowLevelNormal) {
                    if (isForeground && !fgNormalWindow) fgNormalWindow = candidate;
                    if (!anyFallbackWindow) anyFallbackWindow = candidate;
                } else if (candidate.windowLevel < UIWindowLevelAlert) {
                    if (isForeground && !fgAnyWindow) fgAnyWindow = candidate;
                    if (!anyFallbackWindow) anyFallbackWindow = candidate;
                }
            }
            if (fgKeyWindow) break;
        }
    }
    if (fgKeyWindow) return fgKeyWindow;
    if (anyKeyWindow) return anyKeyWindow;
    if (fgNormalWindow) return fgNormalWindow;
    if (fgAnyWindow) return fgAnyWindow;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIWindow *legacyKey = UIApplication.sharedApplication.keyWindow;
    if (NovaPanelIsUsableWindow(legacyKey)) return legacyKey;
    for (UIWindow *candidate in [UIApplication.sharedApplication.windows copy]) {
        if (NovaPanelIsUsableWindow(candidate) && candidate.windowLevel < UIWindowLevelAlert) {
            return candidate;
        }
    }
#pragma clang diagnostic pop
    return anyFallbackWindow;
}

- (void)syncStateFromDefaults {
    BOOL hasOpacity = ([NSUserDefaults.standardUserDefaults objectForKey:@"NovaUI.entryOpacity"] != nil);
    CGFloat savedOpacity = NovaPanelClampOpacity(hasOpacity ? [NSUserDefaults.standardUserDefaults floatForKey:@"NovaUI.entryOpacity"] : 1.0);
    self.opacitySlider.value = savedOpacity;
    self.opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)round(savedOpacity * 100)];
    NSString *savedHeaderIcon = NovaPanelTrimmedString([NSUserDefaults.standardUserDefaults stringForKey:@"NovaUI.headerIcon"]);
    if ([savedHeaderIcon isEqualToString:@"asterisk"] || !savedHeaderIcon.length) {
        savedHeaderIcon = @"nova.sakura";
    }
    self.headerIconName = savedHeaderIcon;
    [self refreshHeaderIconViews];
    NSArray<NSString *> *headerPresets = [NovaControlPanel presetHeaderIconSymbols];
    if (self.customHeaderIconField && !self.customHeaderIconField.isFirstResponder) {
        if ([self.headerIconName isEqualToString:@"__custom_image__"]) {
            self.customHeaderIconField.text = @"[相册图片]";
        } else if (![headerPresets containsObject:self.headerIconName]) {
            self.customHeaderIconField.text = self.headerIconName;
        } else {
            self.customHeaderIconField.text = @"";
        }
    }
    NSString *savedCustomEntry = NovaPanelTrimmedString([NSUserDefaults.standardUserDefaults stringForKey:@"NovaUI.entryCustomIcon"]);
    if (self.customIconField && !self.customIconField.isFirstResponder) {
        if ([savedCustomEntry isEqualToString:@"__custom_image__"]) {
            self.customIconField.text = @"[相册图片]";
        } else if (![savedCustomEntry hasPrefix:@"nova."]) {
            self.customIconField.text = savedCustomEntry;
        } else {
            self.customIconField.text = @"";
        }
    }
    self.currentTheme = NovaPanelNormalizeTheme([NSUserDefaults.standardUserDefaults integerForKey:@"NovaUI.theme"]);
    [self applyTheme:self.currentTheme];
}

- (void)present {
    UIWindow *window = [self discoverTargetWindow];
    if (!window) return;

    [self syncStateFromDefaults];

    if (self.superview == window && !self.isDismissing) {
        self.frame = NovaPanelSanitizeFrame(window.bounds);
        [window bringSubviewToFront:self];
        return;
    }

    BOOL wasInWindow = (self.superview == window && self.isDismissing);
    self.isDismissing = NO;
    self.animationGeneration++;
    [self.layer removeAllAnimations];
    [self.card.layer removeAllAnimations];

    if (self.superview != window) {
        [self removeFromSuperview];
        [window addSubview:self];
    }
    self.frame = NovaPanelSanitizeFrame(window.bounds);
    [window bringSubviewToFront:self];

    if (!wasInWindow) {
        self.card.transform = CGAffineTransformIdentity;
        [self layoutIfNeeded];
        self.alpha = 0;
        self.card.transform = CGAffineTransformMakeScale(0.96, 0.96);
    }

    UIViewAnimationOptions options = UIViewAnimationOptionCurveEaseOut |
                                     UIViewAnimationOptionAllowUserInteraction |
                                     UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.88 initialSpringVelocity:0.2 options:options animations:^{
        self.alpha = 1;
        self.card.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)dismiss {
    if (!self.superview || self.isDismissing) return;
    [self endEditing:YES];
    self.isDismissing = YES;
    NSUInteger generation = ++self.animationGeneration;
    UIViewAnimationOptions options = UIViewAnimationOptionCurveEaseIn |
                                     UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:0.18 delay:0 options:options animations:^{
        self.alpha = 0;
        self.card.transform = CGAffineTransformMakeScale(0.97, 0.97);
    } completion:^(BOOL finished) {
        if (!self.isDismissing || generation != self.animationGeneration) return;
        self.isDismissing = NO;
        [self removeFromSuperview];
        self.card.transform = CGAffineTransformIdentity;
        if (self.appearanceOverlay && !self.appearanceOverlay.hidden) {
            self.appearanceOverlay.hidden = YES;
            self.appearanceOverlay.contentOffset = CGPointZero;
            self.statusPill.hidden = NO;
            self.quickLogsButton.hidden = NO;
            self.quickConfigButton.hidden = NO;
            self.searchContainer.hidden = NO;
            self.sectionHeaderBar.hidden = NO;
            self.scrollView.hidden = NO;
            self.themeHeader.hidden = NO;
            [self applyTheme:self.currentTheme];
        }
        if (self.closeHandler) self.closeHandler();
    }];
}

@end
