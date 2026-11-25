// NetScope - Wi-Fi device scanner + speed test (iOS 14+, tested target iOS 16)
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <net/if.h>
#include <netinet/in.h>
#include <poll.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

#pragma mark - Helpers

#pragma mark - Localization (English / Arabic)

static NSString *NotifLang = @"NetScopeLangChanged";
static BOOL IsAr(void) { return [[NSUserDefaults standardUserDefaults] boolForKey:@"arabic"]; }

static NSDictionary *ArExact(void) {
    static NSDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = @{
            @"Devices": @"الأجهزة", @"Speed": @"السرعة", @"Tools": @"الأدوات", @"Settings": @"الإعدادات", @"Speed Test": @"اختبار السرعة",
            @"devices online": @"جهاز متصل", @"Scan network": @"فحص الشبكة", @"Scanning…": @"جاري الفحص…", @"Scan again": @"فحص مرة أخرى",
            @"All": @"الكل", @"New": @"جديد", @"Slow": @"بطيء", @"Wi-Fi network": @"شبكة الواي فاي", @"Not connected to Wi-Fi": @"غير متصل بالواي فاي",
            @"YOU": @"أنت", @"ROUTER": @"راوتر", @"NEW": @"جديد",
            @"Ping": @"Ping", @"Port scan": @"فحص المنافذ", @"Rename": @"تغيير الاسم", @"Copy IP": @"نسخ العنوان",
            @"Tap Ping or Port scan.": @"اضغط Ping أو فحص المنافذ.", @"IP copied.": @"تم نسخ العنوان.",
            @"Rename device": @"تغيير اسم الجهاز", @"Cancel": @"إلغاء", @"Save": @"حفظ", @"OK": @"حسنًا", @"Copied": @"تم النسخ", @"Cleared": @"تم المسح",
            @"Start test": @"ابدأ الاختبار", @"Testing…": @"جاري الاختبار…", @"Test again": @"اختبر مرة أخرى",
            @"PING (ms)": @"البنج (مللي ثانية)", @"JITTER (ms)": @"الجيتر (مللي ثانية)", @"DOWNLOAD (Mbps)": @"التحميل (ميجابت/ث)", @"UPLOAD (Mbps)": @"الرفع (ميجابت/ث)",
            @"History": @"السجل", @"No tests yet.": @"لا توجد اختبارات بعد.", @"Ready": @"جاهز", @"Measuring latency…": @"جاري قياس التأخير…",
            @"Download  Mbps": @"التحميل ميجابت/ث", @"Upload  Mbps": @"الرفع ميجابت/ث", @"Done · download Mbps": @"تم · التحميل ميجابت/ث",
            @"Test failed, check internet": @"فشل الاختبار، تأكد من الإنترنت",
            @"Host or IP  (e.g. google.com)": @"الدومين أو الـ IP (مثال: google.com)", @"DNS": @"DNS", @"Ports": @"المنافذ", @"Trace": @"تتبع المسار",
            @"My public IP": @"عنوان IP العام", @"Network tools. Enter a host, then pick a tool.": @"أدوات الشبكة. اكتب العنوان ثم اختر الأداة.",
            @"Enter a host first.": @"اكتب العنوان أولاً.", @"Checking…": @"جاري الفحص…", @"Scanning common ports…": @"جاري فحص المنافذ الشائعة…",
            @"No open ports found.": @"لا توجد منافذ مفتوحة.", @"Could not resolve host.": @"تعذر الوصول للعنوان.", @"No internet connection.": @"لا يوجد اتصال بالإنترنت.",
            @"Appearance": @"المظهر", @"Automatic": @"تلقائي", @"Light": @"فاتح", @"Black": @"أسود", @"Color theme": @"لون التطبيق", @"Language": @"اللغة",
            @"Developer": @"المطور", @"Clear history and names": @"مسح السجل والأسماء",
            @"This iPhone": @"هذا الآيفون", @"Router": @"راوتر", @"Smart TV": @"تلفزيون ذكي", @"Chromecast / Cast": @"كروم كاست", @"Android phone": @"موبايل أندرويد",
            @"Windows PC": @"كمبيوتر ويندوز", @"Smart speaker": @"سماعة ذكية", @"Printer": @"طابعة", @"Apple TV / AirPlay": @"Apple TV / AirPlay",
            @"iPhone / iPad": @"آيفون / آيباد", @"IP camera": @"كاميرا مراقبة", @"Computer / NAS": @"كمبيوتر / NAS", @"Server / Linux": @"سيرفر / لينكس",
            @"Apple device": @"جهاز أبل", @"Web device": @"جهاز ويب", @"Unknown": @"غير معروف", @"Mac": @"ماك",
            @"No open ports found in quick scan": @"لا توجد منافذ مفتوحة في الفحص السريع"
        };
    });
    return d;
}
static NSArray *ArFrags(void) {
    return @[ @[ @"Wi-Fi  ·  my IP ", @"واي فاي  ·  عنوان جهازي " ], @[ @"  ·  subnet ", @"  ·  القناع " ],
              @[ @"Open ports: ", @"المنافذ المفتوحة: " ], @[ @"WhatsApp username: ", @"يوزر الواتساب: " ],
              @[ @"Download failed: ", @"فشل التحميل: " ], @[ @"Upload failed: ", @"فشل الرفع: " ], @[ @"no server reachable", @"مفيش سيرفر متاح" ], @[ @"Done · ", @"تم · " ], @[ @"Unknown", @"غير معروف" ], @[ @"This iPhone", @"هذا الآيفون" ], @[ @"Windows PC", @"كمبيوتر ويندوز" ],
              @[ @"Smart speaker", @"سماعة ذكية" ], @[ @"Smart TV", @"تلفزيون ذكي" ], @[ @"Computer / NAS", @"كمبيوتر / NAS" ],
              @[ @"Server / Linux", @"سيرفر / لينكس" ], @[ @"Apple device", @"جهاز أبل" ], @[ @"Web device", @"جهاز ويب" ],
              @[ @"IP camera", @"كاميرا مراقبة" ], @[ @"Printer", @"طابعة" ], @[ @"Router", @"راوتر" ], @[ @"Android phone", @"موبايل أندرويد" ] ];
}
static NSString *T(NSString *s) {
    if (!IsAr() || !s.length) return s;
    NSString *tr = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSString *hit = ArExact()[tr];
    if (hit) { NSRange r = [s rangeOfString:tr]; return [NSString stringWithFormat:@"%@%@%@", [s substringToIndex:r.location], hit, [s substringFromIndex:r.location + r.length]]; }
    if ([s hasPrefix:@"NetScope 1."]) {
        return @"NetScope 1.7\nبيدوّر على الأجهزة المتصلة بالواي فاي بالـ ping وفحص المنافذ وBonjour، وبيقيس السرعة عن طريق Cloudflare. آبل مش بتسمح للتطبيقات بقراءة عناوين MAC، فنوع الجهاز بيتخمن من الاسم والمنافذ المفتوحة. كل حاجة بتشتغل على موبايلك ومفيش حاجة بتترفع.";
    }
    if ([s containsString:@"·"] || [s hasPrefix:@"Open ports"] || [s hasPrefix:@"WhatsApp username"] || [s hasPrefix:@"Download failed"] || [s hasPrefix:@"Upload failed"]) {
        NSString *o = s;
        for (NSArray *f in ArFrags()) o = [o stringByReplacingOccurrencesOfString:f[0] withString:f[1]];
        return o;
    }
    return s;
}
static NSString *TT(NSString *s) { return T(s); }

static void SwizzleSetter(Class c, SEL orig, SEL repl) { method_exchangeImplementations(class_getInstanceMethod(c, orig), class_getInstanceMethod(c, repl)); }

@interface UILabel (NSLoc) @end
@implementation UILabel (NSLoc) - (void)ns_setText:(NSString *)t { [self ns_setText:T(t)]; } @end
@interface UITextView (NSLoc) @end
@implementation UITextView (NSLoc) - (void)ns_setText:(NSString *)t { [self ns_setText:T(t)]; } @end
@interface UIButton (NSLoc) @end
@implementation UIButton (NSLoc) - (void)ns_setTitle:(NSString *)t forState:(UIControlState)s { [self ns_setTitle:T(t) forState:s]; } @end
@interface UIViewController (NSLoc) @end
@implementation UIViewController (NSLoc) - (void)ns_setTitle:(NSString *)t { [self ns_setTitle:T(t)]; } @end

static void SetupLocalization(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SwizzleSetter(UILabel.class, @selector(setText:), @selector(ns_setText:));
        SwizzleSetter(UITextView.class, @selector(setText:), @selector(ns_setText:));
        SwizzleSetter(UIButton.class, @selector(setTitle:forState:), @selector(ns_setTitle:forState:));
        SwizzleSetter(UIViewController.class, @selector(setTitle:), @selector(ns_setTitle:));
    });
}
static void ApplyDirection(void) {
    UISemanticContentAttribute a = IsAr() ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    [UIView appearance].semanticContentAttribute = a;
    [UINavigationBar appearance].semanticContentAttribute = a;
    [UITabBar appearance].semanticContentAttribute = a;
    [UITableView appearance].semanticContentAttribute = a;
    [UISegmentedControl appearance].semanticContentAttribute = a;
}


static double NowMs(void) { struct timeval tv; gettimeofday(&tv, NULL); return tv.tv_sec * 1000.0 + tv.tv_usec / 1000.0; }

static NSString *PrefAccent = @"accent";
static NSString *PrefAppearance = @"appearance";
static NSString *NotifTheme = @"NetScopeThemeChanged";

@interface Theme : NSObject
+ (NSInteger)accentIndex;
+ (UIColor *)accent;
+ (UIColor *)accent2;
+ (NSArray<NSString *> *)accentNames;
+ (void)applyAppearance;
@end

@implementation Theme
+ (NSInteger)accentIndex { return [[NSUserDefaults standardUserDefaults] integerForKey:PrefAccent]; }
+ (NSArray *)palette {
    return @[ @[ @0x0A84FF, @0x5E5CE6 ],  // Ocean
              @[ @0xBF5AF2, @0xFF375F ],  // Violet
              @[ @0x30D158, @0x0A84FF ],  // Mint
              @[ @0xFF9F0A, @0xFF375F ],  // Sunset
              @[ @0xFF2D55, @0xFF6482 ],  // Rose
              @[ @0xFF453A, @0xFF9F0A ],  // Crimson
              @[ @0xFFD60A, @0xFF9F0A ],  // Gold
              @[ @0x00E5FF, @0x00FF9C ],  // Cyber
              @[ @0x8E8E93, @0xC7C7CC ]   // Graphite
    ];
}
+ (NSArray<NSString *> *)accentNames { return @[ @"Ocean", @"Violet", @"Mint", @"Sunset", @"Rose", @"Crimson", @"Gold", @"Cyber", @"Graphite" ]; }
+ (UIColor *)hex:(NSInteger)h { return [UIColor colorWithRed:((h >> 16) & 255) / 255.0 green:((h >> 8) & 255) / 255.0 blue:(h & 255) / 255.0 alpha:1]; }
+ (UIColor *)accent { return [self hex:[[self palette][self.accentIndex % 9][0] integerValue]]; }
+ (UIColor *)accent2 { return [self hex:[[self palette][self.accentIndex % 9][1] integerValue]]; }
+ (void)applyAppearance {
    NSInteger a = [[NSUserDefaults standardUserDefaults] integerForKey:PrefAppearance];
    UIUserInterfaceStyle st = a == 1 ? UIUserInterfaceStyleLight : (a == 2 ? UIUserInterfaceStyleDark : UIUserInterfaceStyleUnspecified);
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:UIWindowScene.class]) for (UIWindow *w in ((UIWindowScene *)s).windows) w.overrideUserInterfaceStyle = st;
    }
    for (UIWindow *w in UIApplication.sharedApplication.windows) w.overrideUserInterfaceStyle = st;
    [[NSNotificationCenter defaultCenter] postNotificationName:NotifTheme object:nil];
}
@end

#pragma mark - Glass UI

@interface GradientView : UIView
@property(nonatomic, strong) CAGradientLayer *grad;
@property(nonatomic, strong) UIView *orb1, *orb2, *orb3;
@end
@implementation GradientView
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:NotifTheme object:nil];
        [self refresh];
    }
    return self;
}
- (void)refresh {
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.backgroundColor = dark ? UIColor.blackColor : UIColor.whiteColor;
}
- (void)traitCollectionDidChange:(UITraitCollection *)t { [super traitCollectionDidChange:t]; [self refresh]; }
@end

@interface GlassView : UIView
@property(nonatomic, strong) UIVisualEffectView *blur;
@end
@implementation GlassView
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.layer.cornerRadius = 22;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.clipsToBounds = YES;
        self.layer.borderWidth = 1;
        self.blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
        self.blur.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.blur];
        [NSLayoutConstraint activateConstraints:@[
            [self.blur.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [self.blur.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.blur.topAnchor constraintEqualToAnchor:self.topAnchor], [self.blur.bottomAnchor constraintEqualToAnchor:self.bottomAnchor] ]];
        [self updateBorder];
    }
    return self;
}
- (void)updateBorder {
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:dark ? 0.16 : 0.7].CGColor;
}
- (void)traitCollectionDidChange:(UITraitCollection *)t { [super traitCollectionDidChange:t]; [self updateBorder]; }
- (UIView *)content { return self.blur.contentView; }
@end

static UILabel *Label(NSString *t, CGFloat size, UIFontWeight w, UIColor *c) {
    UILabel *l = [UILabel new];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.text = t; l.font = [UIFont systemFontOfSize:size weight:w]; l.textColor = c ?: UIColor.labelColor;
    return l;
}

static UIButton *GlassButton(NSString *title, id target, SEL sel) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.backgroundColor = Theme.accent;
    b.layer.cornerRadius = 16; b.layer.cornerCurve = kCACornerCurveContinuous;
    [b addTarget:target action:sel forControlEvents:UIControlEventTouchUpInside];
    [b.heightAnchor constraintEqualToConstant:46].active = YES;
    return b;
}

@interface BaseVC : UIViewController
@property(nonatomic, strong) GradientView *bg;
- (void)themeChanged;
@end
@implementation BaseVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.bg = [[GradientView alloc] initWithFrame:self.view.bounds];
    self.bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:self.bg atIndex:0];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged) name:NotifTheme object:nil];
}
- (void)themeChanged { self.view.tintColor = Theme.accent; }
@end

#pragma mark - Networking core

typedef struct { uint32_t ip; uint32_t mask; char name[16]; } LocalNet;

static BOOL GetLocalNet(LocalNet *out) {
    struct ifaddrs *list = NULL, *p;
    if (getifaddrs(&list) != 0) return NO;
    BOOL found = NO;
    for (p = list; p; p = p->ifa_next) {
        if (!p->ifa_addr || p->ifa_addr->sa_family != AF_INET) continue;
        if (!(p->ifa_flags & IFF_UP) || (p->ifa_flags & IFF_LOOPBACK)) continue;
        if (strncmp(p->ifa_name, "en", 2) != 0) continue;
        uint32_t ip = ntohl(((struct sockaddr_in *)p->ifa_addr)->sin_addr.s_addr);
        uint32_t mask = ntohl(((struct sockaddr_in *)p->ifa_netmask)->sin_addr.s_addr);
        if ((ip >> 24) == 169) continue;
        out->ip = ip; out->mask = mask; strncpy(out->name, p->ifa_name, 15);
        found = YES;
        if (strcmp(p->ifa_name, "en0") == 0) break;
    }
    freeifaddrs(list);
    return found;
}

static NSString *IPString(uint32_t ip) { return [NSString stringWithFormat:@"%u.%u.%u.%u", ip >> 24, (ip >> 16) & 255, (ip >> 8) & 255, ip & 255]; }
static uint32_t IPFromString(NSString *s) { struct in_addr a; if (inet_pton(AF_INET, s.UTF8String, &a) != 1) return 0; return ntohl(a.s_addr); }

static uint16_t Checksum(const void *data, size_t len) {
    const uint16_t *p = data; uint32_t sum = 0;
    while (len > 1) { sum += *p++; len -= 2; }
    if (len) sum += *(const uint8_t *)p;
    sum = (sum >> 16) + (sum & 0xFFFF); sum += (sum >> 16);
    return (uint16_t)~sum;
}

static int OpenICMP(void) {
    int fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
    if (fd >= 0) fcntl(fd, F_SETFL, O_NONBLOCK);
    return fd;
}

static void SendEcho(int fd, uint32_t ip, uint16_t seq) {
    uint8_t pkt[16] = { 8, 0, 0, 0, 0x4E, 0x53, 0, 0, 'N', 'e', 't', 'S', 'c', 'o', 'p', 'e' };
    pkt[6] = seq >> 8; pkt[7] = seq & 255;
    uint16_t cs = Checksum(pkt, sizeof pkt);
    memcpy(pkt + 2, &cs, 2);
    struct sockaddr_in to; memset(&to, 0, sizeof to);
    to.sin_len = sizeof to; to.sin_family = AF_INET; to.sin_addr.s_addr = htonl(ip);
    sendto(fd, pkt, sizeof pkt, 0, (struct sockaddr *)&to, sizeof to);
}

// Receive echo replies until deadline; calls cb(ip) for each reply.
static void CollectReplies(int fd, double deadlineMs, void (^cb)(uint32_t ip)) {
    uint8_t buf[512];
    while (1) {
        double left = deadlineMs - NowMs();
        if (left <= 0) break;
        struct pollfd pf = { fd, POLLIN, 0 };
        int r = poll(&pf, 1, (int)left);
        if (r <= 0) break;
        while (1) {
            struct sockaddr_in from; socklen_t fl = sizeof from;
            ssize_t n = recvfrom(fd, buf, sizeof buf, 0, (struct sockaddr *)&from, &fl);
            if (n <= 0) break;
            size_t hl = (buf[0] & 0x0F) * 4;
            if ((size_t)n > hl && buf[0] >> 4 == 4 && buf[hl] == 0) cb(ntohl(from.sin_addr.s_addr));
            else if ((size_t)n >= 2 && buf[0] == 0) cb(ntohl(from.sin_addr.s_addr));
        }
    }
}

// Single ping, returns ms or -1
static double PingOnce(uint32_t ip, int timeoutMs, uint16_t seq) {
    int fd = OpenICMP();
    if (fd < 0) return -1;
    __block double result = -1;
    double t0 = NowMs();
    SendEcho(fd, ip, seq);
    CollectReplies(fd, t0 + timeoutMs, ^(uint32_t src) { if (src == ip && result < 0) result = NowMs() - t0; });
    close(fd);
    return result;
}

// Parallel TCP probe. Returns open ports; *alive set if host answered (open or refused).
static NSArray<NSNumber *> *TCPProbe(uint32_t ip, NSArray<NSNumber *> *ports, int timeoutMs, BOOL *alive) {
    NSMutableArray *open = [NSMutableArray array];
    int n = (int)ports.count;
    int fds[n]; struct pollfd pfs[n]; int pend = 0;
    for (int i = 0; i < n; i++) {
        fds[i] = -1; pfs[i].fd = -1; pfs[i].events = 0;
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) continue;
        fcntl(fd, F_SETFL, O_NONBLOCK);
        int one = 1; setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof one);
        struct sockaddr_in a; memset(&a, 0, sizeof a);
        a.sin_len = sizeof a; a.sin_family = AF_INET; a.sin_addr.s_addr = htonl(ip); a.sin_port = htons([ports[i] intValue]);
        int rc = connect(fd, (struct sockaddr *)&a, sizeof a);
        if (rc == 0) { [open addObject:ports[i]]; if (alive) *alive = YES; close(fd); continue; }
        if (errno == ECONNREFUSED) { if (alive) *alive = YES; close(fd); continue; }
        if (errno != EINPROGRESS) { close(fd); continue; }
        fds[i] = fd; pfs[i].fd = fd; pfs[i].events = POLLOUT; pend++;
    }
    double end = NowMs() + timeoutMs;
    while (pend > 0) {
        double left = end - NowMs();
        if (left <= 0) break;
        int r = poll(pfs, n, (int)left);
        if (r <= 0) break;
        for (int i = 0; i < n; i++) {
            if (pfs[i].fd < 0 || !pfs[i].revents) continue;
            int err = 0; socklen_t el = sizeof err;
            getsockopt(fds[i], SOL_SOCKET, SO_ERROR, &err, &el);
            if (err == 0) { [open addObject:ports[i]]; if (alive) *alive = YES; }
            else if (err == ECONNREFUSED) { if (alive) *alive = YES; }
            close(fds[i]); fds[i] = -1; pfs[i].fd = -1; pend--;
        }
    }
    for (int i = 0; i < n; i++) if (fds[i] >= 0) close(fds[i]);
    return open;
}

static NSString *ReverseDNS(uint32_t ip) {
    struct sockaddr_in a; memset(&a, 0, sizeof a);
    a.sin_len = sizeof a; a.sin_family = AF_INET; a.sin_addr.s_addr = htonl(ip);
    char host[256];
    if (getnameinfo((struct sockaddr *)&a, sizeof a, host, sizeof host, NULL, 0, NI_NAMEREQD) == 0) {
        NSString *h = [NSString stringWithUTF8String:host];
        if ([h rangeOfString:@"."].location != NSNotFound && [h hasSuffix:@".local"] == NO && [h hasSuffix:@".lan"] == NO && [h hasSuffix:@".home"] == NO) {
            // keep only first label for readability if it is an FQDN of the LAN
            return [h componentsSeparatedByString:@"."].firstObject;
        }
        return [h componentsSeparatedByString:@"."].firstObject;
    }
    return nil;
}

static NSString *DNSNameAt(const uint8_t *b, size_t len, size_t pos) {
    NSMutableArray *parts = [NSMutableArray array]; int guard = 0;
    while (pos < len && guard++ < 20) {
        uint8_t l = b[pos];
        if (l == 0) break;
        if ((l & 0xC0) == 0xC0) { if (pos + 1 >= len) break; pos = ((l & 0x3F) << 8) | b[pos + 1]; continue; }
        if (pos + 1 + l > len) break;
        NSString *p = [[NSString alloc] initWithBytes:b + pos + 1 length:l encoding:NSUTF8StringEncoding];
        if (p) [parts addObject:p];
        pos += 1 + l;
    }
    return [parts componentsJoinedByString:@"."];
}

static NSData *UDPExchange(uint32_t ip, uint16_t port, const uint8_t *q, size_t qlen, int timeoutMs) {
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) return nil;
    struct sockaddr_in a; memset(&a, 0, sizeof a); a.sin_len = sizeof a; a.sin_family = AF_INET; a.sin_addr.s_addr = htonl(ip); a.sin_port = htons(port);
    sendto(fd, q, qlen, 0, (struct sockaddr *)&a, sizeof a);
    struct pollfd pf = { fd, POLLIN, 0 };
    NSData *res = nil;
    if (poll(&pf, 1, timeoutMs) > 0) { uint8_t buf[1024]; ssize_t n = recv(fd, buf, sizeof buf, 0); if (n > 12) res = [NSData dataWithBytes:buf length:n]; }
    close(fd);
    return res;
}

// Unicast mDNS reverse lookup (Apple devices, Windows 10, many Android/Linux devices answer)
static NSString *MDNSName(uint32_t ip) {
    uint8_t q[128]; size_t n = 0;
    memset(q, 0, 12); q[5] = 1; n = 12;
    NSString *rev = [NSString stringWithFormat:@"%u.%u.%u.%u.in-addr.arpa", ip & 255, (ip >> 8) & 255, (ip >> 16) & 255, ip >> 24];
    for (NSString *l in [rev componentsSeparatedByString:@"."]) { q[n++] = (uint8_t)l.length; memcpy(q + n, l.UTF8String, l.length); n += l.length; }
    q[n++] = 0; q[n++] = 0; q[n++] = 12; q[n++] = 0x80; q[n++] = 1;
    NSData *r = UDPExchange(ip, 5353, q, n, 600);
    if (!r) return nil;
    const uint8_t *b = r.bytes; size_t len = r.length;
    if (b[7] == 0 && b[6] == 0) return nil;
    size_t pos = 12; // skip question(s) if echoed
    int qd = (b[4] << 8) | b[5];
    for (int i = 0; i < qd; i++) { while (pos < len && b[pos] != 0) { if ((b[pos] & 0xC0) == 0xC0) { pos++; break; } pos += b[pos] + 1; } pos += 5; }
    // answer: name, type, class, ttl, rdlen, rdata
    while (pos < len && b[pos] != 0) { if ((b[pos] & 0xC0) == 0xC0) { pos++; break; } pos += b[pos] + 1; }
    pos += 1; if (pos + 10 > len) return nil;
    int type = (b[pos] << 8) | b[pos + 1];
    pos += 10;
    if (type != 12) return nil;
    NSString *nm = DNSNameAt(b, len, pos);
    NSString *first = [nm componentsSeparatedByString:@"."].firstObject;
    return first.length ? first : nil;
}

// NetBIOS name query (Windows PCs, some NAS / printers)
static NSString *NBNSName(uint32_t ip) {
    uint8_t q[50]; memset(q, 0, sizeof q);
    q[0] = 0x4E; q[1] = 0x42; q[5] = 1;
    q[12] = 0x20; q[13] = 'C'; q[14] = 'K'; for (int i = 0; i < 30; i++) q[15 + i] = 'A';
    q[45] = 0; q[46] = 0; q[47] = 0x21; q[48] = 0; q[49] = 1;
    NSData *r = UDPExchange(ip, 137, q, sizeof q, 600);
    if (!r || r.length < 70) return nil;
    const uint8_t *b = r.bytes; size_t pos = 12;
    if (b[pos] == 0xC0) pos += 2; else pos += 34;
    pos += 10; if (pos + 1 + 15 > r.length) return nil;
    int cnt = b[pos]; if (cnt < 1) return nil;
    NSString *nm = [[[NSString alloc] initWithBytes:b + pos + 1 length:15 encoding:NSASCIIStringEncoding] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    return nm.length ? nm : nil;
}

static void Traceroute(uint32_t target, void (^line)(NSString *)) {
    for (int ttl = 1; ttl <= 20; ttl++) {
        int fd = OpenICMP();
        if (fd < 0) { line(@"ICMP not available"); return; }
        setsockopt(fd, IPPROTO_IP, IP_TTL, &ttl, sizeof ttl);
        double t0 = NowMs();
        SendEcho(fd, target, (uint16_t)ttl);
        uint32_t src = 0; BOOL reached = NO;
        struct pollfd pf = { fd, POLLIN, 0 };
        if (poll(&pf, 1, 1500) > 0) {
            uint8_t buf[512]; struct sockaddr_in from; socklen_t fl = sizeof from;
            ssize_t n = recvfrom(fd, buf, sizeof buf, 0, (struct sockaddr *)&from, &fl);
            if (n > 0) { src = ntohl(from.sin_addr.s_addr); size_t hl = (buf[0] >> 4 == 4) ? (buf[0] & 15) * 4 : 0; reached = (n > (ssize_t)hl && buf[hl] == 0) || src == target; }
        }
        double ms = NowMs() - t0;
        close(fd);
        if (src) line([NSString stringWithFormat:@"%2d  %-16@ %.0f ms", ttl, IPString(src), ms]);
        else line([NSString stringWithFormat:@"%2d  *", ttl]);
        if (reached) return;
    }
}

static NSDictionary<NSNumber *, NSString *> *PortNames(void) {
    return @{ @21: @"FTP", @22: @"SSH", @23: @"Telnet", @25: @"SMTP", @53: @"DNS", @80: @"HTTP", @110: @"POP3", @111: @"RPC", @135: @"MS-RPC",
              @139: @"NetBIOS", @143: @"IMAP", @443: @"HTTPS", @445: @"SMB", @515: @"LPD", @548: @"AFP", @554: @"RTSP", @631: @"IPP",
              @1883: @"MQTT", @1900: @"UPnP", @3000: @"Dev", @3389: @"RDP", @5000: @"UPnP/NAS", @5900: @"VNC", @7000: @"AirPlay", @8000: @"HTTP-alt",
              @8008: @"Cast", @8009: @"Cast", @8080: @"HTTP-alt", @8443: @"HTTPS-alt", @8888: @"HTTP-alt", @9100: @"Printer", @32400: @"Plex",
              @62078: @"iOS device" };
}

#pragma mark - Device model

@interface Device : NSObject
@property(nonatomic) uint32_t ip;
@property(nonatomic, copy) NSString *host;
@property(nonatomic, copy) NSString *bonjourName;
@property(nonatomic, strong) NSMutableSet<NSString *> *services;
@property(nonatomic, strong) NSArray<NSNumber *> *ports;
@property(nonatomic) double pingMs;
@property(nonatomic) BOOL isMe, isNew;
- (NSString *)ipString;
- (NSString *)kind;
- (NSString *)icon;
- (NSString *)title;
@end
@implementation Device
- (instancetype)init { if ((self = [super init])) { _services = [NSMutableSet set]; _ports = @[]; _pingMs = -1; } return self; }
- (NSString *)ipString { return IPString(self.ip); }
- (BOOL)hasPort:(int)p { return [self.ports containsObject:@(p)]; }
- (BOOL)hasSvc:(NSString *)s { for (NSString *x in self.services) if ([x containsString:s]) return YES; return NO; }
- (NSString *)kind {
    if (self.isMe) return @"This iPhone";
    NSString *n = [(self.bonjourName ?: self.host ?: @"") lowercaseString];
    if ([self hasSvc:@"googlecast"] || [self hasPort:8008] || [self hasPort:8009]) return [n containsString:@"tv"] ? @"Smart TV" : @"Chromecast / Cast";
    if ([n containsString:@"iphone"]) return @"iPhone";
    if ([n containsString:@"ipad"]) return @"iPad";
    if ([n containsString:@"macbook"] || [n containsString:@"imac"] || [n containsString:@"mac-"] || [n containsString:@"mac mini"]) return @"Mac";
    if ([n containsString:@"android"] || [n containsString:@"galaxy"] || [n containsString:@"pixel"] || [n containsString:@"xiaomi"] || [n containsString:@"redmi"] || [n containsString:@"oppo"] || [n containsString:@"huawei"]) return @"Android phone";
    if ([n containsString:@"desktop"] || [n containsString:@"laptop"] || [n containsString:@"-pc"] || [n containsString:@"win"]) return @"Windows PC";
    if ([n containsString:@"tv"] || [n containsString:@"roku"] || [n containsString:@"bravia"]) return @"Smart TV";
    if ([n containsString:@"echo"] || [n containsString:@"alexa"] || [n containsString:@"homepod"]) return @"Smart speaker";
    if ([self hasSvc:@"printer"] || [self hasSvc:@"ipp"] || [self hasPort:9100] || [self hasPort:631] || [self hasPort:515]) return @"Printer";
    if ([self hasSvc:@"airplay"] || [self hasSvc:@"raop"] || [self hasPort:7000]) return @"Apple TV / AirPlay";
    if ([self hasPort:62078]) return @"iPhone / iPad";
    if ([self hasPort:554]) return @"IP camera";
    if ([self hasPort:3389] || [self hasPort:135] || [self hasPort:139]) return @"Windows PC";
    if ([self hasPort:445] || [self hasPort:548] || [self hasSvc:@"smb"]) return @"Computer / NAS";
    if ([self hasPort:22]) return @"Server / Linux";
    if ([self hasSvc:@"companion-link"] || [self hasSvc:@"device-info"]) return @"Apple device";
    uint32_t last = self.ip & 255;
    if ((last == 1 || last == 254) && ([self hasPort:80] || [self hasPort:443] || [self hasPort:53])) return @"Router";
    if ([self hasPort:80] || [self hasPort:443] || [self hasPort:8080]) return @"Web device";
    return @"Unknown";
}
- (NSString *)icon {
    NSString *k = [self kind];
    if ([k isEqualToString:@"Router"]) return @"wifi.router";
    if ([k containsString:@"iPad"] && ![k containsString:@"iPhone"]) return @"ipad";
    if ([k containsString:@"phone"] || [k containsString:@"iPhone"]) return @"iphone";
    if ([k isEqualToString:@"Mac"] || [k isEqualToString:@"Windows PC"]) return @"laptopcomputer";
    if ([k containsString:@"TV"] || [k containsString:@"Cast"]) return @"tv";
    if ([k containsString:@"speaker"]) return @"homepod";
    if ([k isEqualToString:@"Printer"]) return @"printer";
    if ([k containsString:@"camera"]) return @"video";
    if ([k containsString:@"Server"] || [k containsString:@"NAS"]) return @"server.rack";
    if ([k containsString:@"Apple"]) return @"applelogo";
    return @"questionmark.circle";
}
- (NSString *)nick { return [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"nicks"][self.ipString]; }
- (NSString *)title {
    NSString *n = [self nick];
    if (n.length) return n;
    if (self.isMe) return @"This iPhone";
    if (self.bonjourName.length) return self.bonjourName;
    if (self.host.length) return self.host;
    return [self kind];
}
@end

#pragma mark - Bonjour

@interface Bonjour : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
@property(nonatomic, strong) NSMutableArray *browsers, *services;
@property(nonatomic, copy) void (^found)(uint32_t ip, NSString *name, NSString *type);
- (void)start;
- (void)stop;
@end
@implementation Bonjour
- (void)start {
    self.browsers = [NSMutableArray array]; self.services = [NSMutableArray array];
    NSArray *types = @[ @"_http._tcp.", @"_airplay._tcp.", @"_raop._tcp.", @"_googlecast._tcp.", @"_ipp._tcp.", @"_printer._tcp.", @"_smb._tcp.",
                        @"_device-info._tcp.", @"_companion-link._tcp.", @"_homekit._tcp.", @"_hap._tcp.", @"_spotify-connect._tcp.", @"_ssh._tcp.",
                        @"_workstation._tcp.", @"_afpovertcp._tcp.", @"_sleep-proxy._udp." ];
    for (NSString *t in types) {
        NSNetServiceBrowser *b = [NSNetServiceBrowser new];
        b.delegate = self;
        [b searchForServicesOfType:t inDomain:@"local."];
        [self.browsers addObject:b];
    }
}
- (void)stop {
    for (NSNetServiceBrowser *b in self.browsers) [b stop];
    for (NSNetService *s in self.services) [s stop];
    [self.browsers removeAllObjects]; [self.services removeAllObjects];
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)b didFindService:(NSNetService *)s moreComing:(BOOL)more {
    s.delegate = self;
    [self.services addObject:s];
    [s resolveWithTimeout:4];
}
- (void)netServiceDidResolveAddress:(NSNetService *)s {
    for (NSData *d in s.addresses) {
        const struct sockaddr *sa = d.bytes;
        if (sa->sa_family == AF_INET) {
            uint32_t ip = ntohl(((const struct sockaddr_in *)sa)->sin_addr.s_addr);
            NSString *host = s.hostName;
            NSString *name = host.length ? [[host componentsSeparatedByString:@"."].firstObject stringByReplacingOccurrencesOfString:@"-" withString:@" "] : s.name;
            if (host.length) name = [[host componentsSeparatedByString:@"."].firstObject copy];
            if (self.found) self.found(ip, name, s.type);
            break;
        }
    }
}
- (void)netService:(NSNetService *)s didNotResolve:(NSDictionary *)e {}
@end

#pragma mark - Scanner

@interface Scanner : NSObject
+ (void)scanWithProgress:(void (^)(float))progress device:(void (^)(Device *))deviceCB done:(void (^)(NSArray<Device *> *))done;
@end
@implementation Scanner
+ (void)scanWithProgress:(void (^)(float))progress device:(void (^)(Device *))deviceCB done:(void (^)(NSArray<Device *> *))done {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        struct rlimit rl = { 4096, 4096 }; setrlimit(RLIMIT_NOFILE, &rl);
        LocalNet ln;
        if (!GetLocalNet(&ln)) { dispatch_async(dispatch_get_main_queue(), ^{ done(@[]); }); return; }
        uint32_t mask = ln.mask;
        if (mask < 0xFFFFFC00) mask = 0xFFFFFF00;
        uint32_t base = ln.ip & mask, count = ~mask;
        NSMutableDictionary<NSNumber *, Device *> *found = [NSMutableDictionary dictionary];
        NSLock *lock = [NSLock new];
        void (^addDev)(uint32_t, double, NSArray *) = ^(uint32_t ip, double ms, NSArray *ports) {
            [lock lock];
            Device *d = found[@(ip)]; BOOL fresh = NO;
            if (!d) { d = [Device new]; d.ip = ip; d.isMe = (ip == ln.ip); found[@(ip)] = d; fresh = YES; }
            if (ms >= 0 && (d.pingMs < 0 || ms < d.pingMs)) d.pingMs = ms;
            if (ports.count) d.ports = ports;
            [lock unlock];
            if (fresh) dispatch_async(dispatch_get_main_queue(), ^{ deviceCB(d); });
        };
        addDev(ln.ip, 0, @[]);
        // Stage 1: ICMP sweep (2 rounds)
        int fd = OpenICMP();
        if (fd >= 0) {
            for (int round = 0; round < 2; round++) {
                double *sendT = calloc(count + 2, sizeof(double));
                for (uint32_t i = 1; i < count; i++) { sendT[i] = NowMs(); SendEcho(fd, base + i, (uint16_t)i); usleep(1500); }
                double deadline = NowMs() + 1200;
                CollectReplies(fd, deadline, ^(uint32_t src) {
                    if ((src & mask) != base) return;
                    uint32_t i = src - base; if (i >= count) return;
                    addDev(src, -1, nil);
                });
                free(sendT);
                dispatch_async(dispatch_get_main_queue(), ^{ progress(round == 0 ? 0.15f : 0.3f); });
            }
            close(fd);
        }
        // Stage 2: TCP probe every host (finds hosts that block ping + open ports)
        NSArray *ports = @[ @80, @443, @62078, @22, @53, @445, @139, @7000, @8008, @8009, @8080, @9100, @631, @554, @548, @5000 ];
        dispatch_group_t g = dispatch_group_create();
        dispatch_semaphore_t sem = dispatch_semaphore_create(24);
        dispatch_queue_t q = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
        __block int doneCount = 0;
        for (uint32_t i = 1; i < count; i++) {
            uint32_t ip = base + i;
            if (ip == ln.ip) { doneCount++; continue; }
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            dispatch_group_async(g, q, ^{
                BOOL alive = NO;
                double t0 = NowMs();
                NSArray *open = TCPProbe(ip, ports, 700, &alive);
                double ms = NowMs() - t0;
                [lock lock]; BOOL known = found[@(ip)] != nil; [lock unlock];
                if (alive || known) addDev(ip, alive && ms < 600 ? -1 : -1, open);
                dispatch_semaphore_signal(sem);
                [lock lock]; doneCount++; int dc = doneCount; [lock unlock];
                if (dc % 8 == 0) dispatch_async(dispatch_get_main_queue(), ^{ progress(0.3f + 0.6f * dc / (float)count); });
            });
        }
        dispatch_group_wait(g, dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC));
        // Stage 3: names + latency for found hosts
        NSArray *devs; [lock lock]; devs = found.allValues; [lock unlock];
        dispatch_group_t g2 = dispatch_group_create();
        dispatch_semaphore_t sem2 = dispatch_semaphore_create(12);
        for (Device *d in devs) {
            if (d.isMe) continue;
            dispatch_semaphore_wait(sem2, DISPATCH_TIME_FOREVER);
            dispatch_group_async(g2, q, ^{
                NSString *h = ReverseDNS(d.ip);
                if (!h.length) h = MDNSName(d.ip);
                if (!h.length) h = NBNSName(d.ip);
                if (h.length) d.host = h;
                { double best = -1; for (int k = 0; k < 2; k++) { double p = PingOnce(d.ip, 600, (uint16_t)(d.ip + k)); if (p >= 0 && (best < 0 || p < best)) best = p; } d.pingMs = best; }
                dispatch_semaphore_signal(sem2);
            });
        }
        dispatch_group_wait(g2, dispatch_time(DISPATCH_TIME_NOW, 14 * NSEC_PER_SEC));
        NSArray *sorted = [devs sortedArrayUsingComparator:^NSComparisonResult(Device *a, Device *b) { return a.ip < b.ip ? NSOrderedAscending : NSOrderedDescending; }];
        dispatch_async(dispatch_get_main_queue(), ^{ progress(1); done(sorted); });
    });
}
@end

#pragma mark - Devices screen

@interface DeviceCell : UITableViewCell
@property(nonatomic, strong) GlassView *card;
@property(nonatomic, strong) UIImageView *icon;
@property(nonatomic, strong) UILabel *title, *sub, *ms, *badge;
- (void)configure:(Device *)d;
@end
@implementation DeviceCell
- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    if ((self = [super initWithStyle:s reuseIdentifier:r])) {
        self.backgroundColor = UIColor.clearColor; self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.card = [GlassView new]; self.card.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.card];
        UIView *c = self.card.content;
        self.icon = [UIImageView new]; self.icon.translatesAutoresizingMaskIntoConstraints = NO; self.icon.contentMode = UIViewContentModeScaleAspectFit;
        self.title = Label(@"", 17, UIFontWeightSemibold, nil);
        self.sub = Label(@"", 13, UIFontWeightRegular, UIColor.secondaryLabelColor);
        self.ms = Label(@"", 13, UIFontWeightMedium, UIColor.secondaryLabelColor);
        self.badge = Label(@"", 10, UIFontWeightBold, UIColor.whiteColor);
        self.badge.textAlignment = NSTextAlignmentCenter; self.badge.layer.cornerRadius = 8; self.badge.clipsToBounds = YES;
        for (UIView *v in @[ self.icon, self.title, self.sub, self.ms, self.badge ]) [c addSubview:v];
        [NSLayoutConstraint activateConstraints:@[
            [self.card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [self.card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [self.card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
            [self.card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
            [self.icon.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:16], [self.icon.centerYAnchor constraintEqualToAnchor:c.centerYAnchor],
            [self.icon.widthAnchor constraintEqualToConstant:34], [self.icon.heightAnchor constraintEqualToConstant:34],
            [self.title.leadingAnchor constraintEqualToAnchor:self.icon.trailingAnchor constant:14], [self.title.topAnchor constraintEqualToAnchor:c.topAnchor constant:14],
            [self.title.trailingAnchor constraintLessThanOrEqualToAnchor:self.ms.leadingAnchor constant:-8],
            [self.sub.leadingAnchor constraintEqualToAnchor:self.title.leadingAnchor], [self.sub.topAnchor constraintEqualToAnchor:self.title.bottomAnchor constant:3],
            [self.sub.trailingAnchor constraintLessThanOrEqualToAnchor:c.trailingAnchor constant:-12],
            [self.ms.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-16], [self.ms.topAnchor constraintEqualToAnchor:c.topAnchor constant:16],
            [self.badge.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-16], [self.badge.bottomAnchor constraintEqualToAnchor:c.bottomAnchor constant:-12],
            [self.badge.heightAnchor constraintEqualToConstant:16], [self.badge.widthAnchor constraintGreaterThanOrEqualToConstant:44],
            [c.bottomAnchor constraintGreaterThanOrEqualToAnchor:self.sub.bottomAnchor constant:14] ]];
    }
    return self;
}
- (void)configure:(Device *)d {
    self.icon.image = [UIImage systemImageNamed:[d icon]] ?: [UIImage systemImageNamed:@"network"];
    self.icon.tintColor = Theme.accent;
    self.title.text = [d title];
    NSMutableString *s = [NSMutableString stringWithFormat:@"%@  ·  %@", d.ipString, [d kind]];
    self.sub.text = s;
    self.ms.text = d.pingMs >= 0 ? [NSString stringWithFormat:@"%.0f ms", d.pingMs] : @"";
    NSString *b = nil; UIColor *bc = Theme.accent;
    if (d.isMe) { b = @"  YOU  "; }
    else if ([[d kind] isEqualToString:@"Router"]) { b = @"  ROUTER  "; bc = UIColor.systemOrangeColor; }
    else if (d.isNew) { b = @"  NEW  "; bc = UIColor.systemGreenColor; }
    self.badge.text = b; self.badge.hidden = b == nil; self.badge.backgroundColor = bc;
}
@end

@interface DeviceDetailVC : BaseVC
- (instancetype)initWithDevice:(Device *)d;
@end

@interface DevicesVC : BaseVC <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, strong) UITableView *table;
@property(nonatomic, strong) NSMutableArray<Device *> *devices;
@property(nonatomic, strong) UIProgressView *progress;
@property(nonatomic, strong) UILabel *netLabel, *countLabel;
@property(nonatomic, strong) UIButton *scanBtn;
@property(nonatomic, strong) UISegmentedControl *filter;
@property(nonatomic) BOOL scanning, didAuto;
@property(nonatomic, strong) Bonjour *bonjour;
@property(nonatomic, strong) NSMutableDictionary *bjNames, *bjTypes;
@end
@implementation DevicesVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Devices";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareList)];
    self.devices = [NSMutableArray array];
    GlassView *head = [GlassView new]; head.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:head];
    self.netLabel = Label(@"Wi-Fi network", 15, UIFontWeightMedium, nil);
    self.netLabel.numberOfLines = 2;
    self.countLabel = Label(@"0", 44, UIFontWeightBold, Theme.accent);
    UILabel *cl = Label(@"devices online", 13, UIFontWeightRegular, UIColor.secondaryLabelColor);
    self.scanBtn = GlassButton(@"Scan network", self, @selector(scan));
    self.progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.progress.translatesAutoresizingMaskIntoConstraints = NO; self.progress.progressTintColor = Theme.accent; self.progress.alpha = 0;
    for (UIView *v in @[ self.netLabel, self.countLabel, cl, self.scanBtn, self.progress ]) [head.content addSubview:v];
    self.filter = [[UISegmentedControl alloc] initWithItems:@[ T(@"All"), T(@"New"), T(@"Slow") ]];
    self.filter.translatesAutoresizingMaskIntoConstraints = NO; self.filter.selectedSegmentIndex = 0;
    [self.filter addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.filter];
    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    self.table.backgroundColor = UIColor.clearColor; self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.dataSource = self; self.table.delegate = self; self.table.rowHeight = 82;
    self.table.contentInset = UIEdgeInsetsMake(0, 0, 12, 0);
    [self.table registerClass:DeviceCell.class forCellReuseIdentifier:@"c"];
    UIRefreshControl *rc = [UIRefreshControl new]; [rc addTarget:self action:@selector(scan) forControlEvents:UIControlEventValueChanged];
    self.table.refreshControl = rc;
    [self.view addSubview:self.table];
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [head.topAnchor constraintEqualToAnchor:g.topAnchor constant:8], [head.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [head.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.countLabel.leadingAnchor constraintEqualToAnchor:head.content.leadingAnchor constant:18], [self.countLabel.topAnchor constraintEqualToAnchor:head.content.topAnchor constant:12],
        [cl.leadingAnchor constraintEqualToAnchor:self.countLabel.trailingAnchor constant:8], [cl.lastBaselineAnchor constraintEqualToAnchor:self.countLabel.lastBaselineAnchor],
        [self.netLabel.leadingAnchor constraintEqualToAnchor:head.content.leadingAnchor constant:18], [self.netLabel.trailingAnchor constraintEqualToAnchor:head.content.trailingAnchor constant:-18],
        [self.netLabel.topAnchor constraintEqualToAnchor:self.countLabel.bottomAnchor constant:2],
        [self.scanBtn.leadingAnchor constraintEqualToAnchor:head.content.leadingAnchor constant:16], [self.scanBtn.trailingAnchor constraintEqualToAnchor:head.content.trailingAnchor constant:-16],
        [self.scanBtn.topAnchor constraintEqualToAnchor:self.netLabel.bottomAnchor constant:12],
        [self.progress.leadingAnchor constraintEqualToAnchor:head.content.leadingAnchor constant:16], [self.progress.trailingAnchor constraintEqualToAnchor:head.content.trailingAnchor constant:-16],
        [self.progress.topAnchor constraintEqualToAnchor:self.scanBtn.bottomAnchor constant:8],
        [head.content.bottomAnchor constraintEqualToAnchor:self.progress.bottomAnchor constant:14],
        [self.filter.topAnchor constraintEqualToAnchor:head.bottomAnchor constant:12], [self.filter.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.filter.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.table.topAnchor constraintEqualToAnchor:self.filter.bottomAnchor constant:6], [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor], [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor] ]];
    [self updateNet];
}
- (void)themeChanged { [super themeChanged]; self.scanBtn.backgroundColor = Theme.accent; self.countLabel.textColor = Theme.accent; self.progress.progressTintColor = Theme.accent; [self.table reloadData]; }
- (void)viewDidAppear:(BOOL)a { [super viewDidAppear:a]; if (!self.didAuto) { self.didAuto = YES; [self scan]; } }
- (void)updateNet {
    LocalNet ln;
    if (GetLocalNet(&ln)) self.netLabel.text = [NSString stringWithFormat:@"Wi-Fi  ·  my IP %@  ·  subnet %@", IPString(ln.ip), IPString(ln.mask)];
    else self.netLabel.text = @"Not connected to Wi-Fi";
}
- (NSArray<Device *> *)visible {
    NSMutableArray *r = [NSMutableArray array];
    for (Device *d in self.devices) {
        if (self.filter.selectedSegmentIndex == 1 && !d.isNew) continue;
        if (self.filter.selectedSegmentIndex == 2 && !(d.pingMs > 100)) continue;
        [r addObject:d];
    }
    return r;
}
- (void)reload { [self.table reloadData]; }
- (void)scan {
    if (self.scanning) { [self.table.refreshControl endRefreshing]; return; }
    [self updateNet];
    self.scanning = YES; self.devices = [NSMutableArray array]; [self.table reloadData];
    self.countLabel.text = @"0"; self.progress.progress = 0; self.progress.alpha = 1;
    [self.scanBtn setTitle:@"Scanning…" forState:UIControlStateNormal]; self.scanBtn.alpha = 0.6;
    self.bjNames = [NSMutableDictionary dictionary]; self.bjTypes = [NSMutableDictionary dictionary];
    self.bonjour = [Bonjour new];
    __weak DevicesVC *ws = self;
    self.bonjour.found = ^(uint32_t ip, NSString *name, NSString *type) {
        DevicesVC *s = ws; if (!s) return;
        s.bjNames[@(ip)] = name ?: @"";
        NSMutableSet *set = s.bjTypes[@(ip)] ?: [NSMutableSet set]; if (type) [set addObject:type]; s.bjTypes[@(ip)] = set;
        for (Device *d in s.devices) if (d.ip == ip) [s apply:d];
        [s.table reloadData];
    };
    [self.bonjour start];
    NSSet *known = [NSSet setWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"knownIPs"] ?: @[]];
    [Scanner scanWithProgress:^(float p) { ws.progress.progress = p; }
        device:^(Device *d) {
            DevicesVC *s = ws; if (!s) return;
            d.isNew = known.count > 0 && ![known containsObject:d.ipString] && !d.isMe;
            [s apply:d]; [s.devices addObject:d];
            [s.devices sortUsingComparator:^NSComparisonResult(Device *a, Device *b) { return a.ip < b.ip ? NSOrderedAscending : NSOrderedDescending; }];
            s.countLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)s.devices.count];
            [s.table reloadData];
        }
        done:^(NSArray<Device *> *all) {
            DevicesVC *s = ws; if (!s) return;
            // merge scanner results (hostnames / ports filled in place) into UI list
            NSMutableDictionary *byIP = [NSMutableDictionary dictionary];
            for (Device *d in s.devices) byIP[@(d.ip)] = d;
            for (Device *d in all) { Device *u = byIP[@(d.ip)]; if (u && u != d) { u.host = d.host; u.ports = d.ports; if (d.pingMs >= 0) u.pingMs = d.pingMs; } }
            [s.devices removeAllObjects]; [s.devices addObjectsFromArray:all];
            for (Device *d in s.devices) { Device *old = byIP[@(d.ip)]; if (old) d.isNew = old.isNew; [s apply:d]; }
            NSMutableArray *ips = [NSMutableArray array]; for (Device *d in s.devices) [ips addObject:d.ipString];
            [[NSUserDefaults standardUserDefaults] setObject:ips forKey:@"knownIPs"];
            s.countLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)s.devices.count];
            [s.bonjour stop]; s.scanning = NO;
            [s.scanBtn setTitle:@"Scan again" forState:UIControlStateNormal]; s.scanBtn.alpha = 1;
            [UIView animateWithDuration:0.4 animations:^{ s.progress.alpha = 0; }];
            [s.table.refreshControl endRefreshing]; [s.table reloadData];
            [[UINotificationFeedbackGenerator new] notificationOccurred:UINotificationFeedbackTypeSuccess];
        }];
    // let Bonjour keep listening a bit after sweep; stopped in done
}
- (void)shareList {
    NSMutableString *t = [NSMutableString stringWithFormat:@"NetScope scan: %lu devices\n\n", (unsigned long)self.devices.count];
    for (Device *d in self.devices) [t appendFormat:@"%@  |  %@  |  %@%@\n", d.ipString, [d title], [d kind], d.pingMs >= 0 ? [NSString stringWithFormat:@"  |  %.0f ms", d.pingMs] : @""];
    UIActivityViewController *a = [[UIActivityViewController alloc] initWithActivityItems:@[ t ] applicationActivities:nil];
    a.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:a animated:YES completion:nil];
}
- (void)apply:(Device *)d {
    NSString *n = self.bjNames[@(d.ip)]; if (n.length) d.bonjourName = n;
    NSSet *t = self.bjTypes[@(d.ip)]; if (t) [d.services unionSet:t];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return [self visible].count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    DeviceCell *c = [t dequeueReusableCellWithIdentifier:@"c" forIndexPath:ip];
    [c configure:[self visible][ip.row]]; return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    DeviceDetailVC *vc = [[DeviceDetailVC alloc] initWithDevice:[self visible][ip.row]];
    [self.navigationController pushViewController:vc animated:YES];
}
@end

#pragma mark - Device detail

@interface DeviceDetailVC () <UITextViewDelegate>
@property(nonatomic, strong) Device *dev;
@property(nonatomic, strong) UITextView *out;
@end
@implementation DeviceDetailVC
- (instancetype)initWithDevice:(Device *)d { if ((self = [super init])) { _dev = d; } return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [self.dev title];
    GlassView *info = [GlassView new]; info.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:info];
    UIImageView *ic = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:[self.dev icon]]];
    ic.translatesAutoresizingMaskIntoConstraints = NO; ic.tintColor = Theme.accent; ic.contentMode = UIViewContentModeScaleAspectFit;
    UILabel *k = Label([self.dev kind], 20, UIFontWeightBold, nil);
    UILabel *ip = Label(self.dev.ipString, 15, UIFontWeightMedium, UIColor.secondaryLabelColor);
    NSMutableArray *pn = [NSMutableArray array];
    for (NSNumber *p in self.dev.ports) [pn addObject:[NSString stringWithFormat:@"%@ (%@)", p, PortNames()[p] ?: @"?"]];
    UILabel *pl = Label(pn.count ? [@"Open ports: " stringByAppendingString:[pn componentsJoinedByString:@", "]] : @"No open ports found in quick scan", 13, UIFontWeightRegular, UIColor.secondaryLabelColor);
    pl.numberOfLines = 0;
    UILabel *sv = Label(self.dev.services.count ? [@"Bonjour: " stringByAppendingString:[[[self.dev.services allObjects] componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"." withString:@""]] : @"", 12, UIFontWeightRegular, UIColor.tertiaryLabelColor);
    sv.numberOfLines = 0;
    for (UIView *v in @[ ic, k, ip, pl, sv ]) [info.content addSubview:v];
    UIButton *b1 = GlassButton(@"Ping", self, @selector(ping));
    UIButton *b2 = GlassButton(@"Port scan", self, @selector(portScan));
    UIButton *b3 = GlassButton(@"Rename", self, @selector(rename));
    UIButton *b4 = GlassButton(@"Copy IP", self, @selector(copyIP));
    UIStackView *r1 = [[UIStackView alloc] initWithArrangedSubviews:@[ b1, b2 ]]; r1.spacing = 10; r1.distribution = UIStackViewDistributionFillEqually;
    UIStackView *r2 = [[UIStackView alloc] initWithArrangedSubviews:@[ b3, b4 ]]; r2.spacing = 10; r2.distribution = UIStackViewDistributionFillEqually;
    UIStackView *st = [[UIStackView alloc] initWithArrangedSubviews:@[ r1, r2 ]]; st.axis = UILayoutConstraintAxisVertical; st.spacing = 10; st.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:st];
    GlassView *oc = [GlassView new]; oc.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:oc];
    self.out = [UITextView new]; self.out.translatesAutoresizingMaskIntoConstraints = NO; self.out.backgroundColor = UIColor.clearColor; self.out.editable = NO; self.out.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight; self.out.textAlignment = NSTextAlignmentLeft;
    self.out.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular]; self.out.textColor = UIColor.labelColor;
    self.out.text = @"Tap Ping or Port scan.";
    [oc.content addSubview:self.out];
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [info.topAnchor constraintEqualToAnchor:g.topAnchor constant:10], [info.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16], [info.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [ic.leadingAnchor constraintEqualToAnchor:info.content.leadingAnchor constant:18], [ic.topAnchor constraintEqualToAnchor:info.content.topAnchor constant:18],
        [ic.widthAnchor constraintEqualToConstant:48], [ic.heightAnchor constraintEqualToConstant:48],
        [k.leadingAnchor constraintEqualToAnchor:ic.trailingAnchor constant:14], [k.topAnchor constraintEqualToAnchor:ic.topAnchor constant:-1],
        [ip.leadingAnchor constraintEqualToAnchor:k.leadingAnchor], [ip.topAnchor constraintEqualToAnchor:k.bottomAnchor constant:2],
        [pl.leadingAnchor constraintEqualToAnchor:info.content.leadingAnchor constant:18], [pl.trailingAnchor constraintEqualToAnchor:info.content.trailingAnchor constant:-18],
        [pl.topAnchor constraintEqualToAnchor:ic.bottomAnchor constant:14],
        [sv.leadingAnchor constraintEqualToAnchor:pl.leadingAnchor], [sv.trailingAnchor constraintEqualToAnchor:pl.trailingAnchor], [sv.topAnchor constraintEqualToAnchor:pl.bottomAnchor constant:6],
        [info.content.bottomAnchor constraintEqualToAnchor:sv.bottomAnchor constant:16],
        [st.topAnchor constraintEqualToAnchor:info.bottomAnchor constant:12], [st.leadingAnchor constraintEqualToAnchor:info.leadingAnchor], [st.trailingAnchor constraintEqualToAnchor:info.trailingAnchor],
        [oc.topAnchor constraintEqualToAnchor:st.bottomAnchor constant:12], [oc.leadingAnchor constraintEqualToAnchor:info.leadingAnchor], [oc.trailingAnchor constraintEqualToAnchor:info.trailingAnchor],
        [oc.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-10],
        [self.out.leadingAnchor constraintEqualToAnchor:oc.content.leadingAnchor constant:8], [self.out.trailingAnchor constraintEqualToAnchor:oc.content.trailingAnchor constant:-8],
        [self.out.topAnchor constraintEqualToAnchor:oc.content.topAnchor constant:8], [self.out.bottomAnchor constraintEqualToAnchor:oc.content.bottomAnchor constant:-8] ]];
}
- (void)log:(NSString *)s { self.out.text = [self.out.text stringByAppendingFormat:@"%@\n", s]; [self.out scrollRangeToVisible:NSMakeRange(self.out.text.length, 0)]; }
- (void)ping {
    self.out.text = [NSString stringWithFormat:@"PING %@\n", self.dev.ipString];
    uint32_t ip = self.dev.ip;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int ok = 0; double sum = 0, mn = 1e9, mx = 0;
        for (int i = 1; i <= 8; i++) {
            double ms = PingOnce(ip, 1000, i);
            dispatch_async(dispatch_get_main_queue(), ^{ [self log:ms >= 0 ? [NSString stringWithFormat:@"reply seq=%d  time=%.1f ms", i, ms] : [NSString stringWithFormat:@"request timeout seq=%d", i]]; });
            if (ms >= 0) { ok++; sum += ms; mn = MIN(mn, ms); mx = MAX(mx, ms); }
            usleep(250000);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self log:[NSString stringWithFormat:@"\n8 sent, %d received, %d%% loss", ok, (8 - ok) * 100 / 8]];
            if (ok) [self log:[NSString stringWithFormat:@"min/avg/max = %.1f / %.1f / %.1f ms", mn, sum / ok, mx]];
        });
    });
}
- (void)portScan {
    self.out.text = @"Scanning common ports…\n";
    uint32_t ip = self.dev.ip;
    NSArray *ports = PortNames().allKeys;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *open = [TCPProbe(ip, ports, 2000, NULL) sortedArrayUsingSelector:@selector(compare:)];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!open.count) [self log:@"No open ports found."];
            for (NSNumber *p in open) [self log:[NSString stringWithFormat:@"%-6@ open   %@", p, PortNames()[p]]];
            self.dev.ports = open;
        });
    });
}
- (void)rename {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:T(@"Rename device") message:self.dev.ipString preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.text = [self.dev nick]; tf.placeholder = [self.dev title]; }];
    [a addAction:[UIAlertAction actionWithTitle:T(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:T(@"Save") style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        NSMutableDictionary *d = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"nicks"] mutableCopy] ?: [NSMutableDictionary dictionary];
        NSString *t = a.textFields.firstObject.text;
        if (t.length) d[self.dev.ipString] = t; else [d removeObjectForKey:self.dev.ipString];
        [[NSUserDefaults standardUserDefaults] setObject:d forKey:@"nicks"];
        self.title = [self.dev title];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)copyIP { UIPasteboard.generalPasteboard.string = self.dev.ipString; [self log:@"IP copied."]; }
@end

#pragma mark - Speed test

@interface Gauge : UIView
@property(nonatomic) double value; // Mbps
@property(nonatomic, strong) UILabel *num, *unit;
@end
@implementation Gauge
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = UIColor.clearColor;
        self.num = Label(@"0", 54, UIFontWeightBold, nil); self.num.textAlignment = NSTextAlignmentCenter;
        self.unit = Label(@"Ready", 15, UIFontWeightMedium, UIColor.secondaryLabelColor); self.unit.textAlignment = NSTextAlignmentCenter;
        [self addSubview:self.num]; [self addSubview:self.unit];
        [NSLayoutConstraint activateConstraints:@[
            [self.num.centerXAnchor constraintEqualToAnchor:self.centerXAnchor], [self.num.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-8],
            [self.unit.centerXAnchor constraintEqualToAnchor:self.centerXAnchor], [self.unit.topAnchor constraintEqualToAnchor:self.num.bottomAnchor constant:0] ]];
    }
    return self;
}
- (void)setValue:(double)v { _value = v; self.num.text = v < 10 ? [NSString stringWithFormat:@"%.2f", v] : (v < 100 ? [NSString stringWithFormat:@"%.1f", v] : [NSString stringWithFormat:@"%.0f", v]); [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)r {
    CGPoint c = CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r));
    CGFloat rad = MIN(r.size.width, r.size.height) / 2 - 14;
    CGFloat s = M_PI * 0.75, e = M_PI * 2.25;
    UIBezierPath *bg = [UIBezierPath bezierPathWithArcCenter:c radius:rad startAngle:s endAngle:e clockwise:YES];
    bg.lineWidth = 16; bg.lineCapStyle = kCGLineCapRound;
    [[UIColor.labelColor colorWithAlphaComponent:0.12] setStroke]; [bg stroke];
    double frac = MIN(1, log10(1 + self.value) / log10(1001));
    if (frac > 0.003) {
        UIBezierPath *p = [UIBezierPath bezierPathWithArcCenter:c radius:rad startAngle:s endAngle:s + (e - s) * frac clockwise:YES];
        p.lineWidth = 16; p.lineCapStyle = kCGLineCapRound;
        [Theme.accent setStroke]; [p stroke];
    }
}
@end

@interface SpeedTester : NSObject <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>
@property(nonatomic, copy) void (^onPhase)(NSString *phase);
@property(nonatomic, copy) void (^onLive)(double mbps);
@property(nonatomic, copy) void (^onDone)(NSDictionary *res);
@property(nonatomic) int64_t bytes;
@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic) BOOL running, uploading;
@property(nonatomic, strong) NSMutableData *upData;
@property(nonatomic, strong) NSDictionary *pingRes;
@property(nonatomic) double dlRes;
@property(nonatomic, copy) NSString *errText;
@property(nonatomic, copy) NSString *dlErr, *ulErr, *serverName, *curURL, *lastDlErr;
@property(nonatomic) BOOL pingFinished;
@property(nonatomic) int gen;
@end
@implementation SpeedTester
- (NSArray *)pingURLs { return @[ @"https://www.gstatic.com/generate_204", @"https://speed.cloudflare.com/__down?bytes=0", @"https://cachefly.cachefly.net/10mb.test" ]; }
// download servers: url, host label. Chunked URLs restart when a transfer finishes.
- (NSArray *)dlServers {
    return @[ @[ @"https://speed.cloudflare.com/__down?bytes=25000000", @"Cloudflare" ],
              @[ @"https://cachefly.cachefly.net/10mb.test", @"CacheFly" ],
              @[ @"https://ash-speed.hetzner.com/100MB.bin", @"Hetzner" ],
              @[ @"https://download.thinkbroadband.com/10MB.zip", @"ThinkBroadband" ] ];
}
- (NSArray *)ulServers { return @[ @[ @"https://speed.cloudflare.com/__up", @"Cloudflare" ], @[ @"https://httpbin.org/post", @"httpbin" ] ]; }

- (void)start {
    if (self.running) return;
    self.running = YES; self.errText = nil; self.dlErr = nil; self.dlRes = 0; self.ulErr = nil; self.serverName = nil;
    self.pingRes = @{ @"ping": @(-1), @"jitter": @(0), @"avg": @(-1) };
    self.lastDlErr = nil; self.pingFinished = NO; int g = ++self.gen;
    self.onPhase(@"Ping");
    // 1) ICMP ping (works for a normal app on iOS, the device scan uses it too)
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *targets = @[ @"1.1.1.1", @"8.8.8.8" ];
        NSMutableArray *times = [NSMutableArray array];
        for (NSString *t in targets) {
            int fails = 0;
            for (int i = 0; i < 6 && fails < 2; i++) {
                double ms = PingOnce(IPFromString(t), 900, (uint16_t)(i + 1));
                if (ms >= 0) [times addObject:@(ms)]; else fails++;
                if (g != self.gen || self.pingFinished) return;
                usleep(120000);
            }
            if (times.count >= 3) break;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (g != self.gen || self.pingFinished) return;
            if (times.count) { [self finishPing:times]; } else { [self pingFrom:0]; }
        });
    });
    // hard watchdog: never wait more than 10 s for latency
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (g != self.gen || self.pingFinished) return;
        [self finishPing:@[]];
    });
}
- (void)finishPing:(NSArray *)times {
    if (self.pingFinished) return;
    self.pingFinished = YES;
    if (times.count) {
        double mn = 1e9, sum = 0, jit = 0;
        for (NSNumber *t in times) { mn = MIN(mn, t.doubleValue); sum += t.doubleValue; }
        for (NSUInteger i = 1; i < times.count; i++) jit += fabs([times[i] doubleValue] - [times[i - 1] doubleValue]);
        self.pingRes = @{ @"ping": @(mn), @"jitter": @(times.count > 1 ? jit / (times.count - 1) : 0), @"avg": @(sum / times.count) };
    }
    [self download:0];
}
- (void)pingFrom:(NSInteger)idx {
    if (self.pingFinished) return;
    NSArray *urls = [self pingURLs];
    if (idx >= (NSInteger)urls.count) { [self finishPing:@[]]; return; }
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData; cfg.timeoutIntervalForRequest = 2.5; cfg.timeoutIntervalForResource = 4;
    cfg.waitsForConnectivity = NO;
    NSURLSession *s = [NSURLSession sessionWithConfiguration:cfg];
    NSMutableArray *times = [NSMutableArray array];
    __block int n = 0, fails = 0;
    __block void (^next)(void);
    __weak SpeedTester *ws = self;
    next = ^{
        SpeedTester *me = ws; if (!me) return;
        if (n >= 7 || fails >= 2) {
            [s invalidateAndCancel];
            next = nil;
            if (!times.count) { [me pingFrom:idx + 1]; return; }
            [me finishPing:times];
            return;
        }
        NSString *sep = [urls[idx] containsString:@"?"] ? @"&" : @"?";
        NSURL *u = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@r=%u", urls[idx], sep, arc4random()]];
        NSMutableURLRequest *rq = [NSMutableURLRequest requestWithURL:u]; rq.HTTPMethod = [urls[idx] containsString:@"cachefly"] ? @"HEAD" : @"GET";
        double t0 = NowMs();
        [[s dataTaskWithRequest:rq completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
            double ms = NowMs() - t0;
            int code = (int)[(NSHTTPURLResponse *)r statusCode];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!e && code >= 200 && code < 400) { if (n > 0) [times addObject:@(ms)]; } else fails++;
                n++;
                if (next) next();
            });
        }] resume];
    };
    next();
}
- (NSURLSession *)newSession {
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData; cfg.HTTPMaximumConnectionsPerHost = 8; cfg.timeoutIntervalForRequest = 8;
    return [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:nil];
}
- (void)startTask {
    NSString *base = self.curURL;
    NSString *sep = [base containsString:@"?"] ? @"&" : @"?";
    if (self.uploading) {
        NSMutableURLRequest *rq = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:base]];
        rq.HTTPMethod = @"POST"; [rq setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
        [[self.session uploadTaskWithRequest:rq fromData:self.upData] resume];
    } else {
        NSURL *u = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@r=%u", base, sep, arc4random()]];
        [[self.session dataTaskWithURL:u] resume];
    }
}
// Measure; if no bytes arrive in 4 s, call stall instead.
- (void)measureFor:(double)secs done:(void (^)(double))fin stall:(void (^)(void))stall {
    __atomic_store_n(&_bytes, 0, __ATOMIC_RELAXED);
    __block int64_t last = 0, atWarm = 0; __block double lastT = NowMs(); double t0 = lastT; __block BOOL warm = NO; __block double warmT = 0;
    [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:YES block:^(NSTimer *t) {
        double now = NowMs();
        int64_t b = __atomic_load_n(&self->_bytes, __ATOMIC_RELAXED);
        if (b == 0 && now - t0 > 4000) { [t invalidate]; stall(); return; }
        double inst = (b - last) * 8.0 / 1e6 / MAX(0.05, (now - lastT) / 1000.0);
        last = b; lastT = now;
        self.onLive(inst);
        if (!warm && now - t0 > 1500) { warm = YES; atWarm = b; warmT = now; }
        if (now - t0 >= secs * 1000) {
            [t invalidate];
            double mbps = warm && now - warmT > 500 ? (b - atWarm) * 8.0 / 1e6 / ((now - warmT) / 1000.0) : b * 8.0 / 1e6 / MAX(0.1, (now - t0) / 1000.0);
            fin(mbps);
        }
    }];
}
- (void)download:(NSInteger)idx {
    NSArray *servers = [self dlServers];
    if (idx >= (NSInteger)servers.count) { self.dlRes = 0; self.dlErr = [NSString stringWithFormat:@"Download failed: %@", self.lastDlErr ?: @"no server reachable"]; [self upload:0]; return; }
    self.onPhase(@"Download");
    self.errText = nil; self.uploading = NO; self.curURL = servers[idx][0]; self.serverName = servers[idx][1];
    self.session = [self newSession];
    for (int i = 0; i < 4; i++) [self startTask];
    NSURLSession *mine = self.session;
    [self measureFor:9 done:^(double mbps) {
        [mine invalidateAndCancel];
        self.dlRes = mbps;
        [self upload:0];
    } stall:^{
        [mine invalidateAndCancel];
        if (self.errText) self.lastDlErr = self.errText;
        [self download:idx + 1];
    }];
}
- (void)upload:(NSInteger)idx {
    NSArray *servers = [self ulServers];
    if (idx >= (NSInteger)servers.count) { self.ulErr = @"Upload failed: no server reachable"; [self finish:0]; return; }
    self.onPhase(@"Upload");
    self.errText = nil;
    if (!self.upData) self.upData = [NSMutableData dataWithLength:8 * 1024 * 1024];
    self.uploading = YES; self.curURL = servers[idx][0];
    self.session = [self newSession];
    for (int i = 0; i < 3; i++) [self startTask];
    NSURLSession *mine = self.session;
    [self measureFor:8 done:^(double mbps) {
        [mine invalidateAndCancel];
        [self finish:mbps];
    } stall:^{
        [mine invalidateAndCancel];
        [self upload:idx + 1];
    }];
}
- (void)finish:(double)up {
    self.uploading = NO; self.running = NO;
    NSMutableDictionary *r = [self.pingRes mutableCopy];
    r[@"down"] = @(self.dlRes); r[@"up"] = @(up); r[@"ts"] = @([NSDate date].timeIntervalSince1970);
    NSString *err = self.dlErr ?: self.ulErr;
    if (err) r[@"err"] = err;
    if (self.serverName) r[@"server"] = self.serverName;
    self.onDone(r);
}
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveResponse:(NSURLResponse *)r completionHandler:(void (^)(NSURLSessionResponseDisposition))h {
    NSInteger c = [(NSHTTPURLResponse *)r statusCode];
    if (c < 200 || c >= 300) { self.errText = [NSString stringWithFormat:@"Server error %ld", (long)c]; h(NSURLSessionResponseCancel); } else h(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveData:(NSData *)d { __atomic_fetch_add(&_bytes, (int64_t)d.length, __ATOMIC_RELAXED); }
- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t didSendBodyData:(int64_t)b totalBytesSent:(int64_t)tot totalBytesExpectedToSend:(int64_t)exp {
    __atomic_fetch_add(&_bytes, b, __ATOMIC_RELAXED);
}
- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t didCompleteWithError:(NSError *)e {
    if (!self.running || s != self.session) return;
    if (e && e.code == NSURLErrorCancelled) return;
    if (e) self.errText = e.localizedDescription;
    if (self.errText && __atomic_load_n(&_bytes, __ATOMIC_RELAXED) == 0) return; // stall timer moves to next server
    [self startTask];
}
@end

@interface SpeedVC : BaseVC
@property(nonatomic, strong) Gauge *gauge;
@property(nonatomic, strong) UIButton *btn;
@property(nonatomic, strong) UILabel *pingL, *jitL, *dlL, *ulL, *hist;
@property(nonatomic, strong) SpeedTester *tester;
@end
@implementation SpeedVC
- (UIView *)stat:(NSString *)name label:(UILabel * __strong *)lbl {
    GlassView *g = [GlassView new]; g.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *n = Label(name, 12, UIFontWeightMedium, UIColor.secondaryLabelColor);
    UILabel *v = Label(@"—", 22, UIFontWeightBold, nil);
    [g.content addSubview:n]; [g.content addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [n.leadingAnchor constraintEqualToAnchor:g.content.leadingAnchor constant:14], [n.topAnchor constraintEqualToAnchor:g.content.topAnchor constant:12],
        [v.leadingAnchor constraintEqualToAnchor:n.leadingAnchor], [v.topAnchor constraintEqualToAnchor:n.bottomAnchor constant:2],
        [g.content.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:12], [g.heightAnchor constraintGreaterThanOrEqualToConstant:70] ]];
    *lbl = v; return g;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Speed Test";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareResult)];
    UIScrollView *sv = [UIScrollView new]; sv.translatesAutoresizingMaskIntoConstraints = NO; sv.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever; sv.contentInset = UIEdgeInsetsMake(0, 0, 110, 0); sv.verticalScrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 60, 0); sv.alwaysBounceVertical = YES; [self.view addSubview:sv];
    UIView *cv = [UIView new]; cv.translatesAutoresizingMaskIntoConstraints = NO; [sv addSubview:cv];
    GlassView *gc = [GlassView new]; gc.translatesAutoresizingMaskIntoConstraints = NO;
    self.gauge = [[Gauge alloc] initWithFrame:CGRectZero]; self.gauge.translatesAutoresizingMaskIntoConstraints = NO;
    [gc.content addSubview:self.gauge];
    self.btn = GlassButton(@"Start test", self, @selector(go));
    UIView *a = [self stat:@"PING (ms)" label:&_pingL], *b = [self stat:@"JITTER (ms)" label:&_jitL];
    UIView *c = [self stat:@"DOWNLOAD (Mbps)" label:&_dlL], *d = [self stat:@"UPLOAD (Mbps)" label:&_ulL];
    UIStackView *r1 = [[UIStackView alloc] initWithArrangedSubviews:@[ a, b ]]; r1.spacing = 12; r1.distribution = UIStackViewDistributionFillEqually;
    UIStackView *r2 = [[UIStackView alloc] initWithArrangedSubviews:@[ c, d ]]; r2.spacing = 12; r2.distribution = UIStackViewDistributionFillEqually;
    GlassView *hc = [GlassView new]; hc.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *ht = Label(@"History", 16, UIFontWeightSemibold, nil);
    self.hist = Label(@"", 13, UIFontWeightRegular, UIColor.secondaryLabelColor); self.hist.numberOfLines = 0;
    [hc.content addSubview:ht]; [hc.content addSubview:self.hist];
    for (UIView *v in @[ gc, self.btn, r1, r2, hc ]) { v.translatesAutoresizingMaskIntoConstraints = NO; [cv addSubview:v]; }
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [sv.topAnchor constraintEqualToAnchor:g.topAnchor], [sv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [sv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [sv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [cv.topAnchor constraintEqualToAnchor:sv.contentLayoutGuide.topAnchor], [cv.bottomAnchor constraintEqualToAnchor:sv.contentLayoutGuide.bottomAnchor],
        [cv.leadingAnchor constraintEqualToAnchor:sv.contentLayoutGuide.leadingAnchor], [cv.trailingAnchor constraintEqualToAnchor:sv.contentLayoutGuide.trailingAnchor],
        [cv.widthAnchor constraintEqualToAnchor:sv.frameLayoutGuide.widthAnchor],
        [gc.topAnchor constraintEqualToAnchor:cv.topAnchor constant:10], [gc.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:16], [gc.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-16],
        [gc.heightAnchor constraintEqualToConstant:270],
        [self.gauge.centerXAnchor constraintEqualToAnchor:gc.content.centerXAnchor], [self.gauge.centerYAnchor constraintEqualToAnchor:gc.content.centerYAnchor],
        [self.gauge.widthAnchor constraintEqualToConstant:250], [self.gauge.heightAnchor constraintEqualToConstant:250],
        [self.btn.topAnchor constraintEqualToAnchor:gc.bottomAnchor constant:14], [self.btn.leadingAnchor constraintEqualToAnchor:gc.leadingAnchor], [self.btn.trailingAnchor constraintEqualToAnchor:gc.trailingAnchor],
        [r1.topAnchor constraintEqualToAnchor:self.btn.bottomAnchor constant:14], [r1.leadingAnchor constraintEqualToAnchor:gc.leadingAnchor], [r1.trailingAnchor constraintEqualToAnchor:gc.trailingAnchor],
        [r2.topAnchor constraintEqualToAnchor:r1.bottomAnchor constant:12], [r2.leadingAnchor constraintEqualToAnchor:gc.leadingAnchor], [r2.trailingAnchor constraintEqualToAnchor:gc.trailingAnchor],
        [hc.topAnchor constraintEqualToAnchor:r2.bottomAnchor constant:12], [hc.leadingAnchor constraintEqualToAnchor:gc.leadingAnchor], [hc.trailingAnchor constraintEqualToAnchor:gc.trailingAnchor],
        [ht.leadingAnchor constraintEqualToAnchor:hc.content.leadingAnchor constant:16], [ht.topAnchor constraintEqualToAnchor:hc.content.topAnchor constant:14],
        [self.hist.leadingAnchor constraintEqualToAnchor:ht.leadingAnchor], [self.hist.trailingAnchor constraintEqualToAnchor:hc.content.trailingAnchor constant:-16],
        [self.hist.topAnchor constraintEqualToAnchor:ht.bottomAnchor constant:8], [hc.content.bottomAnchor constraintEqualToAnchor:self.hist.bottomAnchor constant:16],
        [cv.bottomAnchor constraintEqualToAnchor:hc.bottomAnchor constant:24] ]];
    [self showHistory];
}
- (void)themeChanged { [super themeChanged]; self.btn.backgroundColor = Theme.accent; [self.gauge setNeedsDisplay]; }
- (void)shareResult {
    NSDictionary *r = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"speedHistory"] firstObject];
    if (!r) return;
    NSString *t = [NSString stringWithFormat:@"NetScope speed test\nDownload: %.1f Mbps\nUpload: %.1f Mbps\nPing: %.0f ms  Jitter: %.1f ms", [r[@"down"] doubleValue], [r[@"up"] doubleValue], [r[@"ping"] doubleValue], [r[@"jitter"] doubleValue]];
    UIActivityViewController *a = [[UIActivityViewController alloc] initWithActivityItems:@[ t ] applicationActivities:nil];
    a.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:a animated:YES completion:nil];
}
- (void)showHistory {
    NSArray *h = [[NSUserDefaults standardUserDefaults] arrayForKey:@"speedHistory"];
    if (!h.count) { self.hist.text = @"No tests yet."; return; }
    NSDateFormatter *f = [NSDateFormatter new]; f.dateFormat = @"d MMM HH:mm";
    NSMutableArray *lines = [NSMutableArray array];
    for (NSDictionary *r in h) {
        [lines addObject:[NSString stringWithFormat:@"%@   ↓ %.1f   ↑ %.1f   %.0f ms", [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:[r[@"ts"] doubleValue]]], [r[@"down"] doubleValue], [r[@"up"] doubleValue], [r[@"ping"] doubleValue]]];
    }
    self.hist.text = [lines componentsJoinedByString:@"\n"];
}
- (void)go {
    if (self.tester.running) return;
    self.pingL.text = self.jitL.text = self.dlL.text = self.ulL.text = @"—";
    self.gauge.value = 0;
    self.btn.alpha = 0.5; [self.btn setTitle:@"Testing…" forState:UIControlStateNormal];
    UIApplication.sharedApplication.idleTimerDisabled = YES;
    self.tester = [SpeedTester new];
    __weak SpeedVC *ws = self;
    __block NSString *phase = @"Ping";
    self.tester.onPhase = ^(NSString *p) {
        dispatch_async(dispatch_get_main_queue(), ^{
            phase = p; ws.gauge.unit.text = p == nil ? @"" : ([p isEqualToString:@"Ping"] ? @"Measuring latency…" : [p isEqualToString:@"Download"] ? @"Download  Mbps" : @"Upload  Mbps");
            if ([p isEqualToString:@"Download"]) { double pg = [ws.tester.pingRes[@"ping"] doubleValue]; ws.pingL.text = pg >= 0 ? [NSString stringWithFormat:@"%.0f", pg] : @"—"; ws.jitL.text = pg >= 0 ? [NSString stringWithFormat:@"%.1f", [ws.tester.pingRes[@"jitter"] doubleValue]] : @"—"; }
            if ([p isEqualToString:@"Upload"]) ws.dlL.text = ws.tester.dlRes > 0 ? [NSString stringWithFormat:@"%.1f", ws.tester.dlRes] : @"—";
            ws.gauge.value = 0;
        });
    };
    self.tester.onLive = ^(double m) {
        dispatch_async(dispatch_get_main_queue(), ^{ if (![phase isEqualToString:@"Ping"]) ws.gauge.value = m; });
    };
    self.tester.onDone = ^(NSDictionary *r) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIApplication.sharedApplication.idleTimerDisabled = NO;
            ws.ulL.text = [r[@"up"] doubleValue] > 0 ? [NSString stringWithFormat:@"%.1f", [r[@"up"] doubleValue]] : @"—";
            if (r[@"err"]) { ws.gauge.unit.text = r[@"err"]; }
            ws.gauge.value = [r[@"down"] doubleValue]; if (!r[@"err"]) ws.gauge.unit.text = r[@"server"] ? [NSString stringWithFormat:@"Done · %@", r[@"server"]] : @"Done";
            ws.btn.alpha = 1; [ws.btn setTitle:@"Test again" forState:UIControlStateNormal];
            NSMutableArray *h = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"speedHistory"] mutableCopy] ?: [NSMutableArray array];
            [h insertObject:r atIndex:0]; while (h.count > 8) [h removeLastObject];
            [[NSUserDefaults standardUserDefaults] setObject:h forKey:@"speedHistory"];
            [ws showHistory];
            [[UINotificationFeedbackGenerator new] notificationOccurred:UINotificationFeedbackTypeSuccess];
        });
    };
    [self.tester start];
}
@end

#pragma mark - Tools

@interface ToolsVC : BaseVC
@property(nonatomic, strong) UITextField *host;
@property(nonatomic, strong) UITextView *out;
@end
@implementation ToolsVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Tools";
    GlassView *f = [GlassView new]; f.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:f];
    self.host = [UITextField new]; self.host.translatesAutoresizingMaskIntoConstraints = NO;
    self.host.placeholder = T(@"Host or IP  (e.g. google.com)"); self.host.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.host.autocorrectionType = UITextAutocorrectionTypeNo; self.host.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.host.keyboardType = UIKeyboardTypeURL; self.host.returnKeyType = UIReturnKeyDone;
    [self.host addTarget:self.host action:@selector(resignFirstResponder) forControlEvents:UIControlEventEditingDidEndOnExit];
    [f.content addSubview:self.host];
    UIButton *b1 = GlassButton(@"Ping", self, @selector(ping)), *b2 = GlassButton(@"DNS", self, @selector(dns)), *b3 = GlassButton(@"Ports", self, @selector(ports)), *b5 = GlassButton(@"Trace", self, @selector(trace)), *b4 = GlassButton(@"My public IP", self, @selector(pubip));
    UIStackView *r = [[UIStackView alloc] initWithArrangedSubviews:@[ b1, b2, b3, b5 ]]; r.spacing = 10; r.distribution = UIStackViewDistributionFillEqually;
    UIStackView *st = [[UIStackView alloc] initWithArrangedSubviews:@[ r, b4 ]]; st.axis = UILayoutConstraintAxisVertical; st.spacing = 10; st.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:st];
    GlassView *oc = [GlassView new]; oc.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:oc];
    self.out = [UITextView new]; self.out.translatesAutoresizingMaskIntoConstraints = NO; self.out.backgroundColor = UIColor.clearColor; self.out.editable = NO;
    self.out.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight; self.out.textAlignment = NSTextAlignmentLeft; self.out.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular]; self.out.text = @"Network tools. Enter a host, then pick a tool.";
    [oc.content addSubview:self.out];
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [f.topAnchor constraintEqualToAnchor:g.topAnchor constant:10], [f.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16], [f.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [f.heightAnchor constraintEqualToConstant:54],
        [self.host.leadingAnchor constraintEqualToAnchor:f.content.leadingAnchor constant:16], [self.host.trailingAnchor constraintEqualToAnchor:f.content.trailingAnchor constant:-16],
        [self.host.centerYAnchor constraintEqualToAnchor:f.content.centerYAnchor],
        [st.topAnchor constraintEqualToAnchor:f.bottomAnchor constant:12], [st.leadingAnchor constraintEqualToAnchor:f.leadingAnchor], [st.trailingAnchor constraintEqualToAnchor:f.trailingAnchor],
        [oc.topAnchor constraintEqualToAnchor:st.bottomAnchor constant:12], [oc.leadingAnchor constraintEqualToAnchor:f.leadingAnchor], [oc.trailingAnchor constraintEqualToAnchor:f.trailingAnchor],
        [oc.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-10],
        [self.out.leadingAnchor constraintEqualToAnchor:oc.content.leadingAnchor constant:8], [self.out.trailingAnchor constraintEqualToAnchor:oc.content.trailingAnchor constant:-8],
        [self.out.topAnchor constraintEqualToAnchor:oc.content.topAnchor constant:8], [self.out.bottomAnchor constraintEqualToAnchor:oc.content.bottomAnchor constant:-8] ]];
}
- (void)log:(NSString *)s { dispatch_async(dispatch_get_main_queue(), ^{ self.out.text = [self.out.text stringByAppendingFormat:@"%@\n", s]; [self.out scrollRangeToVisible:NSMakeRange(self.out.text.length, 0)]; }); }
- (NSArray<NSString *> *)resolve:(NSString *)h {
    struct addrinfo hints; memset(&hints, 0, sizeof hints); hints.ai_family = AF_INET; hints.ai_socktype = SOCK_STREAM;
    struct addrinfo *res = NULL; NSMutableArray *ips = [NSMutableArray array];
    if (getaddrinfo(h.UTF8String, NULL, &hints, &res) == 0) {
        for (struct addrinfo *p = res; p; p = p->ai_next) { char b[64]; inet_ntop(AF_INET, &((struct sockaddr_in *)p->ai_addr)->sin_addr, b, sizeof b); [ips addObject:[NSString stringWithUTF8String:b]]; }
        freeaddrinfo(res);
    }
    return ips;
}
- (NSString *)target { [self.host resignFirstResponder]; return [self.host.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]; }
- (void)ping {
    NSString *h = [self target]; if (!h.length) { self.out.text = @"Enter a host first."; return; }
    self.out.text = @"";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *ips = [self resolve:h];
        if (!ips.count) { [self log:@"Could not resolve host."]; return; }
        uint32_t ip = IPFromString(ips[0]);
        [self log:[NSString stringWithFormat:@"PING %@ (%@)", h, ips[0]]];
        int ok = 0; double sum = 0;
        for (int i = 1; i <= 6; i++) {
            double ms = PingOnce(ip, 1500, i);
            [self log:ms >= 0 ? [NSString stringWithFormat:@"reply seq=%d  %.1f ms", i, ms] : [NSString stringWithFormat:@"timeout seq=%d", i]];
            if (ms >= 0) { ok++; sum += ms; }
            usleep(300000);
        }
        [self log:ok ? [NSString stringWithFormat:@"\n%d/6 received, avg %.1f ms", ok, sum / ok] : @"\nNo replies (host may block ping)."];
    });
}
- (void)trace {
    NSString *h = [self target]; if (!h.length) { self.out.text = @"Enter a host first."; return; }
    self.out.text = @"";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *ips = [self resolve:h];
        if (!ips.count) { [self log:@"Could not resolve host."]; return; }
        [self log:[NSString stringWithFormat:@"Traceroute to %@ (%@), max 20 hops", h, ips[0]]];
        Traceroute(IPFromString(ips[0]), ^(NSString *l) { [self log:l]; });
        [self log:@"\nDone. Some routers do not reply (shown as *)."];
    });
}
- (void)dns {
    NSString *h = [self target]; if (!h.length) { self.out.text = @"Enter a host first."; return; }
    self.out.text = @"";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        double t0 = NowMs(); NSArray *ips = [self resolve:h];
        [self log:[NSString stringWithFormat:@"DNS lookup %@  (%.0f ms)", h, NowMs() - t0]];
        for (NSString *i in ips) [self log:[NSString stringWithFormat:@"  A  %@", i]];
        if (!ips.count) [self log:@"  no result"];
    });
}
- (void)ports {
    NSString *h = [self target]; if (!h.length) { self.out.text = @"Enter a host first."; return; }
    self.out.text = @"Scanning common ports…\n";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *ips = [self resolve:h];
        if (!ips.count) { [self log:@"Could not resolve host."]; return; }
        NSArray *open = [TCPProbe(IPFromString(ips[0]), PortNames().allKeys, 2500, NULL) sortedArrayUsingSelector:@selector(compare:)];
        [self log:[NSString stringWithFormat:@"%@ (%@)", h, ips[0]]];
        for (NSNumber *p in open) [self log:[NSString stringWithFormat:@"%-6@ open   %@", p, PortNames()[p]]];
        if (!open.count) [self log:@"No open ports found."];
    });
}
- (void)pubip {
    self.out.text = @"Checking…\n";
    [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"https://www.cloudflare.com/cdn-cgi/trace"] completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (!d) { [self log:@"No internet connection."]; return; }
        NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        NSMutableString *o = [NSMutableString string];
        for (NSString *ln in [s componentsSeparatedByString:@"\n"]) {
            if ([ln hasPrefix:@"ip="]) [o appendFormat:@"Public IP : %@\n", [ln substringFromIndex:3]];
            if ([ln hasPrefix:@"loc="]) [o appendFormat:@"Country   : %@\n", [ln substringFromIndex:4]];
            if ([ln hasPrefix:@"colo="]) [o appendFormat:@"Edge      : %@\n", [ln substringFromIndex:5]];
            if ([ln hasPrefix:@"http="]) [o appendFormat:@"HTTP      : %@\n", [ln substringFromIndex:5]];
        }
        [self log:o];
    }] resume];
}
@end

#pragma mark - Settings

static NSArray<NSArray<NSString *> *> *DevLinks(void) {
    // title, url  (filled in when the developer sends his account links)
    return @[ @[ @"Facebook", @"https://www.facebook.com/share/1BSuPxYGiZ/" ],
              @[ @"Instagram", @"https://www.instagram.com/jo0seff" ],
              @[ @"WhatsApp", @"copy:jo0seff" ] ];
}

@interface SettingsVC : BaseVC
@property(nonatomic, strong) UISegmentedControl *appearance;
@property(nonatomic, strong) UIStackView *accent;
@end
@implementation SettingsVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
    UIScrollView *sv = [UIScrollView new]; sv.translatesAutoresizingMaskIntoConstraints = NO; sv.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever; sv.contentInset = UIEdgeInsetsMake(0, 0, 110, 0); sv.verticalScrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 60, 0); sv.alwaysBounceVertical = YES; [self.view addSubview:sv];
    UIView *cv = [UIView new]; cv.translatesAutoresizingMaskIntoConstraints = NO; [sv addSubview:cv];
    GlassView *g1 = [GlassView new]; g1.translatesAutoresizingMaskIntoConstraints = NO; [cv addSubview:g1];
    UILabel *t1 = Label(@"Appearance", 16, UIFontWeightSemibold, nil);
    self.appearance = [[UISegmentedControl alloc] initWithItems:@[ T(@"Automatic"), T(@"Light"), T(@"Black") ]];
    self.appearance.translatesAutoresizingMaskIntoConstraints = NO;
    self.appearance.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:PrefAppearance];
    [self.appearance addTarget:self action:@selector(appearanceChanged) forControlEvents:UIControlEventValueChanged];
    UILabel *t2 = Label(@"Color theme", 16, UIFontWeightSemibold, nil);
    self.accent = [UIStackView new];
    self.accent.translatesAutoresizingMaskIntoConstraints = NO; self.accent.distribution = UIStackViewDistributionEqualSpacing; self.accent.alignment = UIStackViewAlignmentCenter;
    for (NSInteger i = 0; i < (NSInteger)[Theme accentNames].count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.translatesAutoresizingMaskIntoConstraints = NO; b.tag = i;
        NSInteger old = [[NSUserDefaults standardUserDefaults] integerForKey:PrefAccent];
        [[NSUserDefaults standardUserDefaults] setInteger:i forKey:PrefAccent];
        b.backgroundColor = Theme.accent;
        [[NSUserDefaults standardUserDefaults] setInteger:old forKey:PrefAccent];
        b.layer.cornerRadius = 16; b.layer.borderColor = UIColor.whiteColor.CGColor;
        b.layer.borderWidth = (i == old) ? 3 : 0;
        [b.widthAnchor constraintEqualToConstant:32].active = YES; [b.heightAnchor constraintEqualToConstant:32].active = YES;
        [b addTarget:self action:@selector(accentTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.accent addArrangedSubview:b];
    }
    UILabel *t3 = Label(@"Language", 16, UIFontWeightSemibold, nil);
    UISegmentedControl *lang = [[UISegmentedControl alloc] initWithItems:@[ @"English", @"العربية" ]];
    lang.translatesAutoresizingMaskIntoConstraints = NO; lang.selectedSegmentIndex = IsAr() ? 1 : 0;
    [lang addTarget:self action:@selector(langChanged:) forControlEvents:UIControlEventValueChanged];
    for (UIView *v in @[ t1, self.appearance, t2, self.accent, t3, lang ]) [g1.content addSubview:v];
    GlassView *g2 = [GlassView new]; g2.translatesAutoresizingMaskIntoConstraints = NO; [cv addSubview:g2];
    UILabel *about = Label(@"NetScope 1.7\nFinds devices on your Wi-Fi using ping, TCP probes and Bonjour, and measures speed against Cloudflare. iOS does not let apps read MAC addresses, so device types are estimated from names and open ports. Everything runs on your phone, nothing is uploaded.", 13, UIFontWeightRegular, UIColor.secondaryLabelColor);
    about.numberOfLines = 0; [g2.content addSubview:about];
    GlassView *g3 = [GlassView new]; g3.translatesAutoresizingMaskIntoConstraints = NO; [cv addSubview:g3];
    UILabel *dv = Label(@"Developer", 12, UIFontWeightMedium, UIColor.secondaryLabelColor);
    UILabel *dn = Label(@"Youssef elbaheriy", 20, UIFontWeightBold, nil);
    [g3.content addSubview:dv]; [g3.content addSubview:dn];
    UIStackView *ls = [UIStackView new]; ls.axis = UILayoutConstraintAxisHorizontal; ls.spacing = 8; ls.distribution = UIStackViewDistributionFillEqually; ls.translatesAutoresizingMaskIntoConstraints = NO;
    [g3.content addSubview:ls];
    for (NSArray *l in DevLinks()) {
        UIButton *b = GlassButton(l[0], self, @selector(openLink:));
        b.accessibilityValue = l[1];
        [ls addArrangedSubview:b];
    }
    UIButton *clr = GlassButton(@"Clear history and names", self, @selector(clearAll));
    clr.backgroundColor = UIColor.systemRedColor; [cv addSubview:clr];
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [sv.topAnchor constraintEqualToAnchor:g.topAnchor], [sv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [sv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [sv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [cv.topAnchor constraintEqualToAnchor:sv.contentLayoutGuide.topAnchor], [cv.bottomAnchor constraintEqualToAnchor:sv.contentLayoutGuide.bottomAnchor],
        [cv.leadingAnchor constraintEqualToAnchor:sv.contentLayoutGuide.leadingAnchor], [cv.trailingAnchor constraintEqualToAnchor:sv.contentLayoutGuide.trailingAnchor],
        [cv.widthAnchor constraintEqualToAnchor:sv.frameLayoutGuide.widthAnchor], [cv.bottomAnchor constraintEqualToAnchor:clr.bottomAnchor constant:30],
        [g1.topAnchor constraintEqualToAnchor:cv.topAnchor constant:10], [g1.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:16], [g1.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-16],
        [t1.leadingAnchor constraintEqualToAnchor:g1.content.leadingAnchor constant:16], [t1.topAnchor constraintEqualToAnchor:g1.content.topAnchor constant:16],
        [self.appearance.leadingAnchor constraintEqualToAnchor:t1.leadingAnchor], [self.appearance.trailingAnchor constraintEqualToAnchor:g1.content.trailingAnchor constant:-16],
        [self.appearance.topAnchor constraintEqualToAnchor:t1.bottomAnchor constant:10],
        [t2.leadingAnchor constraintEqualToAnchor:t1.leadingAnchor], [t2.topAnchor constraintEqualToAnchor:self.appearance.bottomAnchor constant:20],
        [self.accent.leadingAnchor constraintEqualToAnchor:t1.leadingAnchor], [self.accent.trailingAnchor constraintEqualToAnchor:self.appearance.trailingAnchor],
        [self.accent.topAnchor constraintEqualToAnchor:t2.bottomAnchor constant:10], [t3.leadingAnchor constraintEqualToAnchor:t1.leadingAnchor], [t3.topAnchor constraintEqualToAnchor:self.accent.bottomAnchor constant:20],
        [lang.leadingAnchor constraintEqualToAnchor:t1.leadingAnchor], [lang.trailingAnchor constraintEqualToAnchor:self.appearance.trailingAnchor], [lang.topAnchor constraintEqualToAnchor:t3.bottomAnchor constant:10],
        [g1.content.bottomAnchor constraintEqualToAnchor:lang.bottomAnchor constant:18],
        [g2.topAnchor constraintEqualToAnchor:g1.bottomAnchor constant:12], [g2.leadingAnchor constraintEqualToAnchor:g1.leadingAnchor], [g2.trailingAnchor constraintEqualToAnchor:g1.trailingAnchor],
        [about.leadingAnchor constraintEqualToAnchor:g2.content.leadingAnchor constant:16], [about.trailingAnchor constraintEqualToAnchor:g2.content.trailingAnchor constant:-16],
        [about.topAnchor constraintEqualToAnchor:g2.content.topAnchor constant:16], [g2.content.bottomAnchor constraintEqualToAnchor:about.bottomAnchor constant:16],
        [g3.topAnchor constraintEqualToAnchor:g2.bottomAnchor constant:12], [g3.leadingAnchor constraintEqualToAnchor:g1.leadingAnchor], [g3.trailingAnchor constraintEqualToAnchor:g1.trailingAnchor],
        [dv.leadingAnchor constraintEqualToAnchor:g3.content.leadingAnchor constant:16], [dv.topAnchor constraintEqualToAnchor:g3.content.topAnchor constant:14],
        [dn.leadingAnchor constraintEqualToAnchor:dv.leadingAnchor], [dn.topAnchor constraintEqualToAnchor:dv.bottomAnchor constant:2],
        [ls.leadingAnchor constraintEqualToAnchor:g3.content.leadingAnchor constant:16], [ls.trailingAnchor constraintEqualToAnchor:g3.content.trailingAnchor constant:-16],
        [ls.topAnchor constraintEqualToAnchor:dn.bottomAnchor constant:(DevLinks().count ? 12 : 0)], [g3.content.bottomAnchor constraintEqualToAnchor:ls.bottomAnchor constant:16],
        [clr.topAnchor constraintEqualToAnchor:g3.bottomAnchor constant:12], [clr.leadingAnchor constraintEqualToAnchor:g1.leadingAnchor], [clr.trailingAnchor constraintEqualToAnchor:g1.trailingAnchor] ]];
}
- (void)langChanged:(UISegmentedControl *)c {
    [[NSUserDefaults standardUserDefaults] setBool:(c.selectedSegmentIndex == 1) forKey:@"arabic"];
    [[NSNotificationCenter defaultCenter] postNotificationName:NotifLang object:nil];
}
- (void)openLink:(UIButton *)b {
    if ([b.accessibilityValue hasPrefix:@"copy:"]) {
        NSString *v = [b.accessibilityValue substringFromIndex:5];
        UIPasteboard.generalPasteboard.string = v;
        UIAlertController *al = [UIAlertController alertControllerWithTitle:T(@"Copied") message:T([NSString stringWithFormat:@"WhatsApp username: %@", v]) preferredStyle:UIAlertControllerStyleAlert];
        [al addAction:[UIAlertAction actionWithTitle:T(@"OK") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:al animated:YES completion:nil]; return;
    }
  NSURL *u = [NSURL URLWithString:b.accessibilityValue]; if (u) [UIApplication.sharedApplication openURL:u options:@{} completionHandler:nil]; }
- (void)appearanceChanged { [[NSUserDefaults standardUserDefaults] setInteger:self.appearance.selectedSegmentIndex forKey:PrefAppearance]; [Theme applyAppearance]; }
- (void)accentTapped:(UIButton *)b {
    [[NSUserDefaults standardUserDefaults] setInteger:b.tag forKey:PrefAccent];
    for (UIButton *x in self.accent.arrangedSubviews) x.layer.borderWidth = (x.tag == b.tag) ? 3 : 0;
    [[UIImpactFeedbackGenerator new] impactOccurred];
    [Theme applyAppearance];
}
- (void)clearAll {
    for (NSString *k in @[ @"nicks", @"knownIPs", @"speedHistory" ]) [[NSUserDefaults standardUserDefaults] removeObjectForKey:k];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:T(@"Cleared") message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:T(@"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

#pragma mark - App

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (UINavigationController *)nav:(UIViewController *)vc icon:(NSString *)i {
    UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:vc];
    n.tabBarItem = [[UITabBarItem alloc] initWithTitle:vc.title image:[UIImage systemImageNamed:i] tag:0];
    UINavigationBarAppearance *ap = [UINavigationBarAppearance new]; [ap configureWithTransparentBackground];
    n.navigationBar.standardAppearance = ap; n.navigationBar.scrollEdgeAppearance = ap;
    n.navigationBar.prefersLargeTitles = YES;
    return n;
}
- (void)buildRootSelecting:(NSInteger)idx {
    ApplyDirection();
    DevicesVC *d = [DevicesVC new]; d.title = @"Devices";
    SpeedVC *s = [SpeedVC new]; s.title = @"Speed";
    ToolsVC *t = [ToolsVC new]; t.title = @"Tools";
    SettingsVC *st = [SettingsVC new]; st.title = @"Settings";
    UITabBarController *tb = [UITabBarController new];
    tb.viewControllers = @[ [self nav:d icon:@"wifi"], [self nav:s icon:@"speedometer"], [self nav:t icon:@"wrench.and.screwdriver"], [self nav:st icon:@"gearshape"] ];
    UITabBarAppearance *ta = [UITabBarAppearance new]; [ta configureWithDefaultBackground];
    ta.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    tb.tabBar.standardAppearance = ta; tb.tabBar.scrollEdgeAppearance = ta;
    tb.selectedIndex = idx;
    self.window.rootViewController = tb;
    tb.view.tintColor = Theme.accent;
    self.window.semanticContentAttribute = IsAr() ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
}
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)o {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ PrefAppearance: @2 }];
    SetupLocalization();
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [self buildRootSelecting:0];
    [self.window makeKeyAndVisible];
    [Theme applyAppearance];
    [[NSNotificationCenter defaultCenter] addObserverForName:NotifTheme object:nil queue:nil usingBlock:^(NSNotification *n) { self.window.tintColor = Theme.accent; self.window.rootViewController.view.tintColor = Theme.accent; }];
    [[NSNotificationCenter defaultCenter] addObserverForName:NotifLang object:nil queue:nil usingBlock:^(NSNotification *n) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self buildRootSelecting:3]; [Theme applyAppearance]; });
    }];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
