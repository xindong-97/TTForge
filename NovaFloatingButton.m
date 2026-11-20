#import "NovaFloatingButton.h"
#import <math.h>

static void *kNovaSuperviewBoundsKVOContext = &kNovaSuperviewBoundsKVOContext;

static inline CGFloat NovaFloatingClampOpacity(CGFloat value) {
    if (!isfinite(value)) return 1.0;
    return MAX(0.35, MIN(1.0, value));
}

static inline NSInteger NovaFloatingNormalizeStyle(NSInteger style) {
    return (style >= 0 && style <= 4) ? style : 0;
}

static inline BOOL NovaFloatingIsValidDimension(CGFloat v) {
    return isfinite(v) && v > 0.0;
}

static inline CGRect NovaFloatingSanitizeFrame(CGRect frame) {
    if (CGRectIsNull(frame) || CGRectIsInfinite(frame)) {
        return CGRectMake(0, 0, 54, 54);
    }
    CGFloat x = isfinite(frame.origin.x) ? frame.origin.x : 0.0;
    CGFloat y = isfinite(frame.origin.y) ? frame.origin.y : 0.0;
    CGFloat w = NovaFloatingIsValidDimension(frame.size.width) ? frame.size.width : 54.0;
    CGFloat h = NovaFloatingIsValidDimension(frame.size.height) ? frame.size.height : 54.0;
    return CGRectMake(x, y, w, h);
}

static BOOL NovaFloatingIsIOS26OrLater(void) {
    if (@available(iOS 13.0, *)) {
        NSOperatingSystemVersion ver = [NSProcessInfo processInfo].operatingSystemVersion;
        return (ver.majorVersion >= 26);
    }
    return NO;
}

static UIVisualEffect *NovaFloatingCreateLiquidGlassEffect(void) {
    if (NovaFloatingIsIOS26OrLater()) {
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
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
}

// Center-crops and scales any arbitrary album photo to fit a square cleanly without aspect distortion
static UIImage *NovaFloatingAspectFillSquareImage(UIImage *source, CGFloat sideLength) {
    if (!source || sideLength <= 0) return nil;
    CGSize srcSize = source.size;
    if (!NovaFloatingIsValidDimension(srcSize.width) || !NovaFloatingIsValidDimension(srcSize.height)) {
        return source;
    }
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = MAX(2.0, UIScreen.mainScreen.scale);
    fmt.opaque = NO;
    CGSize targetSize = CGSizeMake(sideLength, sideLength);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:fmt];
    UIImage *rendered = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, sideLength, sideLength)] addClip];
        CGFloat scale = MAX(sideLength / srcSize.width, sideLength / srcSize.height);
        CGFloat drawW = srcSize.width * scale;
        CGFloat drawH = srcSize.height * scale;
        CGRect drawRect = CGRectMake((sideLength - drawW) / 2.0, (sideLength - drawH) / 2.0, drawW, drawH);
        [source drawInRect:drawRect];
    }];
    return [rendered imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

static NSCache<NSString *, UIImage *> *NovaFloatingIconCache(void) {
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSCache new];
        cache.countLimit = 64;
    });
    return cache;
}

// Bespoke CoreGraphics Vector Icon Renderer for built-in artistic icons:
// - "nova.sakura": True 5-petal Japanese cherry blossom with V-notched petals & stamen center
// - "nova.claw.slash": Fierce 3-slash diagonal predator claw tear marks with jagged edges & splinters
// - "nova.glass.orb": 3D refractive liquid glass orb with crescent specular highlight & caustic rim
// - "nova.neon.ring": Cyberpunk concentric energy ring with segmented tech arcs & diamond core
// - "nova.minimal.core": Precision 4-point concave star-compass inside orbital reticle
static UIImage *NovaFloatingDrawCustomVectorIcon(NSString *identifier, CGFloat pointSize) {
    if (![identifier hasPrefix:@"nova."]) return nil;
    CGFloat box = MAX(24.0, pointSize * 1.38);
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
                stamen.lineWidth = MAX(1.0, box * 0.042);
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
            ring.lineWidth = MAX(1.4, box * 0.065);
            [ring stroke];

            UIBezierPath *crescent = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r * 0.64 startAngle:M_PI * 1.12 endAngle:M_PI * 1.72 clockwise:YES];
            crescent.lineWidth = MAX(2.0, box * 0.095);
            crescent.lineCapStyle = kCGLineCapRound;
            [crescent stroke];

            UIBezierPath *caustic = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r * 0.66 startAngle:M_PI * 0.15 endAngle:M_PI * 0.52 clockwise:YES];
            caustic.lineWidth = MAX(1.1, box * 0.05);
            caustic.lineCapStyle = kCGLineCapRound;
            [caustic stroke];

            UIBezierPath *spark = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx - r * 0.22, cy - r * 0.48) radius:r * 0.09 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
            [spark fill];
        } else if ([identifier isEqualToString:@"nova.neon.ring"]) {
            for (int seg = 0; seg < 2; seg++) {
                CGFloat startA = seg * M_PI + 0.28;
                CGFloat endA = startA + M_PI - 0.56;
                UIBezierPath *arc = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r * 0.92 startAngle:startA endAngle:endA clockwise:YES];
                arc.lineWidth = MAX(1.8, box * 0.08);
                arc.lineCapStyle = kCGLineCapRound;
                [arc stroke];
            }
            UIBezierPath *innerRing = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy) radius:r * 0.56 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
            innerRing.lineWidth = MAX(1.2, box * 0.05);
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

static UIImage *NovaFloatingRenderTextIcon(NSString *text, CGFloat pointSize) {
    if (!text.length) return nil;
    NSString *clipped = text.length > 3 ? [text substringToIndex:3] : text;
    BOOL isASCII = [clipped canBeConvertedToEncoding:NSASCIIStringEncoding];
    CGSize canvasSize = CGSizeMake(30, 30);
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

static BOOL NovaFloatingLooksLikeSymbolIdentifier(NSString *str) {
    if (!str.length) return NO;
    if (![str canBeConvertedToEncoding:NSASCIIStringEncoding]) return NO;
    if ([str containsString:@"."] || str.length > 4) return YES;
    return NO;
}

static UIImage *NovaFloatingSymbol(NSString *primary, NSString *fallback) {
    NSString *trimmed = [primary isKindOfClass:NSString.class]
        ? [primary stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    NSString *cacheKey = [NSString stringWithFormat:@"%@|%@", trimmed, fallback ?: @""];
    UIImage *cached = [NovaFloatingIconCache() objectForKey:cacheKey];
    if (cached) return cached;

    UIImage *img = nil;
    if ([trimmed hasPrefix:@"nova."]) {
        img = NovaFloatingDrawCustomVectorIcon(trimmed, 21);
    }
    if (!img && [fallback hasPrefix:@"nova."] && !trimmed.length) {
        img = NovaFloatingDrawCustomVectorIcon(fallback, 21);
    }

    if (!img && @available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:21 weight:UIFontWeightSemibold];
        if (trimmed.length > 0 && ![trimmed hasPrefix:@"nova."]) {
            img = [UIImage systemImageNamed:trimmed withConfiguration:config];
            if (!img && [trimmed hasSuffix:@".filled"]) {
                NSString *legacy = [[trimmed substringToIndex:trimmed.length - 7] stringByAppendingString:@".fill"];
                img = [UIImage systemImageNamed:legacy withConfiguration:config];
            }
            if (!img && !NovaFloatingLooksLikeSymbolIdentifier(trimmed)) {
                img = NovaFloatingRenderTextIcon(trimmed, 21);
            }
        }
        if (!img && fallback.length) {
            if ([fallback hasPrefix:@"nova."]) {
                img = NovaFloatingDrawCustomVectorIcon(fallback, 21);
            } else {
                img = [UIImage systemImageNamed:fallback withConfiguration:config];
            }
        }
        if (!img && trimmed.length > 0 && ![trimmed hasPrefix:@"nova."]) {
            img = NovaFloatingRenderTextIcon(trimmed, 21);
        }
        if (!img) {
            img = NovaFloatingDrawCustomVectorIcon(@"nova.sakura", 21) ?: [UIImage systemImageNamed:@"circle.fill" withConfiguration:config];
        }
    }
    if (img) {
        [NovaFloatingIconCache() setObject:img forKey:cacheKey];
    }
    return img;
}

static BOOL NovaIsUsableWindow(UIWindow *candidate) {
    if (!candidate || candidate.isHidden || candidate.alpha <= 0.01) return NO;
    NSString *clsName = NSStringFromClass(candidate.class) ?: @"";
    if ([clsName containsString:@"Keyboard"] || [clsName containsString:@"TextEffects"]) return NO;
    return YES;
}

@interface NovaFloatingButton ()
@property (nonatomic, unsafe_unretained, nullable) UIView *observedSuperview;
@property (nonatomic, strong) UIVisualEffectView *glassEffectView;
@property (nonatomic, strong) CAGradientLayer *glassSheenLayer;
@property (nonatomic, strong) UIView *innerSpecularRing;
@property (nonatomic, strong) UIImageView *customPhotoImageView;
@property (nonatomic, assign) BOOL isDragging;
@property (nonatomic, assign) BOOL hasInitialized;
@property (nonatomic, assign) NSInteger currentStyle;
@end

@implementation NovaFloatingButton

- (instancetype)initWithFrame:(CGRect)frame {
    CGRect safeFrame = NovaFloatingSanitizeFrame(frame);
    if ((self = [super initWithFrame:safeFrame])) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        if (!NovaFloatingIsValidDimension(self.bounds.size.width) || !NovaFloatingIsValidDimension(self.bounds.size.height)) {
            self.frame = CGRectMake(0, 0, 54, 54);
        }
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    if (self.hasInitialized) return;
    self.hasInitialized = YES;
    self.magneticEdgeSnap = YES;
    self.layer.cornerRadius = MIN(self.bounds.size.width, self.bounds.size.height) / 2.0;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.borderWidth = 1.6;
    self.layer.shadowOpacity = 0.52;
    self.layer.shadowRadius = 14;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.titleLabel.font = [UIFont systemFontOfSize:25 weight:UIFontWeightMedium];

    _glassEffectView = [[UIVisualEffectView alloc] initWithEffect:NovaFloatingCreateLiquidGlassEffect()];
    _glassEffectView.frame = self.bounds;
    _glassEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _glassEffectView.userInteractionEnabled = NO;
    _glassEffectView.layer.cornerRadius = self.layer.cornerRadius;
    _glassEffectView.layer.cornerCurve = kCACornerCurveContinuous;
    _glassEffectView.clipsToBounds = YES;
    [self insertSubview:_glassEffectView atIndex:0];

    _glassSheenLayer = [CAGradientLayer layer];
    _glassSheenLayer.frame = self.bounds;
    _glassSheenLayer.startPoint = CGPointMake(0.0, 0.0);
    _glassSheenLayer.endPoint = CGPointMake(1.0, 1.0);
    _glassSheenLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.65].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.15].CGColor,
        (id)[UIColor colorWithRed:0.75 green:0.90 blue:1.0 alpha:0.05].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.44].CGColor
    ];
    _glassSheenLayer.locations = @[@0.0, @0.28, @0.68, @1.0];
    [_glassEffectView.contentView.layer addSublayer:_glassSheenLayer];

    // Full-bleed circular custom photo view (inset by 2pt so the glowing orb rim frames the user's photo cleanly)
    CGRect photoFrame = CGRectInset(self.bounds, 2.0, 2.0);
    _customPhotoImageView = [[UIImageView alloc] initWithFrame:photoFrame];
    _customPhotoImageView.userInteractionEnabled = NO;
    _customPhotoImageView.contentMode = UIViewContentModeScaleAspectFill;
    _customPhotoImageView.clipsToBounds = YES;
    _customPhotoImageView.layer.cornerRadius = MIN(photoFrame.size.width, photoFrame.size.height) / 2.0;
    _customPhotoImageView.hidden = YES;
    [self addSubview:_customPhotoImageView];

    // Jewel-like 3D inner specular bezel ring
    CGRect innerFrame = CGRectInset(self.bounds, 3.2, 3.2);
    _innerSpecularRing = [[UIView alloc] initWithFrame:innerFrame];
    _innerSpecularRing.userInteractionEnabled = NO;
    _innerSpecularRing.backgroundColor = UIColor.clearColor;
    _innerSpecularRing.layer.cornerRadius = MIN(innerFrame.size.width, innerFrame.size.height) / 2.0;
    _innerSpecularRing.layer.borderWidth = 0.75;
    _innerSpecularRing.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.36].CGColor;
    [self addSubview:_innerSpecularRing];

    [self addTarget:self action:@selector(didTouchDown) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(didTouchCancel) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchDragExit | UIControlEventTouchUpOutside];
    [self addTarget:self action:@selector(didTap) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
    pan.cancelsTouchesInView = YES;
    [self addGestureRecognizer:pan];
    self.accessibilityLabel = @"打开 NOVA 控制面板";

    NSString *savedCustomIcon = [NSUserDefaults.standardUserDefaults stringForKey:@"NovaUI.entryCustomIcon"];
    NSString *trimmedIcon = [savedCustomIcon isKindOfClass:NSString.class]
        ? [savedCustomIcon stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    _customIcon = trimmedIcon.length > 0 ? [trimmedIcon copy] : nil;
    NSInteger savedStyle = [NSUserDefaults.standardUserDefaults integerForKey:@"NovaUI.entryStyle"];
    [self applyEntryStyle:savedStyle];
    BOOL hasOpacity = ([NSUserDefaults.standardUserDefaults objectForKey:@"NovaUI.entryOpacity"] != nil);
    CGFloat opacity = hasOpacity ? [NSUserDefaults.standardUserDefaults floatForKey:@"NovaUI.entryOpacity"] : 1.0;
    self.alpha = NovaFloatingClampOpacity(opacity);
}

- (void)dealloc {
    if (_observedSuperview) {
        @try {
            [_observedSuperview removeObserver:self forKeyPath:@"bounds" context:kNovaSuperviewBoundsKVOContext];
        } @catch (NSException * _unused) {}
        _observedSuperview = nil;
    }
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];
    if (_observedSuperview != newSuperview) {
        if (_observedSuperview) {
            @try {
                [_observedSuperview removeObserver:self forKeyPath:@"bounds" context:kNovaSuperviewBoundsKVOContext];
            } @catch (NSException * _unused) {}
            _observedSuperview = nil;
        }
        if (newSuperview) {
            [newSuperview addObserver:self forKeyPath:@"bounds" options:NSKeyValueObservingOptionNew context:kNovaSuperviewBoundsKVOContext];
            _observedSuperview = newSuperview;
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == kNovaSuperviewBoundsKVOContext) {
        if (!self.isDragging && self.superview) {
            [self repositionInSuperview:self.superview];
        }
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    if (!self.isDragging && self.superview) {
        [self repositionInSuperview:self.superview];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (!self.isDragging && self.superview) {
        [self repositionInSuperview:self.superview];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (NovaFloatingIsValidDimension(self.bounds.size.width) && NovaFloatingIsValidDimension(self.bounds.size.height)) {
        CGFloat radius = MIN(self.bounds.size.width, self.bounds.size.height) / 2.0;
        self.layer.cornerRadius = radius;
        self.glassEffectView.frame = self.bounds;
        self.glassEffectView.layer.cornerRadius = radius;
        self.glassSheenLayer.frame = self.bounds;

        CGRect photoFrame = CGRectInset(self.bounds, 2.0, 2.0);
        self.customPhotoImageView.frame = photoFrame;
        self.customPhotoImageView.layer.cornerRadius = MIN(photoFrame.size.width, photoFrame.size.height) / 2.0;

        CGRect innerFrame = CGRectInset(self.bounds, 3.2, 3.2);
        self.innerSpecularRing.frame = innerFrame;
        self.innerSpecularRing.layer.cornerRadius = MIN(innerFrame.size.width, innerFrame.size.height) / 2.0;

        [self sendSubviewToBack:self.glassEffectView];
        [self bringSubviewToFront:self.customPhotoImageView];
        [self bringSubviewToFront:self.innerSpecularRing];
    }
}

- (void)applyCustomIcon:(NSString *)icon {
    NSString *trimmed = [icon isKindOfClass:NSString.class]
        ? [icon stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    self.customIcon = trimmed.length > 0 ? [trimmed copy] : nil;
    [self applyEntryStyle:self.currentStyle];
}

- (void)applyEntryStyle:(NSInteger)style {
    NSInteger normalizedStyle = NovaFloatingNormalizeStyle(style);
    self.currentStyle = normalizedStyle;
    UIColor *pink = [UIColor colorWithRed:0.95 green:0.22 blue:0.68 alpha:1];
    BOOL isIOS26 = NovaFloatingIsIOS26OrLater();
    self.layer.shadowColor = pink.CGColor;
    self.layer.borderWidth = 1.6;
    self.layer.shadowOpacity = 0.52;
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.84].CGColor;
    self.backgroundColor = [pink colorWithAlphaComponent:isIOS26 ? 0.62 : 0.88];
    self.glassEffectView.hidden = NO;
    self.glassEffectView.effect = NovaFloatingCreateLiquidGlassEffect();
    self.glassSheenLayer.hidden = NO;
    self.innerSpecularRing.hidden = NO;
    self.innerSpecularRing.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.38].CGColor;
    [self setImage:nil forState:UIControlStateNormal];

    NSString *defaultPrimary = @"nova.sakura";
    NSString *defaultFallback = @"nova.sakura";

    switch (normalizedStyle) {
        case 1: // Liquid Glass Orb (液态玻璃球)
            self.glassEffectView.hidden = NO;
            self.glassEffectView.effect = NovaFloatingCreateLiquidGlassEffect();
            self.backgroundColor = [UIColor colorWithRed:0.84 green:0.94 blue:1.0 alpha:0.18];
            self.layer.borderWidth = 1.6;
            self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.92].CGColor;
            self.layer.shadowColor = [UIColor colorWithRed:0.28 green:0.64 blue:1.0 alpha:1.0].CGColor;
            self.layer.shadowOpacity = 0.46;
            self.innerSpecularRing.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.55].CGColor;
            defaultPrimary = @"nova.glass.orb";
            defaultFallback = @"nova.glass.orb";
            self.tintColor = UIColor.whiteColor;
            break;
        case 2: // Neon Ring (脉冲霓虹环)
            self.glassEffectView.hidden = YES;
            self.backgroundColor = [UIColor colorWithRed:0.03 green:0.05 blue:0.11 alpha:0.96];
            self.layer.borderWidth = 2.4;
            self.layer.borderColor = pink.CGColor;
            self.layer.shadowOpacity = 0.88;
            self.innerSpecularRing.layer.borderColor = [pink colorWithAlphaComponent:0.42].CGColor;
            defaultPrimary = @"nova.neon.ring";
            defaultFallback = @"nova.neon.ring";
            self.tintColor = pink;
            break;
        case 3: // Minimal Core (极简晶核)
            self.glassEffectView.hidden = !isIOS26;
            self.backgroundColor = [UIColor colorWithWhite:0.06 alpha:isIOS26 ? 0.68 : 0.94];
            self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.32].CGColor;
            self.innerSpecularRing.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
            defaultPrimary = @"nova.minimal.core";
            defaultFallback = @"nova.minimal.core";
            self.tintColor = UIColor.whiteColor;
            break;
        case 4: // Fierce Claw Tear (撕裂感爪印)
            self.backgroundColor = [UIColor colorWithRed:0.90 green:0.12 blue:0.44 alpha:isIOS26 ? 0.66 : 0.90];
            self.layer.shadowColor = [UIColor colorWithRed:1.0 green:0.12 blue:0.42 alpha:1.0].CGColor;
            defaultPrimary = @"nova.claw.slash";
            defaultFallback = @"nova.claw.slash";
            self.tintColor = UIColor.whiteColor;
            break;
        default: // Sakura Blossom (五瓣樱花)
            defaultPrimary = @"nova.sakura";
            defaultFallback = @"nova.sakura";
            self.tintColor = UIColor.whiteColor;
            break;
    }

    [self sendSubviewToBack:self.glassEffectView];

    NSData *customImgData = [NSUserDefaults.standardUserDefaults dataForKey:@"NovaUI.entryCustomImageData"];
    if (customImgData.length > 0 && [self.customIcon isEqualToString:@"__custom_image__"]) {
        UIImage *rawImg = [UIImage imageWithData:customImgData];
        if (rawImg) {
            CGFloat targetSide = MAX(50.0, MIN(self.bounds.size.width, self.bounds.size.height) - 4.0);
            UIImage *cropped = NovaFloatingAspectFillSquareImage(rawImg, targetSide);
            self.customPhotoImageView.image = cropped ?: rawImg;
            self.customPhotoImageView.hidden = NO;
            [self setImage:nil forState:UIControlStateNormal];
            [self bringSubviewToFront:self.customPhotoImageView];
            [self bringSubviewToFront:self.innerSpecularRing];
            return;
        }
    }

    self.customPhotoImageView.hidden = YES;
    self.customPhotoImageView.image = nil;
    NSString *resolvedPrimary = self.customIcon.length > 0 ? self.customIcon : defaultPrimary;
    [self setImage:NovaFloatingSymbol(resolvedPrimary, defaultFallback) forState:UIControlStateNormal];
    [self bringSubviewToFront:self.innerSpecularRing];
}

- (void)didTouchDown {
    [UIView animateWithDuration:0.14 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformMakeScale(0.91, 0.91);
    } completion:nil];
}

- (void)didTouchCancel {
    [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.3 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (CGPoint)clampedCenterForPoint:(CGPoint)candidate inView:(UIView *)parent {
    CGFloat bw = NovaFloatingIsValidDimension(self.bounds.size.width) ? self.bounds.size.width : 54.0;
    CGFloat bh = NovaFloatingIsValidDimension(self.bounds.size.height) ? self.bounds.size.height : 54.0;
    CGFloat halfW = MAX(27.0, bw / 2.0);
    CGFloat halfH = MAX(27.0, bh / 2.0);
    if (!parent || !NovaFloatingIsValidDimension(parent.bounds.size.width) || !NovaFloatingIsValidDimension(parent.bounds.size.height)) {
        return CGPointMake(halfW, halfH);
    }
    UIEdgeInsets insets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        insets = parent.safeAreaInsets;
    }
    CGFloat safeLeft = (isfinite(insets.left) && insets.left > 0) ? insets.left : 0.0;
    CGFloat safeRight = (isfinite(insets.right) && insets.right > 0) ? insets.right : 0.0;
    CGFloat safeTop = (isfinite(insets.top) && insets.top > 0) ? insets.top : 0.0;
    CGFloat safeBottom = (isfinite(insets.bottom) && insets.bottom > 0) ? insets.bottom : 0.0;

    CGFloat minX = MAX(halfW + 6.0, safeLeft + halfW + 6.0);
    CGFloat maxX = MAX(minX, parent.bounds.size.width - safeRight - halfW - 6.0);
    CGFloat minY = MAX(halfH + 8.0, safeTop + halfH + 4.0);
    CGFloat maxY = MAX(minY, parent.bounds.size.height - MAX(8.0, safeBottom + 4.0) - halfH);

    CGFloat cx = isfinite(candidate.x) ? candidate.x : (parent.bounds.size.width - 38.0);
    CGFloat cy = isfinite(candidate.y) ? candidate.y : (parent.bounds.size.height * 0.55);
    cx = MAX(minX, MIN(maxX, cx));
    cy = MAX(minY, MIN(maxY, cy));
    return CGPointMake(cx, cy);
}

- (CGPoint)magneticEdgeSnappedCenterForPoint:(CGPoint)candidate inView:(UIView *)parent {
    CGPoint clamped = [self clampedCenterForPoint:candidate inView:parent];
    if (!self.magneticEdgeSnap || !parent || !NovaFloatingIsValidDimension(parent.bounds.size.width)) {
        return clamped;
    }
    CGFloat midX = parent.bounds.size.width / 2.0;
    CGPoint leftEdge = [self clampedCenterForPoint:CGPointMake(0.0, clamped.y) inView:parent];
    CGPoint rightEdge = [self clampedCenterForPoint:CGPointMake(parent.bounds.size.width, clamped.y) inView:parent];
    return (clamped.x < midX) ? leftEdge : rightEdge;
}

- (void)repositionInSuperview:(UIView *)parent {
    if (!parent || !NovaFloatingIsValidDimension(parent.bounds.size.width) || !NovaFloatingIsValidDimension(parent.bounds.size.height)) return;
    CGFloat x = [NSUserDefaults.standardUserDefaults doubleForKey:@"NovaUI.floatingX"];
    CGFloat y = [NSUserDefaults.standardUserDefaults doubleForKey:@"NovaUI.floatingY"];
    CGPoint targetCenter;
    if (isfinite(x) && isfinite(y) && x > 0 && x <= 1 && y > 0 && y <= 1) {
        targetCenter = CGPointMake(x * parent.bounds.size.width, y * parent.bounds.size.height);
    } else {
        targetCenter = CGPointMake(parent.bounds.size.width - 38, parent.bounds.size.height * 0.55);
    }
    self.center = [self clampedCenterForPoint:targetCenter inView:parent];
}

- (void)persistPositionInView:(UIView *)parent {
    if (!parent || !NovaFloatingIsValidDimension(parent.bounds.size.width) || !NovaFloatingIsValidDimension(parent.bounds.size.height)) return;
    CGPoint clamped = [self clampedCenterForPoint:self.center inView:parent];
    self.center = clamped;
    CGFloat normX = MAX(0.0001, MIN(1.0, clamped.x / parent.bounds.size.width));
    CGFloat normY = MAX(0.0001, MIN(1.0, clamped.y / parent.bounds.size.height));
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setDouble:normX forKey:@"NovaUI.floatingX"];
    [defaults setDouble:normY forKey:@"NovaUI.floatingY"];
}

- (void)didTap {
    [UIView animateWithDuration:0.24 delay:0 usingSpringWithDamping:0.68 initialSpringVelocity:0.4 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
    if (self.tapHandler) self.tapHandler();
}

- (void)didPan:(UIPanGestureRecognizer *)gesture {
    UIView *parent = self.superview;
    if (!parent || !gesture) return;
    CGPoint rawDelta = [gesture translationInView:parent];
    CGFloat dx = isfinite(rawDelta.x) ? rawDelta.x : 0.0;
    CGFloat dy = isfinite(rawDelta.y) ? rawDelta.y : 0.0;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.isDragging = YES;
        [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.transform = CGAffineTransformMakeScale(1.07, 1.07);
        } completion:nil];
        CGPoint target = CGPointMake(self.center.x + dx, self.center.y + dy);
        self.center = [self clampedCenterForPoint:target inView:parent];
        [gesture setTranslation:CGPointZero inView:parent];
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        self.isDragging = YES;
        CGPoint target = CGPointMake(self.center.x + dx, self.center.y + dy);
        self.center = [self clampedCenterForPoint:target inView:parent];
        [gesture setTranslation:CGPointZero inView:parent];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        CGPoint rawTarget = CGPointMake(self.center.x + dx, self.center.y + dy);
        CGPoint finalCenter = [self magneticEdgeSnappedCenterForPoint:rawTarget inView:parent];
        [gesture setTranslation:CGPointZero inView:parent];
        self.isDragging = NO;
        [UIView animateWithDuration:0.34 delay:0 usingSpringWithDamping:0.76 initialSpringVelocity:0.35 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.transform = CGAffineTransformIdentity;
            self.center = finalCenter;
        } completion:nil];
        self.center = finalCenter;
        [self persistPositionInView:parent];
    } else {
        self.isDragging = NO;
        self.transform = CGAffineTransformIdentity;
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
                if (!NovaIsUsableWindow(candidate)) continue;
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
    if (NovaIsUsableWindow(legacyKey)) return legacyKey;
    for (UIWindow *candidate in [UIApplication.sharedApplication.windows copy]) {
        if (NovaIsUsableWindow(candidate) && candidate.windowLevel < UIWindowLevelAlert) {
            return candidate;
        }
    }
#pragma clang diagnostic pop
    return anyFallbackWindow;
}

- (void)attachToAvailableWindow {
    UIWindow *window = [self discoverTargetWindow];
    if (!window) return;

    if (self.superview != window) {
        [self removeFromSuperview];
        [window addSubview:self];
    }

    [self repositionInSuperview:window];

    [window bringSubviewToFront:self];
    Class panelClass = NSClassFromString(@"NovaControlPanel");
    for (UIView *sub in [window.subviews copy]) {
        if ((panelClass && [sub isKindOfClass:panelClass]) || [NSStringFromClass(sub.class) isEqualToString:@"NovaControlPanel"]) {
            [window bringSubviewToFront:sub];
        }
    }
}

@end
