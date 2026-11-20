#import "NovaControlPanel.h"
#import "NovaUIManager.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface NovaControlPanel ()
@property (nonatomic, copy) NSString *panelTitle;
@property (nonatomic, copy) NSString *panelSubtitle;
@property (nonatomic, copy) NSArray<NSDictionary *> *modules;
@property (nonatomic, strong) UIVisualEffectView *backdrop;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIView *headerIcon;
@property (nonatomic, strong) UILabel *heading;
@property (nonatomic, strong) UILabel *subheading;
@property (nonatomic, strong) UILabel *sectionLabel;
@property (nonatomic, strong) UIStackView *moduleStack;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *themeStack;
@property (nonatomic, strong) UIView *accentLine;
@property (nonatomic, assign) NSInteger currentTheme;
@property (nonatomic, strong) UIView *appearanceOverlay;
@property (nonatomic, strong) UIStackView *entryStyleStack;
@property (nonatomic, strong) UIStackView *appearanceThemeStack;
@property (nonatomic, strong) UISlider *opacitySlider;
@property (nonatomic, strong) UILabel *opacityValueLabel;

@property (nonatomic, strong) UIView *pickerOverlay;
@property (nonatomic, strong) UILabel *pickerTitleLabel;
@property (nonatomic, strong) UILabel *pickerSubtitleLabel;
@property (nonatomic, strong) UIScrollView *pickerScrollView;
@property (nonatomic, strong) UIStackView *pickerStack;
@property (nonatomic, copy) NSArray<NSDictionary *> *activePickerOptions;
@property (nonatomic, copy) NovaUISelectionHandler activePickerHandler;
@property (nonatomic, strong) NSDictionary *activeSubmenuModule;

- (void)buildAppearanceOverlay;
- (void)buildPickerOverlay;
- (void)rebuildRows;
- (void)applyTheme:(NSInteger)theme;
- (void)toggleAppearanceSettings;
- (void)closePickerOverlay;
- (void)openPickerForModule:(NSDictionary *)module;
- (void)openSubmenuForModule:(NSDictionary *)module;
- (void)pickerOptionTapped:(UIControl *)sender;
- (void)submenuActionTapped:(UIControl *)sender;
- (void)themeButtonTapped:(UIButton *)sender;
- (void)entryStyleButtonTapped:(UIButton *)sender;
- (void)opacitySliderChanged:(UISlider *)sender;
- (void)toggleChanged:(UISwitch *)sender;
- (void)moduleRowTapped:(UIControl *)sender;
- (void)outsideTap:(UITapGestureRecognizer *)gesture;
@end

@implementation NovaControlPanel

- (instancetype)initWithTitle:(NSString *)title modules:(NSArray<NSDictionary *> *)modules {
    return [self initWithTitle:title subtitle:@"PLUGIN CONTROL CENTER  ·  v7.32" modules:modules];
}

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle modules:(NSArray<NSDictionary *> *)modules {
    if ((self = [super initWithFrame:UIScreen.mainScreen.bounds])) {
        _panelTitle = [title copy];
        _panelSubtitle = [subtitle copy] ?: @"PLUGIN CONTROL CENTER  ·  v7.32";
        _modules = [modules copy];
        _currentTheme = MAX(0, MIN(4, (NSInteger)[NSUserDefaults.standardUserDefaults integerForKey:@"NovaUI.theme"]));
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.48];

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
        [self addGestureRecognizer:outside];

        _card = [UIView new];
        _card.translatesAutoresizingMaskIntoConstraints = NO;
        _card.layer.cornerRadius = 30;
        _card.layer.cornerCurve = kCACornerCurveContinuous;
        _card.layer.borderWidth = 1;
        _card.layer.shadowColor = UIColor.blackColor.CGColor;
        _card.layer.shadowOpacity = 0.32;
        _card.layer.shadowRadius = 30;
        _card.layer.shadowOffset = CGSizeMake(0, 15);
        _card.clipsToBounds = NO;
        [self addSubview:_card];

        CGFloat maxWidth = 390;
        [NSLayoutConstraint activateConstraints:@[
            [_card.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_card.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_card.widthAnchor constraintLessThanOrEqualToConstant:maxWidth],
            [_card.widthAnchor constraintEqualToAnchor:self.widthAnchor constant:-32],
            [_card.heightAnchor constraintLessThanOrEqualToAnchor:self.heightAnchor constant:-88],
            [_card.heightAnchor constraintGreaterThanOrEqualToConstant:440]
        ]];

        _accentLine = [UIView new];
        _accentLine.translatesAutoresizingMaskIntoConstraints = NO;
        _accentLine.layer.cornerRadius = 2;
        [_card addSubview:_accentLine];
        [NSLayoutConstraint activateConstraints:@[
            [_accentLine.topAnchor constraintEqualToAnchor:_card.topAnchor constant:0],
            [_accentLine.centerXAnchor constraintEqualToAnchor:_card.centerXAnchor],
            [_accentLine.widthAnchor constraintEqualToConstant:42],
            [_accentLine.heightAnchor constraintEqualToConstant:4]
        ]];

        _headerIcon = [UIView new];
        _headerIcon.translatesAutoresizingMaskIntoConstraints = NO;
        _headerIcon.layer.cornerRadius = 19;
        _headerIcon.layer.cornerCurve = kCACornerCurveContinuous;
        [_card addSubview:_headerIcon];
        UIImageView *brand = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"asterisk"]];
        brand.translatesAutoresizingMaskIntoConstraints = NO;
        brand.tintColor = UIColor.whiteColor;
        brand.contentMode = UIViewContentModeScaleAspectFit;
        [_headerIcon addSubview:brand];
        [NSLayoutConstraint activateConstraints:@[
            [_headerIcon.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:20],
            [_headerIcon.topAnchor constraintEqualToAnchor:_card.topAnchor constant:24],
            [_headerIcon.widthAnchor constraintEqualToConstant:42],
            [_headerIcon.heightAnchor constraintEqualToConstant:42],
            [brand.centerXAnchor constraintEqualToAnchor:_headerIcon.centerXAnchor],
            [brand.centerYAnchor constraintEqualToAnchor:_headerIcon.centerYAnchor],
            [brand.widthAnchor constraintEqualToConstant:22],
            [brand.heightAnchor constraintEqualToConstant:22]
        ]];

        _heading = [UILabel new];
        _heading.translatesAutoresizingMaskIntoConstraints = NO;
        _heading.text = title;
        _heading.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
        [_card addSubview:_heading];

        _subheading = [UILabel new];
        _subheading.translatesAutoresizingMaskIntoConstraints = NO;
        _subheading.text = _panelSubtitle;
        _subheading.font = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];
        _subheading.textColor = [UIColor secondaryLabelColor];
        _subheading.adjustsFontSizeToFitWidth = YES;
        [_card addSubview:_subheading];

        UIButton *settings = [UIButton buttonWithType:UIButtonTypeSystem];
        settings.translatesAutoresizingMaskIntoConstraints = NO;
        settings.layer.cornerRadius = 15;
        [settings setImage:[UIImage systemImageNamed:@"slider.horizontal.3"] forState:UIControlStateNormal];
        settings.tintColor = [UIColor secondaryLabelColor];
        settings.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.10];
        [settings addTarget:self action:@selector(toggleAppearanceSettings) forControlEvents:UIControlEventTouchUpInside];
        [_card addSubview:settings];

        UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
        close.translatesAutoresizingMaskIntoConstraints = NO;
        close.layer.cornerRadius = 15;
        [close setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
        close.tintColor = [UIColor secondaryLabelColor];
        close.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.10];
        [close addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
        [_card addSubview:close];

        [NSLayoutConstraint activateConstraints:@[
            [_heading.leadingAnchor constraintEqualToAnchor:_headerIcon.trailingAnchor constant:12],
            [_heading.trailingAnchor constraintLessThanOrEqualToAnchor:settings.leadingAnchor constant:-8],
            [_heading.topAnchor constraintEqualToAnchor:_headerIcon.topAnchor constant:2],
            [_subheading.leadingAnchor constraintEqualToAnchor:_heading.leadingAnchor],
            [_subheading.trailingAnchor constraintEqualToAnchor:_heading.trailingAnchor],
            [_subheading.topAnchor constraintEqualToAnchor:_heading.bottomAnchor constant:4],
            [close.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-18],
            [close.centerYAnchor constraintEqualToAnchor:_headerIcon.centerYAnchor],
            [settings.trailingAnchor constraintEqualToAnchor:close.leadingAnchor constant:-7],
            [settings.centerYAnchor constraintEqualToAnchor:_headerIcon.centerYAnchor],
            [settings.widthAnchor constraintEqualToConstant:30],
            [settings.heightAnchor constraintEqualToConstant:30],
            [close.widthAnchor constraintEqualToConstant:30],
            [close.heightAnchor constraintEqualToConstant:30]
        ]];

        UIView *statusPill = [UIView new];
        statusPill.translatesAutoresizingMaskIntoConstraints = NO;
        statusPill.layer.cornerRadius = 10;
        statusPill.backgroundColor = [UIColor colorWithRed:0.18 green:0.80 blue:0.55 alpha:0.12];
        [_card addSubview:statusPill];
        UIView *statusDot = [UIView new];
        statusDot.translatesAutoresizingMaskIntoConstraints = NO;
        statusDot.backgroundColor = [UIColor colorWithRed:0.20 green:0.86 blue:0.57 alpha:1];
        statusDot.layer.cornerRadius = 3;
        [statusPill addSubview:statusDot];
        UILabel *statusText = [UILabel new];
        statusText.translatesAutoresizingMaskIntoConstraints = NO;
        statusText.text = @"运行中";
        statusText.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        statusText.textColor = [UIColor colorWithRed:0.35 green:0.92 blue:0.68 alpha:1];
        [statusPill addSubview:statusText];
        [NSLayoutConstraint activateConstraints:@[
            [statusPill.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:20],
            [statusPill.topAnchor constraintEqualToAnchor:_headerIcon.bottomAnchor constant:14],
            [statusPill.heightAnchor constraintEqualToConstant:24],
            [statusDot.leadingAnchor constraintEqualToAnchor:statusPill.leadingAnchor constant:9],
            [statusDot.centerYAnchor constraintEqualToAnchor:statusPill.centerYAnchor],
            [statusDot.widthAnchor constraintEqualToConstant:6],
            [statusDot.heightAnchor constraintEqualToConstant:6],
            [statusText.leadingAnchor constraintEqualToAnchor:statusDot.trailingAnchor constant:6],
            [statusText.trailingAnchor constraintEqualToAnchor:statusPill.trailingAnchor constant:-9],
            [statusText.centerYAnchor constraintEqualToAnchor:statusPill.centerYAnchor]
        ]];

        _sectionLabel = [UILabel new];
        _sectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _sectionLabel.text = @"功能模块";
        _sectionLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        _sectionLabel.textColor = [UIColor secondaryLabelColor];
        [_card addSubview:_sectionLabel];

        _scrollView = [UIScrollView new];
        _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.alwaysBounceVertical = YES;
        [_card addSubview:_scrollView];
        _moduleStack = [UIStackView new];
        _moduleStack.translatesAutoresizingMaskIntoConstraints = NO;
        _moduleStack.axis = UILayoutConstraintAxisVertical;
        _moduleStack.spacing = 8;
        [_scrollView addSubview:_moduleStack];

        UIView *themeHeader = [UIView new];
        themeHeader.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:themeHeader];
        UITapGestureRecognizer *appearanceTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleAppearanceSettings)];
        [themeHeader addGestureRecognizer:appearanceTap];
        UILabel *themeLabel = [UILabel new];
        themeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        themeLabel.text = @"外观与风格";
        themeLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        themeLabel.textColor = [UIColor secondaryLabelColor];
        [themeHeader addSubview:themeLabel];
        UILabel *themeHint = [UILabel new];
        themeHint.translatesAutoresizingMaskIntoConstraints = NO;
        themeHint.text = @"点击设置 ›";
        themeHint.font = [UIFont systemFontOfSize:10];
        themeHint.textColor = [UIColor tertiaryLabelColor];
        [themeHeader addSubview:themeHint];

        _themeStack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
        _themeStack.translatesAutoresizingMaskIntoConstraints = NO;
        _themeStack.axis = UILayoutConstraintAxisHorizontal;
        _themeStack.hidden = YES;
        _themeStack.distribution = UIStackViewDistributionFillEqually;
        _themeStack.spacing = 7;
        [_card addSubview:_themeStack];

        [NSLayoutConstraint activateConstraints:@[
            [_sectionLabel.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:20],
            [_sectionLabel.topAnchor constraintEqualToAnchor:statusPill.bottomAnchor constant:16],
            [_scrollView.topAnchor constraintEqualToAnchor:_sectionLabel.bottomAnchor constant:10],
            [_scrollView.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:16],
            [_scrollView.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-16],
            [_scrollView.bottomAnchor constraintEqualToAnchor:themeHeader.topAnchor constant:-12],
            [_scrollView.heightAnchor constraintGreaterThanOrEqualToConstant:280],
            [_moduleStack.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor],
            [_moduleStack.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor],
            [_moduleStack.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor],
            [_moduleStack.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor],
            [_moduleStack.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor],
            [themeHeader.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:20],
            [themeHeader.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-20],
            [themeHeader.bottomAnchor constraintEqualToAnchor:_themeStack.topAnchor constant:-8],
            [themeHeader.heightAnchor constraintEqualToConstant:18],
            [themeLabel.leadingAnchor constraintEqualToAnchor:themeHeader.leadingAnchor],
            [themeLabel.centerYAnchor constraintEqualToAnchor:themeHeader.centerYAnchor],
            [themeHint.trailingAnchor constraintEqualToAnchor:themeHeader.trailingAnchor],
            [themeHint.centerYAnchor constraintEqualToAnchor:themeHeader.centerYAnchor],
            [_themeStack.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:16],
            [_themeStack.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-16],
            [_themeStack.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-16],
            [_themeStack.heightAnchor constraintEqualToConstant:0]
        ]];

        [self buildAppearanceOverlay];
        [self buildPickerOverlay];
        [self rebuildRows];
        [self applyTheme:_currentTheme];
    }
    return self;
}

- (void)buildAppearanceOverlay {
    self.appearanceOverlay = [UIView new];
    self.appearanceOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.appearanceOverlay.hidden = YES;
    self.appearanceOverlay.layer.cornerRadius = 24;
    self.appearanceOverlay.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    [self.card addSubview:self.appearanceOverlay];

    UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
    back.translatesAutoresizingMaskIntoConstraints = NO;
    [back setImage:[UIImage systemImageNamed:@"chevron.left"] forState:UIControlStateNormal];
    [back setTitle:@"  返回控制面板" forState:UIControlStateNormal];
    back.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    back.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [back addTarget:self action:@selector(toggleAppearanceSettings) forControlEvents:UIControlEventTouchUpInside];
    [self.appearanceOverlay addSubview:back];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"外观与风格";
    title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    [self.appearanceOverlay addSubview:title];
    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"自定义控制面板与悬浮入口";
    subtitle.font = [UIFont systemFontOfSize:11];
    [self.appearanceOverlay addSubview:subtitle];

    UILabel *themeTitle = [UILabel new];
    themeTitle.translatesAutoresizingMaskIntoConstraints = NO;
    themeTitle.text = @"面板主题";
    themeTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.appearanceOverlay addSubview:themeTitle];
    self.appearanceThemeStack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    self.appearanceThemeStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.appearanceThemeStack.axis = UILayoutConstraintAxisHorizontal;
    self.appearanceThemeStack.distribution = UIStackViewDistributionFillEqually;
    self.appearanceThemeStack.spacing = 7;
    [self.appearanceOverlay addSubview:self.appearanceThemeStack];
    NSArray *names = @[@"暗粉", @"浅色", @"玻璃", @"极简", @"霓虹"];
    NSArray *symbols = @[@"moon.stars.fill", @"sun.max.fill", @"drop.fill", @"circle.lefthalf.filled", @"bolt.fill"];
    for (NSInteger i = 0; i < (NSInteger)names.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.tag = i; b.layer.cornerRadius = 12; b.layer.borderWidth = 1;
        b.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        [b setImage:[UIImage systemImageNamed:symbols[(NSUInteger)i]] forState:UIControlStateNormal];
        [b setTitle:[@"  " stringByAppendingString:names[(NSUInteger)i]] forState:UIControlStateNormal];
        [b addTarget:self action:@selector(themeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.appearanceThemeStack addArrangedSubview:b];
    }

    UILabel *entryTitle = [UILabel new];
    entryTitle.translatesAutoresizingMaskIntoConstraints = NO;
    entryTitle.text = @"悬浮入口样式";
    entryTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.appearanceOverlay addSubview:entryTitle];
    self.entryStyleStack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    self.entryStyleStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.entryStyleStack.axis = UILayoutConstraintAxisHorizontal;
    self.entryStyleStack.distribution = UIStackViewDistributionFillEqually;
    self.entryStyleStack.spacing = 7;
    [self.appearanceOverlay addSubview:self.entryStyleStack];
    NSArray *entryNames = @[@"樱花", @"玻璃球", @"霓虹环", @"极简", @"爪印"];
    NSArray *entrySymbols = @[@"asterisk", @"circle.fill", @"circle.circle.fill", @"circle.grid.2x2.fill", @"pawprint.fill"];
    for (NSInteger i = 0; i < (NSInteger)entryNames.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.tag = i; b.layer.cornerRadius = 12; b.layer.borderWidth = 1;
        b.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        [b setImage:[UIImage systemImageNamed:entrySymbols[(NSUInteger)i]] forState:UIControlStateNormal];
        [b setTitle:[@"\n" stringByAppendingString:entryNames[(NSUInteger)i]] forState:UIControlStateNormal];
        b.titleLabel.numberOfLines = 2; b.titleLabel.textAlignment = NSTextAlignmentCenter;
        [b addTarget:self action:@selector(entryStyleButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.entryStyleStack addArrangedSubview:b];
    }

    UILabel *opacityTitle = [UILabel new];
    opacityTitle.translatesAutoresizingMaskIntoConstraints = NO;
    opacityTitle.text = @"悬浮入口透明度";
    opacityTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.appearanceOverlay addSubview:opacityTitle];
    self.opacityValueLabel = [UILabel new];
    self.opacityValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    CGFloat savedOpacity = [NSUserDefaults.standardUserDefaults objectForKey:@"NovaUI.entryOpacity"] ? [NSUserDefaults.standardUserDefaults floatForKey:@"NovaUI.entryOpacity"] : 1.0;
    self.opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)round(savedOpacity * 100)];
    self.opacityValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
    self.opacityValueLabel.textAlignment = NSTextAlignmentRight;
    [self.appearanceOverlay addSubview:self.opacityValueLabel];
    self.opacitySlider = [UISlider new];
    self.opacitySlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.opacitySlider.minimumValue = 0.35; self.opacitySlider.maximumValue = 1.0;
    self.opacitySlider.value = savedOpacity; self.opacitySlider.minimumTrackTintColor = [UIColor colorWithRed:0.95 green:0.22 blue:0.68 alpha:1];
    [self.opacitySlider addTarget:self action:@selector(opacitySliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.appearanceOverlay addSubview:self.opacitySlider];

    [NSLayoutConstraint activateConstraints:@[
        [self.appearanceOverlay.topAnchor constraintEqualToAnchor:self.headerIcon.bottomAnchor constant:8],
        [self.appearanceOverlay.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:1],
        [self.appearanceOverlay.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-1],
        [self.appearanceOverlay.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-1],
        [back.topAnchor constraintEqualToAnchor:self.appearanceOverlay.topAnchor constant:15],
        [back.leadingAnchor constraintEqualToAnchor:self.appearanceOverlay.leadingAnchor constant:20],
        [back.heightAnchor constraintEqualToConstant:28],
        [title.leadingAnchor constraintEqualToAnchor:self.appearanceOverlay.leadingAnchor constant:20],
        [title.topAnchor constraintEqualToAnchor:back.bottomAnchor constant:12],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],
        [themeTitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [themeTitle.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:25],
        [self.appearanceThemeStack.leadingAnchor constraintEqualToAnchor:self.appearanceOverlay.leadingAnchor constant:16],
        [self.appearanceThemeStack.trailingAnchor constraintEqualToAnchor:self.appearanceOverlay.trailingAnchor constant:-16],
        [self.appearanceThemeStack.topAnchor constraintEqualToAnchor:themeTitle.bottomAnchor constant:10],
        [self.appearanceThemeStack.heightAnchor constraintEqualToConstant:38],
        [entryTitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [entryTitle.topAnchor constraintEqualToAnchor:self.appearanceThemeStack.bottomAnchor constant:24],
        [self.entryStyleStack.leadingAnchor constraintEqualToAnchor:self.appearanceOverlay.leadingAnchor constant:16],
        [self.entryStyleStack.trailingAnchor constraintEqualToAnchor:self.appearanceOverlay.trailingAnchor constant:-16],
        [self.entryStyleStack.topAnchor constraintEqualToAnchor:entryTitle.bottomAnchor constant:10],
        [self.entryStyleStack.heightAnchor constraintEqualToConstant:58],
        [opacityTitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [opacityTitle.topAnchor constraintEqualToAnchor:self.entryStyleStack.bottomAnchor constant:25],
        [self.opacityValueLabel.trailingAnchor constraintEqualToAnchor:self.appearanceOverlay.trailingAnchor constant:-20],
        [self.opacityValueLabel.centerYAnchor constraintEqualToAnchor:opacityTitle.centerYAnchor],
        [self.opacitySlider.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.opacitySlider.trailingAnchor constraintEqualToAnchor:self.appearanceOverlay.trailingAnchor constant:-20],
        [self.opacitySlider.topAnchor constraintEqualToAnchor:opacityTitle.bottomAnchor constant:8]
    ]];
}

- (void)buildPickerOverlay {
    self.pickerOverlay = [UIView new];
    self.pickerOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.pickerOverlay.hidden = YES;
    self.pickerOverlay.layer.cornerRadius = 24;
    self.pickerOverlay.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    [self.card addSubview:self.pickerOverlay];

    UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
    back.translatesAutoresizingMaskIntoConstraints = NO;
    [back setImage:[UIImage systemImageNamed:@"chevron.left"] forState:UIControlStateNormal];
    [back setTitle:@"  返回控制面板" forState:UIControlStateNormal];
    back.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    back.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [back addTarget:self action:@selector(closePickerOverlay) forControlEvents:UIControlEventTouchUpInside];
    [self.pickerOverlay addSubview:back];

    self.pickerTitleLabel = [UILabel new];
    self.pickerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.pickerTitleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [self.pickerOverlay addSubview:self.pickerTitleLabel];

    self.pickerSubtitleLabel = [UILabel new];
    self.pickerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.pickerSubtitleLabel.font = [UIFont systemFontOfSize:11];
    [self.pickerOverlay addSubview:self.pickerSubtitleLabel];

    self.pickerScrollView = [UIScrollView new];
    self.pickerScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pickerScrollView.showsVerticalScrollIndicator = NO;
    self.pickerScrollView.alwaysBounceVertical = YES;
    [self.pickerOverlay addSubview:self.pickerScrollView];

    self.pickerStack = [UIStackView new];
    self.pickerStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.pickerStack.axis = UILayoutConstraintAxisVertical;
    self.pickerStack.spacing = 7;
    [self.pickerScrollView addSubview:self.pickerStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.pickerOverlay.topAnchor constraintEqualToAnchor:self.headerIcon.bottomAnchor constant:8],
        [self.pickerOverlay.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:1],
        [self.pickerOverlay.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-1],
        [self.pickerOverlay.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-1],
        [back.topAnchor constraintEqualToAnchor:self.pickerOverlay.topAnchor constant:12],
        [back.leadingAnchor constraintEqualToAnchor:self.pickerOverlay.leadingAnchor constant:20],
        [back.heightAnchor constraintEqualToConstant:28],
        [self.pickerTitleLabel.leadingAnchor constraintEqualToAnchor:self.pickerOverlay.leadingAnchor constant:20],
        [self.pickerTitleLabel.topAnchor constraintEqualToAnchor:back.bottomAnchor constant:8],
        [self.pickerSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.pickerTitleLabel.leadingAnchor],
        [self.pickerSubtitleLabel.topAnchor constraintEqualToAnchor:self.pickerTitleLabel.bottomAnchor constant:3],
        [self.pickerScrollView.topAnchor constraintEqualToAnchor:self.pickerSubtitleLabel.bottomAnchor constant:12],
        [self.pickerScrollView.leadingAnchor constraintEqualToAnchor:self.pickerOverlay.leadingAnchor constant:16],
        [self.pickerScrollView.trailingAnchor constraintEqualToAnchor:self.pickerOverlay.trailingAnchor constant:-16],
        [self.pickerScrollView.bottomAnchor constraintEqualToAnchor:self.pickerOverlay.bottomAnchor constant:-16],
        [self.pickerStack.topAnchor constraintEqualToAnchor:self.pickerScrollView.contentLayoutGuide.topAnchor],
        [self.pickerStack.leadingAnchor constraintEqualToAnchor:self.pickerScrollView.contentLayoutGuide.leadingAnchor],
        [self.pickerStack.trailingAnchor constraintEqualToAnchor:self.pickerScrollView.contentLayoutGuide.trailingAnchor],
        [self.pickerStack.bottomAnchor constraintEqualToAnchor:self.pickerScrollView.contentLayoutGuide.bottomAnchor],
        [self.pickerStack.widthAnchor constraintEqualToAnchor:self.pickerScrollView.frameLayoutGuide.widthAnchor]
    ]];
}

- (UIControl *)buildStandardModuleRow:(NSDictionary *)module index:(NSInteger)idx action:(SEL)tapSel {
    NSString *type = module[@"type"] ?: @"switch";
    NSString *key = module[@"key"] ?: @"";
    UIControl *row = [UIControl new];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.layer.cornerRadius = 16;
    row.layer.cornerCurve = kCACornerCurveContinuous;
    row.tag = idx;
    [row.heightAnchor constraintEqualToConstant:62].active = YES;

    UIView *iconTile = [UIView new];
    iconTile.translatesAutoresizingMaskIntoConstraints = NO;
    iconTile.userInteractionEnabled = NO;
    iconTile.layer.cornerRadius = 12;
    iconTile.tag = 101;
    [row addSubview:iconTile];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:module[@"icon"] ?: @"circle"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [iconTile addSubview:icon];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.userInteractionEnabled = NO;
    title.text = module[@"title"] ?: @"未命名模块";
    title.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [row addSubview:title];

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.userInteractionEnabled = NO;
    subtitle.text = module[@"subtitle"] ?: @"";
    subtitle.font = [UIFont systemFontOfSize:10];
    subtitle.tag = 111;
    subtitle.numberOfLines = 1;
    subtitle.lineBreakMode = NSLineBreakByTruncatingTail;
    [row addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [iconTile.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:10],
        [iconTile.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [iconTile.widthAnchor constraintEqualToConstant:40],
        [iconTile.heightAnchor constraintEqualToConstant:40],
        [icon.centerXAnchor constraintEqualToAnchor:iconTile.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconTile.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:19],
        [icon.heightAnchor constraintEqualToConstant:19],
        [title.leadingAnchor constraintEqualToAnchor:iconTile.trailingAnchor constant:11],
        [title.topAnchor constraintEqualToAnchor:row.topAnchor constant:13],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:3]
    ]];

    if ([type isEqualToString:@"switch"]) {
        UISwitch *toggle = [UISwitch new];
        toggle.translatesAutoresizingMaskIntoConstraints = NO;
        NovaUIStateProvider stateProvider = module[@"stateProvider"];
        BOOL isOn = stateProvider ? stateProvider() : [NSUserDefaults.standardUserDefaults boolForKey:[@"NovaUI.module." stringByAppendingString:key]];
        toggle.on = isOn;
        toggle.onTintColor = [UIColor colorWithRed:0.95 green:0.22 blue:0.68 alpha:1];
        toggle.transform = CGAffineTransformMakeScale(0.78, 0.78);
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        [row addSubview:toggle];

        objc_setAssociatedObject(toggle, "NovaUI.moduleKey", key, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(toggle, "NovaUI.handler", module[@"handler"], OBJC_ASSOCIATION_COPY_NONATOMIC);

        [NSLayoutConstraint activateConstraints:@[
            [title.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-4],
            [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-4],
            [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-9],
            [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
        ]];
    } else {
        NovaUIValueProvider valueProvider = module[@"valueProvider"];
        NSString *valText = valueProvider ? (valueProvider() ?: @"") : (module[@"value"] ?: @"");

        UIView *pill = [UIView new];
        pill.translatesAutoresizingMaskIntoConstraints = NO;
        pill.userInteractionEnabled = NO;
        pill.layer.cornerRadius = 10;
        pill.tag = 120;
        [row addSubview:pill];

        UILabel *valLabel = [UILabel new];
        valLabel.translatesAutoresizingMaskIntoConstraints = NO;
        valLabel.userInteractionEnabled = NO;
        valLabel.text = [NSString stringWithFormat:@"%@  ›", valText];
        valLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        valLabel.textAlignment = NSTextAlignmentRight;
        valLabel.tag = 121;
        [pill addSubview:valLabel];

        if (tapSel) [row addTarget:self action:tapSel forControlEvents:UIControlEventTouchUpInside];

        [NSLayoutConstraint activateConstraints:@[
            [title.trailingAnchor constraintLessThanOrEqualToAnchor:pill.leadingAnchor constant:-6],
            [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:pill.leadingAnchor constant:-6],
            [pill.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-10],
            [pill.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [pill.heightAnchor constraintEqualToConstant:26],
            [pill.widthAnchor constraintLessThanOrEqualToConstant:145],
            [valLabel.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:9],
            [valLabel.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-8],
            [valLabel.centerYAnchor constraintEqualToAnchor:pill.centerYAnchor]
        ]];
    }
    return row;
}

- (void)openPickerForModule:(NSDictionary *)module {
    NovaUIOptionsProvider optionsProvider = module[@"optionsProvider"];
    if (!optionsProvider) return;
    NSArray<NSDictionary *> *options = optionsProvider();
    self.activeSubmenuModule = nil;
    self.activePickerOptions = options;
    self.activePickerHandler = module[@"selectionHandler"];
    self.pickerTitleLabel.text = module[@"title"] ?: @"选择选项";
    self.pickerSubtitleLabel.text = module[@"subtitle"] ?: @"点按切换档位并立即生效";

    for (UIView *v in self.pickerStack.arrangedSubviews) {
        [self.pickerStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    for (NSUInteger i = 0; i < options.count; i++) {
        NSDictionary *opt = options[i];
        BOOL selected = [opt[@"selected"] boolValue];
        UIControl *optRow = [UIControl new];
        optRow.translatesAutoresizingMaskIntoConstraints = NO;
        optRow.tag = (NSInteger)i;
        optRow.layer.cornerRadius = 14;
        optRow.layer.cornerCurve = kCACornerCurveContinuous;
        optRow.layer.borderWidth = selected ? 1.2 : 0.6;
        [optRow.heightAnchor constraintEqualToConstant:48].active = YES;
        [optRow addTarget:self action:@selector(pickerOptionTapped:) forControlEvents:UIControlEventTouchUpInside];

        UILabel *optLabel = [UILabel new];
        optLabel.translatesAutoresizingMaskIntoConstraints = NO;
        optLabel.userInteractionEnabled = NO;
        optLabel.tag = 201;
        if ([opt[@"attrTitle"] isKindOfClass:NSAttributedString.class]) {
            optLabel.attributedText = opt[@"attrTitle"];
            objc_setAssociatedObject(optLabel, "NovaUI.hasCustomAttr", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else {
            optLabel.text = opt[@"title"] ?: @"";
            optLabel.font = [UIFont systemFontOfSize:14 weight:selected ? UIFontWeightBold : UIFontWeightMedium];
        }
        [optRow addSubview:optLabel];

        UILabel *check = [UILabel new];
        check.translatesAutoresizingMaskIntoConstraints = NO;
        check.userInteractionEnabled = NO;
        check.tag = 202;
        check.text = selected ? @"✓" : @"";
        check.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        check.textAlignment = NSTextAlignmentRight;
        [optRow addSubview:check];

        objc_setAssociatedObject(optRow, "NovaUI.optSelected", @(selected), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        [NSLayoutConstraint activateConstraints:@[
            [optLabel.leadingAnchor constraintEqualToAnchor:optRow.leadingAnchor constant:16],
            [optLabel.trailingAnchor constraintLessThanOrEqualToAnchor:check.leadingAnchor constant:-8],
            [optLabel.centerYAnchor constraintEqualToAnchor:optRow.centerYAnchor],
            [check.trailingAnchor constraintEqualToAnchor:optRow.trailingAnchor constant:-16],
            [check.centerYAnchor constraintEqualToAnchor:optRow.centerYAnchor],
            [check.widthAnchor constraintEqualToConstant:24]
        ]];
        [self.pickerStack addArrangedSubview:optRow];
    }

    self.appearanceOverlay.hidden = YES;
    self.pickerOverlay.hidden = NO;
    [self applyTheme:self.currentTheme];
}

- (void)openSubmenuForModule:(NSDictionary *)module {
    NovaUIOptionsProvider itemsProvider = module[@"itemsProvider"];
    if (!itemsProvider) return;
    self.activeSubmenuModule = module;
    NSArray<NSDictionary *> *items = itemsProvider();
    self.activePickerOptions = items;
    self.activePickerHandler = nil;
    self.pickerTitleLabel.text = module[@"title"] ?: @"子菜单";
    self.pickerSubtitleLabel.text = module[@"subtitle"] ?: @"";

    for (UIView *v in self.pickerStack.arrangedSubviews) {
        [self.pickerStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    for (NSUInteger i = 0; i < items.count; i++) {
        NSDictionary *subItem = items[i];
        UIControl *row = [self buildStandardModuleRow:subItem index:(NSInteger)i action:@selector(submenuActionTapped:)];
        [self.pickerStack addArrangedSubview:row];
    }

    self.appearanceOverlay.hidden = YES;
    self.pickerOverlay.hidden = NO;
    [self applyTheme:self.currentTheme];
}

- (void)submenuActionTapped:(UIControl *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || (NSUInteger)idx >= self.activePickerOptions.count) return;
    NSDictionary *subItem = self.activePickerOptions[(NSUInteger)idx];
    NovaUIActionHandler actionHandler = subItem[@"actionHandler"];
    if (actionHandler) {
        __weak typeof(self) weakSelf = self;
        actionHandler(self, ^{
            if (weakSelf.activeSubmenuModule) {
                [weakSelf openSubmenuForModule:weakSelf.activeSubmenuModule];
            }
            [weakSelf rebuildRows];
        });
    }
}

- (void)closePickerOverlay {
    self.pickerOverlay.hidden = YES;
    self.activeSubmenuModule = nil;
    [self rebuildRows];
}

- (void)pickerOptionTapped:(UIControl *)sender {
    NSInteger idx = sender.tag;
    if (idx >= 0 && (NSUInteger)idx < self.activePickerOptions.count) {
        NSDictionary *opt = self.activePickerOptions[(NSUInteger)idx];
        if (self.activePickerHandler) {
            self.activePickerHandler(idx, opt[@"value"]);
        }
    }
    self.pickerOverlay.hidden = YES;
    [self rebuildRows];
}

- (void)toggleAppearanceSettings {
    self.pickerOverlay.hidden = YES;
    self.appearanceOverlay.hidden = !self.appearanceOverlay.hidden;
    [self applyTheme:self.currentTheme];
}

- (void)entryStyleButtonTapped:(UIButton *)sender {
    NSInteger style = sender.tag;
    [NSUserDefaults.standardUserDefaults setInteger:style forKey:@"NovaUI.entryStyle"];
    [self applyTheme:self.currentTheme];
    if (self.floatingStyleChanged) self.floatingStyleChanged(style);
}

- (void)opacitySliderChanged:(UISlider *)sender {
    CGFloat opacity = sender.value;
    self.opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)round(opacity * 100)];
    [NSUserDefaults.standardUserDefaults setFloat:opacity forKey:@"NovaUI.entryOpacity"];
    if (self.floatingOpacityChanged) self.floatingOpacityChanged(opacity);
}

- (void)rebuildRows {
    for (UIView *view in self.moduleStack.arrangedSubviews) {
        [self.moduleStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    for (NSUInteger i = 0; i < self.modules.count; i++) {
        NSDictionary *module = self.modules[i];
        UIControl *row = [self buildStandardModuleRow:module index:(NSInteger)i action:@selector(moduleRowTapped:)];
        [self.moduleStack addArrangedSubview:row];
    }
    [self applyTheme:self.currentTheme];
}

- (void)moduleRowTapped:(UIControl *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || (NSUInteger)idx >= self.modules.count) return;
    NSDictionary *module = self.modules[(NSUInteger)idx];
    NSString *type = module[@"type"] ?: @"";
    if ([type isEqualToString:@"picker"]) {
        [self openPickerForModule:module];
    } else if ([type isEqualToString:@"submenu"]) {
        [self openSubmenuForModule:module];
    } else if ([type isEqualToString:@"action"]) {
        NovaUIActionHandler actionHandler = module[@"actionHandler"];
        if (actionHandler) {
            __weak typeof(self) weakSelf = self;
            actionHandler(self, ^{
                [weakSelf rebuildRows];
            });
        }
    }
}

- (void)reloadModules:(NSArray<NSDictionary *> *)modules title:(NSString *)title {
    [self reloadModules:modules title:title subtitle:self.panelSubtitle];
}

- (void)reloadModules:(NSArray<NSDictionary *> *)modules title:(NSString *)title subtitle:(NSString *)subtitle {
    self.modules = [modules copy];
    self.panelTitle = [title copy];
    if (subtitle.length) self.panelSubtitle = [subtitle copy];
    self.heading.text = title;
    self.subheading.text = self.panelSubtitle;
    [self rebuildRows];
}

- (void)themeButtonTapped:(UIButton *)sender {
    self.currentTheme = sender.tag;
    [NSUserDefaults.standardUserDefaults setInteger:self.currentTheme forKey:@"NovaUI.theme"];
    [self applyTheme:self.currentTheme];
}

- (void)applyTheme:(NSInteger)theme {
    UIColor *pink = [UIColor colorWithRed:0.95 green:0.22 blue:0.68 alpha:1];
    UIColor *textColor, *secondary, *cardColor, *rowColor, *iconTileColor, *borderColor;
    switch (theme) {
        case 1:
            cardColor = [UIColor colorWithWhite:0.98 alpha:0.99];
            textColor = [UIColor colorWithWhite:0.10 alpha:1];
            secondary = [UIColor colorWithWhite:0.43 alpha:1];
            rowColor = [UIColor colorWithWhite:0.92 alpha:1];
            iconTileColor = [UIColor colorWithRed:1 green:0.84 blue:0.94 alpha:1];
            borderColor = [UIColor colorWithWhite:0.88 alpha:1];
            self.backdrop.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
            break;
        case 2:
            cardColor = [UIColor colorWithRed:0.20 green:0.23 blue:0.38 alpha:0.80];
            textColor = UIColor.whiteColor;
            secondary = [UIColor colorWithWhite:1 alpha:0.62];
            rowColor = [UIColor colorWithWhite:1 alpha:0.11];
            iconTileColor = [UIColor colorWithWhite:1 alpha:0.14];
            borderColor = [UIColor colorWithWhite:1 alpha:0.30];
            self.backdrop.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
            break;
        case 3:
            cardColor = [UIColor colorWithWhite:0.025 alpha:0.99];
            textColor = UIColor.whiteColor;
            secondary = [UIColor colorWithWhite:1 alpha:0.55];
            rowColor = [UIColor colorWithWhite:1 alpha:0.035];
            iconTileColor = [UIColor colorWithWhite:1 alpha:0.07];
            borderColor = [UIColor colorWithWhite:1 alpha:0.10];
            self.backdrop.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            break;
        case 4:
            cardColor = [UIColor colorWithRed:0.015 green:0.035 blue:0.09 alpha:0.99];
            textColor = UIColor.whiteColor;
            secondary = [UIColor colorWithRed:0.50 green:0.84 blue:1 alpha:1];
            rowColor = [UIColor colorWithRed:0.02 green:0.12 blue:0.20 alpha:0.9];
            iconTileColor = [UIColor colorWithRed:0.02 green:0.25 blue:0.34 alpha:0.9];
            borderColor = [UIColor colorWithRed:0.0 green:0.88 blue:1 alpha:0.8];
            pink = [UIColor colorWithRed:0.0 green:0.88 blue:1 alpha:1];
            self.backdrop.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            break;
        default:
            cardColor = [UIColor colorWithRed:0.055 green:0.065 blue:0.12 alpha:0.98];
            textColor = UIColor.whiteColor;
            secondary = [UIColor colorWithWhite:1 alpha:0.56];
            rowColor = [UIColor colorWithWhite:1 alpha:0.055];
            iconTileColor = [UIColor colorWithRed:0.30 green:0.12 blue:0.31 alpha:0.8];
            borderColor = [pink colorWithAlphaComponent:0.62];
            self.backdrop.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            break;
    }
    self.card.backgroundColor = cardColor;
    self.card.layer.borderColor = borderColor.CGColor;
    self.accentLine.backgroundColor = pink;
    self.headerIcon.backgroundColor = [pink colorWithAlphaComponent:0.82];
    self.heading.textColor = textColor;
    self.subheading.textColor = secondary;
    self.sectionLabel.textColor = secondary;
    self.opacitySlider.minimumTrackTintColor = pink;

    for (UIView *row in self.moduleStack.arrangedSubviews) {
        row.backgroundColor = rowColor;
        for (UIView *sub in row.subviews) {
            if ([sub isKindOfClass:UILabel.class]) {
                ((UILabel *)sub).textColor = sub.tag == 111 ? secondary : textColor;
            } else if (sub.tag == 101) {
                sub.backgroundColor = iconTileColor;
                for (UIView *inner in sub.subviews) {
                    if ([inner isKindOfClass:UIImageView.class]) ((UIImageView *)inner).tintColor = pink;
                }
            } else if (sub.tag == 120) {
                sub.backgroundColor = [pink colorWithAlphaComponent:0.14];
                for (UIView *inner in sub.subviews) {
                    if ([inner isKindOfClass:UILabel.class]) ((UILabel *)inner).textColor = pink;
                }
            } else if ([sub isKindOfClass:UISwitch.class]) {
                ((UISwitch *)sub).onTintColor = pink;
            }
        }
    }

    for (UIView *view in self.appearanceOverlay.subviews) {
        if ([view isKindOfClass:UILabel.class]) {
            UILabel *label = (UILabel *)view;
            label.textColor = (label.font.pointSize >= 20) ? textColor : secondary;
        }
        if ([view isKindOfClass:UIButton.class]) {
            UIButton *button = (UIButton *)view;
            button.tintColor = pink;
            [button setTitleColor:pink forState:UIControlStateNormal];
        }
    }
    self.appearanceOverlay.backgroundColor = cardColor;

    for (UIButton *button in self.appearanceThemeStack.arrangedSubviews) {
        BOOL selected = button.tag == theme;
        button.layer.borderColor = (selected ? pink : borderColor).CGColor;
        button.backgroundColor = selected ? [pink colorWithAlphaComponent:0.18] : rowColor;
        [button setTitleColor:selected ? pink : secondary forState:UIControlStateNormal];
        button.tintColor = selected ? pink : secondary;
    }
    for (UIButton *button in self.entryStyleStack.arrangedSubviews) {
        BOOL selected = [NSUserDefaults.standardUserDefaults integerForKey:@"NovaUI.entryStyle"] == button.tag;
        button.layer.borderColor = (selected ? pink : borderColor).CGColor;
        button.backgroundColor = selected ? [pink colorWithAlphaComponent:0.18] : rowColor;
        [button setTitleColor:selected ? pink : secondary forState:UIControlStateNormal];
        button.tintColor = selected ? pink : secondary;
    }

    self.pickerOverlay.backgroundColor = cardColor;
    for (UIView *view in self.pickerOverlay.subviews) {
        if ([view isKindOfClass:UILabel.class]) {
            UILabel *label = (UILabel *)view;
            label.textColor = (label.font.pointSize >= 18) ? textColor : secondary;
        }
        if ([view isKindOfClass:UIButton.class]) {
            UIButton *button = (UIButton *)view;
            button.tintColor = pink;
            [button setTitleColor:pink forState:UIControlStateNormal];
        }
    }
    for (UIControl *optRow in self.pickerStack.arrangedSubviews) {
        NSNumber *selObj = objc_getAssociatedObject(optRow, "NovaUI.optSelected");
        if (selObj != nil) {
            BOOL selected = [selObj boolValue];
            optRow.backgroundColor = selected ? [pink colorWithAlphaComponent:0.16] : rowColor;
            optRow.layer.borderColor = (selected ? pink : borderColor).CGColor;
            for (UIView *sub in optRow.subviews) {
                if (sub.tag == 201 && [sub isKindOfClass:UILabel.class]) {
                    UILabel *l = (UILabel *)sub;
                    if (![objc_getAssociatedObject(l, "NovaUI.hasCustomAttr") boolValue]) {
                        l.textColor = selected ? pink : textColor;
                    }
                } else if (sub.tag == 202 && [sub isKindOfClass:UILabel.class]) {
                    ((UILabel *)sub).textColor = pink;
                }
            }
        } else {
            optRow.backgroundColor = rowColor;
            for (UIView *sub in optRow.subviews) {
                if ([sub isKindOfClass:UILabel.class]) {
                    ((UILabel *)sub).textColor = sub.tag == 111 ? secondary : textColor;
                } else if (sub.tag == 101) {
                    sub.backgroundColor = iconTileColor;
                    for (UIView *inner in sub.subviews) {
                        if ([inner isKindOfClass:UIImageView.class]) ((UIImageView *)inner).tintColor = pink;
                    }
                } else if (sub.tag == 120) {
                    sub.backgroundColor = [pink colorWithAlphaComponent:0.14];
                    for (UIView *inner in sub.subviews) {
                        if ([inner isKindOfClass:UILabel.class]) ((UILabel *)inner).textColor = pink;
                    }
                } else if ([sub isKindOfClass:UISwitch.class]) {
                    ((UISwitch *)sub).onTintColor = pink;
                }
            }
        }
    }
}

- (void)toggleChanged:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, "NovaUI.moduleKey");
    NovaUIModuleHandler handler = objc_getAssociatedObject(sender, "NovaUI.handler");
    [NSUserDefaults.standardUserDefaults setBool:sender.isOn forKey:[@"NovaUI.module." stringByAppendingString:key ?: @""]];
    if (handler) handler(sender.isOn);
    if (!self.pickerOverlay.hidden) {
        [self rebuildRows];
    }
}

- (void)outsideTap:(UITapGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self];
    CGRect cardFrame = [self.card convertRect:self.card.bounds toView:self];
    if (!CGRectContainsPoint(cardFrame, point)) [self dismiss];
}

- (void)present {
    if (self.superview) return;
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
    if (!window) return;
    self.appearanceOverlay.hidden = YES;
    self.pickerOverlay.hidden = YES;
    self.activeSubmenuModule = nil;
    self.frame = window.bounds;
    self.alpha = 0;
    self.card.transform = CGAffineTransformMakeScale(0.96, 0.96);
    [window addSubview:self];
    [self setNeedsLayout];
    [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.88 initialSpringVelocity:0.2 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.alpha = 1;
        self.card.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)dismiss {
    [UIView animateWithDuration:0.18 animations:^{
        self.alpha = 0;
        self.card.transform = CGAffineTransformMakeScale(0.97, 0.97);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        self.card.transform = CGAffineTransformIdentity;
        if (self.closeHandler) self.closeHandler();
    }];
}

@end
