//
//  ViewController.m
//  ModernKey
//
//  Created by Tuyen on 1/18/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#import "ViewController.h"
#import "OpenKeyManager.h"
#import "AppDelegate.h"
#import "MyTextField.h"

extern AppDelegate* appDelegate;
extern void OnSpellCheckingChanged(void);

ViewController* viewController;
extern int vLanguage;
extern int vCheckSpelling;
extern int vUseModernOrthography;
extern int vSwitchKeyStatus;
extern int vQuickTelex;
extern int vRestoreIfWrongSpelling;
extern int vFixRecommendBrowser;
extern int vUseMacro;
extern int vUseMacroInEnglishMode;
extern int vSendKeyStepByStep;
extern int vUseSmartSwitchKey;
extern int vUpperCaseFirstChar;
extern int vTempOffSpelling;
extern int vAllowConsonantZFWJ;
extern int vQuickStartConsonant;
extern int vQuickEndConsonant;
extern int vRememberCode;
extern int vTempOffOpenKey;
extern int vShowIconOnDock;
extern int vAutoCapsMacro;
extern int vFixChromiumBrowser;
extern int vPerformLayoutCompat;

#pragma mark - Layout building blocks

@interface SettingsFlippedView : NSView
@end
@implementation SettingsFlippedView
- (BOOL)isFlipped { return YES; }
@end

static void Pin(NSView* view, NSView* container, CGFloat inset) {
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:inset],
        [view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-inset],
        [view.topAnchor constraintEqualToAnchor:container.topAnchor constant:inset],
        [view.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-inset]]];
}

static NSStackView* VStack(NSArray<NSView*>* views, CGFloat spacing) {
    NSStackView* s = [NSStackView stackViewWithViews:views];
    s.orientation = NSUserInterfaceLayoutOrientationVertical;
    s.alignment = NSLayoutAttributeLeading;
    s.spacing = spacing;
    s.translatesAutoresizingMaskIntoConstraints = NO;
    return s;
}

static void FillWidth(NSStackView* stack, NSView* view) {
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [view.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-(stack.edgeInsets.left + stack.edgeInsets.right)].active = YES;
}

static NSTextField* SecondaryLabel(NSString* text, CGFloat size) {
    NSTextField* l = [NSTextField labelWithString:text];
    l.font = [NSFont systemFontOfSize:size];
    l.textColor = NSColor.secondaryLabelColor;
    return l;
}

// One line of a section: title (and optional subtitle) on the left, control on the right.
static NSView* Row(NSString* title, NSString* subtitle, NSView* accessory, NSString* tip) {
    NSView* row = [NSView new];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.toolTip = tip;

    NSTextField* titleLabel = [NSTextField labelWithString:title];
    titleLabel.font = [NSFont systemFontOfSize:13];
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    NSMutableArray* texts = [NSMutableArray arrayWithObject:titleLabel];
    if (subtitle)
        [texts addObject:SecondaryLabel(subtitle, 11)];
    NSStackView* textStack = VStack(texts, 2);
    [textStack setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [row addSubview:textStack];

    NSMutableArray* constraints = [NSMutableArray arrayWithArray:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:subtitle ? 48 : 38],
        [textStack.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
        [textStack.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [textStack.topAnchor constraintGreaterThanOrEqualToAnchor:row.topAnchor constant:8]]];
    if (accessory) {
        if (accessory.accessibilityLabel.length == 0)
            accessory.accessibilityLabel = title; // switches and popups have no text of their own for VoiceOver
        accessory.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:accessory];
        [constraints addObjectsFromArray:@[
            [accessory.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
            [accessory.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [accessory.leadingAnchor constraintGreaterThanOrEqualToAnchor:textStack.trailingAnchor constant:12],
            [accessory.topAnchor constraintGreaterThanOrEqualToAnchor:row.topAnchor constant:6]]];
    } else {
        [constraints addObject:[textStack.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor constant:-12]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
    return row;
}

// A rounded group of rows separated by hairlines, with an optional header and footer.
static NSView* Section(NSString* header, NSArray<NSView*>* rows, NSString* footer) {
    NSStackView* rowStack = VStack(@[], 0);
    for (NSUInteger i = 0; i < rows.count; i++) {
        if (i > 0) {
            NSBox* line = [NSBox new];
            line.boxType = NSBoxSeparator;
            [rowStack addArrangedSubview:line];
            line.translatesAutoresizingMaskIntoConstraints = NO;
            [line.widthAnchor constraintEqualToAnchor:rowStack.widthAnchor constant:-24].active = YES;
            [rowStack setCustomSpacing:0 afterView:line];
        }
        [rowStack addArrangedSubview:rows[i]];
        FillWidth(rowStack, rows[i]);
    }
    rowStack.alignment = NSLayoutAttributeCenterX;

    NSBox* box = [NSBox new];
    box.boxType = NSBoxCustom;
    box.titlePosition = NSNoTitle;
    box.cornerRadius = 10;
    box.borderWidth = 0;
    box.fillColor = NSColor.quaternarySystemFillColor;
    box.contentViewMargins = NSZeroSize;
    [box.contentView addSubview:rowStack];
    Pin(rowStack, box.contentView, 0);

    NSMutableArray* parts = [NSMutableArray array];
    if (header) {
        NSTextField* h = [NSTextField labelWithString:header];
        h.font = [NSFont boldSystemFontOfSize:13];
        [parts addObject:h];
    }
    [parts addObject:box];
    if (footer)
        [parts addObject:SecondaryLabel(footer, 11)];
    NSStackView* section = VStack(parts, 8);
    FillWidth(section, box);
    return section;
}

// A scrolling page of sections; content starts at the top and scrolls under the toolbar.
static NSScrollView* Page(NSArray<NSView*>* sections) {
    NSStackView* stack = VStack(sections, 22);
    stack.edgeInsets = NSEdgeInsetsMake(20, 24, 24, 24);
    for (NSView* s in sections)
        FillWidth(stack, s);

    SettingsFlippedView* doc = [SettingsFlippedView new];
    doc.translatesAutoresizingMaskIntoConstraints = NO;
    [doc addSubview:stack];
    Pin(stack, doc, 0);

    NSScrollView* scroll = [NSScrollView new];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.automaticallyAdjustsContentInsets = YES;
    scroll.documentView = doc;
    NSClipView* clip = scroll.contentView;
    [NSLayoutConstraint activateConstraints:@[
        [doc.leadingAnchor constraintEqualToAnchor:clip.leadingAnchor],
        [doc.topAnchor constraintEqualToAnchor:clip.topAnchor],
        [doc.widthAnchor constraintEqualToAnchor:clip.widthAnchor]]];
    return scroll;
}

#pragma mark - Sidebar

@interface SettingsSidebar : NSViewController<NSTableViewDataSource, NSTableViewDelegate>
@property (copy) NSArray<NSArray*>* items; // @[title, SF Symbol name, badge color]
@property (copy) void (^onSelect)(NSInteger row);
@property (strong) NSTableView* table;
@end

@implementation SettingsSidebar
- (void)loadView {
    NSTableView* table = [NSTableView new];
    table.style = NSTableViewStyleSourceList;
    table.headerView = nil;
    table.rowHeight = 32;
    NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:@"page"];
    [table addTableColumn:column];
    table.dataSource = self;
    table.delegate = self;

    NSScrollView* scroll = [NSScrollView new];
    scroll.drawsBackground = NO;
    scroll.documentView = table;
    self.table = table;
    self.view = scroll;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.items.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSArray* item = self.items[row];

    NSImageView* icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:item[1] accessibilityDescription:nil]];
    icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:12 weight:NSFontWeightSemibold];
    icon.contentTintColor = NSColor.whiteColor;
    NSBox* badge = [NSBox new];
    badge.boxType = NSBoxCustom;
    badge.titlePosition = NSNoTitle;
    badge.borderWidth = 0;
    badge.cornerRadius = 6;
    badge.fillColor = item[2];
    badge.contentViewMargins = NSZeroSize;
    [badge.contentView addSubview:icon];
    icon.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField* label = [NSTextField labelWithString:item[0]];
    label.font = [NSFont systemFontOfSize:13];

    NSTableCellView* cell = [NSTableCellView new];
    cell.textField = label;
    NSStackView* stack = [NSStackView stackViewWithViews:@[badge, label]];
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [cell addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [badge.widthAnchor constraintEqualToConstant:22],
        [badge.heightAnchor constraintEqualToConstant:22],
        [icon.centerXAnchor constraintEqualToAnchor:badge.contentView.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:badge.contentView.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:2],
        [stack.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]]];
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if (self.table.selectedRow >= 0 && self.onSelect)
        self.onSelect(self.table.selectedRow);
}
@end

#pragma mark - Control panel

@implementation ViewController {
    SettingsSidebar* sidebar;
    NSViewController* content;
    NSArray<NSView*>* pages;
    NSArray<NSString*>* pageTitles;
}

- (instancetype)init {
    if (self = [super initWithNibName:nil bundle:nil]) {
        sidebar = [SettingsSidebar new];
        content = [NSViewController new];
        content.view = [NSView new];

        NSSplitViewItem* side = [NSSplitViewItem sidebarWithViewController:sidebar];
        side.minimumThickness = 190;
        side.maximumThickness = 240;
        side.canCollapse = NO;
        [self addSplitViewItem:side];
        [self addSplitViewItem:[NSSplitViewItem splitViewItemWithViewController:content]];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    viewController = self;

    pageTitles = @[@"Bộ gõ", @"Gõ tắt", @"Hệ thống", @"Thông tin"];
    pages = @[[self typingPage], [self macroPage], [self systemPage], [self infoPage]];

    __weak ViewController* weakSelf = self;
    sidebar.items = @[@[pageTitles[0], @"keyboard", NSColor.systemBlueColor],
                      @[pageTitles[1], @"text.badge.plus", NSColor.systemOrangeColor],
                      @[pageTitles[2], @"gearshape", NSColor.systemGrayColor],
                      @[pageTitles[3], @"info.circle", NSColor.systemPurpleColor]];
    sidebar.onSelect = ^(NSInteger row) { [weakSelf showPage:row]; };
    [sidebar.table reloadData];
    [sidebar.table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    [self showPage:0];

    [self.popupInputType addItemsWithTitles:@[@"Telex", @"VNI", @"Simple Telex"]];
    [self.popupCode addItemsWithTitles:[OpenKeyManager getTableCodes]];

    [self fillData];

    self.VersionInfo.stringValue = [NSString stringWithFormat:@"Phiên bản %@ (build %@) - Ngày cập nhật %@",
    [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"],
    [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"],
    [OpenKeyManager getBuildDate]] ;
}

- (void)viewWillAppear {
    [super viewWillAppear];
    [self initKey];
}

-(void)initKey {
    dispatch_async(dispatch_get_main_queue(), ^{
        [OpenKeyManager initEventTap];
    });
}

-(void)showPage:(NSInteger)index {
    NSView* page = pages[index];
    [content.view.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [content.view addSubview:page];
    Pin(page, content.view, 0);
    self.title = pageTitles[index]; // the window title follows the content view controller
}

#pragma mark - Pages

-(NSSwitch*)toggle:(SEL)action {
    NSSwitch* s = [NSSwitch new];
    s.controlSize = NSControlSizeMini;
    s.target = self;
    s.action = action;
    return s;
}

-(NSView*)typingPage {
    self.languageControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Tiếng Việt", @"English"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(onLanguageChanged:)];
    self.popupInputType = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.popupInputType.target = self;
    self.popupInputType.action = @selector(onInputTypeChanged:);
    self.popupCode = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.popupCode.target = self;
    self.popupCode.action = @selector(onCodeTableChanged:);

    self.switchModifiers = [NSSegmentedControl segmentedControlWithLabels:@[@"⌃", @"⌥", @"⌘", @"⇧"] trackingMode:NSSegmentSwitchTrackingSelectAny target:self action:@selector(onSwitchModifiersChanged:)];
    NSArray* modifierTips = @[@"Phím Control", @"Phím Option", @"Phím Command", @"Phím Shift"];
    for (NSInteger i = 0; i < modifierTips.count; i++)
        [self.switchModifiers setToolTip:modifierTips[i] forSegment:i];
    self.CustomSwitchKey = [MyTextField new];
    self.CustomSwitchKey.Parent = self;
    self.CustomSwitchKey.alignment = NSTextAlignmentCenter;
    self.CustomSwitchKey.bezelStyle = NSTextFieldRoundedBezel;
    self.CustomSwitchKey.toolTip = @"Bấm vào đây rồi gõ phím muốn dùng";
    [self.CustomSwitchKey.widthAnchor constraintEqualToConstant:56].active = YES;
    NSStackView* hotKey = [NSStackView stackViewWithViews:@[self.switchModifiers, self.CustomSwitchKey]];
    hotKey.spacing = 8;
    self.CustomBeepSound = [self toggle:@selector(onBeepSound:)];

    self.CheckSpellingButton = [self toggle:@selector(onCheckSpelling:)];
    self.RestoreIfInvalidWord = [self toggle:@selector(onRestoreIfInvalidWord:)];
    self.AllowZWJF = [self toggle:@selector(onAllowZFWJ:)];
    self.TempOffSpellChecking = [self toggle:@selector(omTempOffSpellChecking:)];

    self.UseModernOrthography = [self toggle:@selector(onModernOrthography:)];
    self.UpperCaseFirstChar = [self toggle:@selector(onUpperCaseFirstChar:)];
    self.FixRecommendBrowser = [self toggle:@selector(onFixRecommendBrowser:)];
    self.FixChromiumBrowser = [self toggle:@selector(onFixChromiumBrowser:)];

    self.AutoRememberSwitchKey = [self toggle:@selector(onAutoRememberSwitchKey:)];
    self.RememberTableCode = [self toggle:@selector(onRememberTableCode:)];
    self.TempOffOpenKey = [self toggle:@selector(onTempOffOpenKeyByHotKey:)];

    return Page(@[
        Section(@"Điều khiển", @[
            Row(@"Chế độ gõ", nil, self.languageControl, nil),
            Row(@"Kiểu gõ", nil, self.popupInputType, @"Lựa chọn kiểu gõ của bạn"),
            Row(@"Bảng mã", nil, self.popupCode, @"Chọn bảng mã cần gõ, thường là Unicode"),
            Row(@"Phím chuyển chế độ", nil, hotKey, @"Tổ hợp phím chuyển giữa Tiếng Việt và English"),
            Row(@"Kêu beep khi chuyển chế độ", nil, self.CustomBeepSound, @"Kêu tiếng beep mỗi khi chuyển chế độ, không có tác dụng với tính năng chuyển chế độ thông minh")], nil),
        Section(@"Chính tả", @[
            Row(@"Kiểm tra chính tả", nil, self.CheckSpellingButton, @"Tính năng kiểm tra chính tả tương đối, hạn chế gõ sai từ"),
            Row(@"Tự khôi phục phím với từ sai", nil, self.RestoreIfInvalidWord, @"Từ nào gõ sai với Tiếng Việt thì tự động khôi phục các phím đã gõ"),
            Row(@"Cho phép \"z w j f\" làm phụ âm", nil, self.AllowZWJF, @"Vẫn cho phép gõ các chữ z w j f làm phụ âm đầu khi bật tính năng kiểm tra chính tả"),
            Row(@"Tạm tắt chính tả bằng phím ⌃", nil, self.TempOffSpellChecking, @"Tạm tắt kiểm tra chính tả khi gõ một từ nào đó như từ Đắk Lắk, Krông,... Kiểm tra chính tả sẽ phục hồi trở lại cho từ tiếp theo")],
            @"Các tuỳ chọn phụ chỉ có tác dụng khi bật kiểm tra chính tả."),
        Section(@"Gõ dấu", @[
            Row(@"Đặt dấu oà, uý", @"Thay vì òa, úy", self.UseModernOrthography, @"Đặt dấu kiểu cũ và kiểu mới"),
            Row(@"Viết hoa chữ cái đầu câu", nil, self.UpperCaseFirstChar, @"Tự động viết hoa sau dấu chấm ngắt câu và sau khi xuống dòng"),
            Row(@"Sửa lỗi gợi ý", @"Trình duyệt, Excel, ...", self.FixRecommendBrowser, @"Sửa lỗi đúp từ trên thanh địa chỉ trình duyệt, Excel,..."),
            Row(@"Sửa lỗi trên Chromium (beta)", nil, self.FixChromiumBrowser, @"Cần bật Sửa lỗi gợi ý")], nil),
        Section(@"Chuyển chế độ thông minh", @[
            Row(@"Chuyển chế độ thông minh", @"Nhớ Tiếng Việt/English cho từng ứng dụng", self.AutoRememberSwitchKey, nil),
            Row(@"Tự ghi nhớ bảng mã theo ứng dụng", nil, self.RememberTableCode, nil),
            Row(@"Tạm tắt OpenKey bằng phím ⌘", nil, self.TempOffOpenKey, @"Bằng cách bấm phím Command, OpenKey sẽ tạm ngừng hoạt động cho tới khi bạn gõ 1 từ mới.")], nil)]);
}

-(NSView*)macroPage {
    self.UseMacro = [self toggle:@selector(onMacroChanged:)];
    self.UseMacroInEnglishMode = [self toggle:@selector(onUseMacroInEnglishModeChanged:)];
    self.AutoCapsMacro = [self toggle:@selector(onAutoCapsMacro:)];
    NSButton* macroTable = [NSButton buttonWithTitle:@"Chỉnh sửa…" target:self action:@selector(onMacroButton:)];

    self.QuickTelex = [self toggle:@selector(onQuickTelex:)];
    self.QuickStartConsonant = [self toggle:@selector(onQuickStartConsonant:)];
    self.QuickEndConsonant = [self toggle:@selector(onQuickEndConsonant:)];

    return Page(@[
        Section(@"Gõ tắt", @[
            Row(@"Cho phép gõ tắt", nil, self.UseMacro, @"Bật chế độ gõ tắt để tiết kiệm thời gian gõ"),
            Row(@"Gõ tắt cả khi tắt gõ tiếng Việt", nil, self.UseMacroInEnglishMode, @"Vẫn có thể gõ tắt khi bạn đang ở chế độ Tiếng Anh"),
            Row(@"Tự động viết hoa theo phím tắt", nil, self.AutoCapsMacro, nil),
            Row(@"Bảng gõ tắt", nil, macroTable, @"Bấm vào đây để cấu hình bảng gõ tắt")], nil),
        Section(@"Gõ nhanh", @[
            Row(@"Gõ nhanh", @"cc=ch, gg=gi, kk=kh, nn=ng, qq=qu, pp=ph, tt=th", self.QuickTelex, nil),
            Row(@"Gõ tắt phụ âm đầu", @"f→ph, j→gi, w→qu", self.QuickStartConsonant, @"Ví dụ: fải→phải, jảng→giảng, wên→quên"),
            Row(@"Gõ tắt phụ âm cuối", @"g→ng, h→nh, k→ch", self.QuickEndConsonant, @"Ví dụ: trươg→trương, nhah→nhanh, bák→bách")], nil)]);
}

-(NSView*)systemPage {
    self.RunOnStartupButton = [self toggle:@selector(onRunOnStartup:)];
    self.ShowUIButton = [self toggle:@selector(onShowUIOnStartup:)];
    self.UseGrayIcon = [self toggle:@selector(onGrayIcon:)];
    self.ShowIconOnDock = [self toggle:@selector(onShowIconOnDock:)];
    self.SendKeyStepByStep = [self toggle:@selector(onSendKeyStepByStep:)];
    self.PerformLayoutCompat = [self toggle:@selector(onPerformLayoutCompat:)];

    NSStackView* actions = [NSStackView stackViewWithViews:@[
        [NSButton buttonWithTitle:@"Khôi phục mặc định…" target:self action:@selector(onDefaultConfig:)],
        [NSButton buttonWithTitle:@"Thoát OpenKey" target:self action:@selector(onTerminateApp:)]]];
    actions.spacing = 8;
    NSView* actionsRow = [NSView new];
    [actionsRow addSubview:actions];
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [actions.trailingAnchor constraintEqualToAnchor:actionsRow.trailingAnchor],
        [actions.topAnchor constraintEqualToAnchor:actionsRow.topAnchor],
        [actions.bottomAnchor constraintEqualToAnchor:actionsRow.bottomAnchor]]];

    return Page(@[
        Section(@"Khởi động", @[
            Row(@"Khởi động cùng macOS", nil, self.RunOnStartupButton, @"Tự động chạy chương trình mỗi khi mở máy"),
            Row(@"Mở bảng điều khiển khi khởi động", nil, self.ShowUIButton, @"Hiện bảng điều khiển này mỗi khi chạy chương trình")], nil),
        Section(@"Biểu tượng", @[
            Row(@"Biểu tượng đơn sắc trên thanh menu", nil, self.UseGrayIcon, @"Bật biểu tượng đen trắng để phù hợp hơn với Dark Mode"),
            Row(@"Hiện biểu tượng trên thanh Dock", nil, self.ShowIconOnDock, @"Hiện biểu tượng OpenKey trên thanh Dock của máy bạn")], nil),
        Section(@"Tương thích", @[
            Row(@"Gửi từng phím", @"Chỉ bật nếu ứng dụng bị lỗi khi gõ", self.SendKeyStepByStep, @"Mặc định nên tắt, với các ứng dụng gặp lỗi thì thử bật tính năng này lên"),
            Row(@"Tương thích Telex với layout khác", @"Dvorak, Colemak, ...", self.PerformLayoutCompat, nil)], nil),
        actionsRow]);
}

-(NSView*)infoPage {
    NSImageView* icon = [NSImageView imageViewWithImage:NSApp.applicationIconImage];
    [icon.widthAnchor constraintEqualToConstant:64].active = YES;
    [icon.heightAnchor constraintEqualToConstant:64].active = YES;
    NSTextField* name = [NSTextField labelWithString:@"OpenKey"];
    name.font = [NSFont boldSystemFontOfSize:17];
    self.VersionInfo = SecondaryLabel(@"", 11);
    NSStackView* about = [NSStackView stackViewWithViews:@[icon, VStack(@[name, SecondaryLabel(@"Fork từ mã nguồn OpenKey", 13), self.VersionInfo], 3)]];
    about.spacing = 14;

    self.CheckNewVersionOnStartup = [self toggle:@selector(onCheckNewVersionOnStartup:)];
    self.CheckNewVersionButton = [NSButton buttonWithTitle:@"Kiểm tra bản mới..." target:self action:@selector(onCheckNewVersionButton:)];

    return Page(@[
        about,
        Section(@"Cập nhật", @[
            Row(@"Kiểm tra bản mới lúc khởi động", nil, self.CheckNewVersionOnStartup, @"Tự động kiểm tra phiên bản mới nhất mỗi khi khởi chạy OpenKey"),
            Row(@"Phiên bản mới", nil, self.CheckNewVersionButton, @"Bấm vào đây để kiểm tra phiên bản mới của OpenKey")], nil)]);
}

#pragma mark - Actions

- (IBAction)onInputTypeChanged:(NSPopUpButton *)sender {
    [appDelegate onInputTypeSelectedIndex:(int)[self.popupInputType indexOfSelectedItem]];
}

- (IBAction)onCodeTableChanged:(NSPopUpButton *)sender {
    [appDelegate onCodeTableChanged:(int)[self.popupCode indexOfSelectedItem]];
}

- (IBAction)onLanguageChanged:(NSSegmentedControl *)sender {
    int wantVietnamese = sender.selectedSegment == 0 ? 1 : 0;
    if (wantVietnamese != vLanguage)
        [appDelegate onInputMethodSelected];
}

- (IBAction)onModernOrthography:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"ModernOrthography"];
    vUseModernOrthography = (int)val;
}

- (IBAction)onCheckSpelling:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"Spelling"];
    vCheckSpelling = (int)val;
    [self.RestoreIfInvalidWord setEnabled:val];
    [self.AllowZWJF setEnabled:val];
    [self.TempOffSpellChecking setEnabled:val];
    OnSpellCheckingChanged();
}

- (IBAction)onShowUIOnStartup:(id)sender {
    [self setCustomValue:sender keyToSet:@"ShowUIOnStartup"];
}

- (IBAction)onRunOnStartup:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"RunOnStartup"];
    [appDelegate setRunOnStartup:val];
}

- (IBAction)onGrayIcon:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"GrayIcon"];
    [appDelegate setGrayIcon:val];
}

- (IBAction)onQuickTelex:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"QuickTelex"];
    vQuickTelex = (int)val;
}

- (IBAction)onRestoreIfInvalidWord:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"RestoreIfInvalidWord"];
    vRestoreIfWrongSpelling = (int)val;
}

- (IBAction)omTempOffSpellChecking:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vTempOffSpelling"];
    vTempOffSpelling = (int)val;
}

- (IBAction)onAllowZFWJ:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vAllowConsonantZFWJ"];
    vAllowConsonantZFWJ = (int)val;
}

- (IBAction)onFixRecommendBrowser:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"FixRecommendBrowser"];
    vFixRecommendBrowser = (int)val;
    [self.FixChromiumBrowser setEnabled:val];
}

- (IBAction)onSwitchModifiersChanged:(NSSegmentedControl *)sender {
    static const int bits[] = {0x100, 0x200, 0x400, 0x800}; // control, option, command, shift
    for (NSInteger i = 0; i < 4; i++) {
        vSwitchKeyStatus &= ~bits[i];
        if ([sender isSelectedForSegment:i])
            vSwitchKeyStatus |= bits[i];
    }
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

-(void)onMyTextFieldKeyChange:(unsigned short)keyCode character:(unsigned short)character {
    vSwitchKeyStatus &= 0xFFFFFF00;
    vSwitchKeyStatus |= keyCode;
    vSwitchKeyStatus &= 0x00FFFFFF;
    vSwitchKeyStatus |= ((unsigned int)character<<24);
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

- (IBAction)onBeepSound:(id)sender {
    unsigned int val = (unsigned int)[self setCustomValue:sender keyToSet:nil];
    vSwitchKeyStatus &= (~0x8000);
    vSwitchKeyStatus |= val << 15;
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

- (IBAction)onSendKeyStepByStep:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"SendKeyStepByStep"];
    vSendKeyStepByStep = (int)val;
}

- (IBAction)onPerformLayoutCompat:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vPerformLayoutCompat"];
    vPerformLayoutCompat = (int)val;
}

- (NSInteger)setCustomValue:(NSSwitch*)sender keyToSet:(NSString*) key {
    NSInteger val = sender.state == NSControlStateValueOn ? 1 : 0;
    if (key != nil)
        [[NSUserDefaults standardUserDefaults] setInteger:val forKey:key];
    return val;
}

- (IBAction)onMacroButton:(id)sender {
    [appDelegate onMacroSelected];
}

- (IBAction)onMacroChanged:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"UseMacro"];
    vUseMacro = (int)val;
}

- (IBAction)onUseMacroInEnglishModeChanged:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"UseMacroInEnglishMode"];
    vUseMacroInEnglishMode = (int)val;
}

- (IBAction)onAutoRememberSwitchKey:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"UseSmartSwitchKey"];
    vUseSmartSwitchKey = (int)val;
}

- (IBAction)onUpperCaseFirstChar:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"UpperCaseFirstChar"];
    vUpperCaseFirstChar = (int)val;
}
- (IBAction)onQuickStartConsonant:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vQuickStartConsonant"];
    vQuickStartConsonant = (int)val;
}

- (IBAction)onQuickEndConsonant:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vQuickEndConsonant"];
    vQuickEndConsonant = (int)val;
}

- (IBAction)onTempOffOpenKeyByHotKey:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vTempOffOpenKey"];
    vTempOffOpenKey = (int)val;
}

- (IBAction)onRememberTableCode:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vRememberCode"];
    vRememberCode = (int)val;
}

- (IBAction)onAutoCapsMacro:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vAutoCapsMacro"];
    vAutoCapsMacro = (int)val;
}

- (IBAction)onShowIconOnDock:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vShowIconOnDock"];
    vShowIconOnDock = (int)val;
    if (!vShowIconOnDock) {
        [self.view.window close];
    }
    [appDelegate showIconOnDock:vShowIconOnDock];
}

- (IBAction)onCheckNewVersionOnStartup:(NSSwitch *)sender {
    NSInteger val = sender.state == NSControlStateValueOn ? 0 : 1;
    [[NSUserDefaults standardUserDefaults] setInteger:val forKey:@"DontCheckUpdate"];
}

- (IBAction)onFixChromiumBrowser:(id)sender {
    NSInteger val = [self setCustomValue:sender keyToSet:@"vFixChromiumBrowser"];
    vFixChromiumBrowser = (int)val;
}

- (IBAction)onTerminateApp:(id)sender {
    [NSApp terminate:0];
}

-(void)fillData {
    NSInteger value;

    NSInteger intInputMethod = [[NSUserDefaults standardUserDefaults] integerForKey:@"InputMethod"];
    self.languageControl.selectedSegment = intInputMethod == 1 ? 0 : 1;

    NSInteger intInputType = [[NSUserDefaults standardUserDefaults] integerForKey:@"InputType"];
    [self.popupInputType selectItemAtIndex:intInputType];

    NSInteger intCodeTable = [[NSUserDefaults standardUserDefaults] integerForKey:@"CodeTable"];
    [self.popupCode selectItemAtIndex:intCodeTable];

    //option
    NSInteger showui = [[NSUserDefaults standardUserDefaults] integerForKey:@"ShowUIOnStartup"];
    self.ShowUIButton.state = showui ? NSControlStateValueOn : NSControlStateValueOff;

    NSInteger useModernOrthography = [[NSUserDefaults standardUserDefaults] integerForKey:@"ModernOrthography"];
    self.UseModernOrthography.state = useModernOrthography ? NSControlStateValueOn : NSControlStateValueOff;

    NSInteger spelling = [[NSUserDefaults standardUserDefaults] integerForKey:@"Spelling"];
    self.CheckSpellingButton.state = spelling ? NSControlStateValueOn : NSControlStateValueOff;

    NSInteger runOnStartup = [[NSUserDefaults standardUserDefaults] integerForKey:@"RunOnStartup"];
    self.RunOnStartupButton.state = runOnStartup ? NSControlStateValueOn : NSControlStateValueOff;

    NSInteger useGrayIcon = [[NSUserDefaults standardUserDefaults] integerForKey:@"GrayIcon"];
    self.UseGrayIcon.state = useGrayIcon ? NSControlStateValueOn : NSControlStateValueOff;

    NSInteger quicTelex = [[NSUserDefaults standardUserDefaults] integerForKey:@"QuickTelex"];
    self.QuickTelex.state = quicTelex ? NSControlStateValueOn : NSControlStateValueOff;

    NSInteger restoreIfInvalidWord = [[NSUserDefaults standardUserDefaults] integerForKey:@"RestoreIfInvalidWord"];
    self.RestoreIfInvalidWord.state = restoreIfInvalidWord ? NSControlStateValueOn : NSControlStateValueOff;
    [self.RestoreIfInvalidWord setEnabled:spelling];

    NSInteger tempOffSpelling = [[NSUserDefaults standardUserDefaults] integerForKey:@"vTempOffSpelling"];
    self.TempOffSpellChecking.state = tempOffSpelling ? NSControlStateValueOn : NSControlStateValueOff;
    [self.TempOffSpellChecking setEnabled:spelling];

    NSInteger allowZFWJ = [[NSUserDefaults standardUserDefaults] integerForKey:@"vAllowConsonantZFWJ"];
    self.AllowZWJF.state = allowZFWJ ? NSControlStateValueOn : NSControlStateValueOff;
    [self.AllowZWJF setEnabled:spelling];

    NSInteger fixRecommendBrowser = [[NSUserDefaults standardUserDefaults] integerForKey:@"FixRecommendBrowser"];
    self.FixRecommendBrowser.state = fixRecommendBrowser ? NSControlStateValueOn : NSControlStateValueOff;

    NSInteger useMacro = [[NSUserDefaults standardUserDefaults] integerForKey:@"UseMacro"];
    self.UseMacro.state = useMacro ? NSControlStateValueOn : NSControlStateValueOff;

    NSInteger useMacroInEnglish = [[NSUserDefaults standardUserDefaults] integerForKey:@"UseMacroInEnglishMode"];
    self.UseMacroInEnglishMode.state = useMacroInEnglish ? NSControlStateValueOn : NSControlStateValueOff;

    NSInteger sendKeySbS = [[NSUserDefaults standardUserDefaults] integerForKey:@"SendKeyStepByStep"];
    self.SendKeyStepByStep.state = sendKeySbS ? NSControlStateValueOn : NSControlStateValueOff;

    NSInteger useSmartSwitchKey = [[NSUserDefaults standardUserDefaults] integerForKey:@"UseSmartSwitchKey"];
    self.AutoRememberSwitchKey.state = useSmartSwitchKey ? NSControlStateValueOn : NSControlStateValueOff;

    NSInteger upperCaseFirstChar = [[NSUserDefaults standardUserDefaults] integerForKey:@"UpperCaseFirstChar"];
    self.UpperCaseFirstChar.state = upperCaseFirstChar ? NSControlStateValueOn : NSControlStateValueOff;

    NSInteger quickStartConsonant = [[NSUserDefaults standardUserDefaults] integerForKey:@"vQuickStartConsonant"];
    self.QuickStartConsonant.state = quickStartConsonant ? NSControlStateValueOn : NSControlStateValueOff;

    NSInteger quickEndConsonant = [[NSUserDefaults standardUserDefaults] integerForKey:@"vQuickEndConsonant"];
    self.QuickEndConsonant.state = quickEndConsonant ? NSControlStateValueOn : NSControlStateValueOff;

    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"vRememberCode"];
    self.RememberTableCode.state = value ? NSControlStateValueOn : NSControlStateValueOff;

    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"vTempOffOpenKey"];
    self.TempOffOpenKey.state = value ? NSControlStateValueOn : NSControlStateValueOff;

    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"vAutoCapsMacro"];
    self.AutoCapsMacro.state = value ? NSControlStateValueOn : NSControlStateValueOff;

    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"vShowIconOnDock"];
    self.ShowIconOnDock.state = value ? NSControlStateValueOn : NSControlStateValueOff;

    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"DontCheckUpdate"];
    self.CheckNewVersionOnStartup.state = value ? NSControlStateValueOff :NSControlStateValueOn;

    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"vFixChromiumBrowser"];
    self.FixChromiumBrowser.state = value ? NSControlStateValueOn : NSControlStateValueOff;
    self.FixChromiumBrowser.enabled = fixRecommendBrowser ? YES : NO;

    value = [[NSUserDefaults standardUserDefaults] integerForKey:@"vPerformLayoutCompat"];
    self.PerformLayoutCompat.state = value ? NSControlStateValueOn : NSControlStateValueOff;

    [self.switchModifiers setSelected:(vSwitchKeyStatus & 0x100) != 0 forSegment:0];
    [self.switchModifiers setSelected:(vSwitchKeyStatus & 0x200) != 0 forSegment:1];
    [self.switchModifiers setSelected:(vSwitchKeyStatus & 0x400) != 0 forSegment:2];
    [self.switchModifiers setSelected:(vSwitchKeyStatus & 0x800) != 0 forSegment:3];
    self.CustomBeepSound.state = (vSwitchKeyStatus & 0x8000) ? NSControlStateValueOn : NSControlStateValueOff;
    [self.CustomSwitchKey setTextByChar:((vSwitchKeyStatus>>24) & 0xFF)];

}

- (IBAction)onDefaultConfig:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Bạn có chắc chắn muốn thiết lập lại cấu hình mặc định?"];
    [alert addButtonWithTitle:@"Có"];
    [alert addButtonWithTitle:@"Không"];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == 1000) {
            [appDelegate loadDefaultConfig];
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"ShowUIOnStartup"];
            self.ShowUIButton.state = NSControlStateValueOff;

            [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"RunOnStartup"];
            self.RunOnStartupButton.state = NSControlStateValueOn;
        }
    }];
}

- (IBAction)onCheckNewVersionButton:(id)sender {
    self.CheckNewVersionButton.title = @"Đang kiểm tra...";
    self.CheckNewVersionButton.enabled = false;

    [OpenKeyManager checkNewVersion:self.view.window callbackFunc:^{
        self.CheckNewVersionButton.enabled = true;
        self.CheckNewVersionButton.title = @"Kiểm tra bản mới...";
    }];
}

@end
