#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <stdlib.h>
#import "NovaUIManager.h"

static BOOL gBlockReport = NO;
static BOOL gSneakAll = YES;
static BOOL gH5Capture = NO;
static BOOL gRTAntiMute = NO;
static NSTimeInterval gRTSelfActionTs = 0;
static NSTimeInterval gRTDownMicTs = 0;
static BOOL gRTUserMuteIntent = NO;
static id gRTMeUser = nil;
static unsigned int gRTMicStatusMuted = 0;
static unsigned int gRTMicStatusUnmuted = 0;
static BOOL gRTCalibMuted = NO;
static BOOL gRTCalibUnmuted = NO;
static id gRTReportService = nil;
static unsigned int gRTReportUid = 0;
static unsigned int gRTReportMicId = 0;
static unsigned int gRTReportChType = 0;
static unsigned int gRTReportChId = 0;
static id gRTMicControl = nil;
static id gRTVC = nil;

static void TTRTMarkSelfAction(void) {
    gRTSelfActionTs = [NSDate timeIntervalSinceReferenceDate];
}

static BOOL TTRTIsSelfAction(void) {
    return ([NSDate timeIntervalSinceReferenceDate] - gRTSelfActionTs) < 2.0;
}

static BOOL TTRTIsSelfDownMic(void) {
    return ([NSDate timeIntervalSinceReferenceDate] - gRTDownMicTs) < 15.0;
}
static BOOL gRTAntiClear = NO;
static BOOL gRTAudio192 = NO;
static BOOL gRTSkin = NO;
static BOOL gRTAntiKick = NO;
static BOOL gRTUpMic = NO;
static BOOL gRTIsland = NO;
static uint32_t gRTDressId = 0;
static NSMutableDictionary *gRTOrigImps = nil;
static NSDictionary *gRTOrigSnapshot = nil;

static uint32_t gSelfUid = 0;
static NSInteger gMemberLevel = 8;
static NSInteger gNobleLevel = 10;
static NSInteger gRichLevelVal = 0;
static NSInteger gCharmLevelVal = 0;
static NSInteger gNameStyle = 1;
static NSInteger gNameColorIndex = 0;
static uint64_t gStealthSwitch = 2;

static uint32_t gBubbleDressId = 0;
static uint32_t gChatBgDressId = 0;
static uint32_t gSpecialDressId = 0;
static uint32_t gRoomDressId = 0;
static NSString *gBubbleDressName = nil;
static NSString *gChatBgDressName = nil;
static NSString *gSpecialDressName = nil;
static NSString *gRoomDressName = nil;

static NSString *gMyNickname = nil;
static NSString *gCustomId = nil;
static NSString *gPrevCustomId = nil;
static NSString *gMyRealAccount = nil;
static BOOL gLastPrivWasSelf = NO;
static CFAbsoluteTime gLastOtherProfileTs = 0;
static BOOL gActiveProfileIsOther = NO;

static NSMutableDictionary *gHits = nil;
static NSHashTable *gForgedPlayers = nil;
static NSMapTable *gGPBOrig = nil;
static NSMutableDictionary *gHideVisits = nil;
static NSMutableSet *gHideSent = nil;
static NSMutableSet *gSpecialKeys = nil;
static NSMutableDictionary *gAccountUid = nil;
static id gLogLock = nil;

static id gConnCore = nil;
static id gMagicMgr = nil;
static id gMagicCurrentVM = nil;
static NSHashTable *gMagicEchoTargets = nil;
static NSHashTable *gMagicVMs = nil;
static uint32_t gMagicVMLogged = 0;
static uint32_t gMagicLastMicId = 0;
static uint32_t gMagicLastUid = 0;
static uint64_t gMagicLastSendTimeMs = 0;

static char kTTMyLevelObjKey;
static char kTTNobleUidKey;
static char kTTSelfPrivKey;
static char kTTRealAccKey;
static char kTTCtxExplicitIsMeKey;
static char kTTCountedUidKey;
static char kTTTaggedNobleUidKey;

static NSMapTable *gWeakCtxMap = nil;
static inline id TTGetWeakCtx(NSString *k) {
    if (!gWeakCtxMap || !k) return nil;
    @synchronized (gWeakCtxMap) { return [gWeakCtxMap objectForKey:k]; }
}
static inline void TTSetWeakCtx(NSString *k, id ctx) {
    if (!k) return;
    if (!gWeakCtxMap) gWeakCtxMap = [[NSMapTable strongToWeakObjectsMapTable] retain];
    static BOOL inSet = NO;
    if (inSet) return;
    inSet = YES;
    @synchronized (gWeakCtxMap) {
        if (ctx) [gWeakCtxMap setObject:ctx forKey:k];
        else [gWeakCtxMap removeObjectForKey:k];
    }
    inSet = NO;
}
static inline id TTGetLastSelfLayoutCtx(void)       { return TTGetWeakCtx(@"self"); }
static inline void TTSetLastSelfLayoutCtx(id ctx)   { TTSetWeakCtx(@"self", ctx); }
static inline id TTGetLastOtherLayoutCtx(void)      { return TTGetWeakCtx(@"other"); }
static inline void TTSetLastOtherLayoutCtx(id ctx)  { TTSetWeakCtx(@"other", ctx); }
static inline id TTGetLatestLayoutCtx(void)         { return TTGetWeakCtx(@"latest"); }
static inline void TTSetLatestLayoutCtx(id ctx)     { TTSetWeakCtx(@"latest", ctx); }
static dispatch_queue_t gLogQueue = NULL;
static NSFileHandle *gLogFileHandle = nil;

static inline BOOL TTMemberForgeOn(void)     { return gMemberLevel > 0; }
static inline BOOL TTNobleForgeOn(void)      { return gNobleLevel > 0; }
static inline BOOL TTDressForgeOn(void)      { return gBubbleDressId > 0 || gChatBgDressId > 0 || gSpecialDressId > 0 || gRoomDressId > 0; }
static inline BOOL TTMemberForgeActive(void) { return TTMemberForgeOn(); }
static inline BOOL TTH5ForgeActive(void)     { return TTMemberForgeOn() || TTNobleForgeOn() || TTDressForgeOn(); }
static inline BOOL TTIsSelfUidRaw(uint32_t u){ return gSelfUid != 0 && u == gSelfUid; }
static inline BOOL TTIsSelfUid(uint32_t u)   { return TTMemberForgeOn() && TTIsSelfUidRaw(u); }

static float TTNobleBandFLevel(NSInteger lv) {
    if (lv <= 0) return 0.0f;
    if (lv > 10) lv = 10;
    return (lv == 1) ? 0.5f : (float)(lv - 1);
}

static uint64_t TTMemberGrowthCap(NSInteger lv) {
    static const uint64_t t[9] = {0, 260, 700, 1800, 4000, 6700, 12800, 25500, 25500};
    return t[lv < 1 ? 1 : (lv > 8 ? 8 : lv)];
}

static uint64_t TTNobleValueCap(NSInteger lv) {
    static const uint64_t t[11] = {0, 50000, 200000, 500000, 1000000, 2000000, 5000000, 10000000, 20000000, 50000000, 50000000};
    return t[lv < 1 ? 1 : (lv > 10 ? 10 : lv)];
}

static uint64_t TTNobleKeepCap(NSInteger lv) {
    static const uint64_t t[11] = {0, 3000, 15000, 60000, 150000, 300000, 600000, 1500000, 3000000, 6000000, 2000000000ULL};
    return t[lv < 1 ? 1 : (lv > 10 ? 10 : lv)];
}

static NSString *TTNobleTitleForLevel(NSInteger lv) {
    if (lv <= 0) return @"";
    static NSArray *names = nil;
    if (!names) names = [@[@"少爵", @"男爵", @"子爵", @"伯爵", @"侯爵", @"公爵", @"郡王", @"亲王", @"国王", @"神王"] retain];
    NSUInteger idx = (NSUInteger)(lv - 1);
    return idx < names.count ? names[idx] : @"神王";
}

static NSString *TTMemberLevelName(void) {
    return gMemberLevel <= 0 ? @"原样（真实数据）" : [NSString stringWithFormat:@"SVIP %ld", (long)gMemberLevel];
}

static NSString *TTNobleLevelName(void) {
    if (gNobleLevel <= 0) return @"原样（真实数据）";
    static NSArray *names = nil;
    if (!names) names = [@[@"1级·少爵", @"2级·男爵", @"3级·子爵", @"4级·伯爵", @"5级·侯爵",
                           @"6级·公爵", @"7级·郡王", @"8级·亲王", @"9级·国王", @"10级·神王"] retain];
    NSUInteger idx = (NSUInteger)(gNobleLevel - 1);
    return idx < names.count ? names[idx] : [NSString stringWithFormat:@"%ld级", (long)gNobleLevel];
}

static NSInteger TTTitleBandForValue(NSInteger v) {
    if (v <= 10) return 0;
    if (v <= 100) return 1;
    if (v <= 1000) return 2;
    if (v <= 10000) return 3;
    if (v <= 100000) return 4;
    if (v <= 1000000) return 5;
    return 6;
}

static NSString *TTCharmLevelName(void) {
    if (gCharmLevelVal <= 0) return @"原样（真实数据）";
    static NSArray *t = nil;
    if (!t) t = [@[@"初见锋芒", @"见习偶像", @"名声大振", @"人气之星", @"光辉夺目", @"风华绝代", @"永恒璀璨"] retain];
    return t[(NSUInteger)TTTitleBandForValue(gCharmLevelVal)];
}

static NSString *TTRichLevelName(void) {
    if (gRichLevelVal <= 0) return @"原样（真实数据）";
    static NSArray *t = nil;
    if (!t) t = [@[@"优雅才子", @"圣殿绅士", @"荣耀城主", @"尊贵诸侯", @"枭雄霸王", @"至尊帝皇", @"永恒帝尊"] retain];
    return t[(NSUInteger)TTTitleBandForValue(gRichLevelVal)];
}

static NSString *TTNameStyleName(void) {
    switch (gNameStyle) {
        case 1: return @"贵族红名";
        case 2: return @"贵族红名V2";
        case 3: return @"SVIP图案";
        default: return @"原样";
    }
}

static NSString *TTNameColorNameIdx(NSInteger idx) {
    static NSArray *names = nil;
    if (!names) names = [@[@"原生渐变", @"SVIP橙", @"蓝紫", @"薄荷", @"湖青", @"紫金", @"粉黄", @"红黄", @"霓虹", @"落日"] retain];
    return (idx >= 1 && idx < (NSInteger)names.count) ? names[(NSUInteger)idx] : @"原生渐变";
}

static NSString *TTNamePresetName(void) {
    if (gNameStyle == 0) return @"原样";
    return [NSString stringWithFormat:@"%@ · %@", TTNameStyleName(), TTNameColorNameIdx(gNameColorIndex)];
}

static NSString *TTLogPath(void) {
    NSString *dir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]
                     stringByAppendingPathComponent:@"TTForgeLog"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:@"ttforge.log"];
}

static void TTLog(NSString *fmt, ...) {
    @try {
        va_list ap; va_start(ap, fmt);
        NSString *body = [[NSString alloc] initWithFormat:fmt arguments:ap];
        va_end(ap);
        if (!gLogQueue) gLogQueue = dispatch_queue_create("com.ttforge.log", DISPATCH_QUEUE_SERIAL);
        dispatch_async(gLogQueue, ^{
            @try {
                static NSDateFormatter *df = nil;
                if (!df) { df = [[NSDateFormatter alloc] init]; df.dateFormat = @"MM-dd HH:mm:ss"; }
                NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [df stringFromDate:[NSDate date]], body];
                NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
                if (!gLogFileHandle) {
                    NSString *p = TTLogPath();
                    if (![[NSFileManager defaultManager] fileExistsAtPath:p]) {
                        [data writeToFile:p atomically:NO];
                        gLogFileHandle = [[NSFileHandle fileHandleForWritingAtPath:p] retain];
                        [gLogFileHandle seekToEndOfFile];
                        return;
                    }
                    gLogFileHandle = [[NSFileHandle fileHandleForWritingAtPath:p] retain];
                    [gLogFileHandle seekToEndOfFile];
                }
                if (gLogFileHandle && data) [gLogFileHandle writeData:data];
            } @catch (id e) {
                [gLogFileHandle release];
                gLogFileHandle = nil;
            }
        });
        [body release];
    } @catch (id e) {}
}

static NSString *TTHex(NSData *d, NSUInteger cap) {
    NSUInteger n = MIN(d.length, cap);
    NSMutableString *s = [NSMutableString stringWithCapacity:n * 2];
    const uint8_t *p = d.bytes;
    for (NSUInteger i = 0; i < n; i++) [s appendFormat:@"%02x", p[i]];
    if (d.length > cap) [s appendString:@"…"];
    return s;
}

static long TTPBRet(NSData *d) {
    const uint8_t *p = d.bytes; NSUInteger n = d.length, i = 0;
    while (i < n) {
        uint64_t tag = 0; int sh = 0;
        while (i < n && sh < 70) { uint8_t b = p[i++]; tag |= (uint64_t)(b & 0x7f) << sh; if (!(b & 0x80)) break; sh += 7; }
        uint64_t field = tag >> 3; int wire = (int)(tag & 7);
        if (wire == 2) {
            uint64_t len = 0; sh = 0;
            while (i < n && sh < 70) { uint8_t b = p[i++]; len |= (uint64_t)(b & 0x7f) << sh; if (!(b & 0x80)) break; sh += 7; }
            if (field == 1) {
                NSUInteger end = MIN(i + (NSUInteger)len, n), j = i;
                while (j < end) {
                    uint64_t t2 = 0; int s2 = 0;
                    while (j < end && s2 < 70) { uint8_t b = p[j++]; t2 |= (uint64_t)(b & 0x7f) << s2; if (!(b & 0x80)) break; s2 += 7; }
                    uint64_t f2 = t2 >> 3; int w2 = (int)(t2 & 7);
                    if (w2 == 0) {
                        uint64_t v = 0; int s3 = 0;
                        while (j < end && s3 < 70) { uint8_t b = p[j++]; v |= (uint64_t)(b & 0x7f) << s3; if (!(b & 0x80)) break; s3 += 7; }
                        if (f2 == 1) return (long)v;
                    } else if (w2 == 2) {
                        uint64_t l2 = 0; int s4 = 0;
                        while (j < end && s4 < 70) { uint8_t b = p[j++]; l2 |= (uint64_t)(b & 0x7f) << s4; if (!(b & 0x80)) break; s4 += 7; }
                        j += (NSUInteger)l2;
                    } else if (w2 == 5) j += 4;
                    else if (w2 == 1) j += 8;
                    else return -1;
                }
                return -2;
            }
            i += (NSUInteger)len;
        } else if (wire == 0) {
            while (i < n) { if (!(p[i++] & 0x80)) break; }
        } else if (wire == 5) i += 4;
        else if (wire == 1) i += 8;
        else return -1;
    }
    return -3;
}

static inline BOOL TTGetBool(id obj, SEL sel) {
    return (obj && [obj respondsToSelector:sel]) ? ((BOOL (*)(id, SEL))objc_msgSend)(obj, sel) : NO;
}
static inline uint32_t TTGetU32(id obj, SEL sel) {
    return (obj && [obj respondsToSelector:sel]) ? ((uint32_t (*)(id, SEL))objc_msgSend)(obj, sel) : 0;
}
static inline uint64_t TTGetU64(id obj, SEL sel) {
    return (obj && [obj respondsToSelector:sel]) ? ((uint64_t (*)(id, SEL))objc_msgSend)(obj, sel) : 0;
}
static inline float TTGetFloat(id obj, SEL sel) {
    return (obj && [obj respondsToSelector:sel]) ? ((float (*)(id, SEL))objc_msgSend)(obj, sel) : 0.0f;
}
static inline id TTGetObj(id obj, SEL sel) {
    return (obj && [obj respondsToSelector:sel]) ? ((id (*)(id, SEL))objc_msgSend)(obj, sel) : nil;
}
static inline void TTSetBool(id obj, SEL sel, BOOL v) {
    if (obj && [obj respondsToSelector:sel]) ((void (*)(id, SEL, BOOL))objc_msgSend)(obj, sel, v);
}
static inline void TTSetU32(id obj, SEL sel, uint32_t v) {
    if (obj && [obj respondsToSelector:sel]) ((void (*)(id, SEL, uint32_t))objc_msgSend)(obj, sel, v);
}
static inline void TTSetU64(id obj, SEL sel, uint64_t v) {
    if (obj && [obj respondsToSelector:sel]) ((void (*)(id, SEL, uint64_t))objc_msgSend)(obj, sel, v);
}
static inline void TTSetFloat(id obj, SEL sel, float v) {
    if (obj && [obj respondsToSelector:sel]) ((void (*)(id, SEL, float))objc_msgSend)(obj, sel, v);
}
static inline void TTSetObj(id obj, SEL sel, id v) {
    if (obj && [obj respondsToSelector:sel]) ((void (*)(id, SEL, id))objc_msgSend)(obj, sel, v);
}

static BOOL TTSwizzle(Class cls, SEL sel, IMP newImp, IMP *origOut) {
    if (!cls) return NO;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NO;
    *origOut = method_getImplementation(m);
    method_setImplementation(m, newImp);
    return YES;
}

static BOOL TTSwizzleClassMethod(Class cls, SEL sel, IMP newImp, IMP *origOut) {
    if (!cls) return NO;
    Method m = class_getClassMethod(cls, sel);
    if (!m) return NO;
    *origOut = method_getImplementation(m);
    method_setImplementation(m, newImp);
    return YES;
}

static IMP TTOrigIMP(Class cls, SEL sel) {
    Method m = cls ? class_getInstanceMethod(cls, sel) : NULL;
    return m ? method_getImplementation(m) : NULL;
}

static NSString *TTRTKey(Class cls, SEL sel) {
    return [NSString stringWithFormat:@"%@|%@", NSStringFromClass(cls), NSStringFromSelector(sel)];
}

static NSMutableArray *TTRTOrigStack(void) {
    NSMutableDictionary *td = [[NSThread currentThread] threadDictionary];
    NSMutableArray *st = [td objectForKey:@"ttforge.rtorigstack"];
    if (!st) { st = [NSMutableArray array]; [td setObject:st forKey:@"ttforge.rtorigstack"]; }
    return st;
}

static IMP TTRTOrig(id self, SEL sel) {
    NSMutableArray *st = TTRTOrigStack();
    IMP first = NULL;
    for (Class c = [self class]; c; c = class_getSuperclass(c)) {
        IMP imp = (IMP)[[(gRTOrigSnapshot ? gRTOrigSnapshot : gRTOrigImps) objectForKey:TTRTKey(c, sel)] pointerValue];
        if (!imp) continue;
        if (!first) first = imp;
        NSString *key = [NSString stringWithFormat:@"%p|%@|%p", self, NSStringFromSelector(sel), imp];
        if (![st containsObject:key]) { [st addObject:key]; return imp; }
    }
    if (first) {
        NSString *key = [NSString stringWithFormat:@"%p|%@|%p", self, NSStringFromSelector(sel), first];
        [st addObject:key];
        return first;
    }
    return NULL;
}

static void TTRTOrigDone(id self, SEL sel, IMP imp) {
    if (!imp) return;
    NSMutableArray *st = TTRTOrigStack();
    NSString *key = [NSString stringWithFormat:@"%p|%@|%p", self, NSStringFromSelector(sel), imp];
    NSUInteger idx = [st indexOfObject:key];
    if (idx != NSNotFound) [st removeObjectAtIndex:idx];
}

static void TTRTSwizzle(Class cls, SEL sel, IMP repl) {
    if (!cls) return;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) { TTLog(@"ROOMTEST MISS %@ %@", NSStringFromClass(cls), NSStringFromSelector(sel)); return; }
    IMP orig = method_getImplementation(m);
    if (orig == repl) { TTLog(@"ROOMTEST SKIP %@ %@ already hooked", NSStringFromClass(cls), NSStringFromSelector(sel)); return; }
    const char *types = method_getTypeEncoding(m);
    BOOL added = class_addMethod(cls, sel, repl, types);
    if (added) {
        [gRTOrigImps setObject:[NSValue valueWithPointer:(void *)orig] forKey:TTRTKey(cls, sel)];
    } else {
        IMP old = method_setImplementation(m, repl);
        [gRTOrigImps setObject:[NSValue valueWithPointer:(void *)old] forKey:TTRTKey(cls, sel)];
    }
    TTLog(@"ROOMTEST HOOK %@ %@ orig=%p", NSStringFromClass(cls), NSStringFromSelector(sel), orig);
}

static NSString *TTRTDesc(id obj) {
    if (!obj) return @"nil";
    NSString *s = nil;
    @try { s = [obj description]; } @catch (id e) { s = @"<desc err>"; }
    if ([s length] > 160) s = [s substringToIndex:160];
    return [NSString stringWithFormat:@"%@:%@", NSStringFromClass([obj class]), s];
}

static void rt_onMuteMicAction4(id self, SEL _cmd, BOOL mute, id tips, id muteToast, id unmuteToast) {
    TTLog(@"ROOMTEST onMuteMicAction mute=%d tips=%@ self=%@", mute, TTRTDesc(tips), NSStringFromClass([self class]));
    if (TTRTIsSelfAction()) { gRTUserMuteIntent = mute; TTLog(@"ROOMTEST userMuteIntent=%d", mute); }
    if (gRTAntiMute && mute && !TTRTIsSelfAction() && !gRTUserMuteIntent) { TTLog(@"ROOMTEST AntiMute BLOCK mute"); return; }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, BOOL, id, id, id))orig)(self, _cmd, mute, tips, muteToast, unmuteToast); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static BOOL rt_shouldIgnoreMuteMic(id self, SEL _cmd, id arg) {
    BOOL origVal = NO;
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { origVal = ((BOOL (*)(id, SEL, id))orig)(self, _cmd, arg); } @finally { TTRTOrigDone(self, _cmd, orig); } }
    TTLog(@"ROOMTEST shouldIgnoreMuteMic arg=%@ orig=%d antiMute=%d", TTRTDesc(arg), origVal, gRTAntiMute);
    if (gRTAntiMute && !gRTUserMuteIntent) return YES;
    return origVal;
}

static void rt_onKicked(id self, SEL _cmd, id msg) {
    TTLog(@"ROOMTEST KICK %@ msg=%@ self=%@", NSStringFromSelector(_cmd), TTRTDesc(msg), NSStringFromClass([self class]));
    if (gRTAntiKick) { TTLog(@"ROOMTEST AntiKick BLOCK %@", NSStringFromSelector(_cmd)); return; }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, id))orig)(self, _cmd, msg); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_clearData(id self, SEL _cmd) {
    TTLog(@"ROOMTEST CLEAR %@ self=%@", NSStringFromSelector(_cmd), NSStringFromClass([self class]));
    if (gRTAntiClear) { TTLog(@"ROOMTEST AntiClear BLOCK %@", NSStringFromSelector(_cmd)); return; }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL))orig)(self, _cmd); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static id rt_jsUiClear(id self, SEL _cmd, id arg, id callback) {
    TTLog(@"ROOMTEST jsUi_clearChatBoxChannel arg=%@ cb=%@ self=%@", TTRTDesc(arg), TTRTDesc(callback), NSStringFromClass([self class]));
    if (gRTAntiClear) { TTLog(@"ROOMTEST AntiClear BLOCK jsUi_clear"); return nil; }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { id _rtRet = nil; @try { _rtRet = ((id (*)(id, SEL, id, id))orig)(self, _cmd, arg, callback); } @finally { TTRTOrigDone(self, _cmd, orig); } return _rtRet; }
    return nil;
}

static void rt_updateAudioBitRate(id self, SEL _cmd, id arg) {
    TTLog(@"ROOMTEST updateAudioBitRate arg=%@ self=%@ audio192=%d", TTRTDesc(arg), NSStringFromClass([self class]), gRTAudio192);
    IMP orig = TTRTOrig(self, _cmd);
    if (!orig) return;
    if (gRTAudio192 && [arg isKindOfClass:[NSNumber class]]) {
        TTLog(@"ROOMTEST Audio192 REPLACE %@ -> 192000", arg);
        @try { ((void (*)(id, SEL, id))orig)(self, _cmd, @(192000)); } @finally { TTRTOrigDone(self, _cmd, orig); }
        return;
    }
    @try { ((void (*)(id, SEL, id))orig)(self, _cmd, arg); } @finally { TTRTOrigDone(self, _cmd, orig); }
}

static void rt_onChannelAudioBitRateChanged(id self, SEL _cmd, unsigned int channelId, id arg) {
    TTLog(@"ROOMTEST onChannelId:audioBitRateChanged channel=%u arg=%@", channelId, TTRTDesc(arg));
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, unsigned int, id))orig)(self, _cmd, channelId, arg); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_onRoomSuitDressIdUpdatedTo(id self, SEL _cmd, unsigned int dressId) {
    TTLog(@"ROOMTEST onRoomSuitDressIdUpdatedTo dressId=%u skin=%d override=%u", dressId, gRTSkin, gRTDressId);
    IMP orig = TTRTOrig(self, _cmd);
    if (!orig) return;
    if (gRTSkin && gRTDressId > 0) {
        @try { ((void (*)(id, SEL, unsigned int))orig)(self, _cmd, gRTDressId); } @finally { TTRTOrigDone(self, _cmd, orig); }
        return;
    }
    @try { ((void (*)(id, SEL, unsigned int))orig)(self, _cmd, dressId); } @finally { TTRTOrigDone(self, _cmd, orig); }
}

static BOOL rt_supportChangemic(id self, SEL _cmd, id micSpace, id *tip) {
    gRTMicControl = self;
    BOOL origVal = NO;
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { origVal = ((BOOL (*)(id, SEL, id, id *))orig)(self, _cmd, micSpace, tip); } @finally { TTRTOrigDone(self, _cmd, orig); } }
    TTLog(@"ROOMTEST supportChangemic micSpace=%@ orig=%d upMic=%d self=%@", TTRTDesc(micSpace), origVal, gRTUpMic, NSStringFromClass([self class]));
    if (gRTUpMic) return YES;
    return origVal;
}

static BOOL rt_supportChangemicCb(id self, SEL _cmd, id micSpace, id *tip, id callback) {
    BOOL origVal = NO;
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { origVal = ((BOOL (*)(id, SEL, id, id *, id))orig)(self, _cmd, micSpace, tip, callback); } @finally { TTRTOrigDone(self, _cmd, orig); } }
    TTLog(@"ROOMTEST supportChangemic:tip:callback micSpace=%@ orig=%d upMic=%d self=%@", TTRTDesc(micSpace), origVal, gRTUpMic, NSStringFromClass([self class]));
    if (gRTUpMic) return YES;
    return origVal;
}

static BOOL rt_isCanChangeMeToMic(id self, SEL _cmd, id arg, BOOL isMeOnMic, id *reason, id callback) {
    BOOL origVal = NO;
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { origVal = ((BOOL (*)(id, SEL, id, BOOL, id *, id))orig)(self, _cmd, arg, isMeOnMic, reason, callback); } @finally { TTRTOrigDone(self, _cmd, orig); } }
    TTLog(@"ROOMTEST isCanChangeMeToMic arg=%@ isMeOnMic=%d orig=%d upMic=%d self=%@", TTRTDesc(arg), isMeOnMic, origVal, gRTUpMic, NSStringFromClass([self class]));
    if (gRTUpMic) return YES;
    return origVal;
}

static id rt_getChannelLiveActivityContainerView(id self, SEL _cmd) {
    IMP orig = TTRTOrig(self, _cmd);
    id v = nil;
    if (orig) { @try { v = ((id (*)(id, SEL))orig)(self, _cmd); } @finally { TTRTOrigDone(self, _cmd, orig); } }
    TTLog(@"ROOMTEST getChannelLiveActivityContainerView -> %@ island=%d", TTRTDesc(v), gRTIsland);
    return v;
}

static void rt_registerLiveActivity(id self, SEL _cmd, id a, id b, long long seq) {
    TTLog(@"ROOMTEST registerLiveActivity %@ a=%@ b=%@ seq=%lld self=%@", NSStringFromSelector(_cmd), TTRTDesc(a), TTRTDesc(b), seq, NSStringFromClass([self class]));
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, id, id, long long))orig)(self, _cmd, a, b, seq); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}


static void rt_clearBoxAllMsgs(id self, SEL _cmd) {
    TTLog(@"ROOMTEST clearBoxAllMsgs self=%@ antiClear=%d", NSStringFromClass([self class]), gRTAntiClear);
    if (gRTAntiClear) { TTLog(@"ROOMTEST AntiClear BLOCK clearBoxAllMsgs"); return; }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL))orig)(self, _cmd); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_clearMessageWithTabidList(id self, SEL _cmd, id arg) {
    TTLog(@"ROOMTEST clearMessageWithTabidList arg=%@ self=%@ antiClear=%d", TTRTDesc(arg), NSStringFromClass([self class]), gRTAntiClear);
    if (gRTAntiClear) { TTLog(@"ROOMTEST AntiClear BLOCK clearMessageWithTabidList"); return; }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, id))orig)(self, _cmd, arg); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_setMicEnabled(id self, SEL _cmd, BOOL enabled) {
    TTLog(@"ROOMTEST setMicEnabled=%d self=%@ antiMute=%d ra:%p", enabled, NSStringFromClass([self class]), gRTAntiMute, __builtin_return_address(0));
    if (gRTAntiMute && !enabled && !gRTUserMuteIntent && !TTRTIsSelfDownMic()) { BOOL cur = YES; if ([self respondsToSelector:@selector(micEnabled)]) { cur = ((BOOL (*)(id, SEL))objc_msgSend)(self, @selector(micEnabled)); } if (cur) { TTLog(@"ROOMTEST AntiMute BLOCK setMicEnabled=0"); return; } }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, BOOL))orig)(self, _cmd, enabled); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_setSilence(id self, SEL _cmd, BOOL silence) {
    TTLog(@"ROOMTEST setSilence=%d self=%@ antiMute=%d ra:%p", silence, NSStringFromClass([self class]), gRTAntiMute, __builtin_return_address(0));
    if (gRTAntiMute && silence && !gRTUserMuteIntent && !TTRTIsSelfDownMic()) { TTLog(@"ROOMTEST AntiMute BLOCK setSilence=1"); return; }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, BOOL))orig)(self, _cmd, silence); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_onAmISilentChangeTo(id self, SEL _cmd, BOOL silent) {
    TTLog(@"ROOMTEST onAmISilentChangeTo=%d self=%@ antiMute=%d ra:%p", silent, NSStringFromClass([self class]), gRTAntiMute, __builtin_return_address(0));
    if (gRTAntiMute && silent && !gRTUserMuteIntent && !TTRTIsSelfDownMic()) { TTLog(@"ROOMTEST AntiMute BLOCK onAmISilentChangeTo=1"); return; }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, BOOL))orig)(self, _cmd, silent); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_onButtonMuteMyMicTapped(id self, SEL _cmd) {
    TTRTMarkSelfAction();
    TTLog(@"ROOMTEST onButtonMuteMyMicTapped self=%@ antiMute=%d", NSStringFromClass([self class]), gRTAntiMute);
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL))orig)(self, _cmd); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_handleTap(id self, SEL _cmd, id arg) {
    TTLog(@"ROOMTEST handleTap arg=%@ self=%@ upMic=%d", TTRTDesc(arg), NSStringFromClass([self class]), gRTUpMic);
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, id))orig)(self, _cmd, arg); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_onMicViewClicked(id self, SEL _cmd, id arg) {
    gRTVC = self;
    TTLog(@"ROOMTEST onMicViewClicked arg=%@ self=%@ upMic=%d", TTRTDesc(arg), NSStringFromClass([self class]), gRTUpMic);
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, id))orig)(self, _cmd, arg); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_upMicWithMicIdToken(id self, SEL _cmd, unsigned int micId, id token) {
    TTLog(@"ROOMTEST upMicWithMicId=%u token=%@ self=%@ upMic=%d ra:%p", micId, TTRTDesc(token), NSStringFromClass([self class]), gRTUpMic, __builtin_return_address(0));
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, unsigned int, id))orig)(self, _cmd, micId, token); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static BOOL rt_icanChangeToMicView(id self, SEL _cmd, id arg) {
    IMP orig = TTRTOrig(self, _cmd);
    BOOL origVal = NO;
    if (orig) { @try { origVal = ((BOOL (*)(id, SEL, id))orig)(self, _cmd, arg); } @finally { TTRTOrigDone(self, _cmd, orig); } }
    TTLog(@"ROOMTEST icanChangeToMicView arg=%@ orig=%d upMic=%d self=%@", TTRTDesc(arg), origVal, gRTUpMic, NSStringFromClass([self class]));
    if (gRTUpMic) return YES;
    return origVal;
}

static id rt_decideChainNodesBeforeUpMic(id self, SEL _cmd) {
    IMP orig = TTRTOrig(self, _cmd);
    id r = nil;
    if (orig) { @try { r = ((id (*)(id, SEL))orig)(self, _cmd); } @finally { TTRTOrigDone(self, _cmd, orig); } }
    TTLog(@"ROOMTEST decideChainNodesBeforeUpMic -> %@ upMic=%d self=%@", TTRTDesc(r), gRTUpMic, NSStringFromClass([self class]));
    return r;
}


static void rt_clearVoid(id self, SEL _cmd) {
    TTLog(@"ROOMTEST %@ self=%@ antiClear=%d", NSStringFromSelector(_cmd), NSStringFromClass([self class]), gRTAntiClear);
    if (gRTAntiClear) { TTLog(@"ROOMTEST AntiClear BLOCK %@", NSStringFromSelector(_cmd)); return; }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL))orig)(self, _cmd); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}


static void rt_muteThisMicHandle(id self, SEL _cmd, id arg) {
    TTRTMarkSelfAction();
    TTLog(@"ROOMTEST muteThisMicHandle arg=%@ self=%@ antiMute=%d", TTRTDesc(arg), NSStringFromClass([self class]), gRTAntiMute);
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, id))orig)(self, _cmd, arg); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static int rt_onButtonRequestDownMic(id self, SEL _cmd, id arg) {
    TTRTMarkSelfAction();
    gRTDownMicTs = [NSDate timeIntervalSinceReferenceDate];
    gRTUserMuteIntent = YES;
    TTLog(@"ROOMTEST onButtonRequestDownMic arg=%@ self=%@ antiMute=%d", TTRTDesc(arg), NSStringFromClass([self class]), gRTAntiMute);
    IMP orig = TTRTOrig(self, _cmd);
    int r = 0;
    if (orig) { @try { r = ((int (*)(id, SEL, id))orig)(self, _cmd, arg); } @finally { TTRTOrigDone(self, _cmd, orig); } }
    return r;
}


static void rt_enableMic(id self, SEL _cmd, BOOL enabled) {
    TTLog(@"ROOMTEST enableMic=%d self=%@ antiMute=%d ra:%p", enabled, NSStringFromClass([self class]), gRTAntiMute, __builtin_return_address(0));
    if (gRTAntiMute && !enabled && !gRTUserMuteIntent && !TTRTIsSelfDownMic()) { BOOL pub = YES; if ([self respondsToSelector:@selector(isPublishing)]) { pub = ((BOOL (*)(id, SEL))objc_msgSend)(self, @selector(isPublishing)); } if (pub) { TTLog(@"ROOMTEST AntiMute BLOCK enableMic=0"); return; } }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, BOOL))orig)(self, _cmd, enabled); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}


static void TTRTAutoSeatChange(void) {
    if (!gRTMicControl || !gRTVC) { TTLog(@"ROOMTEST AUTO SEAT no capture micControl=%@ vc=%@", TTRTDesc(gRTMicControl), TTRTDesc(gRTVC)); return; }
    if (![gRTMicControl respondsToSelector:@selector(micSpaces)] || ![gRTMicControl respondsToSelector:@selector(micViewForMicId:)] || ![gRTVC respondsToSelector:@selector(onMicViewClicked:)]) { TTLog(@"ROOMTEST AUTO SEAT selector missing"); return; }
    id spaces = ((id (*)(id, SEL))objc_msgSend)(gRTMicControl, @selector(micSpaces));
    if (!spaces) { TTLog(@"ROOMTEST AUTO SEAT micSpaces nil"); return; }
    for (id sp in spaces) {
        if (![sp respondsToSelector:@selector(isEmpty)] || ![sp respondsToSelector:@selector(micId)]) continue;
        BOOL empty = ((BOOL (*)(id, SEL))objc_msgSend)(sp, @selector(isEmpty));
        if (!empty) continue;
        unsigned int mid = ((unsigned int (*)(id, SEL))objc_msgSend)(sp, @selector(micId));
        id view = ((id (*)(id, SEL, unsigned int))objc_msgSend)(gRTMicControl, @selector(micViewForMicId:), mid);
        TTLog(@"ROOMTEST AUTO SEAT free micId=%u view=%@", mid, TTRTDesc(view));
        if (view) {
            ((void (*)(id, SEL, id))objc_msgSend)(gRTVC, @selector(onMicViewClicked:), view);
            TTLog(@"ROOMTEST AUTO SEAT onMicViewClicked sent micId=%u", mid);
            return;
        }
    }
    TTLog(@"ROOMTEST AUTO SEAT no free seat");
}

static void rt_setMute(id self, SEL _cmd, BOOL mute) {
    gRTMeUser = self;
    TTLog(@"ROOMTEST setMute=%d self=%@ antiMute=%d ra:%p", mute, NSStringFromClass([self class]), gRTAntiMute, __builtin_return_address(0));
    if (gRTAntiMute && mute && !gRTUserMuteIntent && !TTRTIsSelfDownMic()) {
        TTLog(@"ROOMTEST AntiMute BLOCK setMute=1");
        BOOL silentNow = NO;
        if ([self respondsToSelector:@selector(amISilent)]) { silentNow = ((BOOL (*)(id, SEL))objc_msgSend)(self, @selector(amISilent)); }
        TTLog(@"ROOMTEST BLOCK setMute amISilent=%d", silentNow);
        if (silentNow && [self respondsToSelector:@selector(rePublishStreamWhenSilentChangeTo:)]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(self, @selector(rePublishStreamWhenSilentChangeTo:), NO);
            TTLog(@"ROOMTEST republish non-silent stream");
        }
        if (gRTCalibUnmuted && gRTReportService && [gRTReportService respondsToSelector:@selector(reportRoomMicState:micID:channelType:channelId:micStatus:)]) {
            id svc = gRTReportService;
            unsigned int ruid = gRTReportUid;
            unsigned int rmic = gRTReportMicId;
            unsigned int rtype = gRTReportChType;
            unsigned int rch = gRTReportChId;
            unsigned int rstatus = gRTMicStatusUnmuted;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                ((void (*)(id, SEL, unsigned int, unsigned int, unsigned int, unsigned int, unsigned int))objc_msgSend)(svc, @selector(reportRoomMicState:micID:channelType:channelId:micStatus:), ruid, rmic, rtype, rch, rstatus);
                TTLog(@"ROOMTEST FORCE REPORT micStatus=%u", rstatus);
            });
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            TTRTAutoSeatChange();
        });
        return;
    }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, BOOL))orig)(self, _cmd, mute); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_setAmISilent(id self, SEL _cmd, BOOL silent) {
    TTLog(@"ROOMTEST setAmISilent=%d self=%@ antiMute=%d ra:%p", silent, NSStringFromClass([self class]), gRTAntiMute, __builtin_return_address(0));
    if (gRTAntiMute && silent && !gRTUserMuteIntent && !TTRTIsSelfDownMic()) { TTLog(@"ROOMTEST AntiMute BLOCK setAmISilent=1"); return; }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, BOOL))orig)(self, _cmd, silent); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_stopPublishStream(id self, SEL _cmd) {
    TTLog(@"ROOMTEST stopPublishStream self=%@ antiMute=%d ra:%p", NSStringFromClass([self class]), gRTAntiMute, __builtin_return_address(0));
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL))orig)(self, _cmd); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_rePublishStreamWhenSilentChangeTo(id self, SEL _cmd, BOOL silent) {
    TTLog(@"ROOMTEST rePublishStreamWhenSilentChangeTo=%d self=%@ antiMute=%d ra:%p", silent, NSStringFromClass([self class]), gRTAntiMute, __builtin_return_address(0));
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, BOOL))orig)(self, _cmd, silent); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}


static int rt_onButtonMuteMyMicTappedU(id self, SEL _cmd, id arg) {
    TTRTMarkSelfAction();
    TTLog(@"ROOMTEST _onButtonMuteMyMicTapped arg=%@ self=%@ antiMute=%d", TTRTDesc(arg), NSStringFromClass([self class]), gRTAntiMute);
    IMP orig = TTRTOrig(self, _cmd);
    int r = 0;
    if (orig) { @try { r = ((int (*)(id, SEL, id))orig)(self, _cmd, arg); } @finally { TTRTOrigDone(self, _cmd, orig); } }
    return r;
}

static void rt_onButtonMuteMyMicTappedWithTipsView(id self, SEL _cmd, id arg) {
    TTRTMarkSelfAction();
    TTLog(@"ROOMTEST onButtonMuteMyMicTappedWithTipsView arg=%@ self=%@ antiMute=%d", TTRTDesc(arg), NSStringFromClass([self class]), gRTAntiMute);
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, id))orig)(self, _cmd, arg); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_onButtonMuteMyMicWithPenaltyTime(id self, SEL _cmd, double penaltyTime) {
    TTRTMarkSelfAction();
    TTLog(@"ROOMTEST onButtonMuteMyMicWithPenaltyTime penalty=%f self=%@ antiMute=%d", penaltyTime, NSStringFromClass([self class]), gRTAntiMute);
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, double))orig)(self, _cmd, penaltyTime); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_pipMicButtonCloseMic(id self, SEL _cmd, BOOL closeMic) {
    TTRTMarkSelfAction();
    TTLog(@"ROOMTEST pipMicButtonCloseMic=%d self=%@ antiMute=%d", closeMic, NSStringFromClass([self class]), gRTAntiMute);
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, BOOL))orig)(self, _cmd, closeMic); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_setCaptureVolume(id self, SEL _cmd, int volume) {
    TTLog(@"ROOMTEST setCaptureVolume=%d self=%@ antiMute=%d ra:%p", volume, NSStringFromClass([self class]), gRTAntiMute, __builtin_return_address(0));
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, int))orig)(self, _cmd, volume); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void rt_configForMic(id self, SEL _cmd, BOOL enabled) {
    TTLog(@"ROOMTEST configForMic=%d self=%@ antiMute=%d ra:%p", enabled, NSStringFromClass([self class]), gRTAntiMute, __builtin_return_address(0));
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, BOOL))orig)(self, _cmd, enabled); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}


static id rt_genStreamID(id self, SEL _cmd) {
    IMP orig = TTRTOrig(self, _cmd);
    id r = nil;
    if (orig) { @try { r = ((id (*)(id, SEL))orig)(self, _cmd); } @finally { TTRTOrigDone(self, _cmd, orig); } }
    TTLog(@"ROOMTEST genStreamID=%@ antiMute=%d intent=%d", r, gRTAntiMute, gRTUserMuteIntent);
    if (gRTAntiMute && !gRTUserMuteIntent && [r isKindOfClass:[NSString class]] && [(NSString *)r containsString:@"-S1-"]) {
        NSString *fixed = [(NSString *)r stringByReplacingOccurrencesOfString:@"-S1-" withString:@"-"];
        TTLog(@"ROOMTEST genStreamID strip S1 -> %@", fixed);
        return fixed;
    }
    return r;
}

static BOOL rt_amISilent(id self, SEL _cmd) {
    IMP orig = TTRTOrig(self, _cmd);
    BOOL r = NO;
    if (orig) { @try { r = ((BOOL (*)(id, SEL))orig)(self, _cmd); } @finally { TTRTOrigDone(self, _cmd, orig); } }
    TTLog(@"ROOMTEST amISilent=%d antiMute=%d intent=%d", r, gRTAntiMute, gRTUserMuteIntent);
    return r;
}

static void rt_publishStream(id self, SEL _cmd) {
    gRTMeUser = self;
    TTLog(@"ROOMTEST publishStream self=%@ antiMute=%d intent=%d", NSStringFromClass([self class]), gRTAntiMute, gRTUserMuteIntent);
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL))orig)(self, _cmd); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}


static void rt_reportRoomMicState(id self, SEL _cmd, unsigned int uid, unsigned int micId, unsigned int channelType, unsigned int channelId, unsigned int micStatus) {
    gRTReportService = self;
    gRTReportUid = uid;
    gRTReportMicId = micId;
    gRTReportChType = channelType;
    gRTReportChId = channelId;
    TTLog(@"ROOMTEST reportRoomMicState uid=%u micId=%u chType=%u chId=%u micStatus=%u intent=%d antiMute=%d", uid, micId, channelType, channelId, micStatus, gRTUserMuteIntent, gRTAntiMute);
    if (([NSDate timeIntervalSinceReferenceDate] - gRTSelfActionTs) < 5.0) {
        if (gRTUserMuteIntent) { gRTMicStatusMuted = micStatus; gRTCalibMuted = YES; TTLog(@"ROOMTEST calib muted micStatus=%u", micStatus); }
        else { gRTMicStatusUnmuted = micStatus; gRTCalibUnmuted = YES; TTLog(@"ROOMTEST calib unmuted micStatus=%u", micStatus); }
    }
    if (gRTAntiMute && !gRTUserMuteIntent && gRTCalibMuted && gRTCalibUnmuted && gRTMicStatusMuted != gRTMicStatusUnmuted && micStatus == gRTMicStatusMuted) {
        TTLog(@"ROOMTEST reportRoomMicState REWRITE micStatus %u -> %u", micStatus, gRTMicStatusUnmuted);
        micStatus = gRTMicStatusUnmuted;
    }
    IMP orig = TTRTOrig(self, _cmd);
    if (orig) { @try { ((void (*)(id, SEL, unsigned int, unsigned int, unsigned int, unsigned int, unsigned int))orig)(self, _cmd, uid, micId, channelType, channelId, micStatus); } @finally { TTRTOrigDone(self, _cmd, orig); } }
}

static void TTRTInstallHooks(void) {
    if (!gRTOrigImps) gRTOrigImps = [[NSMutableDictionary alloc] init];
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(onMuteMicAction:tipsInView:muteToast:unmuteToast:), (IMP)rt_onMuteMicAction4);
    TTRTSwizzle(NSClassFromString(@"RealTimeMicControl"), @selector(shouldIgnoreMuteMic:), (IMP)rt_shouldIgnoreMuteMic);
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(onChannelMsgKicked:), (IMP)rt_onKicked);
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(onChannelMsgKickedMic:), (IMP)rt_onKicked);
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(onChannelMsgPushTimeOutKickedSelf:), (IMP)rt_onKicked);
    TTRTSwizzle(NSClassFromString(@"RealTimeMicControl"), @selector(onMicKicked:), (IMP)rt_onKicked);
    TTRTSwizzle(NSClassFromString(@"CommonChannelServiceCache"), @selector(clearChannelMessageData), (IMP)rt_clearData);
    TTRTSwizzle(NSClassFromString(@"CommonChannelServiceCache"), @selector(clearChannelMessageDataWithoutGiftMessage), (IMP)rt_clearData);
    TTRTSwizzle(NSClassFromString(@"RealTimeMicGameControl"), @selector(jsUi_clearChatBoxChannel:callback:), (IMP)rt_jsUiClear);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveRoom"), @selector(updateAudioBitRate:), (IMP)rt_updateAudioBitRate);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVRoom"), @selector(updateAudioBitRate:), (IMP)rt_updateAudioBitRate);
    TTRTSwizzle(NSClassFromString(@"RealTimeMicControl"), @selector(onChannelId:audioBitRateChanged:), (IMP)rt_onChannelAudioBitRateChanged);
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(onRoomSuitDressIdUpdatedTo:), (IMP)rt_onRoomSuitDressIdUpdatedTo);
    NSArray *supportClasses = @[@"RealTimeMicControl", @"RealTimeDramaticPgcMicControl", @"RealTimeDramaticUgcMicControl", @"RealTimeMicGameControl", @"RealTimeMicTempGameControl", @"WeddingMicControl", @"RealTimeSingPlayTempMicControl", @"RealTimeSingPlayUGCMicControl", @"RealTimeUGCBandMicControl"];
    for (NSString *cn in supportClasses) {
        TTRTSwizzle(NSClassFromString(cn), @selector(supportChangemic:tip:), (IMP)rt_supportChangemic);
    }
    NSArray *supportCbClasses = @[@"RealTimeMicControl", @"WeddingMicControl"];
    for (NSString *cn in supportCbClasses) {
        TTRTSwizzle(NSClassFromString(cn), @selector(supportChangemic:tip:callback:), (IMP)rt_supportChangemicCb);
    }
    NSArray *canChangeClasses = @[@"RealTimeMicControl", @"PGCDefaultMicControl", @"WeddingMicControl", @"RealTimeUGCBandMicControl", @"RealTimeMicGameControl"];
    for (NSString *cn in canChangeClasses) {
        TTRTSwizzle(NSClassFromString(cn), @selector(isCanChangeMeToMic:isMeOnMic:reason:callback:), (IMP)rt_isCanChangeMeToMic);
    }
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(getChannelLiveActivityContainerView), (IMP)rt_getChannelLiveActivityContainerView);
    TTRTSwizzle(NSClassFromString(@"GtSdkManager"), @selector(registerLiveActivity:activityToken:sequenceNum:), (IMP)rt_registerLiveActivity);
    TTRTSwizzle(NSClassFromString(@"GXLiveManager"), @selector(registerLiveActivity:activityToken:sequenceNum:), (IMP)rt_registerLiveActivity);
    TTRTSwizzle(NSClassFromString(@"RealTimeVoiceMessageControl"), @selector(clearBoxAllMsgs), (IMP)rt_clearBoxAllMsgs);
    TTRTSwizzle(NSClassFromString(@"RealTimeVoiceMessageControl"), @selector(clearMessageWithTabidList:), (IMP)rt_clearMessageWithTabidList);
    TTRTSwizzle(NSClassFromString(@"GameModeMessageScreen"), @selector(clearMessageWithTabidList:), (IMP)rt_clearMessageWithTabidList);
    TTRTSwizzle(NSClassFromString(@"GameModeSingleScreen"), @selector(clearMessageWithTabidList:), (IMP)rt_clearMessageWithTabidList);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVRoom"), @selector(setMicEnabled:), (IMP)rt_setMicEnabled);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveRoom"), @selector(setMicEnabled:), (IMP)rt_setMicEnabled);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVRoom"), @selector(setSilence:), (IMP)rt_setSilence);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveRoom"), @selector(setSilence:), (IMP)rt_setSilence);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveRoom"), @selector(onAmISilentChangeTo:), (IMP)rt_onAmISilentChangeTo);
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(onButtonMuteMyMicTapped), (IMP)rt_onButtonMuteMyMicTapped);
    TTRTSwizzle(NSClassFromString(@"TTRealTimeMicView"), @selector(handleTap:), (IMP)rt_handleTap);
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(onMicViewClicked:), (IMP)rt_onMicViewClicked);
    TTRTSwizzle(NSClassFromString(@"CommonSuperVoiceRoomViewController"), @selector(onMicViewClicked:), (IMP)rt_onMicViewClicked);
    TTRTSwizzle(NSClassFromString(@"RealTimeMicControl"), @selector(upMicWithMicId:token:), (IMP)rt_upMicWithMicIdToken);
    TTRTSwizzle(NSClassFromString(@"RealTimeMicControl"), @selector(icanChangeToMicView:), (IMP)rt_icanChangeToMicView);
    TTRTSwizzle(NSClassFromString(@"RealTimeCPGameMicControl"), @selector(icanChangeToMicView:), (IMP)rt_icanChangeToMicView);
    TTRTSwizzle(NSClassFromString(@"RealTimeDateMicControl"), @selector(icanChangeToMicView:), (IMP)rt_icanChangeToMicView);
    TTRTSwizzle(NSClassFromString(@"RealTimeOfferRoomMicControl"), @selector(icanChangeToMicView:), (IMP)rt_icanChangeToMicView);
    TTRTSwizzle(NSClassFromString(@"RealTimeMicControl"), @selector(decideChainNodesBeforeUpMic), (IMP)rt_decideChainNodesBeforeUpMic);
    TTRTSwizzle(NSClassFromString(@"WeddingMicControl"), @selector(decideChainNodesBeforeUpMic), (IMP)rt_decideChainNodesBeforeUpMic);
    TTRTSwizzle(NSClassFromString(@"RealTimeVoiceMessageControl"), @selector(clearAllMsgs), (IMP)rt_clearVoid);
    TTRTSwizzle(NSClassFromString(@"RealTimeVoiceMessageControl"), @selector(clearGamingAllMsgs), (IMP)rt_clearVoid);
    TTRTSwizzle(NSClassFromString(@"GameModeSingleScreen"), @selector(clearMsgs), (IMP)rt_clearVoid);
    TTRTSwizzle(NSClassFromString(@"RealTimeFunMicControl"), @selector(clearGameMessageScreen), (IMP)rt_clearVoid);
    TTRTSwizzle(NSClassFromString(@"CommonChannelService"), @selector(clearGameMessageWithTabidList:), (IMP)rt_clearMessageWithTabidList);
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(muteThisMicHandle:), (IMP)rt_muteThisMicHandle);
    TTRTSwizzle(NSClassFromString(@"CommonSuperVoiceRoomViewController"), @selector(muteThisMicHandle:), (IMP)rt_muteThisMicHandle);
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(_onButtonRequestDownMic:), (IMP)rt_onButtonRequestDownMic);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveMeUser"), @selector(enableMic:), (IMP)rt_enableMic);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveMeUser"), @selector(setMute:), (IMP)rt_setMute);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveMeUser"), @selector(setAmISilent:), (IMP)rt_setAmISilent);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveMeUser"), @selector(stopPublishStream), (IMP)rt_stopPublishStream);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveMeUser"), @selector(rePublishStreamWhenSilentChangeTo:), (IMP)rt_rePublishStreamWhenSilentChangeTo);
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(_onButtonMuteMyMicTapped:), (IMP)rt_onButtonMuteMyMicTappedU);
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(onButtonMuteMyMicTappedWithTipsView:), (IMP)rt_onButtonMuteMyMicTappedWithTipsView);
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(onButtonMuteMyMicWithPenaltyTime:), (IMP)rt_onButtonMuteMyMicWithPenaltyTime);
    TTRTSwizzle(NSClassFromString(@"CommonRealTimeVoiceRoomViewController"), @selector(pipUGCVoiceMicControlDidClickMicButtonWithCloseMic:), (IMP)rt_pipMicButtonCloseMic);
    TTRTSwizzle(NSClassFromString(@"RealTimeMicControl"), @selector(pipUGCVoiceMicControlDidClickMicButtonWithCloseMic:), (IMP)rt_pipMicButtonCloseMic);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVRoom"), @selector(setCaptureVolume:), (IMP)rt_setCaptureVolume);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveRoom"), @selector(setCaptureVolume:), (IMP)rt_setCaptureVolume);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVRoom"), @selector(configForMic:), (IMP)rt_configForMic);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveRoom"), @selector(configForMic:), (IMP)rt_configForMic);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveMeUser"), @selector(genStreamID), (IMP)rt_genStreamID);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveMeUser"), @selector(amISilent), (IMP)rt_amISilent);
    TTRTSwizzle(NSClassFromString(@"RealTimeAVLiveMeUser"), @selector(publishStream), (IMP)rt_publishStream);
    TTRTSwizzle(NSClassFromString(@"CommonChannelService"), @selector(reportRoomMicState:micID:channelType:channelId:micStatus:), (IMP)rt_reportRoomMicState);
    gRTOrigSnapshot = [[NSDictionary alloc] initWithDictionary:gRTOrigImps];
    TTLog(@"ROOMTEST hooks installed mute=%d clear=%d audio=%d skin=%d kick=%d upMic=%d island=%d dressId=%u", gRTAntiMute, gRTAntiClear, gRTAudio192, gRTSkin, gRTAntiKick, gRTUpMic, gRTIsland, gRTDressId);
}

static Class TTFindClassWithMethod(SEL sel, Class preferred) {
    if (preferred && class_getInstanceMethod(preferred, sel)) return preferred;
    static NSArray *candidates = nil;
    if (!candidates) {
        candidates = [@[
            @"TTSuperPlayer", @"TTSuperPlayerManager", @"TTWKWebView",
            @"ChannelMagicExpressionManager", @"MagicExpressionMicPlayerVM",
            @"RealTimeMicControl", @"RealTimeVoiceMessageHandler",
            @"ConnectionCore", @"TTIMMessage", @"DataClientAPI", @"JavascriptBridge",
            @"_TtC13UserComponent28PersonalDetailViewController", @"PersonalDetailViewController"
        ] retain];
    }
    for (NSString *nm in candidates) {
        Class c = NSClassFromString(nm);
        if (c && class_getInstanceMethod(c, sel)) return c;
    }
    return nil;
}

static BOOL TTMethodReturnsBool(Class cls, SEL sel) {
    Method m = (cls && sel) ? class_getInstanceMethod(cls, sel) : NULL;
    const char *te = m ? method_getTypeEncoding(m) : NULL;
    return (te && (te[0] == 'B' || te[0] == 'c'));
}

static Class TTFindLabClass(SEL sel) {
    for (NSString *cand in @[@"LabService", @"LabServiceClient", @"TTEnvironmentManager"]) {
        Class c = NSClassFromString(cand);
        if (c && TTMethodReturnsBool(c, sel)) return c;
    }
    return nil;
}

static id TTContactService(void) {
    @try {
        Class csc = NSClassFromString(@"CommonServiceCenter");
        Class csCls = NSClassFromString(@"ContactService");
        if (!csc || !csCls || ![csc respondsToSelector:@selector(defaultCenter)]) return nil;
        id center = ((id (*)(id, SEL))objc_msgSend)((id)csc, @selector(defaultCenter));
        if (center && [center respondsToSelector:@selector(getService:)])
            return ((id (*)(id, SEL, Class))objc_msgSend)(center, @selector(getService:), csCls);
    } @catch (id e) {}
    return nil;
}

static void TTEnsureAccountUidLoaded(void) {
    if (!gAccountUid) {
        NSDictionary *saved = [[NSUserDefaults standardUserDefaults] objectForKey:@"ttforge.accountUid"];
        gAccountUid = saved ? [[NSMutableDictionary alloc] initWithDictionary:saved] : [[NSMutableDictionary alloc] init];
    }
}

static void TTRecordAccountUid(NSString *acc, uint32_t uid) {
    if (![acc isKindOfClass:[NSString class]] || !acc.length || !uid) return;
    if ((gCustomId.length && [acc isEqualToString:gCustomId]) ||
        (gPrevCustomId.length && [acc isEqualToString:gPrevCustomId])) return;
    @try {
        TTEnsureAccountUidLoaded();
        NSNumber *old = gAccountUid[acc];
        if (old && old.unsignedIntValue == uid) return;
        gAccountUid[acc] = @(uid);
        [[NSUserDefaults standardUserDefaults] setObject:gAccountUid forKey:@"ttforge.accountUid"];
        TTLog(@"SPECIAL 记录账号uid %@ -> %u", acc, uid);
    } @catch (id e) {}
}

static uint32_t TTUidForAccount(NSString *acc) {
    if (![acc isKindOfClass:[NSString class]] || !acc.length) return 0;
    @try {
        TTEnsureAccountUidLoaded();
        id cs = TTContactService();
        if (cs) {
            id contact = [cs respondsToSelector:@selector(contactForAccount:)]
                ? ((id (*)(id, SEL, id))objc_msgSend)(cs, @selector(contactForAccount:), acc) : nil;
            if (!contact && [cs respondsToSelector:@selector(accountContactMap)]) {
                NSDictionary *map = TTGetObj(cs, @selector(accountContactMap));
                if ([map isKindOfClass:[NSDictionary class]]) contact = map[acc];
            }
            if (contact) {
                uint32_t cuid = TTGetU32(contact, @selector(uid));
                if (!cuid) cuid = TTGetU32(contact, @selector(userId));
                if (cuid > 0) {
                    TTRecordAccountUid(acc, cuid);
                    return cuid;
                }
            }
        }
        NSNumber *n = gAccountUid[acc];
        if (n && n.unsignedIntValue > 0) {
            uint32_t cached = n.unsignedIntValue;
            if (cached != (uint32_t)[acc longLongValue]) return cached;
        }
        if (gHits) {
            @synchronized (gHits) {
                for (NSNumber *uk in gHits) {
                    NSDictionary *rec = gHits[uk];
                    if ([rec[@"account"] isEqualToString:acc] && uk.unsignedIntValue > 0) {
                        TTRecordAccountUid(acc, uk.unsignedIntValue);
                        return uk.unsignedIntValue;
                    }
                }
            }
        }
        if (n && n.unsignedIntValue > 0) return n.unsignedIntValue;
        NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
        if ([digits isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:acc]]) {
            uint32_t cand = (uint32_t)[acc longLongValue];
            if (cand > 0 && cs && [cs respondsToSelector:@selector(contactForUid:)]) {
                id c2 = ((id (*)(id, SEL, uint32_t))objc_msgSend)(cs, @selector(contactForUid:), cand);
                if (c2) return cand;
            }
        }
    } @catch (id e) {}
    return 0;
}

static NSString *TTAccountForUid(uint32_t uid) {
    if (!uid) return nil;
    @try {
        id cs = TTContactService();
        if (cs && [cs respondsToSelector:@selector(contactForUid:)]) {
            id c = ((id (*)(id, SEL, uint32_t))objc_msgSend)(cs, @selector(contactForUid:), uid);
            NSString *a = c ? TTGetObj(c, @selector(account)) : nil;
            if ([a isKindOfClass:[NSString class]] && a.length) {
                TTRecordAccountUid(a, uid);
                return a;
            }
        }
        if (gHits) {
            @synchronized (gHits) {
                NSString *a = gHits[@(uid)][@"account"];
                if ([a isKindOfClass:[NSString class]] && a.length) return a;
            }
        }
        TTEnsureAccountUidLoaded();
        for (NSString *k in [gAccountUid allKeys]) {
            if ([gAccountUid[k] unsignedIntValue] == uid) return k;
        }
    } @catch (id e) {}
    return nil;
}

static BOOL TTIsDefaultInstance(id info) {
    if (!info) return NO;
    @try {
        Class cls = object_getClass(info);
        if ([cls respondsToSelector:@selector(defaultInstance)])
            return info == ((id (*)(id, SEL))objc_msgSend)((id)cls, @selector(defaultInstance));
    } @catch (id e) {}
    return NO;
}

static void TTSnapVal(id obj, NSString *field, id val) {
    if (!obj || !gGPBOrig || !val || TTIsDefaultInstance(obj)) return;
    @synchronized (gGPBOrig) {
        NSMutableDictionary *d = [gGPBOrig objectForKey:obj];
        if (!d) {
            if (gGPBOrig.count >= 64) [gGPBOrig removeAllObjects];
            d = [NSMutableDictionary dictionary];
            [gGPBOrig setObject:d forKey:obj];
        }
        if (!d[field]) d[field] = val;
    }
}

static void TTSnapU(id obj, NSString *field, SEL getter) {
    if (obj && getter && [obj respondsToSelector:getter]) TTSnapVal(obj, field, @(TTGetU64(obj, getter)));
}

static void TTSnapF(id obj, NSString *field, SEL getter) {
    if (obj && getter && [obj respondsToSelector:getter]) TTSnapVal(obj, field, @(TTGetFloat(obj, getter)));
}

static void TTSnapObj(id obj, NSString *field, SEL getter) {
    if (!obj || !getter || ![obj respondsToSelector:getter]) return;
    id v = objc_getAssociatedObject(obj, &kTTRealAccKey) ?: TTGetObj(obj, getter);
    if (v) TTSnapVal(obj, field, v);
}

static NSArray *TTRestoreForgedGPB(void) {
    if (!gGPBOrig) return @[];
    static NSDictionary *setters = nil;
    if (!setters) {
        setters = [@{
            @"level": @"setLevel:", @"value": @"setValue:", @"keepValue": @"setKeepValue:",
            @"visible": @"setVisible:", @"isYearMember": @"setIsYearMember:", @"spLevel": @"setSpLevel:",
            @"superPlayerValue": @"setSuperPlayerValue:", @"superPlayerLevel": @"setSuperPlayerLevel:",
            @"yearMemberExpireTimestamp": @"setYearMemberExpireTimestamp:", @"superPlayerType": @"setSuperPlayerType:",
            @"isSvip": @"setIsSvip:", @"richLevel": @"setRichLevel:", @"charmLevel": @"setCharmLevel:",
            @"vipLevel": @"setVipLevel:", @"fLevel": @"setFLevel:",
            @"spValue": @"setSpValue:", @"isSuperPlayer": @"setIsSuperPlayer:",
            @"account": @"setAccount:"
        } retain];
    }
    NSMutableArray *alive = [NSMutableArray array];
    NSUInteger restored = 0;
    @synchronized (gGPBOrig) {
        NSArray *keys = [[gGPBOrig keyEnumerator] allObjects];
        for (id obj in keys) {
            @try {
                if (!obj || TTIsDefaultInstance(obj)) continue;
                NSDictionary *d = [gGPBOrig objectForKey:obj];
                if (![d isKindOfClass:[NSDictionary class]]) continue;
                [alive addObject:obj];
                for (NSString *field in d) {
                    SEL setSel = NSSelectorFromString(setters[field]);
                    if (!setSel || ![obj respondsToSelector:setSel]) continue;
                    id rawVal = d[field];
                    if ([field isEqualToString:@"account"]) {
                        if ([rawVal isKindOfClass:[NSString class]]) TTSetObj(obj, setSel, rawVal);
                        continue;
                    }
                    if (![rawVal isKindOfClass:[NSNumber class]]) continue;
                    NSNumber *num = (NSNumber *)rawVal;
                    if ([field isEqualToString:@"fLevel"]) {
                        TTSetFloat(obj, setSel, num.floatValue);
                    } else if ([field isEqualToString:@"visible"] || [field isEqualToString:@"isYearMember"] ||
                               [field isEqualToString:@"isSvip"] || [field isEqualToString:@"isSuperPlayer"]) {
                        TTSetBool(obj, setSel, num.boolValue);
                    } else if ([field isEqualToString:@"value"] || [field isEqualToString:@"keepValue"] ||
                               [field isEqualToString:@"superPlayerValue"] || [field isEqualToString:@"yearMemberExpireTimestamp"] ||
                               [field isEqualToString:@"spValue"] || [field isEqualToString:@"spLevel"]) {
                        TTSetU64(obj, setSel, num.unsignedLongLongValue);
                    } else {
                        TTSetU32(obj, setSel, num.unsignedIntValue);
                    }
                }
                restored++;
            } @catch (id e) {}
        }
        [gGPBOrig removeAllObjects];
    }
    TTLog(@"FORGE 已还原 %lu 个 GPB 对象的原始字段", (unsigned long)restored);
    return alive;
}

static id TTEnsureSubObj(id owner, id sub, SEL setter, NSString *clsName) {
    if (TTIsDefaultInstance(sub)) sub = nil;
    if (!sub) {
        Class c = NSClassFromString(clsName);
        if (c && [owner respondsToSelector:setter]) {
            sub = [[c alloc] init];
            TTSetObj(owner, setter, sub);
            [sub release];
        }
    }
    return sub;
}

static id TTGetOrCreateSub(id owner, SEL getter, SEL setter, NSString *clsName) {
    return TTEnsureSubObj(owner, TTGetObj(owner, getter), setter, clsName);
}

static void TTRegisterForgedPlayer(id player) {
    if (!player || !gForgedPlayers) return;
    @synchronized (gForgedPlayers) {
        [gForgedPlayers addObject:player];
    }
}

static BOOL TTIsForgedPlayer(id player) {
    if (!player || !gForgedPlayers) return NO;
    @synchronized (gForgedPlayers) {
        return [gForgedPlayers containsObject:player];
    }
}

static id TTSuperPlayerDefaultMgr(void) {
    Class mc = NSClassFromString(@"TTSuperPlayerManager");
    return (mc && [mc respondsToSelector:@selector(defaultManager)])
        ? ((id (*)(id, SEL))objc_msgSend)((id)mc, @selector(defaultManager)) : nil;
}

static id (*origCM_mePlayer)(id, SEL);

static id TTCMePlayer(void) {
    @try {
        id mgr = TTSuperPlayerDefaultMgr();
        if (!mgr) return nil;
        id p = origCM_mePlayer ? origCM_mePlayer(mgr, @selector(mePlayer)) : TTGetObj(mgr, @selector(mePlayer));
        if (p) TTRegisterForgedPlayer(p);
        return p;
    } @catch (id e) { return nil; }
}

static uint32_t TTPlayerUidOf(id player) {
    if (!player) return 0;
    uint32_t u = TTGetU32(player, @selector(uid));
    if (!u) u = TTGetU32(player, @selector(userId));
    if (!u) u = TTGetU32(player, @selector(userID));
    if (!u) u = TTGetU32(player, @selector(playerUid));
    if (!u) u = TTGetU32(player, @selector(superPlayerUid));
    if (!u) u = TTGetU32(player, @selector(id_p));
    return u;
}

static uint32_t TTStrictSelfUid(void) {
    if (gSelfUid > 0) return gSelfUid;
    NSMutableDictionary *ttd = [[NSThread currentThread] threadDictionary];
    if ([ttd objectForKey:@"ttforge.inStrictUid"]) return gSelfUid;
    [ttd setObject:@YES forKey:@"ttforge.inStrictUid"];
    @try {
        id me = TTCMePlayer();
        if (me) {
            uint32_t u = TTGetU32(me, @selector(userId));
            if (!u) u = TTGetU32(me, @selector(uid));
            if (u > 0 && gSelfUid != u) {
                gSelfUid = u;
                [[NSUserDefaults standardUserDefaults] setObject:@(u) forKey:@"ttforge.selfUid"];
            }
        }
    } @catch (id e) {}
    [ttd removeObjectForKey:@"ttforge.inStrictUid"];
    return gSelfUid;
}

static void TTCaptureMyRealAccount(NSString *acc, uint32_t u) {
    if (![acc isKindOfClass:[NSString class]] || !acc.length) return;
    if (gCustomId.length && [acc isEqualToString:gCustomId]) return;
    if (gPrevCustomId.length && [acc isEqualToString:gPrevCustomId]) return;
    if (![gMyRealAccount isEqualToString:acc]) {
        [gMyRealAccount release];
        gMyRealAccount = [acc copy];
        [[NSUserDefaults standardUserDefaults] setObject:gMyRealAccount forKey:@"ttforge.myRealAccount"];
        TTLog(@"ACCOUNT 本人真实ID已记录: %@ (uid=%u)", gMyRealAccount, u);
    }
}

static BOOL TTAccountMatchesMyReal(NSString *acc) {
    if (![acc isKindOfClass:[NSString class]] || !acc.length || !gMyRealAccount.length) return NO;
    if ([acc isEqualToString:gMyRealAccount]) return YES;
    NSString *s1 = ([acc hasPrefix:@"tt"] || [acc hasPrefix:@"TT"]) ? [acc substringFromIndex:2] : acc;
    NSString *s2 = ([gMyRealAccount hasPrefix:@"tt"] || [gMyRealAccount hasPrefix:@"TT"]) ? [gMyRealAccount substringFromIndex:2] : gMyRealAccount;
    return s1.length > 0 && [s1 isEqualToString:s2];
}

static void TTCountHit(uint32_t u, NSString *nick, NSString *acc) {
    if (u == 0) return;
    uint32_t myUid = TTStrictSelfUid();
    BOOL isFakeAcc = (acc.length && ((gCustomId.length && [acc isEqualToString:gCustomId]) ||
                                     (gPrevCustomId.length && [acc isEqualToString:gPrevCustomId])));
    @synchronized (gHits) {
        NSMutableDictionary *rec = gHits[@(u)];
        if (!rec) {
            rec = [@{ @"count": @0, @"nickname": nick ?: @"", @"account": (!isFakeAcc && acc) ? acc : @"" } mutableCopy];
            gHits[@(u)] = rec;
            [rec release];
        } else {
            if (nick.length) rec[@"nickname"] = nick;
            if (acc.length && !isFakeAcc) rec[@"account"] = acc;
        }
        rec[@"count"] = @([rec[@"count"] intValue] + 1);
    }
    if (!isFakeAcc && acc.length && (!myUid || u != myUid)) {
        TTRecordAccountUid(acc, u);
    }
    if (myUid > 0 && u == myUid) {
        if (nick.length && ![gMyNickname isEqualToString:nick]) {
            [gMyNickname release];
            gMyNickname = [nick copy];
            [[NSUserDefaults standardUserDefaults] setObject:gMyNickname forKey:@"ttforge.myNickname"];
            TTLog(@"NICK 本人主页昵称已同步: %@ (uid=%u)", gMyNickname, u);
        }
        if (!isFakeAcc) TTCaptureMyRealAccount(acc, u);
    }
}

static int32_t (*origA_vipLevel)(id, SEL);
static id (*origA_nobleInfo)(id, SEL);
static id (*origA_spInfo)(id, SEL);
static uint32_t (*origA_uid)(id, SEL);
static id (*origA_nickname)(id, SEL);
static id (*origA_account)(id, SEL);

static uint32_t TTAUid(id obj) {
    if (!obj || !origA_uid) return 0;
    @try { return origA_uid(obj, @selector(uid)); } @catch (id e) { return 0; }
}

static void TTACount(id obj) {
    if (!obj || !origA_uid) return;
    @try {
        uint32_t u = TTAUid(obj);
        if (!u) return;
        NSNumber *counted = objc_getAssociatedObject(obj, &kTTCountedUidKey);
        if (counted && counted.unsignedIntValue == u) return;
        NSString *n = origA_nickname ? origA_nickname(obj, @selector(nickname)) : nil;
        NSString *a = objc_getAssociatedObject(obj, &kTTRealAccKey) ?: (origA_account ? origA_account(obj, @selector(account)) : nil);
        if ([a isKindOfClass:[NSString class]] && a.length && !objc_getAssociatedObject(obj, &kTTRealAccKey)) {
            if (!gCustomId.length || ![a isEqualToString:gCustomId])
                objc_setAssociatedObject(obj, &kTTRealAccKey, a, OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
        if (n.length && a.length) {
            objc_setAssociatedObject(obj, &kTTCountedUidKey, @(u), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        TTCountHit(u, n, a);
    } @catch (id e) {}
}

static BOOL TTAIsSelfRaw(id obj) {
    if (!obj) return NO;
    uint32_t u = TTAUid(obj);
    if (u > 0) return TTIsSelfUidRaw(u);
    if (gSelfUid > 0) return NO;
    NSString *a = objc_getAssociatedObject(obj, &kTTRealAccKey) ?: (origA_account ? origA_account(obj, @selector(account)) : nil);
    return TTAccountMatchesMyReal(a);
}

static BOOL TTAIsSelf(id obj) {
    return TTMemberForgeOn() && TTAIsSelfRaw(obj);
}

static int32_t TTA_vipLevel(id self, SEL _cmd) {
    int32_t v = origA_vipLevel(self, _cmd);
    TTACount(self);
    return (TTAIsSelf(self) && TTMemberForgeOn()) ? (int32_t)gMemberLevel : v;
}

static void TTForgeNoblesGPB(id info) {
    if (!info || !TTNobleForgeOn() || TTIsDefaultInstance(info)) return;
    objc_setAssociatedObject(info, &kTTNobleUidKey, @(TTStrictSelfUid() ?: 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    TTSnapU(info, @"level", @selector(level));
    TTSnapF(info, @"fLevel", @selector(fLevel));
    TTSnapU(info, @"value", @selector(value));
    TTSnapU(info, @"keepValue", @selector(keepValue));
    TTSnapU(info, @"visible", @selector(visible));
    uint32_t rawLv = (uint32_t)(gNobleLevel <= 1 ? 1 : MIN(gNobleLevel - 1, 9));
    TTSetU32(info, @selector(setLevel:), rawLv);
    TTSetFloat(info, @selector(setFLevel:), TTNobleBandFLevel(gNobleLevel));
    TTSetU64(info, @selector(setValue:), TTNobleValueCap(gNobleLevel));
    TTSetU64(info, @selector(setKeepValue:), TTNobleKeepCap(gNobleLevel));
    TTSetBool(info, @selector(setVisible:), YES);
}

static id TTA_nobleInfo(id self, SEL _cmd) {
    id info = origA_nobleInfo(self, _cmd);
    TTACount(self);
    uint32_t u = TTAUid(self);
    if (TTAIsSelfRaw(self)) {
        if (TTNobleForgeOn()) {
            @try {
                info = TTEnsureSubObj(self, info, @selector(setNobleInfo:), @"UserUGCInfo_Nobles");
                TTForgeNoblesGPB(info);
            } @catch (id e) {}
        } else if (info && !TTIsDefaultInstance(info) && u > 0) {
            objc_setAssociatedObject(info, &kTTNobleUidKey, @(u), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else if (info && !TTIsDefaultInstance(info) && u > 0) {
        objc_setAssociatedObject(info, &kTTNobleUidKey, @(u), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return info;
}

static void TTForgeSPLevel(id lvl) {
    if (!lvl || !TTMemberForgeOn()) return;
    TTSnapU(lvl, @"superPlayerValue", @selector(superPlayerValue));
    TTSnapU(lvl, @"superPlayerLevel", @selector(superPlayerLevel));
    TTSnapU(lvl, @"yearMemberExpireTimestamp", @selector(yearMemberExpireTimestamp));
    TTSnapU(lvl, @"superPlayerType", @selector(superPlayerType));
    TTSnapU(lvl, @"isSvip", @selector(isSvip));
    TTSetU64(lvl, @selector(setSuperPlayerValue:), TTMemberGrowthCap(gMemberLevel));
    TTSetU32(lvl, @selector(setSuperPlayerLevel:), (uint32_t)MIN(gMemberLevel, 8));
    TTSetU64(lvl, @selector(setYearMemberExpireTimestamp:), 4102444800ULL);
    TTSetU32(lvl, @selector(setSuperPlayerType:), 4);
    TTSetBool(lvl, @selector(setIsSvip:), YES);
}

static void TTForgeSpInfoGPB(id info) {
    if (!info || !TTMemberForgeOn()) return;
    TTSnapU(info, @"isYearMember", @selector(isYearMember));
    TTSnapU(info, @"spLevel", @selector(spLevel));
    TTSetBool(info, @selector(setIsYearMember:), YES);
    TTSetU32(info, @selector(setSpLevel:), (uint32_t)MIN(gMemberLevel, 8));
    TTForgeSPLevel(TTGetOrCreateSub(info, @selector(superPlayerLevel), @selector(setSuperPlayerLevel:), @"SuperPlayerLevel"));
}

static id TTA_spInfo(id self, SEL _cmd) {
    id info = origA_spInfo(self, _cmd);
    TTACount(self);
    if (TTAIsSelf(self)) {
        @try {
            info = TTEnsureSubObj(self, info, @selector(setSpInfo:), @"UserUGCInfo_SpInfo");
            TTForgeSpInfoGPB(info);
        } @catch (id e) {}
    }
    return info;
}

static id TTA_nickname(id self, SEL _cmd) {
    id v = origA_nickname(self, _cmd);
    TTACount(self);
    return v;
}

static id TTA_account(id self, SEL _cmd) {
    id v = origA_account(self, _cmd);
    TTACount(self);
    return v;
}

static uint32_t (*origB_uid)(id, SEL);
static id (*origB_nickName)(id, SEL);
static id (*origB_account)(id, SEL);
static id (*origB_displayAccount)(id, SEL);
static id (*origB_ttAvatarAccount)(id, SEL);
static int32_t (*origB_vipLevel)(id, SEL);
static BOOL (*origB_isYearMemberhip)(id, SEL);
static id (*origB_nobilityInfo)(id, SEL);

static uint32_t TTBUid(id obj) {
    if (!obj || !origB_uid) return 0;
    @try { return origB_uid(obj, @selector(uid)); } @catch (id e) { return 0; }
}

static void TTBCount(id obj) {
    if (!obj || !origB_uid) return;
    @try {
        uint32_t u = TTBUid(obj);
        if (!u) return;
        NSNumber *counted = objc_getAssociatedObject(obj, &kTTCountedUidKey);
        if (counted && counted.unsignedIntValue == u) return;
        NSString *n = origB_nickName ? origB_nickName(obj, @selector(nickName)) : nil;
        NSString *a = objc_getAssociatedObject(obj, &kTTRealAccKey) ?: (origB_account ? origB_account(obj, @selector(account)) : nil);
        if ([a isKindOfClass:[NSString class]] && a.length && !objc_getAssociatedObject(obj, &kTTRealAccKey)) {
            if (!gCustomId.length || ![a isEqualToString:gCustomId])
                objc_setAssociatedObject(obj, &kTTRealAccKey, a, OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
        if (n.length && a.length) {
            objc_setAssociatedObject(obj, &kTTCountedUidKey, @(u), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        TTCountHit(u, n, a);
    } @catch (id e) {}
}

static BOOL TTBIsSelfRaw(id obj) {
    if (!obj) return NO;
    uint32_t u = TTBUid(obj);
    if (u > 0) return TTIsSelfUidRaw(u);
    if (gSelfUid > 0) return NO;
    NSString *a = objc_getAssociatedObject(obj, &kTTRealAccKey) ?: (origB_account ? origB_account(obj, @selector(account)) : nil);
    return TTAccountMatchesMyReal(a);
}

static BOOL TTBIsSelf(id obj) {
    return TTMemberForgeOn() && TTBIsSelfRaw(obj);
}

static id TTB_account(id self, SEL _cmd) {
    id v = origB_account(self, _cmd);
    TTBCount(self);
    return v;
}

static id TTB_displayAccount(id self, SEL _cmd) {
    id v = origB_displayAccount ? origB_displayAccount(self, _cmd) : (origB_account ? origB_account(self, @selector(account)) : nil);
    TTBCount(self);
    return (gCustomId.length && TTBIsSelfRaw(self)) ? gCustomId : v;
}

static id TTB_ttAvatarAccount(id self, SEL _cmd) {
    id v = origB_ttAvatarAccount ? origB_ttAvatarAccount(self, _cmd) : nil;
    if ([v isKindOfClass:[NSString class]] && gCustomId.length && [(NSString *)v isEqualToString:gCustomId]) {
        NSString *realAcc = objc_getAssociatedObject(self, &kTTRealAccKey) ?: gMyRealAccount;
        if (realAcc.length) return realAcc;
    }
    return v;
}

static int32_t TTB_vipLevel(id self, SEL _cmd) {
    int32_t v = origB_vipLevel(self, _cmd);
    TTBCount(self);
    return (TTBIsSelf(self) && TTMemberForgeOn()) ? (int32_t)gMemberLevel : v;
}

static BOOL TTB_isYearMemberhip(id self, SEL _cmd) {
    BOOL v = origB_isYearMemberhip(self, _cmd);
    TTBCount(self);
    return TTBIsSelf(self) ? YES : v;
}

static void TTForgeNobilityInfo(id info) {
    if (!info || !TTNobleForgeOn() || TTIsDefaultInstance(info)) return;
    objc_setAssociatedObject(info, &kTTNobleUidKey, @(TTStrictSelfUid() ?: 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    TTSnapU(info, @"level", @selector(level));
    TTSnapF(info, @"fLevel", @selector(fLevel));
    TTSnapU(info, @"value", @selector(value));
    TTSnapU(info, @"keepValue", @selector(keepValue));
    TTSnapU(info, @"visible", @selector(visible));
    uint32_t rawLv = (uint32_t)(gNobleLevel <= 1 ? 1 : MIN(gNobleLevel - 1, 9));
    TTSetU32(info, @selector(setLevel:), rawLv);
    TTSetFloat(info, @selector(setFLevel:), TTNobleBandFLevel(gNobleLevel));
    TTSetU64(info, @selector(setValue:), TTNobleValueCap(gNobleLevel));
    TTSetU64(info, @selector(setKeepValue:), TTNobleKeepCap(gNobleLevel));
    TTSetBool(info, @selector(setVisible:), YES);
}

static id TTB_nobilityInfo(id self, SEL _cmd) {
    id info = origB_nobilityInfo(self, _cmd);
    TTBCount(self);
    uint32_t u = TTBUid(self);
    if (TTBIsSelfRaw(self)) {
        if (TTNobleForgeOn()) {
            @try {
                NSString *clsName = NSClassFromString(@"TTNobilityInfo") ? @"TTNobilityInfo" : @"NobilityInfo";
                info = TTEnsureSubObj(self, info, @selector(setNobilityInfo:), clsName);
                TTForgeNobilityInfo(info);
            } @catch (id e) {}
        } else if (info && !TTIsDefaultInstance(info) && u > 0) {
            objc_setAssociatedObject(info, &kTTNobleUidKey, @(u), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else if (info && !TTIsDefaultInstance(info) && u > 0) {
        objc_setAssociatedObject(info, &kTTNobleUidKey, @(u), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return info;
}

static BOOL (*origC_isSvip)(id, SEL);
static uint64_t (*origC_getLevel)(id, SEL);
static BOOL (*origC_isYearMembership)(id, SEL);
static BOOL (*origC_isSuperPlayerActive)(id, SEL);
static uint64_t (*origC_superPlayerType)(id, SEL);
static id (*origC_getSuperPlayerLevel)(id, SEL);
static id (*origC_nobilityInfo)(id, SEL);
static uint32_t (*origC_weekRemain)(id, SEL);
static id (*origC_getLevelIcon)(id, SEL, BOOL);
static uint32_t (*origC_weekTimes)(id, SEL);
static BOOL (*origC_isTodayStealth)(id, SEL);
static uint64_t (*origC_sneakilySwitch)(id, SEL);
static id (*origC_getAccount)(id, SEL);
static id (*origC_account)(id, SEL);
static id (*origC_getSuperLevelPngIcon)(id, SEL, id);
static uint64_t (*origC_getVipStatus)(id, SEL);
static uint64_t (*origC_onlineSwitch)(id, SEL);
static void (*origC_setOnlineSwitch)(id, SEL, uint64_t, id);
static id (*origC_information)(id, SEL);
static id (*origC_getInformation)(id, SEL);
static id (*origC_currentDress)(id, SEL);
static void (*origC_setCurrentDress)(id, SEL, id);
static id (*origC_getSpecialConcernSuit)(id, SEL);
static void (*origC_dressConfigDidUpdate)(id, SEL, id);

static BOOL (*origCL_isSvip)(id, SEL);
static BOOL (*origCL_isSuperPlayer)(id, SEL);
static int32_t (*origCL_superPlayerType)(id, SEL);
static int64_t (*origCL_spLevel)(id, SEL);

static BOOL (*origCM_isMySuperPlayerActive)(id, SEL);
static BOOL (*origCM_hasPrivilege)(id, SEL, int64_t);
static BOOL (*origCM_isWhiteUid)(id, SEL, uint32_t);
static id (*origCM_playerForUid)(id, SEL, uint32_t);

static BOOL TTCIsMe(id player) {
    if (!player) return NO;
    if (TTIsForgedPlayer(player)) return YES;
    id me = nil;
    if (origCM_mePlayer) {
        @try {
            id mgr = TTSuperPlayerDefaultMgr();
            if (mgr) me = origCM_mePlayer(mgr, @selector(mePlayer));
        } @catch (id e) {}
    } else {
        me = TTCMePlayer();
    }
    return me && player == me;
}

static BOOL TTPlayerIsSelfRaw(id player) {
    if (!player) return NO;
    if (TTIsForgedPlayer(player)) return YES;
    uint32_t u = TTPlayerUidOf(player);
    if (u > 0 && gSelfUid > 0) return u == gSelfUid;
    if (TTCIsMe(player)) return YES;
    if (u > 0) return TTIsSelfUidRaw(u);
    if (gSelfUid > 0) return NO;
    NSString *a = objc_getAssociatedObject(player, &kTTRealAccKey);
    return TTAccountMatchesMyReal(a);
}

static BOOL TTPlayerIsSelf(id player) {
    return (player && TTMemberForgeOn()) ? TTPlayerIsSelfRaw(player) : NO;
}

static void TTSyncMyLevelObject(id lvl) {
    if (!lvl) return;
    objc_setAssociatedObject(lvl, &kTTMyLevelObjKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (TTMemberForgeOn()) {
        TTSnapU(lvl, @"spLevel", @selector(spLevel));
        TTSnapU(lvl, @"spValue", @selector(spValue));
        TTSnapU(lvl, @"superPlayerType", @selector(superPlayerType));
        TTSnapU(lvl, @"isSvip", @selector(isSvip));
        TTSnapU(lvl, @"isYearMember", @selector(isYearMember));
        TTSnapU(lvl, @"isSuperPlayer", @selector(isSuperPlayer));
        TTSetU64(lvl, @selector(setSpLevel:), (uint64_t)MIN(gMemberLevel, 8));
        TTSetU64(lvl, @selector(setSpValue:), TTMemberGrowthCap(gMemberLevel));
        TTSetU32(lvl, @selector(setSuperPlayerType:), 4);
        TTSetBool(lvl, @selector(setIsSvip:), YES);
        TTSetBool(lvl, @selector(setIsYearMember:), YES);
        TTSetBool(lvl, @selector(setIsSuperPlayer:), YES);
    }
}

static void TTSyncMyInformationObject(id info) {
    if (!info || !TTMemberForgeOn()) return;
    @try {
        uint64_t lv = (uint64_t)MIN(MAX(gMemberLevel, 1), 8);
        TTSnapU(info, @"level", @selector(level));
        TTSnapU(info, @"growthValue", @selector(growthValue));
        TTSnapU(info, @"endTimestamp", @selector(endTimestamp));
        TTSnapU(info, @"superPlayerType", @selector(superPlayerType));
        TTSnapU(info, @"isSvip", @selector(isSvip));
        TTSetU64(info, @selector(setLevel:), lv);
        TTSetU64(info, @selector(setGrowthValue:), TTMemberGrowthCap(gMemberLevel));
        TTSetU64(info, @selector(setEndTimestamp:), 4102444800ULL);
        TTSetU64(info, @selector(setSuperPlayerType:), 4);
        TTSetBool(info, @selector(setIsSvip:), YES);
        id mgr = TTSuperPlayerDefaultMgr();
        if (mgr && [mgr respondsToSelector:@selector(privilegesForLevel:)]) {
            id privs = ((id (*)(id, SEL, uint64_t))objc_msgSend)(mgr, @selector(privilegesForLevel:), lv);
            if ([privs isKindOfClass:[NSArray class]] && [(NSArray *)privs count] > 0)
                TTSetObj(info, @selector(setPrivileges:), privs);
        }
    } @catch (id e) {}
}

static id TTC_information(id self, SEL _cmd) {
    id info = origC_information ? origC_information(self, _cmd) : nil;
    if (TTPlayerIsSelfRaw(self) && TTMemberForgeOn()) {
        if (!info) {
            Class ic = NSClassFromString(@"TTSuperPlayerInformation");
            if (ic) {
                info = [[[ic alloc] init] autorelease];
                TTSetObj(self, @selector(setInformation:), info);
            }
        }
        if (info) TTSyncMyInformationObject(info);
    }
    return info;
}

static id TTC_getInformation(id self, SEL _cmd) {
    id info = origC_getInformation ? origC_getInformation(self, _cmd) : nil;
    if (TTPlayerIsSelfRaw(self) && TTMemberForgeOn()) {
        if (!info) info = [self respondsToSelector:@selector(information)] ? TTGetObj(self, @selector(information)) : nil;
        if (info) TTSyncMyInformationObject(info);
    }
    return info;
}

static id TTC_getSuperPlayerLevel(id self, SEL _cmd) {
    id lvl = origC_getSuperPlayerLevel ? origC_getSuperPlayerLevel(self, _cmd) : nil;
    if (lvl && TTPlayerIsSelfRaw(self)) TTSyncMyLevelObject(lvl);
    return lvl;
}

static id TTC_nobilityInfo(id self, SEL _cmd) {
    id info = origC_nobilityInfo ? origC_nobilityInfo(self, _cmd) : nil;
    uint32_t u = TTPlayerUidOf(self);
    if (TTPlayerIsSelfRaw(self)) {
        if (TTNobleForgeOn()) {
            @try {
                if (!info || TTIsDefaultInstance(info)) {
                    Class c = NSClassFromString(@"NobilityInfo");
                    if (c) {
                        info = [[[c alloc] init] autorelease];
                        TTSetObj(self, @selector(setNobilityInfo:), info);
                    }
                }
                TTForgeNobilityInfo(info);
            } @catch (id e) {}
        } else if (info && !TTIsDefaultInstance(info)) {
            objc_setAssociatedObject(info, &kTTNobleUidKey, @(u ?: (TTStrictSelfUid() ?: 1)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else if (info && !TTIsDefaultInstance(info) && u > 0) {
        objc_setAssociatedObject(info, &kTTNobleUidKey, @(u), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return info;
}

static id TTC_getAccount(id self, SEL _cmd) {
    id v = origC_getAccount ? origC_getAccount(self, _cmd) : nil;
    if (TTPlayerIsSelfRaw(self)) {
        if ([v isKindOfClass:[NSString class]] && [v length] && (!gCustomId.length || ![v isEqualToString:gCustomId])) {
            objc_setAssociatedObject(self, &kTTRealAccKey, v, OBJC_ASSOCIATION_COPY_NONATOMIC);
            TTCaptureMyRealAccount(v, TTStrictSelfUid());
        } else if ([v isKindOfClass:[NSString class]] && gCustomId.length && [v isEqualToString:gCustomId]) {
            NSString *realAcc = objc_getAssociatedObject(self, &kTTRealAccKey) ?: gMyRealAccount;
            if (realAcc.length) return realAcc;
        }
    }
    return v;
}

static id TTC_account(id self, SEL _cmd) {
    id v = origC_account ? origC_account(self, _cmd) : nil;
    if (TTPlayerIsSelfRaw(self)) {
        if ([v isKindOfClass:[NSString class]] && [v length] && (!gCustomId.length || ![v isEqualToString:gCustomId])) {
            objc_setAssociatedObject(self, &kTTRealAccKey, v, OBJC_ASSOCIATION_COPY_NONATOMIC);
            TTCaptureMyRealAccount(v, TTStrictSelfUid());
        } else if ([v isKindOfClass:[NSString class]] && gCustomId.length && [v isEqualToString:gCustomId]) {
            NSString *realAcc = objc_getAssociatedObject(self, &kTTRealAccKey) ?: gMyRealAccount;
            if (realAcc.length) return realAcc;
        }
    }
    return v;
}

static id TTC_getSuperLevelPngIcon(id self, SEL _cmd, id lvlObj) {
    if (lvlObj && [objc_getAssociatedObject(lvlObj, &kTTMyLevelObjKey) boolValue]) TTSyncMyLevelObject(lvlObj);
    return origC_getSuperLevelPngIcon ? origC_getSuperLevelPngIcon(self, _cmd, lvlObj) : nil;
}

static BOOL TTCIsMyLevel(id lvl) {
    if (!lvl || !TTMemberForgeOn()) return NO;
    if ([objc_getAssociatedObject(lvl, &kTTMyLevelObjKey) boolValue]) return YES;
    if (!origC_getSuperPlayerLevel) return NO;
    NSMutableDictionary *ttd = [[NSThread currentThread] threadDictionary];
    if ([ttd objectForKey:@"ttforge.inIsMyLevel"]) return NO;
    [ttd setObject:@YES forKey:@"ttforge.inIsMyLevel"];
    BOOL match = NO;
    @try {
        id me = TTCMePlayer();
        if (me && origC_getSuperPlayerLevel(me, @selector(getSuperPlayerLevel)) == lvl) match = YES;
        if (!match && gForgedPlayers) {
            @synchronized (gForgedPlayers) {
                for (id p in gForgedPlayers) {
                    if (origC_getSuperPlayerLevel(p, @selector(getSuperPlayerLevel)) == lvl) { match = YES; break; }
                }
            }
        }
        if (match) {
            objc_setAssociatedObject(lvl, &kTTMyLevelObjKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } @catch (id e) {}
    [ttd removeObjectForKey:@"ttforge.inIsMyLevel"];
    return match;
}

static id TTC_getLevelIcon(id self, SEL _cmd, BOOL needNoOpen) {
    if (TTMemberForgeOn() && TTPlayerIsSelfRaw(self)) {
        @try {
            id lvlObj = origC_getSuperPlayerLevel ? origC_getSuperPlayerLevel(self, @selector(getSuperPlayerLevel)) : nil;
            if (lvlObj) TTSyncMyLevelObject(lvlObj);
            id icon = origC_getLevelIcon ? origC_getLevelIcon(self, _cmd, NO) : nil;
            if (icon) return icon;
            Class pc = NSClassFromString(@"TTSuperPlayer");
            if (lvlObj && pc && [pc respondsToSelector:@selector(getSuperLevelPngIcon:)]) {
                icon = origC_getSuperLevelPngIcon
                    ? origC_getSuperLevelPngIcon((id)pc, @selector(getSuperLevelPngIcon:), lvlObj)
                    : ((id (*)(id, SEL, id))objc_msgSend)((id)pc, @selector(getSuperLevelPngIcon:), lvlObj);
                if (icon) return icon;
            }
        } @catch (id e) {}
    }
    return origC_getLevelIcon(self, _cmd, needNoOpen);
}

static uint64_t TTC_getLevel(id self, SEL _cmd) {
    uint64_t v = origC_getLevel ? origC_getLevel(self, _cmd) : 0;
    return TTPlayerIsSelf(self) ? (uint64_t)gMemberLevel : v;
}

static BOOL TTC_isSvip(id self, SEL _cmd) {
    BOOL v = origC_isSvip(self, _cmd);
    return TTPlayerIsSelf(self) ? YES : v;
}

static BOOL TTC_isYearMembership(id self, SEL _cmd) {
    BOOL v = origC_isYearMembership(self, _cmd);
    return TTPlayerIsSelf(self) ? YES : v;
}

static BOOL TTC_isSuperPlayerActive(id self, SEL _cmd) {
    BOOL v = origC_isSuperPlayerActive(self, _cmd);
    return TTPlayerIsSelf(self) ? YES : v;
}

static uint64_t TTC_getVipStatus(id self, SEL _cmd) {
    uint64_t v = origC_getVipStatus ? origC_getVipStatus(self, _cmd) : 0;
    if (TTPlayerIsSelf(self) && v != 1) {
        static int sLogN = 0;
        if (sLogN++ < 5) TTLog(@"FORGE getVipStatus 原值 %llu → 1（特权详情开通墙判定点取证）", (unsigned long long)v);
        return 1;
    }
    return v;
}

static uint64_t TTC_superPlayerType(id self, SEL _cmd) {
    uint64_t v = origC_superPlayerType(self, _cmd);
    return TTPlayerIsSelf(self) ? 4 : v;
}

static uint32_t TTC_weekRemain(id self, SEL _cmd) {
    uint32_t v = origC_weekRemain(self, _cmd);
    return TTPlayerIsSelf(self) ? 999 : v;
}

static uint32_t TTC_weekTimes(id self, SEL _cmd) {
    uint32_t v = origC_weekTimes(self, _cmd);
    return TTPlayerIsSelf(self) ? 999 : v;
}

static BOOL TTC_isTodayStealth(id self, SEL _cmd) {
    BOOL v = origC_isTodayStealth(self, _cmd);
    return TTPlayerIsSelf(self) ? (gStealthSwitch == 2) : v;
}

static uint64_t TTC_onlineSwitch(id self, SEL _cmd) {
    uint64_t v = origC_onlineSwitch(self, _cmd);
    return TTPlayerIsSelf(self) ? gStealthSwitch : v;
}

static void TTPatchStealthProfile(id prof, BOOL includeTimes) {
    if (!prof) return;
    if (includeTimes) {
        TTSetU32(prof, @selector(setWeekRemainStealthTimes:), 999);
        TTSetU32(prof, @selector(setWeekStealthTimes:), 999);
    }
    TTSetU64(prof, @selector(setOnlineSwitch:), gStealthSwitch);
    TTSetBool(prof, @selector(setIsTodayStealth:), (gStealthSwitch == 2));
}

static void TTApplyStealthLocally(void) {
    @try {
        id me = TTCMePlayer();
        NSMutableArray *players = [NSMutableArray array];
        if (me) [players addObject:me];
        for (id p in [gForgedPlayers allObjects]) if (p != me) [players addObject:p];
        for (id p in players) TTPatchStealthProfile(TTGetObj(p, @selector(mySvipProfile)), NO);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ttc://superPlayer/superPlayerStatusChanged" object:me];
        TTLog(@"STEALTH 本地隐身状态 → %@（onlineSwitch=%llu，已同步 %lu 个 self profile）",
              gStealthSwitch == 2 ? @"隐身" : @"在线", (unsigned long long)gStealthSwitch, (unsigned long)players.count);
    } @catch (id e) { TTLog(@"STEALTH 应用异常 %@", e); }
}

static void TTC_setOnlineSwitch(id self, SEL _cmd, uint64_t sw, id completion) {
    if (TTPlayerIsSelf(self)) {
        gStealthSwitch = (sw == 1) ? 1 : 2;
        [[NSUserDefaults standardUserDefaults] setObject:@(gStealthSwitch) forKey:@"ttforge.stealthSwitch"];
        TTApplyStealthLocally();
        TTLog(@"STEALTH App 内切换 → %@（已本地生效，不写服务端）", gStealthSwitch == 2 ? @"隐身" : @"在线");
        if (completion) {
            @try { ((void (^)(id))completion)(nil); } @catch (id e) {}
        }
        return;
    }
    if (origC_setOnlineSwitch) origC_setOnlineSwitch(self, _cmd, sw, completion);
}

static uint64_t TTC_sneakilySwitch(id self, SEL _cmd) {
    uint64_t v = origC_sneakilySwitch(self, _cmd);
    return (TTPlayerIsSelf(self) && gSneakAll) ? 1 : v;
}

static BOOL TTCL_isSvip(id self, SEL _cmd) {
    BOOL v = origCL_isSvip(self, _cmd);
    return TTCIsMyLevel(self) ? YES : v;
}

static BOOL TTCL_isSuperPlayer(id self, SEL _cmd) {
    BOOL v = origCL_isSuperPlayer(self, _cmd);
    return TTCIsMyLevel(self) ? YES : v;
}

static int32_t TTCL_superPlayerType(id self, SEL _cmd) {
    int32_t v = origCL_superPlayerType(self, _cmd);
    return TTCIsMyLevel(self) ? 4 : v;
}

static int64_t TTCL_spLevel(id self, SEL _cmd) {
    int64_t v = origCL_spLevel(self, _cmd);
    return TTCIsMyLevel(self) ? (int64_t)gMemberLevel : v;
}

static BOOL TTCM_isMySuperPlayerActive(id self, SEL _cmd) {
    BOOL v = origCM_isMySuperPlayerActive(self, _cmd);
    return TTMemberForgeOn() ? YES : v;
}

static BOOL TTCM_hasPrivilege(id self, SEL _cmd, int64_t p) {
    BOOL v = origCM_hasPrivilege(self, _cmd, p);
    return TTMemberForgeOn() ? YES : v;
}

static BOOL TTCM_isWhiteUid(id self, SEL _cmd, uint32_t uid) {
    BOOL v = origCM_isWhiteUid(self, _cmd, uid);
    return TTIsSelfUid(uid) ? YES : v;
}

static void TTTagNobilityInfoOnObject(id obj, uint32_t u);

static id TTCM_playerForUid(id self, SEL _cmd, uint32_t uid) {
    id p = origCM_playerForUid(self, _cmd, uid);
    if (p && uid > 0) {
        if (TTIsSelfUidRaw(uid)) TTRegisterForgedPlayer(p);
        NSNumber *tagged = objc_getAssociatedObject(p, &kTTTaggedNobleUidKey);
        if (!tagged || tagged.unsignedIntValue != uid) {
            objc_setAssociatedObject(p, &kTTTaggedNobleUidKey, @(uid), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            TTTagNobilityInfoOnObject(p, uid);
        }
    }
    return p;
}

static id TTCM_mePlayer(id self, SEL _cmd) {
    id p = origCM_mePlayer(self, _cmd);
    if (p) {
        TTRegisterForgedPlayer(p);
        uint32_t u = TTPlayerUidOf(p) ?: gSelfUid;
        if (u > 0) {
            if (gSelfUid != u) {
                gSelfUid = u;
                [[NSUserDefaults standardUserDefaults] setObject:@(u) forKey:@"ttforge.selfUid"];
            }
            NSNumber *tagged = objc_getAssociatedObject(p, &kTTTaggedNobleUidKey);
            if (!tagged || tagged.unsignedIntValue != u) {
                objc_setAssociatedObject(p, &kTTTaggedNobleUidKey, @(u), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                TTTagNobilityInfoOnObject(p, u);
            }
        }
    }
    return p;
}

static void TTSaveSpecialKeys(void) {
    @synchronized (gSpecialKeys) {
        [[NSUserDefaults standardUserDefaults] setObject:[gSpecialKeys allObjects] forKey:@"ttforge.specialConcernKeys"];
    }
}

static NSString *TTSCKeyOf(id acc) {
    if (!acc) return nil;
    if ([acc isKindOfClass:[NSString class]]) return [(NSString *)acc length] ? (NSString *)acc : nil;
    if ([acc isKindOfClass:[NSNumber class]]) return [(NSNumber *)acc stringValue];
    id a = objc_getAssociatedObject(acc, &kTTRealAccKey) ?: TTGetObj(acc, @selector(account));
    if ([a isKindOfClass:[NSString class]] && [(NSString *)a length]) return a;
    uint32_t uid = TTGetU32(acc, @selector(uid));
    if (!uid) uid = TTGetU32(acc, @selector(userId));
    return uid ? [NSString stringWithFormat:@"%u", uid] : nil;
}

static BOOL (*origON_isSPActive)(id, SEL);
static BOOL TTON_isSPActive(id self, SEL _cmd) {
    if (TTMemberForgeOn()) return YES;
    return origON_isSPActive ? origON_isSPActive(self, _cmd) : NO;
}

static BOOL (*origON_scDontOverLimit)(id, SEL);
static BOOL TTON_scDontOverLimit(id self, SEL _cmd) {
    if (TTMemberForgeOn()) return YES;
    return origON_scDontOverLimit ? origON_scDontOverLimit(self, _cmd) : NO;
}

static BOOL (*origSC_isSC)(id, SEL, uint32_t);
static BOOL TTSC_isSC(id self, SEL _cmd, uint32_t uid) {
    BOOL localHit = NO;
    if (TTMemberForgeOn() && gSpecialKeys) {
        if ([gSpecialKeys containsObject:[NSString stringWithFormat:@"%u", uid]]) {
            localHit = YES;
        } else {
            @synchronized (gSpecialKeys) {
                for (NSString *acc in gSpecialKeys) {
                    if (TTUidForAccount(acc) == uid) { localHit = YES; break; }
                }
            }
        }
    }
    BOOL orig = origSC_isSC ? origSC_isSC(self, _cmd, uid) : NO;
    static int scLog = 0;
    if (scLog < 8) {
        scLog++;
        id dict = TTGetObj(self, @selector(specialConcernDict));
        NSUInteger dc = [dict respondsToSelector:@selector(count)] ? [(NSDictionary *)dict count] : 9999;
        TTLog(@"SPECIAL isSpecialConcern uid=%u 本地映射命中=%d 原函数=%d self字典条数=%lu", uid, localHit, orig, (unsigned long)dc);
    }
    return localHit ? YES : orig;
}

static BOOL (*origSC_isSCAcc)(id, SEL, id);
static BOOL TTSC_isSCAcc(id self, SEL _cmd, id acc) {
    NSString *key = TTSCKeyOf(acc);
    BOOL localHit = NO;
    if (TTMemberForgeOn() && key && gSpecialKeys) {
        if ([gSpecialKeys containsObject:key]) {
            localHit = YES;
        } else {
            uint32_t u = TTUidForAccount(key);
            if (!u && [key intValue] > 0) u = (uint32_t)[key intValue];
            if (u > 0) {
                NSString *us = [NSString stringWithFormat:@"%u", u];
                if ([gSpecialKeys containsObject:us]) {
                    localHit = YES;
                } else {
                    @synchronized (gSpecialKeys) {
                        for (NSString *k in gSpecialKeys) {
                            if (TTUidForAccount(k) == u) { localHit = YES; break; }
                        }
                    }
                }
            }
        }
    }
    BOOL orig = origSC_isSCAcc ? origSC_isSCAcc(self, _cmd, acc) : NO;
    static int scAccLog = 0;
    if (scAccLog < 8) {
        scAccLog++;
        TTLog(@"SPECIAL isSpecialConcernAccount key=%@ 本地命中=%d 原函数=%d", key, localHit, orig);
    }
    return localHit ? YES : orig;
}

static BOOL TTSCIsSelfPlayer(id self) {
    return TTPlayerIsSelf(self) || (gSelfUid && self && TTGetU32(self, @selector(userId)) == gSelfUid);
}

static void (*origSC_add)(id, SEL, id, id);
static void TTSC_add(id self, SEL _cmd, id acc, id cb) {
    NSString *key = TTSCKeyOf(acc);
    if (TTMemberForgeOn() && key) {
        @synchronized (gSpecialKeys) { [gSpecialKeys addObject:key]; }
        TTSaveSpecialKeys();
        TTLog(@"SPECIAL 特别关心添加 key=%@（走服务端，W 层兜底伪造成功）", key);
    }
    if (origSC_add) origSC_add(self, _cmd, acc, cb);
}

static void (*origSC_remove)(id, SEL, id, id);
static void TTSC_remove(id self, SEL _cmd, id acc, id cb) {
    NSString *key = TTSCKeyOf(acc);
    if (TTMemberForgeOn() && key) {
        @synchronized (gSpecialKeys) { [gSpecialKeys removeObject:key]; }
        TTSaveSpecialKeys();
        TTLog(@"SPECIAL 特别关心移除 key=%@（走服务端，W 层兜底伪造成功）", key);
    }
    if (origSC_remove) origSC_remove(self, _cmd, acc, cb);
}

static void (*origSC_addOrDel)(id, SEL, id, BOOL);
static void TTSC_addOrDel(id self, SEL _cmd, id acc, BOOL isAdd) {
    NSString *key = TTSCKeyOf(acc);
    if (TTMemberForgeOn() && key && TTSCIsSelfPlayer(self)) {
        @synchronized (gSpecialKeys) {
            if (isAdd) [gSpecialKeys addObject:key]; else [gSpecialKeys removeObject:key];
        }
        TTSaveSpecialKeys();
        TTLog(@"SPECIAL addOrDelSpecial key=%@ isAdd=%@（已同步本地集合）", key, isAdd ? @"YES" : @"NO");
    }
    if (origSC_addOrDel) origSC_addOrDel(self, _cmd, acc, isAdd);
}

static void (*origD_report)(id, SEL, id);
static void TTD_report(id self, SEL _cmd, id req) {
    if (!gBlockReport) origD_report(self, _cmd, req);
}

static void (*origR_syncInfo)(id, SEL, id, BOOL);
static void (*origR_updateProfile)(id, SEL, id);
static id (*origR_initWithPb)(id, SEL, id);
static void (*origR_updateMyGrow)(id, SEL, id);
static id (*origR_growWithPB)(id, SEL, id);

static void TTR_syncInfo(id self, SEL _cmd, id pb, BOOL needCheck) {
    uint32_t puid = 0;
    BOOL isSelf = NO;
    @try {
        if (pb) puid = TTPlayerUidOf(pb);
        if (!puid) puid = TTPlayerUidOf(self);
        NSString *origAcc = pb ? (objc_getAssociatedObject(pb, &kTTRealAccKey) ?: TTGetObj(pb, @selector(account))) : nil;
        if (!puid && [origAcc isKindOfClass:[NSString class]] && origAcc.length) {
            if (gSelfUid == 0 && TTAccountMatchesMyReal(origAcc)) puid = TTStrictSelfUid();
            else puid = TTUidForAccount(origAcc);
        }
        isSelf = TTIsSelfUidRaw(puid) || TTPlayerIsSelfRaw(self);
        if (isSelf) {
            TTRegisterForgedPlayer(self);
            if (!puid) puid = TTStrictSelfUid();
            if ([origAcc isKindOfClass:[NSString class]] && origAcc.length) {
                if (!gCustomId.length || ![origAcc isEqualToString:gCustomId]) {
                    objc_setAssociatedObject(pb, &kTTRealAccKey, origAcc, OBJC_ASSOCIATION_COPY_NONATOMIC);
                    objc_setAssociatedObject(self, &kTTRealAccKey, origAcc, OBJC_ASSOCIATION_COPY_NONATOMIC);
                    TTCaptureMyRealAccount(origAcc, puid);
                }
            }
            if (TTMemberForgeOn()) {
                TTForgeSPLevel(pb);
                TTSetU64(pb, @selector(setExpireTimestamp:), 4102444800ULL);
            }
        }
        if (puid > 0 && pb) TTTagNobilityInfoOnObject(pb, puid);
    } @catch (id e) {}
    NSMutableDictionary *ttd = [[NSThread currentThread] threadDictionary];
    if (puid > 0) [ttd setObject:@(puid) forKey:@"ttforge.parsingUid"];
    if (isSelf) [ttd setObject:@YES forKey:@"ttforge.nobleOK"];
    origR_syncInfo(self, _cmd, pb, needCheck);
    if (puid > 0) [ttd removeObjectForKey:@"ttforge.parsingUid"];
    if (isSelf) [ttd removeObjectForKey:@"ttforge.nobleOK"];
    @try {
        if (!puid) puid = TTPlayerUidOf(self);
        if (!isSelf && (TTIsSelfUidRaw(puid) || TTPlayerIsSelfRaw(self))) {
            isSelf = YES;
            TTRegisterForgedPlayer(self);
        }
        if (puid > 0) TTTagNobilityInfoOnObject(self, puid);
        if (isSelf) {
            if (origC_getSuperPlayerLevel) {
                id lvl = origC_getSuperPlayerLevel(self, @selector(getSuperPlayerLevel));
                if (lvl) TTSyncMyLevelObject(lvl);
            }
        }
    } @catch (id e) {}
}

static void TTR_updateProfile(id self, SEL _cmd, id profile) {
    @try {
        if (profile && TTPlayerIsSelf(self)) {
            TTPatchStealthProfile(profile, YES);
            if (gSneakAll && TTGetU64(profile, @selector(sneakilyReadSwitch)) == 0)
                TTSetU64(profile, @selector(setSneakilyReadSwitch:), 1);
        }
    } @catch (id e) {}
    origR_updateProfile(self, _cmd, profile);
}

static void TTForgeGrowGPB(id grow, uint32_t uidForGate) {
    if (!grow) return;
    if (gRichLevelVal > 0) {
        TTSnapU(grow, @"richLevel", @selector(richLevel));
        TTSetU32(grow, @selector(setRichLevel:), (uint32_t)gRichLevelVal);
    }
    if (gCharmLevelVal > 0) {
        TTSnapU(grow, @"charmLevel", @selector(charmLevel));
        TTSetU32(grow, @selector(setCharmLevel:), (uint32_t)gCharmLevelVal);
    }
    if (uidForGate) TTSetU32(grow, @selector(setUid:), uidForGate);
}

static void TTForgeUGC(id pb) {
    TTACount(pb);
    if (TTMemberForgeOn()) {
        TTSnapU(pb, @"vipLevel", @selector(vipLevel));
        TTSetU32(pb, @selector(setVipLevel:), (uint32_t)MIN(gMemberLevel, 8));
        TTForgeSpInfoGPB(TTGetOrCreateSub(pb, @selector(spInfo), @selector(setSpInfo:), @"UserUGCInfo_SpInfo"));
    }
    if (TTNobleForgeOn()) {
        TTForgeNoblesGPB(TTGetOrCreateSub(pb, @selector(nobleInfo), @selector(setNobleInfo:), @"UserUGCInfo_Nobles"));
    }
    if (gRichLevelVal > 0 || gCharmLevelVal > 0) {
        TTForgeGrowGPB(TTGetOrCreateSub(pb, @selector(growInfo), @selector(setGrowInfo:), @"GrowInfo"), gSelfUid);
    }
}

static BOOL TTIvarTypeMatchesAny(const char *type, const char *name, NSArray *tokens) {
    if (!type || type[0] != '@') return NO;
    NSString *ts = (type[1] == '"') ? [NSString stringWithUTF8String:type] : nil;
    NSString *ns = name ? [NSString stringWithUTF8String:name] : nil;
    for (NSString *tk in tokens) {
        if (ts && [ts rangeOfString:tk options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
        if (!ts && ns && [ns rangeOfString:tk options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    return NO;
}

static void TTTagNobilityInfoOnObject(id obj, uint32_t u) {
    if (!obj || !u) return;
    @try {
        BOOL isSelf = TTIsSelfUidRaw(u);
        NSString *ocn = NSStringFromClass([obj class]);
        if ([ocn isEqualToString:@"UserUGCInfo"]) {
            id ni = origA_nobleInfo ? origA_nobleInfo(obj, @selector(nobleInfo)) : nil;
            if (ni && !TTIsDefaultInstance(ni)) {
                objc_setAssociatedObject(ni, &kTTNobleUidKey, @(u), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        } else if ([ocn isEqualToString:@"TTUGCUserInfo"]) {
            id ni = origB_nobilityInfo ? origB_nobilityInfo(obj, @selector(nobilityInfo)) : nil;
            if (ni && !TTIsDefaultInstance(ni)) {
                objc_setAssociatedObject(ni, &kTTNobleUidKey, @(u), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                if (isSelf && TTNobleForgeOn() && [NSStringFromClass([ni class]) rangeOfString:@"NobilityInfo"].location != NSNotFound)
                    TTForgeNobilityInfo(ni);
            }
        } else if (![ocn isEqualToString:@"TTSuperPlayer"]) {
            for (NSString *selName in @[@"nobilityInfo", @"nobleInfo"]) {
                SEL sel = NSSelectorFromString(selName);
                if ([obj respondsToSelector:sel]) {
                    id ni = ((id (*)(id, SEL))objc_msgSend)(obj, sel);
                    if (ni && !TTIsDefaultInstance(ni)) {
                        objc_setAssociatedObject(ni, &kTTNobleUidKey, @(u), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        if (isSelf && TTNobleForgeOn() && [NSStringFromClass([ni class]) rangeOfString:@"NobilityInfo"].location != NSNotFound)
                            TTForgeNobilityInfo(ni);
                    }
                }
            }
        }
        Class cls = [obj class];
        for (int depth = 0; cls && cls != [NSObject class] && depth < 4; depth++, cls = class_getSuperclass(cls)) {
            unsigned int count = 0;
            Ivar *ivars = class_copyIvarList(cls, &count);
            if (!ivars) continue;
            for (unsigned int i = 0; i < count; i++) {
                const char *type = ivar_getTypeEncoding(ivars[i]);
                const char *name = ivar_getName(ivars[i]);
                if (!TTIvarTypeMatchesAny(type, name, @[@"NobilityInfo", @"UserUGCInfo_Nobles", @"NobilityPrivilege", @"nobility", @"noble"])) continue;
                id val = object_getIvar(obj, ivars[i]);
                if (!val || TTIsDefaultInstance(val)) continue;
                NSString *vcn = NSStringFromClass([val class]);
                if ([vcn rangeOfString:@"NobilityInfo"].location != NSNotFound ||
                    [vcn rangeOfString:@"UserUGCInfo_Nobles"].location != NSNotFound) {
                    objc_setAssociatedObject(val, &kTTNobleUidKey, @(u), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    if (isSelf && TTNobleForgeOn() && [vcn rangeOfString:@"NobilityInfo"].location != NSNotFound)
                        TTForgeNobilityInfo(val);
                } else if ([vcn rangeOfString:@"NobilityPrivilege"].location != NSNotFound) {
                    objc_setAssociatedObject(val, &kTTSelfPrivKey, @(isSelf), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            }
            free(ivars);
        }
    } @catch (id e) {}
}

static BOOL TTObjectOwnsNobilityInfo(id holder, id targetInfo, int depth) {
    if (!holder || !targetInfo || depth > 2) return NO;
    @try {
        Class cls = [holder class];
        for (int d = 0; cls && cls != [NSObject class] && d < 4; d++, cls = class_getSuperclass(cls)) {
            unsigned int count = 0;
            Ivar *ivars = class_copyIvarList(cls, &count);
            if (!ivars) continue;
            for (unsigned int i = 0; i < count; i++) {
                const char *type = ivar_getTypeEncoding(ivars[i]);
                const char *name = ivar_getName(ivars[i]);
                if (!TTIvarTypeMatchesAny(type, name, @[@"NobilityInfo", @"UserUGCInfo_Nobles", @"UGCUserInfo", @"SuperPlayer", @"nobility", @"noble"])) continue;
                id val = object_getIvar(holder, ivars[i]);
                if (!val) continue;
                if (val == targetInfo) { free(ivars); return YES; }
                NSString *vcn = NSStringFromClass([val class]);
                if (depth < 2 && ([vcn rangeOfString:@"UGCUserInfo"].location != NSNotFound ||
                                  [vcn rangeOfString:@"SuperPlayer"].location != NSNotFound)) {
                    if (TTObjectOwnsNobilityInfo(val, targetInfo, depth + 1)) { free(ivars); return YES; }
                }
            }
            free(ivars);
        }
    } @catch (id e) {}
    return NO;
}

static BOOL TTIsMePlayerNobilityInfo(id info) {
    if (!info || TTIsDefaultInstance(info)) return NO;
    NSNumber *ownerUid = objc_getAssociatedObject(info, &kTTNobleUidKey);
    if (ownerUid != nil) return TTIsSelfUidRaw(ownerUid.unsignedIntValue);
    id me = TTCMePlayer();
    if (me && TTObjectOwnsNobilityInfo(me, info, 0)) return YES;
    if (gForgedPlayers) {
        @synchronized (gForgedPlayers) {
            for (id p in gForgedPlayers) {
                if (p != me && TTObjectOwnsNobilityInfo(p, info, 0)) return YES;
            }
        }
    }
    return NO;
}

static id TTR_initWithPb(id self, SEL _cmd, id pb) {
    BOOL selfPb = NO;
    uint32_t u = 0;
    NSString *realAcc = nil;
    @try {
        if (pb) {
            u = origA_uid ? origA_uid(pb, @selector(uid)) : TTPlayerUidOf(pb);
            NSString *n = origA_nickname ? origA_nickname(pb, @selector(nickname)) : TTGetObj(pb, @selector(nickname));
            realAcc = objc_getAssociatedObject(pb, &kTTRealAccKey) ?: (origA_account ? origA_account(pb, @selector(account)) : TTGetObj(pb, @selector(account)));
            if ([realAcc isKindOfClass:[NSString class]] && realAcc.length && (!gCustomId.length || ![realAcc isEqualToString:gCustomId])) {
                objc_setAssociatedObject(pb, &kTTRealAccKey, realAcc, OBJC_ASSOCIATION_COPY_NONATOMIC);
            }
            TTCountHit(u, n, realAcc);
            TTRecordAccountUid(realAcc, u);
            if (TTIsSelfUidRaw(u) || (u == 0 && gSelfUid == 0 && TTAccountMatchesMyReal(realAcc))) {
                TTForgeUGC(pb);
                selfPb = YES;
            } else if (u > 0) {
                TTTagNobilityInfoOnObject(pb, u);
            }
        }
    } @catch (id e) {}
    NSMutableDictionary *ttd = [[NSThread currentThread] threadDictionary];
    if (u > 0) [ttd setObject:@(u) forKey:@"ttforge.parsingUid"];
    if (selfPb) [ttd setObject:@YES forKey:@"ttforge.nobleOK"];
    id r = origR_initWithPb(self, _cmd, pb);
    if (u > 0) [ttd removeObjectForKey:@"ttforge.parsingUid"];
    if (selfPb) [ttd removeObjectForKey:@"ttforge.nobleOK"];
    if (r) {
        @try {
            if ([realAcc isKindOfClass:[NSString class]] && realAcc.length && (!gCustomId.length || ![realAcc isEqualToString:gCustomId])) {
                objc_setAssociatedObject(r, &kTTRealAccKey, realAcc, OBJC_ASSOCIATION_COPY_NONATOMIC);
            }
            if (u > 0) TTTagNobilityInfoOnObject(r, u);
        } @catch (id e) {}
    }
    return r;
}

static void TTR_updateMyGrow(id self, SEL _cmd, id pb) {
    @try { TTForgeGrowGPB(pb, 0); } @catch (id e) {}
    origR_updateMyGrow(self, _cmd, pb);
}

static id TTR_growWithPB(id self, SEL _cmd, id pb) {
    @try {
        uint32_t u = TTGetU32(pb, @selector(uid));
        if (TTIsSelfUidRaw(u)) TTForgeGrowGPB(pb, 0);
    } @catch (id e) {}
    return origR_growWithPB(self, _cmd, pb);
}

static BOOL (*origH_isMe)(id, SEL);

static BOOL TTLayoutContextHasVisibleView(id ctx) {
    if (!ctx) return NO;
    @try {
        UIView *idv = TTGetObj(ctx, @selector(IdView));
        if ([idv isKindOfClass:[UIView class]] && idv.window != nil && !idv.hidden) return YES;
        UIView *nbv = TTGetObj(ctx, @selector(nobilityTipView));
        if ([nbv isKindOfClass:[UIView class]] && nbv.window != nil) return YES;
    } @catch (id e) {}
    return NO;
}

static BOOL TTIsOtherUserProfileVisible(void) {
    @try {
        id otherCtx = TTGetLastOtherLayoutCtx();
        if (otherCtx) {
            BOOL isMe = origH_isMe ? origH_isMe(otherCtx, @selector(isMe)) : TTGetBool(otherCtx, @selector(isMe));
            if (!isMe && TTLayoutContextHasVisibleView(otherCtx)) return YES;
        }
        if (gActiveProfileIsOther && (CFAbsoluteTimeGetCurrent() - gLastOtherProfileTs) < 0.6) return YES;
    } @catch (id e) {}
    gActiveProfileIsOther = NO;
    return NO;
}

static BOOL (*origN_exclusive)(id, SEL);
static BOOL (*origN_onlineInVisible)(id, SEL);
static id (*origN_createPriv)(id, SEL, float, id, id);
static BOOL (*origName_chatColor)(id, SEL);
static BOOL (*origName_micColor)(id, SEL);
static BOOL (*origName_godMicColor)(id, SEL);
static BOOL (*origName_friendRed)(id, SEL);
static BOOL (*origName_friendV2)(id, SEL);
static UIColor *(*origN_getGradientRed)(id, SEL, CGSize);
static UIColor *(*origN_getGradientRedV2)(id, SEL, CGSize);
static id (*origName_attr)(id, SEL, id, id);
static id (*origN_useNobility)(id, SEL, id);

static BOOL TTNobleHasPrivilege(id priv) {
    @try {
        if (!priv) return NO;
        float f = TTGetFloat(priv, @selector(fLevel));
        if (f > 0.0f) return YES;
        NSString *img = TTGetObj(priv, @selector(smallExclusiveImageName));
        return [img isKindOfClass:[NSString class]] && img.length > 0;
    } @catch (id e) { return NO; }
}

static BOOL TTN_isSelfPrivilege(id priv) {
    if (!priv) return NO;
    NSNumber *tag = objc_getAssociatedObject(priv, &kTTSelfPrivKey);
    if (tag) return [tag boolValue];
    return [[[NSThread currentThread] threadDictionary] objectForKey:@"ttforge.nobleOK"] != nil;
}

static BOOL TTN_exclusive(id self, SEL _cmd) {
    BOOL v = origN_exclusive(self, _cmd);
    return (TTNobleForgeOn() && TTN_isSelfPrivilege(self) && TTNobleHasPrivilege(self)) ? YES : v;
}

static BOOL TTN_onlineInVisible(id self, SEL _cmd) {
    BOOL v = origN_onlineInVisible(self, _cmd);
    return (TTNobleForgeOn() && TTN_isSelfPrivilege(self) && TTNobleHasPrivilege(self)) ? YES : v;
}

static BOOL TTN_chatColor(id self, SEL _cmd) {
    BOOL isSelf = TTN_isSelfPrivilege(self);
    gLastPrivWasSelf = isSelf;
    if (isSelf) return (gNameStyle != 0);
    return origName_chatColor ? origName_chatColor(self, _cmd) : NO;
}

static BOOL TTN_micColor(id self, SEL _cmd) {
    BOOL isSelf = TTN_isSelfPrivilege(self);
    gLastPrivWasSelf = isSelf;
    if (isSelf) return (gNameStyle != 0);
    return origName_micColor ? origName_micColor(self, _cmd) : NO;
}

static BOOL TTN_godMicColor(id self, SEL _cmd) {
    BOOL isSelf = TTN_isSelfPrivilege(self);
    gLastPrivWasSelf = isSelf;
    if (isSelf) return (gNameStyle != 0);
    return origName_godMicColor ? origName_godMicColor(self, _cmd) : NO;
}

static BOOL TTN_friendRed(id self, SEL _cmd) {
    BOOL isSelf = TTN_isSelfPrivilege(self);
    gLastPrivWasSelf = isSelf;
    if (isSelf) return (gNameStyle != 0);
    return origName_friendRed ? origName_friendRed(self, _cmd) : NO;
}

static BOOL TTN_friendV2(id self, SEL _cmd) {
    BOOL isSelf = TTN_isSelfPrivilege(self);
    gLastPrivWasSelf = isSelf;
    if (isSelf) {
        if (gNameStyle == 2) return YES;
        if (gNameStyle == 1 || gNameStyle == 3) return NO;
    }
    return origName_friendV2 ? origName_friendV2(self, _cmd) : NO;
}

static UIColor *TTNativeGradientColor(Class pc, SEL sel, CGSize sz) {
    if (!pc || ![(id)pc respondsToSelector:sel]) return nil;
    if (sel == @selector(getGradientFriendRedName:) && origN_getGradientRed)
        return origN_getGradientRed((id)pc, sel, sz);
    if (sel == @selector(getGradientFriendRedNameV2:) && origN_getGradientRedV2)
        return origN_getGradientRedV2((id)pc, sel, sz);
    return ((id (*)(id, SEL, CGSize))objc_msgSend)((id)pc, sel, sz);
}

static UIColor *TTBuildPatternColor(Class pc, NSString *hex1, NSString *hex2, CGSize sz) {
    if (!pc || ![(id)pc respondsToSelector:@selector(getColor:)]) return nil;
    UIColor *c1 = ((id (*)(id, SEL, id))objc_msgSend)((id)pc, @selector(getColor:), hex1);
    UIColor *c2 = ((id (*)(id, SEL, id))objc_msgSend)((id)pc, @selector(getColor:), hex2);
    if (!c1 || !c2 || ![(id)pc respondsToSelector:@selector(getImageWith:AndSize:)]) return c1;
    if (sz.width < 1 || sz.height < 1) sz = CGSizeMake(120, 18);
    UIImage *img = ((id (*)(id, SEL, id, CGSize))objc_msgSend)((id)pc, @selector(getImageWith:AndSize:), @[c1, c2], sz);
    return img ? [UIColor colorWithPatternImage:img] : c1;
}

static UIColor *TTNativeSVIPPatternColor(Class pc, CGSize sz) {
    return TTBuildPatternColor(pc, @"#FF5811", @"#FFA439", sz);
}

static UIColor *TTColorFromHex(NSString *hex) {
    if (!hex) return nil;
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    if ([hex hasPrefix:@"#"]) [scanner setScanLocation:1];
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16) / 255.0
                           green:((rgbValue & 0xFF00) >> 8) / 255.0
                            blue:(rgbValue & 0xFF) / 255.0 alpha:1.0];
}

static UIColor *TTNameGradientForIndex(NSInteger idx, CGSize sz) {
    if (idx <= 0) return nil;
    static NSArray *pal = nil;
    if (!pal) pal = [@[
        @[@"#FF5811", @"#FFA439"], @[@"#8BA2FF", @"#B9CFFF"],
        @[@"#84FAB0", @"#8FD3F4"], @[@"#61EDFF", @"#BFF8FF"],
        @[@"#C470FF", @"#FFD478"], @[@"#FE5AFF", @"#FFF981"],
        @[@"#FF213E", @"#FFFF73"], @[@"#333399", @"#FF00CC"],
        @[@"#FA709A", @"#FEE140"]
    ] retain];
    NSArray *pair = pal[(idx - 1) % (NSInteger)pal.count];
    UIColor *pat = TTBuildPatternColor(NSClassFromString(@"TTNobilityPrivilege"), pair[0], pair[1], sz);
    return pat ?: TTColorFromHex(pair[0]);
}

static UIColor *TTResolveNameColor(NSInteger style, NSInteger idx, CGSize sz) {
    if (style == 0) return nil;
    if (idx > 0) return TTNameGradientForIndex(idx, sz);
    Class pc = NSClassFromString(@"TTNobilityPrivilege");
    if (style == 1) return TTNativeGradientColor(pc, @selector(getGradientFriendRedName:), sz);
    if (style == 2) return TTNativeGradientColor(pc, @selector(getGradientFriendRedNameV2:), sz);
    if (style == 3) return TTNativeSVIPPatternColor(pc, sz);
    return nil;
}

static UIColor *TTN_getGradientRed(id self, SEL _cmd, CGSize sz) {
    if (gNameStyle != 0 && gLastPrivWasSelf) {
        if (gNameColorIndex > 0) {
            UIColor *c = TTNameGradientForIndex(gNameColorIndex, sz);
            if (c) return c;
        } else if (gNameStyle == 3) {
            UIColor *c = TTNativeSVIPPatternColor((Class)self, sz);
            if (c) return c;
        }
    }
    return origN_getGradientRed ? origN_getGradientRed(self, _cmd, sz) : nil;
}

static UIColor *TTN_getGradientRedV2(id self, SEL _cmd, CGSize sz) {
    if (gNameStyle != 0 && gLastPrivWasSelf && gNameColorIndex > 0) {
        UIColor *c = TTNameGradientForIndex(gNameColorIndex, sz);
        if (c) return c;
    }
    return origN_getGradientRedV2 ? origN_getGradientRedV2(self, _cmd, sz) : nil;
}

static id TTN_attrName(id self, SEL _cmd, id player, id textColor) {
    uint32_t puid = TTPlayerUidOf(player);
    BOOL isSelf = TTPlayerIsSelfRaw(player) || (gSelfUid && puid == gSelfUid);
    NSMutableDictionary *ttd = [[NSThread currentThread] threadDictionary];
    if (puid > 0) [ttd setObject:@(puid) forKey:@"ttforge.parsingUid"];
    if (isSelf) [ttd setObject:@YES forKey:@"ttforge.nobleOK"];
    id attr = origName_attr ? origName_attr(self, _cmd, player, textColor) : nil;
    if (puid > 0) [ttd removeObjectForKey:@"ttforge.parsingUid"];
    if (isSelf) [ttd removeObjectForKey:@"ttforge.nobleOK"];
    @try {
        BOOL want = gNameStyle != 0 && isSelf &&
            [attr isKindOfClass:[NSAttributedString class]] && [(NSAttributedString *)attr length] > 0;
        UIColor *col = nil;
        if (want) {
            CGSize sz = [(NSAttributedString *)attr size];
            if (sz.width < 1 || sz.height < 1) sz = CGSizeMake(120, 18);
            col = TTResolveNameColor(gNameStyle, gNameColorIndex, sz);
        }
        static int sAttrDiag = 0;
        if (sAttrDiag < 5) {
            sAttrDiag++;
            TTLog(@"NAME attrName 玩家类=%@ uid=%u selfUid=%u isSelf=%@ style=%d 已染色=%@",
                  player ? NSStringFromClass([player class]) : @"nil", puid, gSelfUid,
                  isSelf ? @"Y" : @"N", (int)gNameStyle, col ? @"Y" : @"N");
        }
        if (want && col) {
            NSMutableAttributedString *m = [[attr mutableCopy] autorelease];
            [m addAttribute:NSForegroundColorAttributeName value:col range:NSMakeRange(0, m.length)];
            return m;
        }
    } @catch (id e) {}
    return attr;
}

static id TTN_useNobility(id self, SEL _cmd, id info) {
    BOOL isSelfInfo = NO;
    id callInfo = info;
    @try {
        if (!info) {
            NSMutableDictionary *ttd = [[NSThread currentThread] threadDictionary];
            BOOL selfParse = [ttd objectForKey:@"ttforge.nobleOK"] != nil;
            NSNumber *parsingUid = [ttd objectForKey:@"ttforge.parsingUid"];
            if (selfParse) isSelfInfo = YES;
            else if (parsingUid != nil) isSelfInfo = TTIsSelfUidRaw(parsingUid.unsignedIntValue);
            else isSelfInfo = NO;
        } else if (info && [info respondsToSelector:@selector(fLevel)]) {
            NSMutableDictionary *ttd = [[NSThread currentThread] threadDictionary];
            BOOL selfParse = [ttd objectForKey:@"ttforge.nobleOK"] != nil;
            NSNumber *parsingUid = [ttd objectForKey:@"ttforge.parsingUid"];
            NSNumber *ownerUid = objc_getAssociatedObject(info, &kTTNobleUidKey);
            if (!ownerUid && parsingUid && !TTIsDefaultInstance(info)) {
                ownerUid = parsingUid;
                objc_setAssociatedObject(info, &kTTNobleUidKey, ownerUid, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            if (selfParse) {
                isSelfInfo = YES;
            } else if (ownerUid != nil) {
                isSelfInfo = TTIsSelfUidRaw(ownerUid.unsignedIntValue);
            } else if (parsingUid != nil) {
                isSelfInfo = TTIsSelfUidRaw(parsingUid.unsignedIntValue);
            } else if (TTIsMePlayerNobilityInfo(info)) {
                uint32_t myUid = TTStrictSelfUid() ?: 1;
                ownerUid = @(myUid);
                objc_setAssociatedObject(info, &kTTNobleUidKey, ownerUid, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                isSelfInfo = YES;
            } else {
                isSelfInfo = NO;
            }
            static int lc = 0;
            if (isSelfInfo && TTNobleForgeOn()) {
                float targetF = TTNobleBandFLevel(gNobleLevel);
                if (TTIsDefaultInstance(info)) {
                    Class ic = [info class];
                    id copyInfo = [[[ic alloc] init] autorelease];
                    if (copyInfo) {
                        objc_setAssociatedObject(copyInfo, &kTTNobleUidKey, @(TTStrictSelfUid() ?: 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        callInfo = copyInfo;
                    }
                }
                if (!TTIsDefaultInstance(callInfo)) {
                    TTSnapF(callInfo, @"fLevel", @selector(fLevel));
                    TTSnapU(callInfo, @"level", @selector(level));
                    TTSetFloat(callInfo, @selector(setFLevel:), targetF);
                    TTSetU32(callInfo, @selector(setLevel:), (uint32_t)MIN(gNobleLevel, 10));
                    TTSetBool(callInfo, @selector(setVisible:), YES);
                }
                if (lc++ < 24) TTLog(@"NAME 漏斗 放行 本人 解析=%d 归属uid=%@ → fLevel %.1f（阶梯值）", selfParse, ownerUid, targetF);
            } else if (lc++ < 24) {
                TTLog(@"NAME 漏斗 放行=%d 归属uid=%@ fLevel=%.2f（原样）", isSelfInfo, ownerUid, TTGetFloat(info, @selector(fLevel)));
            }
        }
    } @catch (id e) {}
    id priv = origN_useNobility(self, _cmd, callInfo);
    gLastPrivWasSelf = isSelfInfo;
    if (isSelfInfo) {
        if (!priv && (TTNobleForgeOn() || gNameStyle != 0)) {
            @try {
                Class pc = NSClassFromString(@"TTNobilityPrivilege");
                float f = TTNobleForgeOn() ? TTNobleBandFLevel(gNobleLevel) : 0.0f;
                BOOL vis = TTNobleForgeOn();
                if (pc && [pc instancesRespondToSelector:@selector(initWithFLevel:visible:)])
                    priv = [((id (*)(id, SEL, float, BOOL))objc_msgSend)([pc alloc], @selector(initWithFLevel:visible:), f, vis) autorelease];
            } @catch (id e) {}
        }
        if (priv) objc_setAssociatedObject(priv, &kTTSelfPrivKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (priv) {
        objc_setAssociatedObject(priv, &kTTSelfPrivKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return priv;
}

static id TTN_createPriv(id self, SEL _cmd, float fLevel, id visible, id config) {
    id priv = origN_createPriv(self, _cmd, fLevel, visible, config);
    BOOL selfThread = [[[NSThread currentThread] threadDictionary] objectForKey:@"ttforge.nobleOK"] != nil;
    if (!priv && selfThread && (TTNobleForgeOn() || TTMemberForgeOn())) {
        @try {
            Class pc = NSClassFromString(@"TTNobilityPrivilege");
            float targetF = (fLevel >= 0.4f) ? fLevel : (TTNobleForgeOn() ? TTNobleBandFLevel(gNobleLevel) : 0.0f);
            if (pc && [pc instancesRespondToSelector:@selector(initWithFLevel:visible:)])
                priv = [((id (*)(id, SEL, float, BOOL))objc_msgSend)([pc alloc], @selector(initWithFLevel:visible:), targetF, YES) autorelease];
        } @catch (id e) {}
    }
    if (priv) {
        objc_setAssociatedObject(priv, &kTTSelfPrivKey, @(selfThread), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return priv;
}

static id TTDressManager(void) {
    @try {
        return TTGetObj(TTSuperPlayerDefaultMgr(), @selector(dressManager));
    } @catch (id e) { return nil; }
}

static NSArray *TTGetSortedDresses(int type) {
    @try {
        id dm = TTDressManager();
        if (!dm) return @[];
        SEL dictSel = @selector(chatBackgroundDressDict);
        if (type == 4) dictSel = @selector(msgBubbleDressDict);
        else if (type == 2) dictSel = @selector(specialDressDict);
        else if (type == 1) dictSel = @selector(roomDressDict);
        NSDictionary *dict = TTGetObj(dm, dictSel);
        if ((![dict isKindOfClass:[NSDictionary class]] || dict.count == 0) && [dm respondsToSelector:@selector(getDressDict:)])
            dict = ((id (*)(id, SEL, int))objc_msgSend)(dm, @selector(getDressDict:), type);
        if (![dict isKindOfClass:[NSDictionary class]] || dict.count == 0) {
            if ([dm respondsToSelector:@selector(loadCacheData)])
                ((void (*)(id, SEL))objc_msgSend)(dm, @selector(loadCacheData));
            if ([dm respondsToSelector:@selector(reqGetDressConfigs:)])
                ((void (*)(id, SEL, int))objc_msgSend)(dm, @selector(reqGetDressConfigs:), type);
            dict = TTGetObj(dm, dictSel);
        }
        if (![dict isKindOfClass:[NSDictionary class]] || dict.count == 0) return @[];
        return [[dict allValues] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            uint32_t la = TTGetU32(a, @selector(level)), lb = TTGetU32(b, @selector(level));
            if (la != lb) return (la > lb) ? NSOrderedAscending : NSOrderedDescending;
            uint32_t ida = TTGetU32(a, @selector(id_p)), idb = TTGetU32(b, @selector(id_p));
            return (ida < idb) ? NSOrderedAscending : ((ida > idb) ? NSOrderedDescending : NSOrderedSame);
        }];
    } @catch (id e) { return @[]; }
}

static void TTApplyBubbleDressNow(void) {
    @try {
        Class imCls = NSClassFromString(@"IMConversation");
        if (imCls && [imCls respondsToSelector:@selector(setMsgBubbleDressId:)])
            ((void (*)(id, SEL, uint32_t))objc_msgSend)(imCls, @selector(setMsgBubbleDressId:), gBubbleDressId);
        id dm = TTDressManager();
        id me = TTCMePlayer();
        if (gBubbleDressId > 0 && dm && [dm respondsToSelector:@selector(msgBubbleDressFor:)]) {
            id dress = ((id (*)(id, SEL, uint32_t))objc_msgSend)(dm, @selector(msgBubbleDressFor:), gBubbleDressId);
            if (dress) {
                [gBubbleDressName release];
                gBubbleDressName = [(TTGetObj(dress, @selector(name)) ?: @"") retain];
                TTSetObj(me, @selector(setMsgBubbleDress:), dress);
                if ([dress respondsToSelector:@selector(downloadBubbleSource)])
                    ((void (*)(id, SEL))objc_msgSend)(dress, @selector(downloadBubbleSource));
            } else if ([dm respondsToSelector:@selector(reqGetDressConfigs:)]) {
                ((void (*)(id, SEL, int))objc_msgSend)(dm, @selector(reqGetDressConfigs:), 4);
            }
        } else if (gBubbleDressId == 0) {
            [gBubbleDressName release]; gBubbleDressName = nil;
        }
    } @catch (id e) {}
}

static void TTApplyChatBgDressNow(void) {
    @try {
        id dm = TTDressManager();
        if (gChatBgDressId > 0 && dm && [dm respondsToSelector:@selector(chatBackgroundDressFor:)]) {
            id dress = ((id (*)(id, SEL, uint32_t))objc_msgSend)(dm, @selector(chatBackgroundDressFor:), gChatBgDressId);
            if (dress) {
                [gChatBgDressName release];
                gChatBgDressName = [(TTGetObj(dress, @selector(name)) ?: @"") retain];
            } else if ([dm respondsToSelector:@selector(reqGetDressConfigs:)]) {
                ((void (*)(id, SEL, int))objc_msgSend)(dm, @selector(reqGetDressConfigs:), 3);
            }
        } else if (gChatBgDressId == 0) {
            [gChatBgDressName release]; gChatBgDressName = nil;
        }
        id me = TTCMePlayer();
        if (me && [me respondsToSelector:@selector(reqUserCurrChatBackgroundList)])
            ((void (*)(id, SEL))objc_msgSend)(me, @selector(reqUserCurrChatBackgroundList));
    } @catch (id e) {}
}

static void TTTriggerSpecialDressDownload(id dress, id player) {
    if (!dress) return;
    @try {
        if (player && [dress respondsToSelector:@selector(addListener:)])
            ((void (*)(id, SEL, id))objc_msgSend)(dress, @selector(addListener:), player);
        for (NSString *dlSel in @[@"downloadSource", @"downloadSpecialDressSource", @"download", @"startDownload", @"loadSource"]) {
            SEL s = NSSelectorFromString(dlSel);
            if ([dress respondsToSelector:s]) {
                ((void (*)(id, SEL))objc_msgSend)(dress, s);
                break;
            }
        }
        id src = TTGetObj(dress, @selector(source));
        if (src) {
            for (NSString *dlSel in @[@"downloadSource", @"download", @"startDownload", @"loadSource"]) {
                SEL s = NSSelectorFromString(dlSel);
                if ([src respondsToSelector:s]) {
                    ((void (*)(id, SEL))objc_msgSend)(src, s);
                    break;
                }
            }
            if (player && [player respondsToSelector:@selector(dressSourceDidDownload:)])
                ((void (*)(id, SEL, id))objc_msgSend)(player, @selector(dressSourceDidDownload:), dress);
        }
    } @catch (id e) {}
}

static void TTApplySpecialDressNow(void) {
    @try {
        id me = TTCMePlayer();
        if (gSpecialDressId == 0) {
            [gSpecialDressName release]; gSpecialDressName = nil;
            if (origC_setCurrentDress && me) origC_setCurrentDress(me, @selector(setCurrentDress:), nil);
            else TTSetObj(me, @selector(setCurrentDress:), nil);
            return;
        }
        id dm = TTDressManager();
        if (!dm || ![dm respondsToSelector:@selector(specialConcernDressFor:)]) return;
        id dress = ((id (*)(id, SEL, uint32_t))objc_msgSend)(dm, @selector(specialConcernDressFor:), gSpecialDressId);
        if (!dress) {
            if ([dm respondsToSelector:@selector(loadCacheData)])
                ((void (*)(id, SEL))objc_msgSend)(dm, @selector(loadCacheData));
            dress = ((id (*)(id, SEL, uint32_t))objc_msgSend)(dm, @selector(specialConcernDressFor:), gSpecialDressId);
        }
        if (!dress) {
            if ([dm respondsToSelector:@selector(reqGetDressConfigs:)])
                ((void (*)(id, SEL, int))objc_msgSend)(dm, @selector(reqGetDressConfigs:), 2);
            if (me && [me respondsToSelector:@selector(loadDressData)])
                ((void (*)(id, SEL))objc_msgSend)(me, @selector(loadDressData));
            return;
        }
        [gSpecialDressName release];
        gSpecialDressName = [(TTGetObj(dress, @selector(name)) ?: @"") retain];
        if (me) {
            if (origC_setCurrentDress) origC_setCurrentDress(me, @selector(setCurrentDress:), dress);
            else TTSetObj(me, @selector(setCurrentDress:), dress);
            TTTriggerSpecialDressDownload(dress, me);
            if ([me respondsToSelector:@selector(loadDressData)])
                ((void (*)(id, SEL))objc_msgSend)(me, @selector(loadDressData));
            if ([me respondsToSelector:@selector(dressSourceDidDownload:)])
                ((void (*)(id, SEL, id))objc_msgSend)(me, @selector(dressSourceDidDownload:), dress);
        }
        for (id p in [gForgedPlayers allObjects]) {
            if (p != me) {
                if (origC_setCurrentDress) origC_setCurrentDress(p, @selector(setCurrentDress:), dress);
                else TTSetObj(p, @selector(setCurrentDress:), dress);
                TTTriggerSpecialDressDownload(dress, p);
            }
        }
        TTLog(@"H5DRESS 特别关心已应用 id=%u name=%@ source=%@", gSpecialDressId, gSpecialDressName ?: @"",
              TTGetObj(dress, @selector(source)) ? @"✓" : @"下载中");
    } @catch (id e) { TTLog(@"H5DRESS 特别关心应用异常 %@", e); }
}

static id TTC_currentDress(id self, SEL _cmd) {
    id d = origC_currentDress ? origC_currentDress(self, _cmd) : nil;
    if (TTMemberForgeOn() && gSpecialDressId > 0 && TTPlayerIsSelfRaw(self)) {
        if (!d || TTGetU32(d, @selector(id_p)) != gSpecialDressId) {
            id dm = TTDressManager();
            if (dm && [dm respondsToSelector:@selector(specialConcernDressFor:)]) {
                id target = ((id (*)(id, SEL, uint32_t))objc_msgSend)(dm, @selector(specialConcernDressFor:), gSpecialDressId);
                if (target) {
                    if (origC_setCurrentDress) origC_setCurrentDress(self, @selector(setCurrentDress:), target);
                    TTTriggerSpecialDressDownload(target, self);
                    d = target;
                }
            }
        }
    }
    return d;
}

static void TTC_setCurrentDress(id self, SEL _cmd, id dress) {
    if (TTMemberForgeOn() && gSpecialDressId > 0 && TTPlayerIsSelfRaw(self)) {
        if (!dress || TTGetU32(dress, @selector(id_p)) != gSpecialDressId) {
            id dm = TTDressManager();
            if (dm && [dm respondsToSelector:@selector(specialConcernDressFor:)]) {
                id target = ((id (*)(id, SEL, uint32_t))objc_msgSend)(dm, @selector(specialConcernDressFor:), gSpecialDressId);
                if (target) dress = target;
            }
        }
    }
    if (origC_setCurrentDress) origC_setCurrentDress(self, _cmd, dress);
    if (dress && TTMemberForgeOn() && gSpecialDressId > 0 && TTPlayerIsSelfRaw(self)) {
        if (!TTGetObj(dress, @selector(source))) TTTriggerSpecialDressDownload(dress, self);
    }
}

static id TTC_getSpecialConcernSuit(id self, SEL _cmd) {
    id suit = origC_getSpecialConcernSuit ? origC_getSpecialConcernSuit(self, _cmd) : nil;
    if (!suit && TTMemberForgeOn() && gSpecialDressId > 0 && TTPlayerIsSelfRaw(self)) {
        @try {
            id dress = [self respondsToSelector:@selector(currentDress)] ? TTGetObj(self, @selector(currentDress)) : nil;
            if (dress) {
                suit = TTGetObj(dress, @selector(source));
                if (!suit) {
                    TTTriggerSpecialDressDownload(dress, self);
                    suit = TTGetObj(dress, @selector(source));
                }
            }
        } @catch (id e) {}
    }
    return suit;
}

static void TTC_dressConfigDidUpdate(id self, SEL _cmd, id arg) {
    if (origC_dressConfigDidUpdate) origC_dressConfigDidUpdate(self, _cmd, arg);
    if (TTMemberForgeOn() && gSpecialDressId > 0 && TTPlayerIsSelfRaw(self)) {
        TTApplySpecialDressNow();
    }
}

static void TTApplyRoomDressNow(void) {
    @try {
        if (gRoomDressId == 0) {
            [gRoomDressName release]; gRoomDressName = nil;
            return;
        }
        id dm = TTDressManager();
        id dress = (dm && [dm respondsToSelector:@selector(roomDressFor:)])
            ? ((id (*)(id, SEL, uint32_t))objc_msgSend)(dm, @selector(roomDressFor:), gRoomDressId) : nil;
        if (dress) {
            [gRoomDressName release];
            gRoomDressName = [(TTGetObj(dress, @selector(name)) ?: @"") retain];
        } else if (dm && [dm respondsToSelector:@selector(reqGetDressConfigs:)]) {
            ((void (*)(id, SEL, int))objc_msgSend)(dm, @selector(reqGetDressConfigs:), 1);
        }
        TTLog(@"H5DRESS 房间装扮已记录 id=%u name=%@（房间视图经 getCurSuperplayerRoomDress 返回）",
              gRoomDressId, gRoomDressName ?: @"待0xea6下发");
    } @catch (id e) {}
}

static void TTApplyH5Dress(uint32_t type, uint32_t did) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    switch (type) {
        case 4:
            gBubbleDressId = did;
            [ud setObject:@(did) forKey:@"ttforge.bubbleDressId"];
            TTApplyBubbleDressNow();
            TTLog(@"H5DRESS 气泡%@ id=%u", did ? @"换上" : @"取消", did);
            break;
        case 3:
            gChatBgDressId = did;
            [ud setObject:@(did) forKey:@"ttforge.chatBgDressId"];
            TTApplyChatBgDressNow();
            TTLog(@"H5DRESS 聊天背景%@ id=%u", did ? @"换上" : @"取消", did);
            break;
        case 2:
            gSpecialDressId = did;
            [ud setObject:@(did) forKey:@"ttforge.specialDressId"];
            TTApplySpecialDressNow();
            TTLog(@"H5DRESS 特别关心%@ id=%u", did ? @"换上" : @"取消", did);
            break;
        case 1:
            gRoomDressId = did;
            [ud setObject:@(did) forKey:@"ttforge.roomDressId"];
            TTApplyRoomDressNow();
            TTLog(@"H5DRESS 房间装扮%@ id=%u", did ? @"换上" : @"取消", did);
            break;
        default:
            TTLog(@"H5DRESS 未知装扮类型 type=%u id=%u（忽略）", type, did);
            break;
    }
}

static id (*origW_send)(id, SEL, int32_t, id, id);

static id TTBuildPBResponseData(NSString *respClsName, id existingBase, void (^configure)(id resp)) {
    @try {
        Class respCls = NSClassFromString(respClsName);
        Class baseCls = NSClassFromString(@"TTBaseResp");
        Class rdCls = NSClassFromString(@"ResponseData");
        if (!respCls || !rdCls) return nil;
        id resp = [[respCls alloc] init];
        if (existingBase) {
            TTSetObj(resp, @selector(setBaseResp:), existingBase);
        } else if (baseCls) {
            id base = [[baseCls alloc] init];
            TTSetU32(base, @selector(setRet:), 0);
            TTSetObj(resp, @selector(setBaseResp:), base);
            [base release];
        }
        if (configure) configure(resp);
        NSData *bytes = TTGetObj(resp, @selector(data));
        [resp release];
        if (!bytes) return nil;
        id rd = [[rdCls alloc] init];
        TTSetObj(rd, @selector(setPbData:), bytes);
        return rd;
    } @catch (id e) { return nil; }
}

static id TTForgedSuccessRespData(id reqProfile) {
    Class profCls = NSClassFromString(@"SVIPPrivilegeProfile");
    if (!profCls) return nil;
    return TTBuildPBResponseData(@"SetUserSVIPPrivilegeProfileResp", nil, ^(id resp) {
        id prof = [[profCls alloc] init];
        id me = TTCMePlayer();
        id cur = me ? TTGetObj(me, @selector(mySvipProfile)) : nil;
        if (cur) {
            if ([cur respondsToSelector:@selector(onlineSwitch)])
                TTSetU32(prof, @selector(setOnlineSwitch:), TTGetU32(cur, @selector(onlineSwitch)));
            if ([cur respondsToSelector:@selector(fellowVisible)])
                TTSetBool(prof, @selector(setFellowVisible:), TTGetBool(cur, @selector(fellowVisible)));
            if ([cur respondsToSelector:@selector(sneakilyReadSwitch)])
                TTSetU64(prof, @selector(setSneakilyReadSwitch:), TTGetU64(cur, @selector(sneakilyReadSwitch)));
        }
        if (reqProfile) {
            uint32_t osw = TTGetU32(reqProfile, @selector(onlineSwitch));
            if (osw != 0) TTSetU32(prof, @selector(setOnlineSwitch:), osw);
            uint64_t srsw = TTGetU64(reqProfile, @selector(sneakilyReadSwitch));
            if (srsw != 0) TTSetU64(prof, @selector(setSneakilyReadSwitch:), srsw);
            if ([reqProfile respondsToSelector:@selector(fellowVisible)]) {
                BOOL v = TTGetBool(reqProfile, @selector(fellowVisible));
                BOOL cv = cur ? TTGetBool(cur, @selector(fellowVisible)) : NO;
                if (!cur || v != cv) TTSetBool(prof, @selector(setFellowVisible:), v);
            }
        }
        TTPatchStealthProfile(prof, YES);
        TTSetObj(resp, @selector(setPrivilegeProfile:), prof);
        [prof release];
    });
}

static id TTForgedSpecialDressRespData(uint32_t dressId) {
    return TTBuildPBResponseData(@"GetUserCurrSpecialConcernDressIdResp", nil, ^(id resp) {
        TTSetU32(resp, @selector(setDressId:), dressId);
    });
}

static id TTForgedBubbleRespData(uint32_t dressId) {
    return TTBuildPBResponseData(@"GetUserCurrChatBubbleDressIdResp", nil, ^(id resp) {
        TTSetU32(resp, @selector(setDressId:), dressId);
    });
}

static id TTForgedChatBgRespData(uint32_t dressId) {
    return TTBuildPBResponseData(@"GetUserCurrChatBgDressIdListResp", nil, ^(id resp) {
        TTSetU32(resp, @selector(setCommonDressId:), dressId);
    });
}

static id TTForgedSetDressInUseRespData(void) {
    return TTBuildPBResponseData(@"SetDressInUseResp", nil, nil);
}

static id TTForgedMagicPushRespData(void) {
    return TTBuildPBResponseData(@"ChannelMagicExpressionPushResponse", nil, nil);
}

static id TTForgedUserDressListRespData(int cfgType, uint32_t currentInUseId) {
    Class infoCls = NSClassFromString(@"DressInfo");
    Class resCls = NSClassFromString(@"DressResInfo");
    if (!infoCls) return nil;
    NSArray *dresses = TTGetSortedDresses(cfgType);
    if (!dresses.count && cfgType == 4) dresses = TTGetSortedDresses(3);
    if (!dresses.count) return nil;
    return TTBuildPBResponseData(@"GetUserDressListResp", nil, ^(id resp) {
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:dresses.count];
        for (id d in dresses) {
            id info = [[infoCls alloc] init];
            uint32_t did = TTGetU32(d, @selector(id_p));
            TTSetU32(info, @selector(setId_p:), did);
            TTSetU32(info, @selector(setLevel:), TTGetU32(d, @selector(level)));
            TTSetBool(info, @selector(setIsUse:), (did == currentInUseId));
            NSString *nm = TTGetObj(d, @selector(name));
            NSString *ds = TTGetObj(d, @selector(desc));
            NSString *url = TTGetObj(d, @selector(resourceURL));
            NSString *md5 = TTGetObj(d, @selector(resourceMd5));
            if (nm) TTSetObj(info, @selector(setName:), nm);
            if (ds) TTSetObj(info, @selector(setDesc:), ds);
            if (resCls && (url || md5)) {
                id ri = [[resCls alloc] init];
                if (url) TTSetObj(ri, @selector(setResourceURL:), url);
                if (md5) TTSetObj(ri, @selector(setResourceMd5:), md5);
                TTSetObj(info, @selector(setResInfo:), ri);
                [ri release];
            }
            [arr addObject:info];
            [info release];
        }
        TTSetObj(resp, @selector(setInfoListArray:), arr);
    });
}

static NSArray *TTBuildResolvedSpecialConcernEntries(NSArray *existingItems, NSString *excludeAccount) {
    Class cuCls = NSClassFromString(@"ConcernUser");
    if (!cuCls) return @[];
    NSMutableArray *entries = [NSMutableArray array];
    NSMutableSet *seenAcc = [NSMutableSet set];
    NSMutableSet *seenUid = [NSMutableSet set];
    void (^appendUser)(NSString *, uint32_t) = ^(NSString *rawKey, uint32_t rawUid) {
        uint32_t uid = rawUid;
        NSString *acc = ([rawKey isKindOfClass:[NSString class]] && rawKey.length) ? rawKey : nil;
        if (!uid && acc) uid = TTUidForAccount(acc);
        if (uid) {
            NSString *realAcc = TTAccountForUid(uid);
            if (realAcc.length) acc = realAcc;
        }
        if (!acc.length && uid) acc = [NSString stringWithFormat:@"%u", uid];
        if (!acc.length) return;
        if (excludeAccount.length && [acc isEqualToString:excludeAccount]) return;
        if ([seenAcc containsObject:acc] || (uid && [seenUid containsObject:@(uid)])) return;
        [seenAcc addObject:acc];
        if (uid) [seenUid addObject:@(uid)];
        id cu = [[cuCls alloc] init];
        TTSetObj(cu, @selector(setAccount:), acc);
        if (uid) TTSetU32(cu, @selector(setUid:), uid);
        [entries addObject:cu];
        [cu release];
    };
    if ([existingItems isKindOfClass:[NSArray class]]) {
        for (id item in existingItems) {
            uint32_t uid = TTGetU32(item, @selector(uid));
            if (!uid) uid = TTGetU32(item, @selector(userId));
            NSString *acc = TTGetObj(item, @selector(account));
            if (uid && [acc isKindOfClass:[NSString class]] && acc.length) TTRecordAccountUid(acc, uid);
            appendUser(acc, uid);
        }
    }
    @synchronized (gSpecialKeys) {
        for (NSString *key in [gSpecialKeys allObjects]) {
            appendUser(key, TTUidForAccount(key));
        }
    }
    return entries;
}

static void TTSyncSpecialConcernToMePlayerAndContacts(void) {
    @try {
        id me = TTCMePlayer();
        if (!me || !TTMemberForgeOn()) return;
        id curList = TTGetObj(me, @selector(specialConcernList));
        NSArray *entries = TTBuildResolvedSpecialConcernEntries([curList isKindOfClass:[NSArray class]] ? curList : nil, nil);
        if (entries.count > 0 && [me respondsToSelector:@selector(syncSpeicalUsers:)]) {
            ((void (*)(id, SEL, id))objc_msgSend)(me, @selector(syncSpeicalUsers:), entries);
        } else if (entries.count > 0 && [me respondsToSelector:@selector(transSpecialListToDict)]) {
            ((void (*)(id, SEL))objc_msgSend)(me, @selector(transSpecialListToDict));
        }
        if (gSpecialDressId > 0) {
            id dress = TTGetObj(me, @selector(currentDress));
            if (dress && [me respondsToSelector:@selector(dressSourceDidDownload:)])
                ((void (*)(id, SEL, id))objc_msgSend)(me, @selector(dressSourceDidDownload:), dress);
        }
        id cs = TTContactService();
        if (cs && [cs respondsToSelector:@selector(updateContactStatus)]) {
            ((void (*)(id, SEL))objc_msgSend)(cs, @selector(updateContactStatus));
        }
    } @catch (id e) {}
}

static id TTForgedSpecialConcernRespData(BOOL isAdd, NSString *targetAccount) {
    NSString *clsName = isAdd ? @"AddUserSpecialConcernResp" : @"DelUserSpecialConcernResp";
    return TTBuildPBResponseData(clsName, nil, ^(id resp) {
        id me = TTCMePlayer();
        id curList = me ? TTGetObj(me, @selector(specialConcernList)) : nil;
        if (![curList isKindOfClass:[NSArray class]]) curList = me ? TTGetObj(me, @selector(specialConcernListArray)) : nil;
        NSArray *entries = TTBuildResolvedSpecialConcernEntries(
            [curList isKindOfClass:[NSArray class]] ? (NSArray *)curList : nil,
            isAdd ? nil : targetAccount);
        TTSetObj(resp, @selector(setSpecialConcernListArray:), [NSMutableArray arrayWithArray:entries]);
    });
}

static id TTForgedGetSpecialConcernRespData(id respObj) {
    @try {
        Class respCls = NSClassFromString(@"GetUserSpecialConcernResp");
        Class cuCls = NSClassFromString(@"ConcernUser");
        if (!respCls || !cuCls) return nil;
        id parsed = nil;
        id pb = respObj ? TTGetObj(respObj, @selector(pbData)) : nil;
        if ([pb isKindOfClass:[NSData class]] && [(id)respCls respondsToSelector:@selector(parseFromData:error:)]) {
            parsed = ((id (*)(id, SEL, id, id))objc_msgSend)((id)respCls, @selector(parseFromData:error:), pb, nil);
        }
        id origArr = parsed ? TTGetObj(parsed, @selector(specialConcernListArray)) : nil;
        NSUInteger before = [origArr isKindOfClass:[NSArray class]] ? [(NSArray *)origArr count] : 0;
        NSArray *entries = TTBuildResolvedSpecialConcernEntries([origArr isKindOfClass:[NSArray class]] ? (NSArray *)origArr : nil, nil);
        if (parsed && entries.count == before) return nil;
        id rd = TTBuildPBResponseData(@"GetUserSpecialConcernResp", parsed ? TTGetObj(parsed, @selector(baseResp)) : nil, ^(id resp) {
            TTSetObj(resp, @selector(setSpecialConcernListArray:), [NSMutableArray arrayWithArray:entries]);
            if (parsed && [parsed respondsToSelector:@selector(showExpireWindow)])
                TTSetBool(resp, @selector(setShowExpireWindow:), TTGetBool(parsed, @selector(showExpireWindow)));
        });
        if (rd) {
            TTLog(@"SPECIAL W层 0xe77 名单合并本地关心 %lu 条（原 %lu 条）",
                  (unsigned long)(entries.count >= before ? entries.count - before : entries.count), (unsigned long)before);
        }
        return rd;
    } @catch (id e) { return nil; }
}

static void TTProbeChannelPasswd(uint32_t cid) {
    @try {
        if (cid == 0) { TTLog(@"PASSWD 0x8e32 探测取消：channelId=0"); return; }
        if (!gConnCore) { TTLog(@"PASSWD 0x8e32 失败：尚未捕获 ConnectionCore 实例"); return; }
        Class reqCls = NSClassFromString(@"ChannelGetEnterControlTypeReq");
        Class baseCls = NSClassFromString(@"TTBaseReq");
        Class respCls = NSClassFromString(@"ChannelGetEnterControlTypeResp");
        if (!reqCls) { TTLog(@"PASSWD 0x8e32 失败：无 ChannelGetEnterControlTypeReq 类"); return; }
        id req = [reqCls respondsToSelector:@selector(message)]
            ? ((id (*)(id, SEL))objc_msgSend)(reqCls, @selector(message))
            : [[[reqCls alloc] init] autorelease];
        if (baseCls) {
            id base = [baseCls respondsToSelector:@selector(message)]
                ? ((id (*)(id, SEL))objc_msgSend)(baseCls, @selector(message))
                : [[[baseCls alloc] init] autorelease];
            if (base) TTSetObj(req, @selector(setBaseReq:), base);
        }
        TTSetU32(req, @selector(setChannelId:), cid);
        TTLog(@"PASSWD 发送 0x8e32 取密码请求 channelId=%u", cid);
        void (^cb)(id, id, id) = ^(id request, id respObj, id error) {
            @try {
                if (error) {
                    TTLog(@"PASSWD 0x8e32 失败 channelId=%u error=%@", cid, error);
                    return;
                }
                id pb = TTGetObj(respObj, @selector(pbData));
                long ret = pb ? TTPBRet((NSData *)pb) : -999;
                NSString *passwd = nil;
                uint32_t ctrlType = 0;
                if (pb && respCls) {
                    id parsed = nil;
                    if ([respCls respondsToSelector:@selector(parseFromData:)]) {
                        parsed = ((id (*)(id, SEL, id))objc_msgSend)(respCls, @selector(parseFromData:), pb);
                    } else {
                        parsed = [[[respCls alloc] init] autorelease];
                        TTSetObj(parsed, @selector(mergeFromData:), pb);
                    }
                    if (parsed) {
                        passwd = TTGetObj(parsed, @selector(passwd));
                        ctrlType = TTGetU32(parsed, @selector(controlType));
                    }
                }
                if ([passwd isKindOfClass:[NSString class]] && passwd.length > 0) {
                    [UIPasteboard generalPasteboard].string = passwd;
                    TTLog(@"PASSWD 0x8e32 成功! channelId=%u ret=%ld controlType=%u 明文密码=[%@] (已复制到剪贴板)", cid, ret, ctrlType, passwd);
                } else {
                    TTLog(@"PASSWD 0x8e32 返回 channelId=%u ret=%ld controlType=%u passwd=[%@] raw=%@",
                          cid, ret, ctrlType, passwd ?: @"<nil>", pb ? TTHex((NSData *)pb, 96) : @"<nil>");
                }
            } @catch (id e) { TTLog(@"PASSWD 0x8e32 解析异常 %@", e); }
        };
        id cbCopy = [cb copy];
        origW_send(gConnCore, @selector(send:message:resultBlock:), 0x8e32, req, cbCopy);
        [cbCopy release];
    } @catch (id e) { TTLog(@"PASSWD 0x8e32 异常 %@", e); }
}

static void TTTriggerLocalMagicEcho(uint32_t tabId, uint32_t magicId);

static id TTSendWrapped(id self, SEL _cmd, int32_t cmd, id msg, id block, void (^interceptor)(id req, id resp, id err, void (^origCb)(id, id, id))) {
    id blkCopy = [block copy];
    void (^wrap)(id, id, id) = ^(id request, id respObj, id error) {
        interceptor(request, respObj, error, (void (^)(id, id, id))blkCopy);
    };
    id wrapCopy = [wrap copy];
    id r = origW_send(self, _cmd, cmd, msg, wrapCopy);
    [wrapCopy release];
    [blkCopy release];
    return r;
}

static id TTW_send(id self, SEL _cmd, int32_t cmd, id msg, id block) {
    if (self && !gConnCore) gConnCore = [self retain];

    id reqProfile = (TTMemberForgeOn() && cmd == 0xe7e && block) ? TTGetObj(msg, @selector(privilegeProfile)) : nil;
    if (reqProfile) {
        [reqProfile retain];
        id r = TTSendWrapped(self, _cmd, cmd, msg, block, ^(id request, id respObj, id error, void (^origCb)(id, id, id)) {
            if (error) {
                TTLog(@"W 0xe7e 服务端拒绝 error=%@ → 替换为伪造成功响应", error);
                id forged = TTForgedSuccessRespData(reqProfile);
                if (forged) { origCb(request, forged, nil); [forged release]; return; }
            }
            origCb(request, respObj, error);
        });
        [reqProfile release];
        return r;
    }

    if (cmd == 0xc6aa && msg) {
        uint32_t enterCid = TTGetU32(msg, @selector(channelId));
        if (enterCid) {
            NSString *pw = TTGetObj(msg, @selector(passwd));
            TTLog(@"ENTER 0xc6aa 进房请求 channelId=%u passwd=[%@]", enterCid, pw ?: @"");
        }
        if (block && enterCid) {
            return TTSendWrapped(self, _cmd, cmd, msg, block, ^(id request, id respObj, id error, void (^origCb)(id, id, id)) {
                @try {
                    long code = error ? (long)[(NSError *)error code] : 0;
                    if (code == -2134 || code == -2133) {
                        TTLog(@"ENTER 0xc6aa 被密码门拦截 (code=%ld) → 自动触发 0x8e32 取密码探测 (roomId=%u)", code, enterCid);
                        TTProbeChannelPasswd(enterCid);
                    }
                } @catch (id e) {}
                origCb(request, respObj, error);
            });
        }
    }

    if (TTMemberForgeOn() && cmd == 0x462 && msg) {
        @try {
            if ([msg respondsToSelector:@selector(setIncludeFollowing:)])
                TTSetBool(msg, @selector(setIncludeFollowing:), YES);
            id uidArr = TTGetObj(msg, @selector(extCheckOnlineUidlistArray));
            if (uidArr && [uidArr respondsToSelector:@selector(addValue:)]) {
                @synchronized (gSpecialKeys) {
                    for (NSString *k in [gSpecialKeys allObjects]) {
                        uint32_t suid = TTUidForAccount(k);
                        if (suid > 0) ((void (*)(id, SEL, uint32_t))objc_msgSend)(uidArr, @selector(addValue:), suid);
                    }
                }
            }
        } @catch (id e) {}
    }

    if (block && TTMemberForgeOn() && (cmd == 0xe78 || cmd == 0xe79)) {
        BOOL isAdd = (cmd == 0xe78);
        NSString *target = TTGetObj(msg, @selector(targetAccount));
        if (![target isKindOfClass:[NSString class]]) target = nil;
        [target retain];
        TTLog(@"SPECIAL W层 %@ 请求 target=%@ msg类=%@", isAdd ? @"0xe78添加" : @"0xe79移除",
              target ?: @"?", msg ? NSStringFromClass([msg class]) : @"nil");
        id r = TTSendWrapped(self, _cmd, cmd, msg, block, ^(id request, id respObj, id error, void (^origCb)(id, id, id)) {
            long ret = -999;
            @try {
                id pb = TTGetObj(respObj, @selector(pbData));
                if (pb) ret = TTPBRet((NSData *)pb);
            } @catch (id e) {}
            if (target) {
                @synchronized (gSpecialKeys) {
                    if (isAdd) [gSpecialKeys addObject:target]; else [gSpecialKeys removeObject:target];
                }
                TTSaveSpecialKeys();
            }
            if (error || (respObj && ret != 0)) {
                id forged = TTForgedSpecialConcernRespData(isAdd, target);
                if (forged) {
                    TTLog(@"SPECIAL W层 %@ 服务端拒绝 (error=%@ ret=%ld) → 伪造成功回包",
                          isAdd ? @"0xe78" : @"0xe79", error ?: @"nil", ret);
                    origCb(request, forged, nil);
                    [forged release];
                    dispatch_async(dispatch_get_main_queue(), ^{ TTSyncSpecialConcernToMePlayerAndContacts(); });
                    return;
                }
            }
            origCb(request, respObj, error);
            dispatch_async(dispatch_get_main_queue(), ^{ TTSyncSpecialConcernToMePlayerAndContacts(); });
        });
        [target release];
        return r;
    }

    if (block && TTMemberForgeOn() && cmd == 0xe77) {
        uint32_t reqUid = msg ? TTGetU32(msg, @selector(uid)) : 0;
        if (!reqUid || TTIsSelfUidRaw(reqUid)) {
            return TTSendWrapped(self, _cmd, cmd, msg, block, ^(id request, id respObj, id error, void (^origCb)(id, id, id)) {
                id forged = TTForgedGetSpecialConcernRespData(respObj);
                if (forged) {
                    origCb(request, forged, nil);
                    [forged release];
                    dispatch_async(dispatch_get_main_queue(), ^{ TTSyncSpecialConcernToMePlayerAndContacts(); });
                    return;
                }
                origCb(request, respObj, error);
            });
        }
    }

    if (block && cmd == 0xeae && msg && TTMemberForgeOn()) {
        uint32_t applyId = TTGetU32(msg, @selector(dressId));
        uint32_t applyType = TTGetU32(msg, @selector(dressType));
        TTLog(@"DRESS 原生请求应用装扮 0xeae dressType=%u dressId=%u", applyType, applyId);
        TTApplyH5Dress(applyType, applyId);
        return TTSendWrapped(self, _cmd, cmd, msg, block, ^(id request, id respObj, id error, void (^origCb)(id, id, id)) {
            long ret = -999;
            @try {
                id pb = TTGetObj(respObj, @selector(pbData));
                if (pb) ret = TTPBRet((NSData *)pb);
            } @catch (id e) {}
            if (error || (respObj && ret != 0) || applyType == 1) {
                TTLog(@"W 0xeae 服务端拒绝/过期 (type=%u id=%u error=%@ ret=%ld) → 伪造成功响应",
                      applyType, applyId, error ?: @"nil", ret);
                id forged = TTForgedSetDressInUseRespData();
                if (forged) { origCb(request, forged, nil); [forged release]; return; }
            }
            origCb(request, respObj, error);
        });
    }

    if (block && cmd == 0xead && TTMemberForgeOn()) {
        uint32_t reqType = msg ? TTGetU32(msg, @selector(type)) : 3;
        return TTSendWrapped(self, _cmd, cmd, msg, block, ^(id request, id respObj, id error, void (^origCb)(id, id, id)) {
            @try {
                int cfgType = (int)reqType;
                uint32_t curId = 0;
                if (cfgType == 4) curId = gBubbleDressId;
                else if (cfgType == 3) curId = gChatBgDressId;
                else if (cfgType == 2) curId = gSpecialDressId;
                else if (cfgType == 1) curId = gRoomDressId;
                id forged = TTForgedUserDressListRespData(cfgType, curId);
                if (forged) {
                    TTLog(@"W 0xead 已拥有装扮列表查询 → 注入全量配置表条目 (reqType=%u)", reqType);
                    origCb(request, forged, nil);
                    [forged release];
                    return;
                }
            } @catch (id e) {}
            origCb(request, respObj, error);
        });
    }

    BOOL isSpecialDressReq = (msg && [NSStringFromClass([msg class]) isEqualToString:@"GetUserCurrSpecialConcernDressIdReq"]) || (cmd == 0xea9);
    if (block && (isSpecialDressReq || cmd == 0x75cf || cmd == 0x75cd || cmd == 0x75ce || cmd == 0x13ce || cmd == 0x13cf ||
                  cmd == 0xc76c || cmd == 0xea6 || cmd == 0xeab || cmd == 0xeac || cmd == 0x8e32)) {
        uint32_t magicTabId = 0, magicId = 0;
        if (cmd == 0xc76c && msg) {
            magicId = TTGetU32(msg, @selector(magicId));
            magicTabId = TTGetU32(msg, @selector(tabId));
            gMagicLastMicId = TTGetU32(msg, @selector(micId));
            gMagicLastUid = TTGetU32(msg, @selector(uid));
            gMagicLastSendTimeMs = TTGetU64(msg, @selector(sendTimeMs));
            TTLog(@"MAGIC 0xc76c 请求字段 tab=%u magic=%u mic=%u uid=%u sendTimeMs=%llu",
                  magicTabId, magicId, gMagicLastMicId, gMagicLastUid, (unsigned long long)gMagicLastSendTimeMs);
        }
        if (cmd == 0x13ce || cmd == 0x13cf || cmd == 0xc76c || cmd == 0xea6 || cmd == 0xeab || cmd == 0xeac) {
            @try {
                NSData *rd = TTGetObj(msg, @selector(data));
                NSUInteger cap = (cmd == 0xea6 || cmd == 0xeab || cmd == 0xeac) ? 512 : 96;
                if (rd) TTLog(@"RPC 0x%04x 请求 %luB %@", (unsigned)cmd, (unsigned long)rd.length, TTHex(rd, cap));
            } @catch (id e) {}
        }
        return TTSendWrapped(self, _cmd, cmd, msg, block, ^(id request, id respObj, id error, void (^origCb)(id, id, id)) {
            @try {
                if (cmd == 0xc76c && error && TTMemberForgeOn()) {
                    TTLog(@"W 0xc76c 魔法表情被拒 error=%@ (tab=%u id=%u) → 消音并触发本地动效回显", error, magicTabId, magicId);
                    if (magicId) TTTriggerLocalMagicEcho(magicTabId, magicId);
                    id forged = TTForgedMagicPushRespData();
                    if (forged) { origCb(request, forged, nil); [forged release]; return; }
                }
                if (isSpecialDressReq && TTMemberForgeOn() && gSpecialDressId > 0) {
                    uint32_t reqUid = msg ? TTGetU32(msg, @selector(uid)) : 0;
                    if (!reqUid || TTIsSelfUidRaw(reqUid)) {
                        id forged = TTForgedSpecialDressRespData(gSpecialDressId);
                        if (forged) {
                            TTLog(@"W 0x%04x 特别关心装扮查询回包 → 注入伪造装扮 dressId=%u (%@)", (unsigned)cmd, gSpecialDressId, gSpecialDressName ?: @"");
                            origCb(request, forged, nil);
                            [forged release];
                            return;
                        }
                    }
                }
                if (cmd == 0xeab && TTMemberForgeOn() && gBubbleDressId > 0) {
                    id forged = TTForgedBubbleRespData(gBubbleDressId);
                    if (forged) {
                        TTLog(@"W 0xeab 气泡查询回包 → 注入伪造气泡 dressId=%u (%@)", gBubbleDressId, gBubbleDressName ?: @"");
                        origCb(request, forged, nil);
                        [forged release];
                        return;
                    }
                }
                if (cmd == 0xeac && TTMemberForgeOn() && gChatBgDressId > 0) {
                    id forged = TTForgedChatBgRespData(gChatBgDressId);
                    if (forged) {
                        TTLog(@"W 0xeac 聊天背景查询回包 → 注入伪造背景 commonDressId=%u (%@)", gChatBgDressId, gChatBgDressName ?: @"");
                        origCb(request, forged, nil);
                        [forged release];
                        return;
                    }
                }
                if (error) {
                    TTLog(@"RPC 0x%04x 失败 error=%@", (unsigned)cmd, error);
                } else if (cmd == 0x13ce || cmd == 0x13cf || cmd == 0xc76c || cmd == 0x8e32 || cmd == 0xea6 || cmd == 0xeab || cmd == 0xeac) {
                    NSData *pb = TTGetObj(respObj, @selector(pbData));
                    long ret = pb ? TTPBRet(pb) : -999;
                    if (cmd == 0xea6 || cmd == 0xeab || cmd == 0xeac) {
                        TTLog(@"RPC 0x%04x 成功 ret=%ld len=%lu resp=%@", (unsigned)cmd, ret,
                              (unsigned long)pb.length, pb ? TTHex(pb, 4096) : @"<无数据>");
                    } else {
                        TTLog(@"RPC 0x%04x 成功 ret=%ld resp=%@", (unsigned)cmd, ret,
                              pb ? TTHex(pb, 96) : @"<无数据>");
                    }
                } else if (cmd == 0x75cd) {
                    int cnt = -1, ret = -1;
                    NSData *pb = TTGetObj(respObj, @selector(pbData));
                    Class respCls = NSClassFromString(@"GetHideListResp");
                    if (pb && respCls) {
                        id resp = [[respCls alloc] init];
                        if ([resp respondsToSelector:@selector(mergeFromData:)]) {
                            TTSetObj(resp, @selector(mergeFromData:), pb);
                            id arr = TTGetObj(resp, @selector(listArray));
                            if (arr) cnt = (int)[arr count];
                            id base = TTGetObj(resp, @selector(baseResp));
                            if (base) ret = (int)TTGetU32(base, @selector(ret));
                        }
                        [resp release];
                    }
                    TTLog(@"RPC 0x75cd 隐身名单查询成功 服务端名单条数=%d ret=%d", cnt, ret);
                } else {
                    TTLog(@"RPC 0x%04x 成功", (unsigned)cmd);
                }
            } @catch (id e) {}
            origCb(request, respObj, error);
        });
    }
    return origW_send(self, _cmd, cmd, msg, block);
}

static NSString *TTMyNickname(void) {
    @try {
        uint32_t myUid = TTStrictSelfUid();
        if (myUid && gHits) {
            NSString *n = gHits[@(myUid)][@"nickname"];
            if (n.length) return n;
        }
        if (gMyNickname.length) return gMyNickname;
        NSString *n = TTGetObj(TTCMePlayer(), @selector(nickname));
        if (n.length) return n;
    } @catch (id e) {}
    return @"我的名字";
}

static NSString *TTMyRealAccount(void) {
    @try {
        if (gMyRealAccount.length) return gMyRealAccount;
        uint32_t myUid = TTStrictSelfUid();
        if (myUid && gHits) {
            NSString *a = gHits[@(myUid)][@"account"];
            if (a.length && (!gCustomId.length || ![a isEqualToString:gCustomId])) {
                TTCaptureMyRealAccount(a, myUid);
                return a;
            }
        }
        id me = TTCMePlayer();
        if (me) {
            id ma = objc_getAssociatedObject(me, &kTTRealAccKey);
            if (![ma isKindOfClass:[NSString class]] || ![ma length])
                ma = origC_getAccount ? origC_getAccount(me, @selector(getAccount)) : nil;
            if (![ma isKindOfClass:[NSString class]] || ![ma length])
                ma = origC_account ? origC_account(me, @selector(account)) : nil;
            if ([ma isKindOfClass:[NSString class]] && [ma length] &&
                (!gCustomId.length || ![ma isEqualToString:gCustomId])) {
                TTCaptureMyRealAccount(ma, myUid);
                return ma;
            }
        }
    } @catch (id e) {}
    return nil;
}

static NSArray *TTRealAccountVariants(NSString *seed) {
    NSMutableArray *arr = [NSMutableArray array];
    void (^addAcc)(NSString *) = ^(NSString *s) {
        if (![s isKindOfClass:[NSString class]] || !s.length) return;
        if (![arr containsObject:s]) [arr addObject:s];
        if (([s hasPrefix:@"tt"] || [s hasPrefix:@"TT"]) && s.length > 2) {
            NSString *stripped = [s substringFromIndex:2];
            if (stripped.length && ![arr containsObject:stripped]) [arr addObject:stripped];
        } else {
            NSString *prefixed = [@"tt" stringByAppendingString:s];
            if (![arr containsObject:prefixed]) [arr addObject:prefixed];
        }
    };
    addAcc(seed);
    addAcc(TTMyRealAccount());
    uint32_t myUid = TTStrictSelfUid();
    if (myUid && gHits) addAcc(gHits[@(myUid)][@"account"]);
    id me = TTCMePlayer();
    if (me) addAcc(objc_getAssociatedObject(me, &kTTRealAccKey));
    return arr;
}

static void TTResizeIdPillForView(UIView *labelOrBtn) {
    if (!labelOrBtn || !labelOrBtn.superview) return;
    @try {
        CGFloat h = labelOrBtn.bounds.size.height > 0 ? labelOrBtn.bounds.size.height : 20.0;
        CGFloat newW = 0;
        if ([labelOrBtn isKindOfClass:[UILabel class]]) {
            newW = ceil([(UILabel *)labelOrBtn sizeThatFits:CGSizeMake(10000, h)].width);
        } else if ([labelOrBtn isKindOfClass:[UIButton class]] && labelOrBtn.subviews.count <= 1) {
            newW = ceil([(UIButton *)labelOrBtn sizeThatFits:CGSizeMake(10000, h)].width);
        } else {
            return;
        }
        if (newW < 4.0) return;

        CGRect lf = labelOrBtn.frame;
        if (fabs(lf.size.width - newW) > 0.5) {
            lf.size.width = newW;
            labelOrBtn.frame = lf;
        }
        for (NSLayoutConstraint *c in labelOrBtn.constraints) {
            if (c.firstItem == labelOrBtn && c.firstAttribute == NSLayoutAttributeWidth && c.secondItem == nil) {
                c.constant = newW;
            }
        }
        [labelOrBtn invalidateIntrinsicContentSize];

        CGFloat targetLabelMaxX = CGRectGetMaxX(lf);
        UIView *cur = labelOrBtn.superview;
        for (int depth = 0; cur && depth < 3; depth++, cur = cur.superview) {
            NSString *cn = NSStringFromClass([cur class]);
            if ([cn rangeOfString:@"PersonalDetailHeaderView"].location != NSNotFound ||
                cur.bounds.size.width > 300.0 || cur.bounds.size.height > 48.0) break;

            CGFloat curOldW = cur.frame.size.width;
            CGFloat curOldMaxX = CGRectGetMaxX(cur.frame);
            CGFloat rightMostX = (depth == 0) ? targetLabelMaxX : 0;

            if (depth == 0) {
                NSMutableArray *rightSibs = [NSMutableArray array];
                for (UIView *sib in cur.subviews) {
                    if (sib == labelOrBtn || sib.hidden || sib.alpha < 0.01) continue;
                    CGRect sf = sib.frame;
                    if (sf.origin.x <= 2.0 && fabs(sf.size.width - curOldW) <= 4.0) continue;
                    if (sf.origin.x >= lf.origin.x + 6.0) [rightSibs addObject:sib];
                }
                [rightSibs sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
                    return (a.frame.origin.x < b.frame.origin.x) ? NSOrderedAscending : NSOrderedDescending;
                }];
                CGFloat cursorX = targetLabelMaxX + 4.0;
                for (UIView *sib in rightSibs) {
                    CGRect sf = sib.frame;
                    sf.origin.x = cursorX;
                    sib.frame = sf;
                    cursorX = CGRectGetMaxX(sf) + 4.0;
                    rightMostX = CGRectGetMaxX(sf);
                }
            } else {
                for (UIView *sib in cur.subviews) {
                    if (sib.hidden || sib.alpha < 0.01) continue;
                    CGRect sf = sib.frame;
                    if (sf.origin.x <= 2.0 && fabs(sf.size.width - curOldW) <= 4.0) continue;
                    if (CGRectGetMaxX(sf) > rightMostX) rightMostX = CGRectGetMaxX(sf);
                }
            }

            CGFloat rightPad = (depth == 0 && rightMostX > targetLabelMaxX) ? 6.0 : MAX(6.0, lf.origin.x);
            CGFloat targetCurW = MAX(24.0, rightMostX + rightPad);
            CGFloat deltaCurW = targetCurW - curOldW;

            for (UIView *sib in cur.subviews) {
                CGRect sf = sib.frame;
                if (sf.origin.x <= 2.0 && fabs(sf.size.width - curOldW) <= 4.0) {
                    sf.size.width = targetCurW;
                    sib.frame = sf;
                }
            }

            if (fabs(deltaCurW) > 0.5) {
                CGRect cf = cur.frame;
                BOOL isCentered = (cur.superview && fabs(CGRectGetMidX(cf) - cur.superview.bounds.size.width * 0.5) < 12.0);
                cf.size.width = targetCurW;
                if (isCentered) cf.origin.x -= deltaCurW * 0.5;
                cur.frame = cf;

                for (NSLayoutConstraint *c in cur.constraints) {
                    if (c.firstItem == cur && c.firstAttribute == NSLayoutAttributeWidth && c.secondItem == nil) {
                        c.constant = targetCurW;
                    }
                }
                if (cur.superview) {
                    for (NSLayoutConstraint *c in cur.superview.constraints) {
                        if (c.firstItem == cur && c.firstAttribute == NSLayoutAttributeWidth && c.secondItem == nil) {
                            c.constant = targetCurW;
                        }
                    }
                    if (!isCentered) {
                        for (UIView *outerSib in cur.superview.subviews) {
                            if (outerSib == cur || outerSib.hidden) continue;
                            CGRect osf = outerSib.frame;
                            if (fabs(CGRectGetMidY(osf) - CGRectGetMidY(cf)) < 10.0 && osf.origin.x >= curOldMaxX - 4.0) {
                                osf.origin.x += deltaCurW;
                                outerSib.frame = osf;
                            }
                        }
                    }
                }
                for (CALayer *subL in cur.layer.sublayers) {
                    if (subL.frame.origin.x <= 2.0 && fabs(subL.frame.size.width - curOldW) <= 4.0) {
                        CGRect slf = subL.frame;
                        slf.size.width = targetCurW;
                        subL.frame = slf;
                    }
                }
                [cur invalidateIntrinsicContentSize];
                [cur setNeedsDisplay];
            }
        }
    } @catch (id e) {}
}

static BOOL TTRelabelViewTokens(UIView *v, NSString *fromId, NSString *toId) {
    if (!v || !fromId.length || !toId.length || [fromId isEqualToString:toId]) return NO;
    BOOL changed = NO;
    if ([v isKindOfClass:[UILabel class]]) {
        UILabel *lab = (UILabel *)v;
        NSAttributedString *attr = lab.attributedText;
        if (attr.length && [attr.string rangeOfString:fromId].location != NSNotFound) {
            NSMutableAttributedString *mas = [[attr mutableCopy] autorelease];
            [[mas mutableString] replaceOccurrencesOfString:fromId withString:toId options:0 range:NSMakeRange(0, mas.length)];
            lab.attributedText = mas;
            changed = YES;
        } else if (lab.text.length && [lab.text rangeOfString:fromId].location != NSNotFound) {
            lab.text = [lab.text stringByReplacingOccurrencesOfString:fromId withString:toId];
            changed = YES;
        }
    } else if ([v isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)v;
        NSAttributedString *attr = [btn attributedTitleForState:UIControlStateNormal];
        if (attr.length && [attr.string rangeOfString:fromId].location != NSNotFound) {
            NSMutableAttributedString *mas = [[attr mutableCopy] autorelease];
            [[mas mutableString] replaceOccurrencesOfString:fromId withString:toId options:0 range:NSMakeRange(0, mas.length)];
            [btn setAttributedTitle:mas forState:UIControlStateNormal];
            changed = YES;
        }
        NSString *t = [btn titleForState:UIControlStateNormal];
        if (t.length && [t rangeOfString:fromId].location != NSNotFound) {
            [btn setTitle:[t stringByReplacingOccurrencesOfString:fromId withString:toId] forState:UIControlStateNormal];
            changed = YES;
        }
    }
    if (changed) TTResizeIdPillForView(v);
    return changed;
}

static void TTRelabelIdSubtree(UIView *rootView, NSString *toId) {
    if (!rootView || !toId.length) return;
    @try {
        NSArray *variants = TTRealAccountVariants(nil);
        NSMutableArray *q = [NSMutableArray arrayWithObject:rootView];
        while (q.count) {
            UIView *v = q.lastObject;
            [q removeLastObject];
            for (NSString *cand in variants) TTRelabelViewTokens(v, cand, toId);
            if (gPrevCustomId.length) TTRelabelViewTokens(v, gPrevCustomId, toId);
            if ([v isKindOfClass:[UILabel class]]) {
                UILabel *lab = (UILabel *)v;
                NSString *txt = lab.text ?: lab.attributedText.string;
                if (txt.length && [txt rangeOfString:toId].location != NSNotFound) {
                    TTResizeIdPillForView(v);
                }
            } else if ([v isKindOfClass:[UIButton class]]) {
                UIButton *btn = (UIButton *)v;
                NSString *txt = [btn titleForState:UIControlStateNormal] ?: [btn attributedTitleForState:UIControlStateNormal].string;
                if (txt.length && [txt rangeOfString:toId].location != NSNotFound) {
                    TTResizeIdPillForView(v);
                }
            }
            if (v.subviews.count) [q addObjectsFromArray:v.subviews];
        }
    } @catch (id e) {}
}

static BOOL TTContextEffectiveIsMe(id ctx);

static void TTRelabelVisibleIdLabels(NSString *fromId, NSString *toId) {
    if (!toId.length || TTIsOtherUserProfileVisible()) return;
    id selfCtx = TTGetLastSelfLayoutCtx();
    if (selfCtx) {
        @try {
            if (TTContextEffectiveIsMe(selfCtx)) {
                UIView *idv = TTGetObj(selfCtx, @selector(IdView));
                if ([idv isKindOfClass:[UIView class]]) TTRelabelIdSubtree(idv, toId);
            }
        } @catch (id e) {}
    }
}

static void TTDyeNicknameInSubtree(UIView *rootView) {
    if (!rootView) return;
    NSString *myNick = TTMyNickname();
    if (!myNick.length || [myNick isEqualToString:@"我的名字"]) return;
    NSMutableArray *q = [NSMutableArray arrayWithObject:rootView];
    while (q.count) {
        UIView *v = q.lastObject;
        [q removeLastObject];
        if ([v isKindOfClass:[UILabel class]]) {
            UILabel *lab = (UILabel *)v;
            if ([lab.text isEqualToString:myNick]) {
                CGSize sz = lab.bounds.size;
                if (sz.width < 10) sz = CGSizeMake(120, 22);
                lab.textColor = TTResolveNameColor(gNameStyle, gNameColorIndex, sz) ?: [UIColor labelColor];
            }
        }
        if (v.subviews.count) [q addObjectsFromArray:v.subviews];
    }
}

static void TTDyeVisibleMyNicknameLabels(void) {
    id selfCtx = TTGetLastSelfLayoutCtx();
    if (selfCtx && TTContextEffectiveIsMe(selfCtx)) {
        UIView *idv = TTGetObj(selfCtx, @selector(IdView));
        UIView *root = idv.superview.superview ?: idv.superview;
        if (root) {
            TTDyeNicknameInSubtree(root);
            return;
        }
    }
}

static NSArray *TTAllResourceBundles(void) {
    static NSArray *sBundles = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *all = [NSMutableArray array];
        NSMutableArray *roots = [NSMutableArray arrayWithArray:[NSBundle allBundles]];
        [roots addObjectsFromArray:[NSBundle allFrameworks]];
        for (NSBundle *b in roots) {
            if (![all containsObject:b]) [all addObject:b];
            NSString *bp = b.bundlePath;
            NSArray *subItems = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bp error:nil];
            for (NSString *item in subItems) {
                if (![item hasSuffix:@".bundle"]) continue;
                NSBundle *sb = [NSBundle bundleWithPath:[bp stringByAppendingPathComponent:item]];
                if (sb && ![all containsObject:sb]) [all addObject:sb];
            }
        }
        sBundles = [all copy];
    });
    return sBundles;
}

static UIImage *TTLoadImageFromAllBundles(NSArray *names) {
    for (NSString *nm in names) {
        if (![nm isKindOfClass:[NSString class]] || !nm.length) continue;
        UIImage *img = [UIImage imageNamed:nm];
        if (img) return img;
    }
    for (NSBundle *b in TTAllResourceBundles()) {
        for (NSString *nm in names) {
            if (![nm isKindOfClass:[NSString class]] || !nm.length) continue;
            UIImage *img = [UIImage imageNamed:nm inBundle:b compatibleWithTraitCollection:nil];
            if (img) return img;
        }
    }
    return nil;
}

static void TTApplyBadgeImageToView(id tipView, UIImage *img) {
    if (![tipView isKindOfClass:[UIView class]] || !img) return;
    if ([tipView isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)tipView;
        if ([btn imageForState:UIControlStateNormal] && ![btn backgroundImageForState:UIControlStateNormal]) {
            [btn setImage:img forState:UIControlStateNormal];
        } else {
            [btn setBackgroundImage:img forState:UIControlStateNormal];
        }
    } else if ([tipView isKindOfClass:[UIImageView class]]) {
        ((UIImageView *)tipView).image = img;
    }
    for (UIView *sub in ((UIView *)tipView).subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            ((UIImageView *)sub).image = img;
        } else if ([sub isKindOfClass:[UIButton class]]) {
            UIButton *b = (UIButton *)sub;
            if ([b imageForState:UIControlStateNormal] && ![b backgroundImageForState:UIControlStateNormal]) {
                [b setImage:img forState:UIControlStateNormal];
            } else {
                [b setBackgroundImage:img forState:UIControlStateNormal];
            }
        }
    }
}

static UIImage *TTLoadNobleBadgeImage(NSInteger nobleLv) {
    if (nobleLv <= 0) return nil;
    static NSMutableDictionary *sNobleCache = nil;
    if (!sNobleCache) sNobleCache = [[NSMutableDictionary alloc] init];
    UIImage *cached = sNobleCache[@(nobleLv)];
    if (cached) return cached;
    NSInteger idx = MAX(0, MIN(nobleLv - 1, 9));
    NSMutableArray *names = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"noble_%ld", (long)idx]];
    @try {
        Class pc = NSClassFromString(@"TTNobilityPrivilege");
        if (pc && [pc instancesRespondToSelector:@selector(initWithFLevel:visible:)]) {
            id priv = [((id (*)(id, SEL, float, BOOL))objc_msgSend)([pc alloc], @selector(initWithFLevel:visible:), TTNobleBandFLevel(nobleLv), YES) autorelease];
            for (NSString *selStr in @[@"exclusiveImageName", @"smallExclusiveImageName"]) {
                NSString *nm = TTGetObj(priv, NSSelectorFromString(selStr));
                if ([nm isKindOfClass:[NSString class]] && nm.length && ![names containsObject:nm]) [names insertObject:nm atIndex:0];
            }
        }
    } @catch (id e) {}
    UIImage *img = TTLoadImageFromAllBundles(names);
    if (img) sNobleCache[@(nobleLv)] = img;
    return img;
}

static UIImage *TTLoadMemberBadgeImage(NSInteger memberLv) {
    if (memberLv <= 0) return nil;
    NSInteger lv = MAX(1, MIN(memberLv, 8));
    static NSMutableDictionary *sMemberCache = nil;
    if (!sMemberCache) sMemberCache = [[NSMutableDictionary alloc] init];
    UIImage *cached = sMemberCache[@(lv)];
    if (cached) return cached;
    NSMutableArray *names = [NSMutableArray array];
    @try {
        Class pc = NSClassFromString(@"TTSuperPlayer");
        Class lCls = NSClassFromString(@"TTSuperPlayerLevel");
        id me = TTCMePlayer();
        id lvlObj = me ? (origC_getSuperPlayerLevel ? origC_getSuperPlayerLevel(me, @selector(getSuperPlayerLevel)) : TTGetObj(me, @selector(getSuperPlayerLevel))) : nil;
        if (!lvlObj && lCls) lvlObj = [[[lCls alloc] init] autorelease];
        if (lvlObj) {
            TTSyncMyLevelObject(lvlObj);
            if (pc && [pc respondsToSelector:@selector(getSuperLevelPngIcon:)]) {
                id pIcon = origC_getSuperLevelPngIcon
                    ? origC_getSuperLevelPngIcon((id)pc, @selector(getSuperLevelPngIcon:), lvlObj)
                    : ((id (*)(id, SEL, id))objc_msgSend)((id)pc, @selector(getSuperLevelPngIcon:), lvlObj);
                if ([pIcon isKindOfClass:[UIImage class]]) {
                    sMemberCache[@(lv)] = pIcon;
                    return (UIImage *)pIcon;
                }
                if ([pIcon isKindOfClass:[NSString class]] && [(NSString *)pIcon length]) [names addObject:pIcon];
            }
        }
        if (me && origC_getLevelIcon) {
            id mIcon = origC_getLevelIcon(me, @selector(getLevelIconIsNeedNoOpen:), NO);
            if ([mIcon isKindOfClass:[UIImage class]]) {
                sMemberCache[@(lv)] = mIcon;
                return (UIImage *)mIcon;
            }
            if ([mIcon isKindOfClass:[NSString class]] && [(NSString *)mIcon length]) [names addObject:mIcon];
        }
    } @catch (id e) {}
    [names addObjectsFromArray:@[
        [NSString stringWithFormat:@"svip_%ld", (long)lv],
        [NSString stringWithFormat:@"super_player_%ld", (long)lv],
        [NSString stringWithFormat:@"sp_level_%ld", (long)lv],
        [NSString stringWithFormat:@"icon_svip_%ld", (long)lv]
    ]];
    UIImage *img = TTLoadImageFromAllBundles(names);
    if (img) sMemberCache[@(lv)] = img;
    return img;
}

static void TTApplyNobleIconToTipView(id tipView, NSInteger nobleLv) {
    TTApplyBadgeImageToView(tipView, TTLoadNobleBadgeImage(nobleLv));
}

static id TTFindSuperPlayerViewInContext(id ctx) {
    if (!ctx) return nil;
    for (NSString *selStr in @[@"superPlayerView", @"superPlayerTipView", @"superPlayerBtn", @"svipView", @"vipView"]) {
        SEL sel = NSSelectorFromString(selStr);
        if ([ctx respondsToSelector:sel]) {
            id v = TTGetObj(ctx, sel);
            if ([v isKindOfClass:[UIView class]]) return v;
        }
    }
    @try {
        Class cls = [ctx class];
        for (int d = 0; cls && cls != [NSObject class] && d < 3; d++, cls = class_getSuperclass(cls)) {
            unsigned int count = 0;
            Ivar *ivars = class_copyIvarList(cls, &count);
            if (!ivars) continue;
            for (unsigned int i = 0; i < count; i++) {
                const char *type = ivar_getTypeEncoding(ivars[i]);
                const char *name = ivar_getName(ivars[i]);
                if (!type || type[0] != '@' || !name) continue;
                NSString *inm = [NSString stringWithUTF8String:name];
                if ([inm rangeOfString:@"superPlayer" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [inm rangeOfString:@"svip" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [inm rangeOfString:@"vip" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    if (!TTIvarTypeMatchesAny(type, name, @[@"UIView", @"UIButton", @"UIImageView", @"superPlayer", @"svip", @"vip"])) continue;
                    id val = object_getIvar(ctx, ivars[i]);
                    if ([val isKindOfClass:[UIView class]]) {
                        free(ivars);
                        return val;
                    }
                }
            }
            free(ivars);
        }
    } @catch (id e) {}
    return nil;
}

static void TTApplyMemberIconToContext(id ctx, NSInteger memberLv) {
    if (!ctx) return;
    @try {
        id spView = TTFindSuperPlayerViewInContext(ctx);
        if (memberLv <= 0) {
            if ([spView isKindOfClass:[UIView class]]) ((UIView *)spView).hidden = YES;
            return;
        }
        UIImage *img = TTLoadMemberBadgeImage(memberLv);
        if (spView && img) {
            ((UIView *)spView).hidden = NO;
            TTApplyBadgeImageToView(spView, img);
        }
    } @catch (id e) {}
}

static void (*origIdView_layoutSubviews)(id, SEL);
static NSMutableSet *gHookedIdViewClasses = nil;

static void TTIdView_layoutSubviews(id self, SEL _cmd) {
    if (origIdView_layoutSubviews) origIdView_layoutSubviews(self, _cmd);
    @try {
        NSNumber *isSelfTag = objc_getAssociatedObject(self, &kTTSelfPrivKey);
        if (isSelfTag && isSelfTag.boolValue && gCustomId.length && [self isKindOfClass:[UIView class]]) {
            TTRelabelIdSubtree((UIView *)self, gCustomId);
        }
    } @catch (id e) {}
}

static void TTEnsureIdViewClassHooked(UIView *v, BOOL isMe) {
    if (![v isKindOfClass:[UIView class]]) return;
    objc_setAssociatedObject(v, &kTTSelfPrivKey, @(isMe), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!isMe) return;
    Class cls = [v class];
    if (!cls || cls == [UIView class] || cls == [UILabel class] || cls == [UIButton class]) return;
    @synchronized (gHookedIdViewClasses) {
        if (!gHookedIdViewClasses) gHookedIdViewClasses = [[NSMutableSet alloc] init];
        if ([gHookedIdViewClasses containsObject:cls]) return;
        [gHookedIdViewClasses addObject:cls];
    }
    Method m = class_getInstanceMethod(cls, @selector(layoutSubviews));
    if (m) {
        IMP prev = method_getImplementation(m);
        if (prev != (IMP)TTIdView_layoutSubviews) {
            if (!origIdView_layoutSubviews) origIdView_layoutSubviews = (void (*)(id, SEL))prev;
            method_setImplementation(m, (IMP)TTIdView_layoutSubviews);
        }
    }
}

static BOOL TTContextEffectiveIsMe(id ctx) {
    if (!ctx) return NO;
    BOOL raw = origH_isMe ? origH_isMe(ctx, @selector(isMe)) : TTGetBool(ctx, @selector(isMe));
    if (raw) return YES;
    NSNumber *exp = objc_getAssociatedObject(ctx, &kTTCtxExplicitIsMeKey);
    if (exp != nil) return exp.boolValue;
    return NO;
}

static void TTSyncProfileContextOwnership(id ctx, BOOL isMe) {
    if (!ctx) return;
    TTSetLatestLayoutCtx(ctx);
    if (!isMe) {
        gActiveProfileIsOther = YES;
        gLastOtherProfileTs = CFAbsoluteTimeGetCurrent();
        TTSetLastOtherLayoutCtx(ctx);
    } else {
        gActiveProfileIsOther = NO;
        gLastOtherProfileTs = 0;
        TTSetLastSelfLayoutCtx(ctx);
        if (TTGetLastOtherLayoutCtx() == ctx) TTSetLastOtherLayoutCtx(nil);
    }
    @try {
        UIView *idv = TTGetObj(ctx, @selector(IdView));
        if ([idv isKindOfClass:[UIView class]]) TTEnsureIdViewClassHooked(idv, isMe);
        Class cls = [ctx class];
        for (int d = 0; cls && cls != [NSObject class] && d < 3; d++, cls = class_getSuperclass(cls)) {
            unsigned int count = 0;
            Ivar *ivars = class_copyIvarList(cls, &count);
            if (!ivars) continue;
            for (unsigned int i = 0; i < count; i++) {
                const char *type = ivar_getTypeEncoding(ivars[i]);
                const char *name = ivar_getName(ivars[i]);
                if (!TTIvarTypeMatchesAny(type, name, @[@"UGCUserInfo", @"SuperPlayer", @"NobilityPrivilege"])) continue;
                id val = object_getIvar(ctx, ivars[i]);
                if (!val) continue;
                NSString *vcn = NSStringFromClass([val class]);
                if ([vcn rangeOfString:@"UGCUserInfo"].location != NSNotFound ||
                    [vcn rangeOfString:@"SuperPlayer"].location != NSNotFound) {
                    uint32_t u = TTPlayerUidOf(val);
                    if (isMe && u > 0 && gSelfUid != u) {
                        gSelfUid = u;
                        [[NSUserDefaults standardUserDefaults] setObject:@(u) forKey:@"ttforge.selfUid"];
                    }
                    if (u > 0) TTTagNobilityInfoOnObject(val, u);
                } else if ([vcn rangeOfString:@"NobilityPrivilege"].location != NSNotFound) {
                    objc_setAssociatedObject(val, &kTTSelfPrivKey, @(isMe), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            }
            free(ivars);
        }
    } @catch (id e) {}
}

static void (*origH_updateNickLayout)(id, SEL);
static void (*origH_appear)(id, SEL, BOOL);
static void (*origH_nobleAppear)(id, SEL, BOOL);
static BOOL gInApplySelfBadges = NO;

static void TTApplySelfBadgesToContext(id ctx) {
    if (!ctx || gInApplySelfBadges) return;
    @try {
        BOOL isMe = TTContextEffectiveIsMe(ctx);
        if (!isMe) return;
        gInApplySelfBadges = YES;
        if (TTNobleForgeOn()) {
            if (origH_nobleAppear) origH_nobleAppear(ctx, @selector(handlerNobilityTipViewAppear:), YES);
            id btn = TTGetObj(ctx, @selector(nobilityTipView));
            if ([btn isKindOfClass:[UIView class]]) {
                ((UIView *)btn).hidden = NO;
                TTApplyNobleIconToTipView(btn, gNobleLevel);
            }
        }
        if (TTMemberForgeOn()) {
            if (origH_appear) origH_appear(ctx, @selector(handlerSuperPlayerViewAppear:), YES);
            TTApplyMemberIconToContext(ctx, gMemberLevel);
        }
        if (gCustomId.length) {
            UIView *idv = TTGetObj(ctx, @selector(IdView));
            if ([idv isKindOfClass:[UIView class]]) {
                TTEnsureIdViewClassHooked((UIView *)idv, YES);
                TTRelabelIdSubtree((UIView *)idv, gCustomId);
            }
        }
        if (origH_updateNickLayout) origH_updateNickLayout(ctx, @selector(handlerUpdateNickNameViewLayout));
        gInApplySelfBadges = NO;
    } @catch (id e) {
        gInApplySelfBadges = NO;
    }
}

static id (*origH_init)(id, SEL);
static id TTH_init(id self, SEL _cmd) {
    id r = origH_init ? origH_init(self, _cmd) : nil;
    if (r) TTSetLatestLayoutCtx(r);
    return r;
}

static void (*origH_setNobilityTipView)(id, SEL, id);
static void TTH_setNobilityTipView(id self, SEL _cmd, id v) {
    if (origH_setNobilityTipView) origH_setNobilityTipView(self, _cmd, v);
    @try {
        BOOL isMe = TTContextEffectiveIsMe(self);
        if (isMe && TTNobleForgeOn() && [v isKindOfClass:[UIView class]]) {
            if (origH_nobleAppear) origH_nobleAppear(self, @selector(handlerNobilityTipViewAppear:), YES);
            ((UIView *)v).hidden = NO;
            TTApplyNobleIconToTipView(v, gNobleLevel);
        }
    } @catch (id e) {}
}

static void TTH_updateNickLayout(id self, SEL _cmd) {
    BOOL isMe = NO;
    @try {
        isMe = TTContextEffectiveIsMe(self);
        if (isMe && TTNobleForgeOn()) {
            id btn = TTGetObj(self, @selector(nobilityTipView));
            if ([btn isKindOfClass:[UIView class]]) {
                ((UIView *)btn).hidden = NO;
                TTApplyNobleIconToTipView(btn, gNobleLevel);
            }
        }
    } @catch (id e) {}
    if (origH_updateNickLayout) origH_updateNickLayout(self, _cmd);
    if (isMe && TTMemberForgeOn()) {
        TTApplyMemberIconToContext(self, gMemberLevel);
    }
}

static void (*origH_setIsMe)(id, SEL, BOOL);
static void TTH_setIsMe(id self, SEL _cmd, BOOL isMe) {
    objc_setAssociatedObject(self, &kTTCtxExplicitIsMeKey, @(isMe), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (origH_setIsMe) origH_setIsMe(self, _cmd, isMe);
    TTSyncProfileContextOwnership(self, isMe);
    if (isMe) {
        TTApplySelfBadgesToContext(self);
    }
}

static BOOL TTH_isMe(id self, SEL _cmd) {
    BOOL isMe = origH_isMe ? origH_isMe(self, _cmd) : NO;
    TTSetLatestLayoutCtx(self);
    if (isMe) {
        gActiveProfileIsOther = NO;
        gLastOtherProfileTs = 0;
        TTSetLastSelfLayoutCtx(self);
        if (TTGetLastOtherLayoutCtx() == self) TTSetLastOtherLayoutCtx(nil);
    } else {
        gActiveProfileIsOther = YES;
        gLastOtherProfileTs = CFAbsoluteTimeGetCurrent();
        TTSetLastOtherLayoutCtx(self);
    }
    return isMe;
}

static id (*origH_idView)(id, SEL);
static id TTH_idView(id self, SEL _cmd) {
    id v = origH_idView ? origH_idView(self, _cmd) : nil;
    @try {
        BOOL isMe = TTContextEffectiveIsMe(self);
        if ([v isKindOfClass:[UIView class]]) {
            TTEnsureIdViewClassHooked((UIView *)v, isMe);
            if (isMe && gCustomId.length) TTRelabelIdSubtree((UIView *)v, gCustomId);
        }
    } @catch (id e) {}
    return v;
}

static void (*origH_setIdView)(id, SEL, id);
static void TTH_setIdView(id self, SEL _cmd, id v) {
    if (origH_setIdView) origH_setIdView(self, _cmd, v);
    @try {
        BOOL isMe = TTContextEffectiveIsMe(self);
        if ([v isKindOfClass:[UIView class]]) {
            TTEnsureIdViewClassHooked((UIView *)v, isMe);
            if (isMe && gCustomId.length) {
                TTRelabelIdSubtree((UIView *)v, gCustomId);
            }
        }
    } @catch (id e) {}
}

static void TTH_appear(id self, SEL _cmd, BOOL appear) {
    BOOL isMe = NO;
    @try {
        isMe = TTContextEffectiveIsMe(self);
        gLastPrivWasSelf = isMe;
        TTSyncProfileContextOwnership(self, isMe);
        if (isMe && TTMemberForgeOn()) appear = YES;
    } @catch (id e) {}
    NSMutableDictionary *ttd = [[NSThread currentThread] threadDictionary];
    if (isMe) [ttd setObject:@YES forKey:@"ttforge.nobleOK"];
    origH_appear(self, _cmd, appear);
    if (isMe) [ttd removeObjectForKey:@"ttforge.nobleOK"];
    @try {
        if (isMe && TTMemberForgeOn() && appear) TTApplyMemberIconToContext(self, gMemberLevel);
        if (isMe && TTNobleForgeOn()) {
            id btn = TTGetObj(self, @selector(nobilityTipView));
            if ([btn isKindOfClass:[UIView class]]) {
                ((UIView *)btn).hidden = NO;
                TTApplyNobleIconToTipView(btn, gNobleLevel);
            }
        }
    } @catch (id e) {}
}

static void TTH_nobleAppear(id self, SEL _cmd, BOOL appear) {
    BOOL isMe = NO;
    @try {
        isMe = TTContextEffectiveIsMe(self);
        gLastPrivWasSelf = isMe;
        TTSyncProfileContextOwnership(self, isMe);
        if (isMe && TTNobleForgeOn()) appear = YES;
    } @catch (id e) {}
    NSMutableDictionary *ttd = [[NSThread currentThread] threadDictionary];
    if (isMe) [ttd setObject:@YES forKey:@"ttforge.nobleOK"];
    origH_nobleAppear(self, _cmd, appear);
    if (isMe) [ttd removeObjectForKey:@"ttforge.nobleOK"];
    @try {
        if (!isMe || !TTNobleForgeOn() || !appear) return;
        id btn = TTGetObj(self, @selector(nobilityTipView));
        if (btn) {
            if ([btn isKindOfClass:[UIView class]]) ((UIView *)btn).hidden = NO;
            TTApplyNobleIconToTipView(btn, gNobleLevel);
        }
    } @catch (id e) {}
}

static void (*origH_didReloadData)(id, SEL, BOOL, id, id, id, id);
static void TTH_didReloadData(id self, SEL _cmd, BOOL isShow, id scanerViews, id photoDetailView, id pageBgView, id homeBgV) {
    BOOL isMe = NO;
    @try {
        id latestCtx = TTGetLatestLayoutCtx();
        if (latestCtx) {
            isMe = TTContextEffectiveIsMe(latestCtx);
        }
    } @catch (id e) {}
    NSMutableDictionary *ttd = [[NSThread currentThread] threadDictionary];
    if (isMe) [ttd setObject:@YES forKey:@"ttforge.nobleOK"];
    if (origH_didReloadData) origH_didReloadData(self, _cmd, isShow, scanerViews, photoDetailView, pageBgView, homeBgV);
    if (isMe) [ttd removeObjectForKey:@"ttforge.nobleOK"];
    @try {
        id latestCtx = TTGetLatestLayoutCtx();
        if (latestCtx) {
            isMe = TTContextEffectiveIsMe(latestCtx);
        }
        if (isMe) {
            id selfCtx = TTGetLastSelfLayoutCtx() ?: latestCtx;
            if (selfCtx && TTContextEffectiveIsMe(selfCtx)) {
                if (TTNobleForgeOn()) {
                    if (origH_nobleAppear) origH_nobleAppear(selfCtx, @selector(handlerNobilityTipViewAppear:), YES);
                    id btn = TTGetObj(selfCtx, @selector(nobilityTipView));
                    if (btn) TTApplyNobleIconToTipView(btn, gNobleLevel);
                }
                if (TTMemberForgeOn()) {
                    if (origH_appear) origH_appear(selfCtx, @selector(handlerSuperPlayerViewAppear:), YES);
                    TTApplyMemberIconToContext(selfCtx, gMemberLevel);
                }
                if (gCustomId.length) {
                    UIView *idv = TTGetObj(selfCtx, @selector(IdView));
                    if ([idv isKindOfClass:[UIView class]]) TTRelabelIdSubtree(idv, gCustomId);
                }
            }
            if ([self isKindOfClass:[UIViewController class]]) {
                UIView *v = ((UIViewController *)self).viewIfLoaded;
                if (v) TTDyeNicknameInSubtree(v);
            }
        }
    } @catch (id e) {}
}

static void (*origD2_getStatus)(id, SEL, uint32_t, id);
static void (*origD2_getList)(id, SEL, uint32_t, uint32_t, id);

static void TTSaveHideVisits(void) {
    @try {
        @synchronized (gHideVisits) {
            [[NSUserDefaults standardUserDefaults] setObject:gHideVisits forKey:@"ttforge.hideVisits"];
        }
    } @catch (id e) {}
}

static void TTD2_getStatus(id self, SEL _cmd, uint32_t uid, id callBack) {
    if (gBlockReport && uid != 0 && uid != gSelfUid) {
        NSString *key = [NSString stringWithFormat:@"%u", uid];
        @synchronized (gHideVisits) {
            NSNumber *c = gHideVisits[key];
            gHideVisits[key] = @((c ? c.intValue : 0) + 1);
        }
        TTSaveHideVisits();
    }
    origD2_getStatus(self, _cmd, uid, callBack);
    if (TTMemberForgeOn() && gBlockReport && uid != 0 && uid != gSelfUid) {
        BOOL shouldSend = YES;
        @synchronized (gHideSent) {
            if ([gHideSent containsObject:@(uid)]) shouldSend = NO;
            else [gHideSent addObject:@(uid)];
        }
        if (shouldSend && [self respondsToSelector:@selector(reqSetHideStatusWithUids:hideStatus:isAll:callBack:)]) {
            @try {
                id noop = [[^(id a, id b) {} copy] autorelease];
                ((void (*)(id, SEL, id, BOOL, BOOL, id))objc_msgSend)(self,
                    @selector(reqSetHideStatusWithUids:hideStatus:isAll:callBack:),
                    @[@(uid)], YES, NO, noop);
                TTLog(@"HIDELIST 主动发送 uid=%u（结果看随后 0x75cf 的 RPC 行）", uid);
            } @catch (id e) {}
        }
    }
}

static void TTD2_getList(id self, SEL _cmd, uint32_t offset, uint32_t limit, id callBack) {
    BOOL have = NO;
    @synchronized (gHideVisits) { have = gHideVisits.count > 0; }
    if (TTMemberForgeOn() && gBlockReport && have && callBack) {
        @try {
            Class respCls = NSClassFromString(@"GetHideListResp");
            Class userCls = NSClassFromString(@"UserVisitorRecordUser");
            Class baseCls = NSClassFromString(@"TTBaseResp");
            if (respCls && userCls) {
                NSMutableArray *arr = [NSMutableArray array];
                @synchronized (gHideVisits) {
                    for (NSString *uidKey in gHideVisits) {
                        id u = [[userCls alloc] init];
                        TTSetU32(u, @selector(setUid:), (uint32_t)uidKey.intValue);
                        NSDictionary *rec = nil;
                        @synchronized (gHits) { rec = gHits[@(uidKey.intValue)]; }
                        NSString *nm = rec[@"nickname"];
                        NSString *ac = rec[@"account"];
                        if (nm.length) TTSetObj(u, @selector(setName:), nm);
                        if (ac.length) TTSetObj(u, @selector(setAccount:), ac);
                        [arr addObject:u];
                        [u release];
                    }
                }
                id resp = [[respCls alloc] init];
                if (baseCls) {
                    id base = [[baseCls alloc] init];
                    TTSetU32(base, @selector(setRet:), 0);
                    TTSetObj(resp, @selector(setBaseResp:), base);
                    [base release];
                }
                TTSetObj(resp, @selector(setListArray:), arr);
                ((void (^)(id, id))callBack)(resp, nil);
                [resp release];
                return;
            }
        } @catch (id e) {}
    }
    origD2_getList(self, _cmd, offset, limit, callBack);
}

static int64_t (*origE_realSendType)(id, SEL);
static int64_t TTE_realSendType(id self, SEL _cmd) {
    int64_t v = origE_realSendType(self, _cmd);
    if (TTMemberForgeOn() && v == 0x51) {
        TTLog(@"EMOJI 会员表情按普通表情投递 (type 0x51→0x27)");
        return 0x27;
    }
    return v;
}

typedef NS_ENUM(NSInteger, TTTaskPatchKind) {
    TTTaskPatchNone  = 0,
    TTTaskPatchSP    = 1,
    TTTaskPatchNoble = 2,
    TTTaskPatchYKW   = 3,
};

static BOOL (*origK_switch)(id, SEL, id, BOOL);
static BOOL TTK_switch(id self, SEL _cmd, id key, BOOL def) {
    if ((gH5Capture || TTH5ForgeActive()) && [key isKindOfClass:[NSString class]] &&
        [key isEqualToString:@"wkwebview_request_scheme_handler_hook"]) return YES;
    return origK_switch(self, _cmd, key, def);
}

static BOOL (*origK_lab)(id, SEL);
static BOOL TTK_lab(id self, SEL _cmd) {
    return (gH5Capture || TTH5ForgeActive()) ? YES : origK_lab(self, _cmd);
}

static NSMutableDictionary *gTaskURL = nil;
static NSMutableDictionary *gTaskBody = nil;
static NSMutableDictionary *gTaskCode = nil;
static NSMutableSet *gTaskClasses = nil;
static NSMutableDictionary *gTaskPatchKind = nil;
static NSMutableDictionary *gTaskRespObj = nil;

static BOOL TTH5StaticURL(NSURL *u) {
    NSString *p = u.path.lowercaseString;
    for (NSString *ext in @[@".js", @".css", @".png", @".jpg", @".jpeg", @".gif", @".webp", @".woff", @".woff2", @".ttf", @".svg", @".ico", @".map"]) {
        if ([p hasSuffix:ext]) return YES;
    }
    return NO;
}

static void TTTaskFlush(id task, NSString *note) {
    @try {
        NSValue *k = [NSValue valueWithPointer:task];
        NSURL *u = nil; NSNumber *code = nil; NSData *body = nil;
        @synchronized (gTaskURL) {
            u = [[gTaskURL[k] retain] autorelease];
            code = [[gTaskCode[k] retain] autorelease];
            body = [[gTaskBody[k] retain] autorelease];
            [gTaskURL removeObjectForKey:k];
            [gTaskCode removeObjectForKey:k];
            [gTaskBody removeObjectForKey:k];
        }
        if (!u || !gH5Capture) return;
        NSString *bs = body.length ? [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] : nil;
        TTLog(@"H5 %@ -> %@ (%luB)%@\n%@", u.absoluteString, code ?: @"-", (unsigned long)body.length,
              note ? [@" " stringByAppendingString:note] : @"", bs ?: @"<非文本或空>");
        [bs release];
    } @catch (id e) {}
}

static void TTSPPatchWalk(id node, int depth, long long now, long long far, BOOL *hit) {
    if (!node || depth > 7) return;
    if ([node isKindOfClass:[NSArray class]]) {
        for (id c in (NSArray *)node) TTSPPatchWalk(c, depth + 1, now, far, hit);
        return;
    }
    if (![node isKindOfClass:[NSMutableDictionary class]]) return;
    NSMutableDictionary *d = (NSMutableDictionary *)node;
    long lv = MIN(MAX(gMemberLevel, 1), 8);
    uint64_t val = TTMemberGrowthCap(lv);
    if (d[@"super_player_level"] || d[@"svip_status"] || d[@"super_player_value"] || d[@"super_player_type"] || d[@"svip_expire_timestamp"]) {
        d[@"status"] = @1;
        d[@"svip_status"] = @1;
        d[@"vip_status"] = @1;
        d[@"super_player_status"] = @1;
        d[@"super_player_type"] = @4;
        d[@"superPlayerType"] = @4;
        d[@"year_member_status"] = @1;
        d[@"svip_year_member_status"] = @1;
        d[@"is_svip"] = @1;
        d[@"is_super_player"] = @1;
        d[@"is_year_member"] = @1;
        d[@"super_player_level"] = @(lv);
        d[@"super_player_value"] = @(val);
        d[@"has_expired"] = @NO;
        d[@"is_svip_first"] = @NO;
        d[@"expire_timestamp"] = @(far);
        d[@"svip_expire_timestamp"] = @(far);
        d[@"year_member_expire_ts"] = @(far);
        d[@"svip_year_member_expire_timestamp"] = @(far);
        if (![(NSNumber *)d[@"begin_timestamp"] longLongValue]) d[@"begin_timestamp"] = @(now - 86400);
        if (![(NSNumber *)d[@"svip_begin_timestamp"] longLongValue]) d[@"svip_begin_timestamp"] = @(now - 86400);
        d[@"super_player_left_days"] = @9999;
        d[@"svip_left_days"] = @9999;
        *hit = YES;
    }
    for (NSString *okKey in @[@"is_open", @"isOpen", @"open", @"can_use", @"canUse", @"is_own", @"isOwn", @"owned",
                              @"is_unlock", @"isUnlock", @"unlock", @"unlocked", @"is_enable", @"enable", @"enabled",
                              @"is_active", @"active", @"has_privilege", @"hasPrivilege", @"is_have", @"is_get",
                              @"privilege_status", @"right_status", @"user_status", @"auth_status"]) {
        if (d[okKey] != nil) { d[okKey] = @1; *hit = YES; }
    }
    for (NSString *noKey in @[@"is_lock", @"isLock", @"lock", @"locked", @"need_open", @"needOpen", @"need_svip", @"needSvip", @"is_expired", @"expired"]) {
        if (d[noKey] != nil) { d[noKey] = @0; *hit = YES; }
    }
    for (id k in [d allKeys]) TTSPPatchWalk(d[k], depth + 1, now, far, hit);
}

static NSData *TTSPPatchData(NSData *body) {
    @try {
        id root = [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:nil];
        if (![root isKindOfClass:[NSMutableDictionary class]]) return nil;
        NSMutableDictionary *r = (NSMutableDictionary *)root;
        long long now = [(NSNumber *)r[@"server_time"] longLongValue];
        if (!now) now = (long long)[[NSDate date] timeIntervalSince1970];
        long long far = now + 315360000LL;
        BOOL hit = NO;
        id data = r[@"data"];
        if ([data isKindOfClass:[NSMutableDictionary class]]) {
            NSMutableDictionary *d = (NSMutableDictionary *)data;
            long lv = MIN(MAX(gMemberLevel, 1), 8);
            d[@"status"] = @1;
            d[@"svip_status"] = @1;
            d[@"vip_status"] = @1;
            d[@"super_player_status"] = @1;
            d[@"super_player_type"] = @4;
            d[@"superPlayerType"] = @4;
            d[@"year_member_status"] = @1;
            d[@"svip_year_member_status"] = @1;
            d[@"is_svip"] = @1;
            d[@"is_super_player"] = @1;
            d[@"is_year_member"] = @1;
            d[@"super_player_level"] = @(lv);
            d[@"super_player_value"] = @(TTMemberGrowthCap(lv));
            d[@"has_expired"] = @NO;
            d[@"is_svip_first"] = @NO;
            d[@"expire_timestamp"] = @(far);
            d[@"svip_expire_timestamp"] = @(far);
            d[@"year_member_expire_ts"] = @(far);
            d[@"svip_year_member_expire_timestamp"] = @(far);
            if (![(NSNumber *)d[@"begin_timestamp"] longLongValue]) d[@"begin_timestamp"] = @(now - 86400);
            if (![(NSNumber *)d[@"svip_begin_timestamp"] longLongValue]) d[@"svip_begin_timestamp"] = @(now - 86400);
            d[@"super_player_left_days"] = @9999;
            d[@"svip_left_days"] = @9999;
            hit = YES;
        }
        TTSPPatchWalk(r, 0, now, far, &hit);
        return hit ? [NSJSONSerialization dataWithJSONObject:r options:0 error:nil] : nil;
    } @catch (id e) { return nil; }
}

static void TTNoblePatchWalk(id node, int depth, BOOL *hit) {
    if (!node || depth > 7) return;
    if ([node isKindOfClass:[NSArray class]]) {
        for (id c in (NSArray *)node) TTNoblePatchWalk(c, depth + 1, hit);
        return;
    }
    if (![node isKindOfClass:[NSMutableDictionary class]]) return;
    NSMutableDictionary *d = (NSMutableDictionary *)node;
    id u = d[@"userInfo"];
    if ([u isKindOfClass:[NSMutableDictionary class]] && [(NSDictionary *)u objectForKey:@"realLevel"]) {
        NSMutableDictionary *mu = (NSMutableDictionary *)u;
        uint32_t h5Uid = [mu[@"uid"] respondsToSelector:@selector(unsignedIntValue)] ? [mu[@"uid"] unsignedIntValue] : 0;
        NSString *h5Acc = [mu[@"account"] isKindOfClass:[NSString class]] ? mu[@"account"] : nil;
        NSString *h5Nick = [mu[@"nickName"] isKindOfClass:[NSString class]] ? mu[@"nickName"] : nil;
        if (h5Uid > 0) {
            if (!gSelfUid) {
                gSelfUid = h5Uid;
                [[NSUserDefaults standardUserDefaults] setObject:@(h5Uid) forKey:@"ttforge.selfUid"];
            }
            TTCountHit(h5Uid, h5Nick, h5Acc);
        }
        long NL = MIN(MAX(gNobleLevel, 1), 10);
        long raw = NL - 1;
        uint64_t keep = TTNobleKeepCap(NL);
        mu[@"level"] = @(raw);
        mu[@"realLevel"] = @(raw);
        mu[@"nobilityValue"] = @(TTNobleValueCap(NL));
        mu[@"relagationValue"] = @(keep);
        mu[@"curTopRelagationVal"] = @(keep);
        mu[@"rechargeVal"] = @1;
        mu[@"consumeVal"] = @1;
        mu[@"remainDay"] = @9999;
        mu[@"tempNobilityRemainTs"] = @0;
        if (gCustomId.length) mu[@"account"] = gCustomId;
        *hit = YES;
    }
    for (id k in [d allKeys]) TTNoblePatchWalk(d[k], depth + 1, hit);
}

static void TTYKWPatchWalk(id node, int depth, BOOL *hit) {
    if (!node || depth > 7) return;
    if ([node isKindOfClass:[NSArray class]]) {
        for (id c in (NSArray *)node) TTYKWPatchWalk(c, depth + 1, hit);
        return;
    }
    if (![node isKindOfClass:[NSMutableDictionary class]]) return;
    NSMutableDictionary *d = (NSMutableDictionary *)node;
    if ([d objectForKey:@"nob_level"] && ([d objectForKey:@"nob_name"] || [d objectForKey:@"ykw_conf"])) {
        long NL = MIN(MAX(gNobleLevel, 1), 10);
        long long st = [(NSNumber *)[d objectForKey:@"server_time"] longLongValue];
        if (!st) st = (long long)[[NSDate date] timeIntervalSince1970];
        long long exp = [(NSNumber *)[d objectForKey:@"expire_time"] longLongValue];
        d[@"nob_level"] = @(NL);
        d[@"nob_name"] = TTNobleTitleForLevel(NL);
        d[@"can_be_open"] = @1;
        d[@"status"] = @1;
        d[@"switch"] = @1;
        d[@"is_open_enter_stealth"] = @1;
        d[@"enter_notice"] = @1;
        if (!exp || exp < st + 86400) d[@"expire_time"] = @(st + 3153600000LL);
        id nick = [d objectForKey:@"nickname"];
        if (!nick || nick == [NSNull null] || ([nick isKindOfClass:[NSString class]] && [(NSString *)nick length] == 0))
            d[@"nickname"] = @"888888";
        *hit = YES;
    }
    for (id k in [d allKeys]) TTYKWPatchWalk(d[k], depth + 1, hit);
}

static NSData *TTWalkPatchJSONData(NSData *body, void (*walker)(id, int, BOOL *)) {
    @try {
        id root = [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:nil];
        if (!root) return nil;
        BOOL hit = NO;
        walker(root, 0, &hit);
        return hit ? [NSJSONSerialization dataWithJSONObject:root options:0 error:nil] : nil;
    } @catch (id e) { return nil; }
}

static TTTaskPatchKind TTTaskGetPatchInfo(id task, id *outResp, NSData **outRaw) {
    NSValue *k = [NSValue valueWithPointer:task];
    TTTaskPatchKind kind = TTTaskPatchNone;
    @synchronized (gTaskURL) {
        kind = (TTTaskPatchKind)[gTaskPatchKind[k] integerValue];
        if (kind != TTTaskPatchNone) {
            if (outResp) *outResp = [[gTaskRespObj[k] retain] autorelease];
            if (outRaw) *outRaw = [[(NSData *)gTaskBody[k] retain] autorelease];
        }
    }
    return kind;
}

static void TTTaskSPCleanup(id task) {
    NSValue *k = [NSValue valueWithPointer:task];
    @synchronized (gTaskURL) {
        [gTaskPatchKind removeObjectForKey:k];
        [gTaskRespObj removeObjectForKey:k];
        [gTaskBody removeObjectForKey:k];
        [gTaskURL removeObjectForKey:k];
        [gTaskCode removeObjectForKey:k];
    }
}

static void (*origTaskResp)(id, SEL, id);
static void TTTaskResp(id self, SEL _cmd, id resp) {
    @try {
        NSValue *k = [NSValue valueWithPointer:self];
        TTTaskPatchKind kind = TTTaskPatchNone;
        @synchronized (gTaskURL) { kind = (TTTaskPatchKind)[gTaskPatchKind[k] integerValue]; }
        if (kind != TTTaskPatchNone) {
            @synchronized (gTaskURL) {
                if (!gTaskRespObj) gTaskRespObj = [[NSMutableDictionary alloc] init];
                if (resp) gTaskRespObj[k] = resp;
            }
            if (kind == TTTaskPatchSP) TTLog(@"SPPATCH 已扣住响应，待改写投递");
            return;
        }
        if ([resp isKindOfClass:[NSHTTPURLResponse class]]) {
            @synchronized (gTaskURL) { gTaskCode[k] = @(((NSHTTPURLResponse *)resp).statusCode); }
        }
    } @catch (id e) {}
    origTaskResp(self, _cmd, resp);
}

static void (*origTaskData)(id, SEL, id);
static void TTTaskData(id self, SEL _cmd, id data) {
    @try {
        NSValue *k = [NSValue valueWithPointer:self];
        TTTaskPatchKind kind = TTTaskPatchNone;
        @synchronized (gTaskURL) { kind = (TTTaskPatchKind)[gTaskPatchKind[k] integerValue]; }
        if (kind != TTTaskPatchNone) {
            @synchronized (gTaskURL) {
                NSMutableData *acc = gTaskBody[k];
                if (!acc) { acc = [NSMutableData data]; gTaskBody[k] = acc; }
                if (acc.length < 262144) [acc appendData:data];
            }
            return;
        }
        @synchronized (gTaskURL) {
            NSURL *u = gTaskURL[k];
            if (u && !TTH5StaticURL(u)) {
                NSMutableData *acc = gTaskBody[k];
                if (!acc) { acc = [NSMutableData data]; gTaskBody[k] = acc; }
                if (acc.length < 32768) [acc appendData:data];
            }
        }
    } @catch (id e) {}
    origTaskData(self, _cmd, data);
}

static void (*origTaskFinish)(id, SEL);
static void TTTaskFinish(id self, SEL _cmd) {
    id resp = nil; NSData *raw = nil;
    TTTaskPatchKind kind = TTTaskGetPatchInfo(self, &resp, &raw);
    if (kind != TTTaskPatchNone) {
        NSData *patched = nil;
        if (raw) {
            if (kind == TTTaskPatchNoble) patched = TTWalkPatchJSONData(raw, TTNoblePatchWalk);
            else if (kind == TTTaskPatchYKW) patched = TTWalkPatchJSONData(raw, TTYKWPatchWalk);
            else if (kind == TTTaskPatchSP) patched = TTSPPatchData(raw);
        }
        id outResp = resp;
        NSData *outData = patched ?: raw;
        @try {
            if (patched && [resp isKindOfClass:[NSHTTPURLResponse class]]) {
                NSHTTPURLResponse *hr = (NSHTTPURLResponse *)resp;
                NSMutableDictionary *hdrs = [[hr allHeaderFields] mutableCopy];
                if (hdrs) {
                    for (NSString *hk in [hdrs allKeys]) {
                        if ([hk caseInsensitiveCompare:@"Content-Length"] == NSOrderedSame)
                            hdrs[hk] = [NSString stringWithFormat:@"%lu", (unsigned long)patched.length];
                    }
                    outResp = [[[NSHTTPURLResponse alloc] initWithURL:hr.URL statusCode:hr.statusCode HTTPVersion:@"HTTP/1.1" headerFields:hdrs] autorelease];
                    [hdrs release];
                }
            }
        } @catch (id e) { outResp = resp; }
        unsigned long rawLen = (unsigned long)(raw ? raw.length : 0);
        unsigned long outLen = (unsigned long)(outData ? outData.length : 0);
        if (kind == TTTaskPatchNoble) {
            TTLog(@"NOBPATCH nobility/init 响应已改写 原始编号 level=%ld value=%ld (%luB->%luB)",
                  (long)(gNobleLevel > 0 ? gNobleLevel - 1 : 0), (long)TTNobleValueCap(gNobleLevel), rawLen, outLen);
        } else if (kind == TTTaskPatchYKW) {
            TTLog(@"YKWPATCH getYKW 响应已改写 nob_level=%ld (%luB->%luB)", (long)gNobleLevel, rawLen, outLen);
        } else {
            TTLog(@"SPPATCH getSuperPlayerInfo 响应已改写 status=1 svip_status=1 level=%ld value=%llu (%luB->%luB)",
                  (long)gMemberLevel, (unsigned long long)TTMemberGrowthCap(gMemberLevel), rawLen, outLen);
        }
        TTTaskSPCleanup(self);
        if (outResp) origTaskResp(self, @selector(didReceiveResponse:), outResp);
        if (outData) origTaskData(self, @selector(didReceiveData:), outData);
        origTaskFinish(self, _cmd);
        return;
    }
    TTTaskFlush(self, nil);
    origTaskFinish(self, _cmd);
}

static void (*origTaskFail)(id, SEL, id);
static void TTTaskFail(id self, SEL _cmd, id err) {
    id resp = nil; NSData *raw = nil;
    if (TTTaskGetPatchInfo(self, &resp, &raw) != TTTaskPatchNone) {
        TTTaskSPCleanup(self);
        if (resp) origTaskResp(self, @selector(didReceiveResponse:), resp);
        if (raw) origTaskData(self, @selector(didReceiveData:), raw);
        origTaskFail(self, _cmd, err);
        return;
    }
    TTTaskFlush(self, [NSString stringWithFormat:@"失败 %@", err]);
    origTaskFail(self, _cmd, err);
}

static void TTSwizzleTaskClass(Class cls) {
    @synchronized (gTaskClasses) {
        if ([gTaskClasses containsObject:cls]) return;
        [gTaskClasses addObject:cls];
    }
    TTSwizzle(cls, @selector(didReceiveResponse:), (IMP)TTTaskResp, (IMP *)&origTaskResp);
    TTSwizzle(cls, @selector(didReceiveData:), (IMP)TTTaskData, (IMP *)&origTaskData);
    TTSwizzle(cls, @selector(didFinish), (IMP)TTTaskFinish, (IMP *)&origTaskFinish);
    TTSwizzle(cls, @selector(didFailWithError:), (IMP)TTTaskFail, (IMP *)&origTaskFail);
}

static void (*origK_start)(id, SEL, id, id);
static void TTK_start(id self, SEL _cmd, id webView, id task) {
    @try {
        if ((gH5Capture || TTH5ForgeActive()) && task) {
            id req = TTGetObj(task, @selector(request));
            NSURL *u = TTGetObj(req, @selector(URL));
            if (u) {
                NSString *ext = u.pathExtension.lowercaseString ?: @"";
                static NSSet *staticExts = nil;
                if (!staticExts) {
                    staticExts = [[NSSet alloc] initWithArray:@[
                        @"js", @"css", @"png", @"jpg", @"jpeg", @"gif", @"webp", @"svg",
                        @"woff", @"woff2", @"ttf", @"ico", @"mp3", @"mp4", @"wav", @"pag", @"svga", @"vap", @"map"
                    ]];
                }
                if (![staticExts containsObject:ext]) {
                    NSValue *k = [NSValue valueWithPointer:task];
                    @synchronized (gTaskURL) { gTaskURL[k] = u; }
                    TTSwizzleTaskClass(object_getClass(task));
                    static int h5apiLog = 0;
                    if (TTH5ForgeActive() && h5apiLog < 60 && ![ext isEqualToString:@"html"]) {
                        h5apiLog++;
                        TTLog(@"H5API %@ %@", TTGetObj(req, @selector(HTTPMethod)) ?: @"GET", u.absoluteString);
                    }
                    NSString *urlStr = u.absoluteString;
                    if (TTH5ForgeActive()) {
                        if (TTMemberForgeOn() && [urlStr rangeOfString:@"getSuperPlayerInfo" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                            @synchronized (gTaskURL) { gTaskPatchKind[k] = @(TTTaskPatchSP); }
                            TTLog(@"SPPATCH 已标记 getSuperPlayerInfo 任务待改写");
                        } else if (TTNobleForgeOn() && [urlStr rangeOfString:@"nobility/init" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                            @synchronized (gTaskURL) { gTaskPatchKind[k] = @(TTTaskPatchNoble); }
                            TTLog(@"NOBPATCH 已标记 nobility/init 任务待改写");
                        } else if (TTNobleForgeOn() && [urlStr rangeOfString:@"youknowwho/getYKW" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                            @synchronized (gTaskURL) { gTaskPatchKind[k] = @(TTTaskPatchYKW); }
                            TTLog(@"YKWPATCH 已标记 getYKW 任务待改写");
                        }
                    }
                    if (gH5Capture) {
                        NSData *b = TTGetObj(req, @selector(HTTPBody));
                        NSString *bs = b.length ? [[[NSString alloc] initWithData:b encoding:NSUTF8StringEncoding] autorelease] : nil;
                        TTLog(@"H5 请求 %@ %@%@", TTGetObj(req, @selector(HTTPMethod)) ?: @"GET", urlStr,
                              bs ? [NSString stringWithFormat:@" body=%@", bs] : @"");
                    }
                }
            }
        }
    } @catch (id e) {}
    origK_start(self, _cmd, webView, task);
}

static void (*origM_setTabs)(id, SEL, id);
static void TTM_setTabs(id self, SEL _cmd, id tabs) {
    if (self && !gMagicMgr) gMagicMgr = [self retain];
    origM_setTabs(self, _cmd, tabs);
    @try {
        if (!TTMemberForgeOn() || !tabs) return;
        int flipped = 0;
        for (id tab in (NSArray *)tabs) {
            for (id res in (NSArray *)TTGetObj(tab, @selector(itemsArray))) {
                if ([res respondsToSelector:@selector(setCanUse:)]) {
                    TTSetBool(res, @selector(setCanUse:), YES);
                    flipped++;
                }
            }
        }
        if (flipped) TTLog(@"MAGIC 房内魔法表情 canUse 已放行 %d 项", flipped);
    } @catch (id e) {}
}

static void TTM_recordPushInfoTarget(id target) {
    if (!target || !gMagicEchoTargets) return;
    if ([NSStringFromClass([target class]) isEqualToString:@"TTChannelNewMagicExpressionMsg"]) return;
    @synchronized (gMagicEchoTargets) { [gMagicEchoTargets addObject:target]; }
}

static id (*origM_vmInit)(id, SEL, uint32_t, id, id);
static id TTM_vmInit(id self, SEL _cmd, uint32_t micId, id lotView, id lotBgView) {
    id r = origM_vmInit ? origM_vmInit(self, _cmd, micId, lotView, lotBgView) : nil;
    if (r && gMagicVMs) {
        @synchronized (gMagicVMs) { [gMagicVMs addObject:r]; }
        if (micId < 32 && !(gMagicVMLogged & (1u << micId))) {
            gMagicVMLogged |= (1u << micId);
            TTLog(@"MAGIC 捕获 MicPlayerVM micId=%u class=%@", micId, NSStringFromClass([r class]));
        }
    }
    return r;
}

static id (*origM_currentVM)(id, SEL);
static id TTM_currentVM(id self, SEL _cmd) {
    id vm = origM_currentVM ? origM_currentVM(self, _cmd) : nil;
    if (vm && vm != gMagicCurrentVM) { [gMagicCurrentVM release]; gMagicCurrentVM = [vm retain]; }
    return vm;
}

static BOOL (*origM_startGame)(id, SEL);
static BOOL TTM_startGame(id self, SEL _cmd) {
    if (TTMemberForgeOn()) return NO;
    return origM_startGame ? origM_startGame(self, _cmd) : NO;
}

static uint32_t (*origM_getStartEmoji)(id, SEL);
static uint32_t TTM_getStartEmoji(id self, SEL _cmd) {
    if (TTMemberForgeOn()) return 0;
    return origM_getStartEmoji ? origM_getStartEmoji(self, _cmd) : 0;
}

static BOOL (*origM_startEmojiStatus)(id, SEL);
static BOOL TTM_startEmojiStatus(id self, SEL _cmd) {
    if (TTMemberForgeOn()) return NO;
    return origM_startEmojiStatus ? origM_startEmojiStatus(self, _cmd) : NO;
}

static id TTCommonServiceCenter(void) {
    Class cscCls = NSClassFromString(@"CommonServiceCenter");
    return (cscCls && [cscCls respondsToSelector:@selector(defaultCenter)])
        ? ((id (*)(id, SEL))objc_msgSend)(cscCls, @selector(defaultCenter)) : nil;
}

static void TTTriggerLocalMagicEcho(uint32_t tabId, uint32_t magicId) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            Class pushCls = NSClassFromString(@"MagicExpressionPush");
            if (!pushCls) return;
            id center = TTCommonServiceCenter();
            if (!gMagicMgr && center && [center respondsToSelector:@selector(getService:)]) {
                Class mgrCls = NSClassFromString(@"ChannelMagicExpressionManager");
                if (mgrCls) {
                    id svc = ((id (*)(id, SEL, Class))objc_msgSend)(center, @selector(getService:), mgrCls);
                    if (svc) gMagicMgr = [svc retain];
                }
            }
            id push = [[pushCls alloc] init];
            NSString *md5 = nil;
            if (gMagicMgr && [gMagicMgr respondsToSelector:@selector(getChannelMagicExpressionWithTabId:magicId:)]) {
                id res = ((id (*)(id, SEL, uint32_t, uint32_t))objc_msgSend)(gMagicMgr, @selector(getChannelMagicExpressionWithTabId:magicId:), tabId, magicId);
                if (res) md5 = TTGetObj(res, @selector(md5));
            }
            NSString *msgId = [NSString stringWithFormat:@"ttforge_%llu", (unsigned long long)([[NSDate date] timeIntervalSince1970] * 1000)];
            TTSetObj(push, @selector(setMsgId:), msgId);
            uint32_t micForPush = gMagicCurrentVM ? TTGetU32(gMagicCurrentVM, @selector(micId)) : gMagicLastMicId;
            TTSetU32(push, @selector(setMicId:), micForPush);
            TTSetU32(push, @selector(setUid:), gMagicLastUid ?: gSelfUid);
            TTSetU32(push, @selector(setMagicTabId:), tabId);
            TTSetU32(push, @selector(setMagicId:), magicId);
            if (md5) TTSetObj(push, @selector(setMd5:), md5);
            uint64_t nowMs = gMagicLastSendTimeMs ?: (uint64_t)([[NSDate date] timeIntervalSince1970] * 1000);
            TTSetU64(push, @selector(setSendTimeMs:), nowMs);

            NSData *pbData = TTGetObj(push, @selector(data));
            Class msgCls = NSClassFromString(@"TTChannelNewMagicExpressionMsg");
            Class infoCls = NSClassFromString(@"ChannelMagicExpressionPushInfo");
            id pushInfo = nil;
            int ways = 0;

            if (pbData && msgCls) {
                id msgObj = [[msgCls alloc] init];
                if ([msgObj respondsToSelector:@selector(dealForPbData:andContent:)]) {
                    ((void (*)(id, SEL, id, id))objc_msgSend)(msgObj, @selector(dealForPbData:andContent:), pbData, nil);
                    ways++;
                }
                pushInfo = TTGetObj(msgObj, @selector(pushInfo));
                if (center && [center respondsToSelector:@selector(getService:)]) {
                    for (NSString *svcName in @[@"CommonChannelService", @"ChannelMsgService", @"RoomMessageService"]) {
                        Class sCls = NSClassFromString(svcName);
                        if (!sCls) continue;
                        id svc = ((id (*)(id, SEL, Class))objc_msgSend)(center, @selector(getService:), sCls);
                        for (NSString *selStr in @[@"onReceiveChannelMsg:", @"handleChannelMsg:", @"dispatchChannelMsg:", @"receiveChannelMsg:"]) {
                            SEL s = NSSelectorFromString(selStr);
                            if (svc && [svc respondsToSelector:s]) {
                                TTSetObj(svc, s, msgObj);
                                ways++;
                            }
                        }
                    }
                }
                [msgObj release];
            }

            if (!pushInfo && infoCls && [infoCls respondsToSelector:@selector(modelWithPb:)])
                pushInfo = ((id (*)(id, SEL, id))objc_msgSend)(infoCls, @selector(modelWithPb:), push);
            if (pushInfo) [pushInfo retain];

            if (pushInfo && msgCls) {
                id vmMsg = [[msgCls alloc] init];
                if (pbData && [vmMsg respondsToSelector:@selector(dealForPbData:andContent:)])
                    ((void (*)(id, SEL, id, id))objc_msgSend)(vmMsg, @selector(dealForPbData:andContent:), pbData, nil);
                else
                    TTSetObj(vmMsg, @selector(setPushInfo:), pushInfo);
                NSArray *vms = nil;
                if (gMagicVMs) {
                    @synchronized (gMagicVMs) { vms = [[gMagicVMs allObjects] retain]; }
                }
                int vmHits = 0;
                if (gMagicCurrentVM && [gMagicCurrentVM respondsToSelector:@selector(onNewMagicExpressionMsgCome:)]) {
                    TTSetObj(gMagicCurrentVM, @selector(onNewMagicExpressionMsgCome:), vmMsg);
                    ways++; vmHits++;
                    TTLog(@"MAGIC 当前麦 VM 回放 mic=%u class=%@", TTGetU32(gMagicCurrentVM, @selector(micId)),
                          NSStringFromClass([gMagicCurrentVM class]));
                }
                for (id vm in vms) {
                    if (vm == gMagicCurrentVM) continue;
                    uint32_t mic = TTGetU32(vm, @selector(micId));
                    if (mic == gMagicLastMicId && [vm respondsToSelector:@selector(onNewMagicExpressionMsgCome:)]) {
                        TTSetObj(vm, @selector(onNewMagicExpressionMsgCome:), vmMsg);
                        ways++; vmHits++;
                        TTLog(@"MAGIC VM 回放 mic=%u class=%@", mic, NSStringFromClass([vm class]));
                    }
                }
                if (!vmHits && vms.count == 1) {
                    id vm = vms.firstObject;
                    if ([vm respondsToSelector:@selector(onNewMagicExpressionMsgCome:)]) {
                        TTSetObj(vm, @selector(onNewMagicExpressionMsgCome:), vmMsg);
                        ways++; vmHits++;
                        TTLog(@"MAGIC VM 回放(唯一实例) mic=%u", TTGetU32(vm, @selector(micId)));
                    }
                }
                [vms release];
                [vmMsg release];
            }

            if (pushInfo) {
                if (gMagicMgr && [gMagicMgr respondsToSelector:@selector(setPushInfo:)]) {
                    TTSetObj(gMagicMgr, @selector(setPushInfo:), pushInfo);
                    ways++;
                }
                if (gMagicEchoTargets) {
                    NSArray *allTargets = nil;
                    @synchronized (gMagicEchoTargets) { allTargets = [gMagicEchoTargets allObjects]; }
                    for (id tgt in allTargets) {
                        if (tgt && tgt != gMagicMgr && [tgt respondsToSelector:@selector(setPushInfo:)]) {
                            TTSetObj(tgt, @selector(setPushInfo:), pushInfo);
                            ways++;
                        }
                    }
                }
                #pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                UIWindow *win = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
                if (win) {
                    NSMutableArray *q = [NSMutableArray arrayWithObject:win];
                    while (q.count > 0) {
                        UIView *v = q.lastObject;
                        [q removeLastObject];
                        if ([v respondsToSelector:@selector(setPushInfo:)]) {
                            TTM_recordPushInfoTarget(v);
                            TTSetObj(v, @selector(setPushInfo:), pushInfo);
                            ways++;
                        }
                        for (NSString *sn in @[@"playMagicExpression:", @"showMagicExpression:", @"onMagicExpression:", @"playMagicExpressionWithInfo:"]) {
                            SEL ms = NSSelectorFromString(sn);
                            if ([v respondsToSelector:ms]) {
                                @try {
                                    TTSetObj(v, ms, pushInfo);
                                    ways++;
                                    TTLog(@"MAGIC 命中 %@ -%@", NSStringFromClass([v class]), sn);
                                } @catch (id e) {}
                            }
                        }
                        UIResponder *next = [v nextResponder];
                        if ([next isKindOfClass:[UIViewController class]] && [next respondsToSelector:@selector(setPushInfo:)]) {
                            TTM_recordPushInfoTarget(next);
                            TTSetObj(next, @selector(setPushInfo:), pushInfo);
                            ways++;
                        }
                        if (v.subviews.count) [q addObjectsFromArray:v.subviews];
                    }
                }
            }
            TTLog(@"MAGIC 本地自嗨回显 tab=%u id=%u md5=%@ 触发通道数=%d (pushInfo=%@)",
                  tabId, magicId, md5 ?: @"-", ways, pushInfo ? @"✓" : @"✗");
            [pushInfo release];
            [push release];
        } @catch (id e) { TTLog(@"MAGIC 本地回显异常 %@", e); }
    });
}

static void TTReforgeGPBObject(id obj) {
    NSString *cn = NSStringFromClass([obj class]);
    @try {
        if ([cn isEqualToString:@"UserUGCInfo"]) { TTForgeUGC(obj); return; }
        if ([cn isEqualToString:@"TTUGCUserInfo"] || [cn isEqualToString:@"TTSuperPlayer"]) {
            uint32_t u = TTPlayerUidOf(obj) ?: TTStrictSelfUid();
            if (u > 0) TTTagNobilityInfoOnObject(obj, u);
            return;
        }
        if ([cn isEqualToString:@"MyGrowInfo"] || [cn isEqualToString:@"GrowInfo"]) { TTForgeGrowGPB(obj, 0); return; }
        if ([cn isEqualToString:@"UserUGCInfo_Nobles"]) { TTForgeNoblesGPB(obj); return; }
        if ([cn isEqualToString:@"UserUGCInfo_SpInfo"]) { TTForgeSpInfoGPB(obj); return; }
        if ([cn isEqualToString:@"SuperPlayerLevel"]) { TTForgeSPLevel(obj); return; }
        if ([cn isEqualToString:@"TTSuperPlayerLevel"]) { TTSyncMyLevelObject(obj); return; }
        if ([cn rangeOfString:@"NobilityInfo"].location != NSNotFound) { TTForgeNobilityInfo(obj); return; }
    } @catch (id e) {}
}

static void TTRestoreAndReforgeGPB(void) {
    NSArray *objs = TTRestoreForgedGPB();
    for (id obj in objs) TTReforgeGPBObject(obj);
    @try {
        id me = TTCMePlayer();
        if (me) {
            uint32_t myUid = TTStrictSelfUid();
            if (myUid) TTTagNobilityInfoOnObject(me, myUid);
            if (origC_getSuperPlayerLevel) {
                id lvl = origC_getSuperPlayerLevel(me, @selector(getSuperPlayerLevel));
                if (lvl) TTSyncMyLevelObject(lvl);
            }
        }
    } @catch (id e) {}
    if (objs.count) TTLog(@"FORGE 已按新等级重伪造 %lu 个缓存对象", (unsigned long)objs.count);
}

static void TTApplyForgeStateNow(NSString *what) {
    @try {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ttc://superPlayer/superPlayerStatusChanged" object:TTCMePlayer()];
        id selfCtx = TTGetLastSelfLayoutCtx();
        if (selfCtx && TTContextEffectiveIsMe(selfCtx)) {
            if (origH_nobleAppear) origH_nobleAppear(selfCtx, @selector(handlerNobilityTipViewAppear:), TTNobleForgeOn());
            if (TTNobleForgeOn()) {
                id btn = TTGetObj(selfCtx, @selector(nobilityTipView));
                if (btn) TTApplyNobleIconToTipView(btn, gNobleLevel);
            }
            if (origH_appear) origH_appear(selfCtx, @selector(handlerSuperPlayerViewAppear:), TTMemberForgeOn());
            TTApplyMemberIconToContext(selfCtx, gMemberLevel);
        }
    } @catch (id e) {}
    TTDyeVisibleMyNicknameLabels();
    if (gCustomId.length) TTRelabelVisibleIdLabels(TTMyRealAccount(), gCustomId);
    TTLog(@"FORGE %@ 已即时应用（原生通知+主页昵称重绘+可见视图刷新）", what);
}

static UIWindow *TTKeyWindow(void) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSArray *wins = [UIApplication sharedApplication].windows;
    UIWindow *best = nil; CGFloat bestArea = -1;
    for (UIWindow *w in wins) {
        if (!w.rootViewController || w.windowLevel != UIWindowLevelNormal) continue;
        CGFloat a = w.bounds.size.width * w.bounds.size.height;
        if (a > bestArea) { bestArea = a; best = w; }
    }
    if (best) return best;
    for (UIWindow *w in wins) {
        if (w.rootViewController && w.windowLevel < UIWindowLevelStatusBar) return w;
    }
    UIWindow *kw = [UIApplication sharedApplication].keyWindow;
    return (kw && kw.rootViewController) ? kw : nil;
#pragma clang diagnostic pop
}

static NSArray *TTNamePresetList(void) {
    static NSArray *presets = nil;
    if (!presets) {
        presets = [@[
            @{@"t": @"原样",                 @"s": @0, @"c": @0},
            @{@"t": @"贵族红名（原生渐变）",   @"s": @1, @"c": @0},
            @{@"t": @"贵族红名V2（原生渐变）", @"s": @2, @"c": @0},
            @{@"t": @"SVIP图案（原生）",      @"s": @3, @"c": @0},
            @{@"t": @"贵族红名 · SVIP橙", @"s": @1, @"c": @1},
            @{@"t": @"贵族红名 · 蓝紫",   @"s": @1, @"c": @2},
            @{@"t": @"贵族红名 · 薄荷",   @"s": @1, @"c": @3},
            @{@"t": @"贵族红名 · 湖青",   @"s": @1, @"c": @4},
            @{@"t": @"贵族红名 · 紫金",   @"s": @1, @"c": @5},
            @{@"t": @"贵族红名 · 粉黄",   @"s": @1, @"c": @6},
            @{@"t": @"贵族红名 · 红黄",   @"s": @1, @"c": @7},
            @{@"t": @"贵族红名 · 霓虹",   @"s": @1, @"c": @8},
            @{@"t": @"贵族红名 · 落日",   @"s": @1, @"c": @9},
        ] retain];
    }
    return presets;
}

static NSAttributedString *TTNamePreviewAttr(NSString *nick, NSInteger ps, NSInteger pcIdx) {
    UIColor *col = TTResolveNameColor(ps, pcIdx, CGSizeMake(200, 24));
    NSString *suffix;
    if (ps == 0) suffix = @" · 原样";
    else if (pcIdx > 0) suffix = [NSString stringWithFormat:@" · %@渐变", TTNameColorNameIdx(pcIdx)];
    else if (ps == 1) suffix = @" · 贵族红名 原生渐变";
    else if (ps == 2) suffix = @" · 贵族红名V2 原生渐变";
    else suffix = @" · SVIP图案 原生";
    NSMutableAttributedString *mas = [[[NSMutableAttributedString alloc] init] autorelease];
    [mas appendAttributedString:[[[NSAttributedString alloc] initWithString:nick attributes:@{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:15],
        NSForegroundColorAttributeName: col ?: [UIColor colorWithRed:0.95 green:0.22 blue:0.68 alpha:1] }] autorelease]];
    [mas appendAttributedString:[[[NSAttributedString alloc] initWithString:suffix attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:12],
        NSForegroundColorAttributeName: [UIColor secondaryLabelColor] }] autorelease]];
    return mas;
}

static NSString *TTLogFileSizeText(void) {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:TTLogPath() error:nil];
    unsigned long long bytes = [attrs[NSFileSize] unsignedLongLongValue];
    if (bytes == 0) return @"0 KB";
    if (bytes < 1024) return [NSString stringWithFormat:@"%llu B", bytes];
    if (bytes < 1024 * 1024) return [NSString stringWithFormat:@"%.1f KB", (double)bytes / 1024.0];
    return [NSString stringWithFormat:@"%.2f MB", (double)bytes / (1024.0 * 1024.0)];
}

static void TTExportLogFile(void) {
    @try {
        NSString *path = TTLogPath();
        UIWindow *mw = TTKeyWindow();
        UIViewController *root = mw ? mw.rootViewController : nil;
        while (root.presentedViewController) root = root.presentedViewController;
        if (!root) return;
        UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
        [root presentViewController:av animated:YES completion:nil];
        [av release];
        TTLog(@"日志菜单 导出日志");
    } @catch (id e) { TTLog(@"导出日志异常 %@", e); }
}

static void TTClearLogFile(void) {
    @try {
        if (gLogQueue) {
            dispatch_sync(gLogQueue, ^{
                [gLogFileHandle closeFile];
                [gLogFileHandle release];
                gLogFileHandle = nil;
                [[NSFileManager defaultManager] removeItemAtPath:TTLogPath() error:nil];
            });
        } else {
            [[NSFileManager defaultManager] removeItemAtPath:TTLogPath() error:nil];
        }
        TTLog(@"日志已清空（日志菜单）");
    } @catch (id e) {}
}

static void TTPresentCustomIdAlert(dispatch_block_t reloadBlock) {
    UIWindow *mw = TTKeyWindow();
    UIViewController *root = mw ? mw.rootViewController : nil;
    while (root.presentedViewController) root = root.presentedViewController;
    if (!root) return;
    NSString *real = TTMyRealAccount();
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"显示ID"
        message:(real.length ? [NSString stringWithFormat:@"真实ID：%@（仅本机显示，不影响账号本身）", real] : @"仅本机显示，不影响账号本身")
        preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = gCustomId ?: @"";
        tf.placeholder = real ?: @"输入新ID";
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *t = [ac.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (t.length) {
            NSString *realAcc = TTMyRealAccount();
            [gPrevCustomId release];
            gPrevCustomId = [gCustomId copy];
            [gCustomId release];
            gCustomId = [t copy];
            [[NSUserDefaults standardUserDefaults] setObject:gCustomId forKey:@"ttforge.customId"];
            TTRestoreAndReforgeGPB();
            TTRelabelVisibleIdLabels(realAcc, gCustomId);
            TTLog(@"账号 显示ID → %@ (真实ID=%@)", gCustomId, realAcc ?: @"未捕获");
            TTApplyForgeStateNow(@"显示ID");
        }
        if (reloadBlock) reloadBlock();
    }]];
    if (gCustomId.length) {
        [ac addAction:[UIAlertAction actionWithTitle:@"清除（恢复真实ID）" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            NSString *realAcc = TTMyRealAccount();
            NSString *oldCustom = [[gCustomId retain] autorelease];
            [gPrevCustomId release]; gPrevCustomId = nil;
            [gCustomId release]; gCustomId = nil;
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ttforge.customId"];
            TTRestoreAndReforgeGPB();
            id me = TTCMePlayer();
            NSString *meReal = (me ? objc_getAssociatedObject(me, &kTTRealAccKey) : nil) ?: realAcc;
            NSString *restoreToken = meReal ?: realAcc;
            if (restoreToken.length) {
                NSString *cleanRestore = ([restoreToken hasPrefix:@"tt"] || [restoreToken hasPrefix:@"TT"]) ? [restoreToken substringFromIndex:2] : restoreToken;
                NSString *finalRestore = cleanRestore.length ? cleanRestore : restoreToken;
                id selfCtx = TTGetLastSelfLayoutCtx();
                if (selfCtx && TTContextEffectiveIsMe(selfCtx)) {
                    UIView *idv = TTGetObj(selfCtx, @selector(IdView));
                    if ([idv isKindOfClass:[UIView class]]) {
                        TTRelabelViewTokens(idv, oldCustom, finalRestore);
                        TTRelabelIdSubtree(idv, finalRestore);
                    }
                }
            }
            TTLog(@"账号 显示ID 已清除 (恢复为 %@)", restoreToken ?: @"原样");
            TTApplyForgeStateNow(@"显示ID");
            if (reloadBlock) reloadBlock();
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [root presentViewController:ac animated:YES completion:nil];
}

static void TTRegisterNovaUIModules(void) {
    NovaUIManager *ui = [NovaUIManager sharedManager];
    ui.panelTitle = @"TTForge 控制中心";

    {
        NSArray *titles = @[@"原样（真实数据）", @"SVIP 1", @"SVIP 2", @"SVIP 3", @"SVIP 4", @"SVIP 5", @"SVIP 6", @"SVIP 7", @"SVIP 8（满级）"];
        NSArray *values = @[@0, @1, @2, @3, @4, @5, @6, @7, @8];
        NSInteger defIdx = 0;
        for (NSUInteger i = 0; i < values.count; i++) {
            if ([values[i] integerValue] == gMemberLevel) { defIdx = (NSInteger)i; break; }
        }
        [ui registerSelectInMenu:nil
                             key:@"memberLevel"
                           title:@"会员等级"
                        subtitle:@"伪造 SVIP 会员等级与专属特权"
                            icon:@"crown.fill"
                         options:titles
                    defaultIndex:defIdx
                         handler:^(NSInteger selectedIndex, NSString *selectedOption) {
                             if (selectedIndex < 0 || selectedIndex >= (NSInteger)values.count) return;
                             gMemberLevel = [values[(NSUInteger)selectedIndex] integerValue];
                             [[NSUserDefaults standardUserDefaults] setInteger:gMemberLevel forKey:@"ttforge.memberLevel"];
                             TTRestoreAndReforgeGPB();
                             TTLog(@"面板 会员等级 → %ld", (long)gMemberLevel);
                             TTApplyForgeStateNow(@"会员等级");
                         }];
    }

    {
        NSArray *titles = @[@"原样（真实数据）", @"1级 · 少爵", @"2级 · 男爵", @"3级 · 子爵", @"4级 · 伯爵", @"5级 · 侯爵", @"6级 · 公爵", @"7级 · 郡王", @"8级 · 亲王", @"9级 · 国王", @"10级 · 神王（满级）"];
        NSArray *values = @[@0, @1, @2, @3, @4, @5, @6, @7, @8, @9, @10];
        NSInteger defIdx = 0;
        for (NSUInteger i = 0; i < values.count; i++) {
            if ([values[i] integerValue] == gNobleLevel) { defIdx = (NSInteger)i; break; }
        }
        [ui registerSelectInMenu:nil
                             key:@"nobleLevel"
                           title:@"贵族等级"
                        subtitle:@"伪造贵族爵位、徽章、H5贵族中心与神秘人"
                            icon:@"sparkles"
                         options:titles
                    defaultIndex:defIdx
                         handler:^(NSInteger selectedIndex, NSString *selectedOption) {
                             if (selectedIndex < 0 || selectedIndex >= (NSInteger)values.count) return;
                             gNobleLevel = [values[(NSUInteger)selectedIndex] integerValue];
                             [[NSUserDefaults standardUserDefaults] setInteger:gNobleLevel forKey:@"ttforge.nobleLevel"];
                             TTRestoreAndReforgeGPB();
                             TTLog(@"面板 贵族等级 → %ld", (long)gNobleLevel);
                             TTApplyForgeStateNow(@"贵族等级");
                         }];
    }

    {
        NSArray *presets = TTNamePresetList();
        NSMutableArray *titles = [NSMutableArray arrayWithCapacity:presets.count];
        NSInteger defIdx = 0;
        for (NSUInteger i = 0; i < presets.count; i++) {
            NSDictionary *pr = presets[i];
            [titles addObject:pr[@"t"] ?: @""];
            if ([pr[@"s"] integerValue] == gNameStyle && [pr[@"c"] integerValue] == gNameColorIndex) defIdx = (NSInteger)i;
        }
        [ui registerSelectInMenu:nil
                             key:@"nameStyle"
                           title:@"名字样式"
                        subtitle:@"聊天、麦位与主页昵称渐变炫彩样式"
                            icon:@"paintbrush.fill"
                         options:titles
                    defaultIndex:defIdx
                         handler:^(NSInteger selectedIndex, NSString *selectedOption) {
                             if (selectedIndex < 0 || selectedIndex >= (NSInteger)presets.count) return;
                             NSDictionary *pr = presets[(NSUInteger)selectedIndex];
                             gNameStyle = [pr[@"s"] integerValue];
                             gNameColorIndex = [pr[@"c"] integerValue];
                             NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
                             [ud setInteger:gNameStyle forKey:@"ttforge.nameStyle"];
                             [ud setBool:(gNameStyle != 0) forKey:@"ttforge.nameColor"];
                             [ud setInteger:gNameColorIndex forKey:@"ttforge.nameColorIndex"];
                             TTLog(@"面板 名字样式 → %@", TTNamePresetName());
                             TTApplyForgeStateNow(@"名字样式");
                         }];
    }

    [ui registerActionInMenu:nil
                         key:@"customId"
                       title:@"显示ID"
                    subtitle:@"自定义本机主页与贵族中心显示的TT号"
                        icon:@"person.text.rectangle.fill"
                 buttonTitle:@"设置"
                     handler:^{
                         TTPresentCustomIdAlert(nil);
                     }];

    [ui registerSwitchInMenu:nil
                         key:@"blockReport"
                       title:@"访问隐身"
                    subtitle:@"访问他人主页不留访客记录与足迹"
                        icon:@"eye.slash.fill"
                defaultValue:gBlockReport
                     handler:^(BOOL enabled) {
                         gBlockReport = enabled;
                         [[NSUserDefaults standardUserDefaults] setBool:gBlockReport forKey:@"ttforge.blockReport"];
                         TTLog(@"状态设置 访问隐身 → %@", gBlockReport ? @"开" : @"关");
                     }];

    [ui registerSwitchInMenu:nil
                         key:@"sneakAll"
                       title:@"悄悄看所有人"
                    subtitle:@"已读消息不发回执，悄悄查看会话"
                        icon:@"eye.fill"
                defaultValue:gSneakAll
                     handler:^(BOOL enabled) {
                         gSneakAll = enabled;
                         [[NSUserDefaults standardUserDefaults] setBool:gSneakAll forKey:@"ttforge.sneakAll"];
                         TTLog(@"状态设置 悄悄看所有人 → %@", gSneakAll ? @"开" : @"关");
                     }];

    {
        NSArray *titles = @[@"原样（真实数据）", @"初见锋芒", @"见习偶像", @"名声大振", @"人气之星", @"光辉夺目", @"风华绝代", @"永恒璀璨"];
        NSArray *values = @[@0, @10, @11, @101, @1001, @10001, @100001, @1000001];
        NSInteger defIdx = 0;
        for (NSUInteger i = 0; i < values.count; i++) {
            NSInteger v = [values[i] integerValue];
            if (v == gCharmLevelVal || (v > 0 && gCharmLevelVal > 0 && TTTitleBandForValue(v) == TTTitleBandForValue(gCharmLevelVal))) { defIdx = (NSInteger)i; break; }
        }
        [ui registerSelectInMenu:nil
                             key:@"charmLevel"
                           title:@"魅力等级"
                        subtitle:@"个人资料页魅力称号与等级展示"
                            icon:@"heart.fill"
                         options:titles
                    defaultIndex:defIdx
                         handler:^(NSInteger selectedIndex, NSString *selectedOption) {
                             if (selectedIndex < 0 || selectedIndex >= (NSInteger)values.count) return;
                             gCharmLevelVal = [values[(NSUInteger)selectedIndex] integerValue];
                             [[NSUserDefaults standardUserDefaults] setInteger:gCharmLevelVal forKey:@"ttforge.charmLevelVal"];
                             TTRestoreAndReforgeGPB();
                             TTLog(@"面板 魅力等级 → %ld", (long)gCharmLevelVal);
                             TTApplyForgeStateNow(@"魅力等级");
                         }];
    }

    {
        NSArray *titles = @[@"原样（真实数据）", @"优雅才子", @"圣殿绅士", @"荣耀城主", @"尊贵诸侯", @"枭雄霸王", @"至尊帝皇", @"永恒帝尊"];
        NSArray *values = @[@0, @10, @11, @101, @1001, @10001, @100001, @1000001];
        NSInteger defIdx = 0;
        for (NSUInteger i = 0; i < values.count; i++) {
            NSInteger v = [values[i] integerValue];
            if (v == gRichLevelVal || (v > 0 && gRichLevelVal > 0 && TTTitleBandForValue(v) == TTTitleBandForValue(gRichLevelVal))) { defIdx = (NSInteger)i; break; }
        }
        [ui registerSelectInMenu:nil
                             key:@"richLevel"
                           title:@"财富等级"
                        subtitle:@"个人资料页财富称号与等级展示"
                            icon:@"bitcoinsign.circle.fill"
                         options:titles
                    defaultIndex:defIdx
                         handler:^(NSInteger selectedIndex, NSString *selectedOption) {
                             if (selectedIndex < 0 || selectedIndex >= (NSInteger)values.count) return;
                             gRichLevelVal = [values[(NSUInteger)selectedIndex] integerValue];
                             [[NSUserDefaults standardUserDefaults] setInteger:gRichLevelVal forKey:@"ttforge.richLevelVal"];
                             TTRestoreAndReforgeGPB();
                             TTLog(@"面板 财富等级 → %ld", (long)gRichLevelVal);
                             TTApplyForgeStateNow(@"财富等级");
                         }];
    }

    [ui registerActionInMenu:nil
                         key:@"uidLock"
                       title:@"账号锁定"
                    subtitle:@"点按轮换候选UID锁定"
                        icon:@"lock.shield.fill"
                 buttonTitle:@"轮换"
                     handler:^{
                         @try {
                             NSArray *keys = nil;
                             @synchronized (gHits) {
                                 keys = [[gHits keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                                     return [b[@"count"] compare:a[@"count"]];
                                 }] retain];
                             }
                             if (keys.count) {
                                 NSUInteger idx = 0;
                                 for (NSUInteger i = 0; i < keys.count; i++) {
                                     if ([keys[i] unsignedIntValue] == gSelfUid) { idx = (i + 1) % keys.count; break; }
                                 }
                                 gSelfUid = [keys[idx] unsignedIntValue];
                                 [[NSUserDefaults standardUserDefaults] setObject:@(gSelfUid) forKey:@"ttforge.selfUid"];
                                 TTLog(@"状态设置 账号锁定 → uid=%u %@（候选 %lu 个，点按轮换）", gSelfUid,
                                       gHits[@(gSelfUid)][@"nickname"] ?: @"", (unsigned long)keys.count);
                             } else {
                                 TTLog(@"状态设置 账号锁定：暂无候选（先浏览任意主页/资料页产生命中）");
                             }
                             [keys release];
                         } @catch (id e) { TTLog(@"账号锁定异常 %@", e); }
                         TTApplyForgeStateNow(@"账号锁定");
                     }];

    [ui registerActionInMenu:nil
                         key:@"resetLock"
                       title:@"重置锁定"
                    subtitle:@"清除UID锁定与候选缓存并重新识别"
                        icon:@"arrow.counterclockwise"
                 buttonTitle:@"重置"
                     handler:^{
                         gSelfUid = 0;
                         @synchronized (gHits) { [gHits removeAllObjects]; }
                         @synchronized (gForgedPlayers) { [gForgedPlayers removeAllObjects]; }
                         [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ttforge.selfUid"];
                         TTStrictSelfUid();
                         TTLog(@"状态设置 重置锁定：已清 uid 锁定与候选（当前自动识别 uid=%u）", gSelfUid);
                     }];

    [ui registerSubmenu:@"logMenu"
                  title:@"日志菜单"
               subtitle:@"H5抓取开关、运行日志导出与清空"
                   icon:@"doc.text.magnifyingglass"];

    [ui registerSwitchInMenu:@"logMenu"
                         key:@"h5capture"
                       title:@"H5抓取"
                    subtitle:@"捕获 H5 请求与响应报文写入日志"
                        icon:@"network"
                defaultValue:gH5Capture
                     handler:^(BOOL enabled) {
                         gH5Capture = enabled;
                         [[NSUserDefaults standardUserDefaults] setBool:gH5Capture forKey:@"ttforge.h5capture"];
                         TTLog(@"状态设置 H5抓取 → %@（K 层门控实时读取，即时生效）", gH5Capture ? @"开" : @"关");
                     }];

    [ui registerActionInMenu:@"logMenu"
                         key:@"exportLog"
                       title:@"导出日志"
                    subtitle:@"通过系统分享面板导出 ttforge.log"
                        icon:@"square.and.arrow.up"
                 buttonTitle:@"导出"
                     handler:^{
                         [[NovaUIManager sharedManager] hidePanel];
                         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.22 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                             TTExportLogFile();
                         });
                     }];

    [ui registerActionInMenu:@"logMenu"
                         key:@"clearLog"
                       title:@"清空日志"
                    subtitle:@"删除本地日志文件并释放存储空间"
                        icon:@"trash"
                 buttonTitle:@"清空"
                     handler:^{
                         TTClearLogFile();
                     }];

    [ui registerSubmenu:@"roomTest"
                  title:@"房间测试"
               subtitle:@"防闭麦、防清屏、192k、皮肤、防踢、万能上麦、灵动岛"
                   icon:@"mic.fill"];

    [ui registerSwitchInMenu:@"roomTest"
                         key:@"rtAntiMute"
                       title:@"防闭麦"
                    subtitle:@"房主闭麦指令本地不执行"
                        icon:@"mic.slash.fill"
                defaultValue:gRTAntiMute
                     handler:^(BOOL enabled) {
                         gRTAntiMute = enabled;
                         [[NSUserDefaults standardUserDefaults] setBool:gRTAntiMute forKey:@"ttforge.rtAntiMute"];
                         TTLog(@"状态设置 防闭麦 → %@", gRTAntiMute ? @"开" : @"关");
                     }];

    [ui registerSwitchInMenu:@"roomTest"
                         key:@"rtAntiClear"
                       title:@"防清屏"
                    subtitle:@"清屏指令本地不执行，聊天记录保留"
                        icon:@"text.bubble.fill"
                defaultValue:gRTAntiClear
                     handler:^(BOOL enabled) {
                         gRTAntiClear = enabled;
                         [[NSUserDefaults standardUserDefaults] setBool:gRTAntiClear forKey:@"ttforge.rtAntiClear"];
                         TTLog(@"状态设置 防清屏 → %@", gRTAntiClear ? @"开" : @"关");
                     }];

    [ui registerSwitchInMenu:@"roomTest"
                         key:@"rtAudio192"
                       title:@"192k音质"
                    subtitle:@"音频码率本地替换为 192000（测试值）"
                        icon:@"waveform"
                defaultValue:gRTAudio192
                     handler:^(BOOL enabled) {
                         gRTAudio192 = enabled;
                         [[NSUserDefaults standardUserDefaults] setBool:gRTAudio192 forKey:@"ttforge.rtAudio192"];
                         TTLog(@"状态设置 192k音质 → %@", gRTAudio192 ? @"开" : @"关");
                     }];

    [ui registerSwitchInMenu:@"roomTest"
                         key:@"rtSkin"
                       title:@"皮肤DressId"
                    subtitle:@"房间套装更新时替换为填入的 DressId"
                        icon:@"paintpalette.fill"
                defaultValue:gRTSkin
                     handler:^(BOOL enabled) {
                         gRTSkin = enabled;
                         [[NSUserDefaults standardUserDefaults] setBool:gRTSkin forKey:@"ttforge.rtSkin"];
                         TTLog(@"状态设置 皮肤DressId → %@", gRTSkin ? @"开" : @"关");
                     }];

    [ui registerInputInMenu:@"roomTest"
                        key:@"rtDressId"
                      title:@"皮肤DressId值"
                   subtitle:@"填房间套装 DressId，0 表示只记录"
                       icon:@"number"
                placeholder:@"DressId"
               defaultValue:gRTDressId ? [NSString stringWithFormat:@"%u", gRTDressId] : @""
                    handler:^(NSString *text) {
                        gRTDressId = (uint32_t)[text intValue];
                        [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)gRTDressId forKey:@"ttforge.rtDressId"];
                        TTLog(@"状态设置 皮肤DressId → %u", gRTDressId);
                    }];

    [ui registerSwitchInMenu:@"roomTest"
                         key:@"rtAntiKick"
                       title:@"防踢"
                    subtitle:@"踢出与踢下麦消息本地不执行"
                        icon:@"hand.raised.fill"
                defaultValue:gRTAntiKick
                     handler:^(BOOL enabled) {
                         gRTAntiKick = enabled;
                         [[NSUserDefaults standardUserDefaults] setBool:gRTAntiKick forKey:@"ttforge.rtAntiKick"];
                         TTLog(@"状态设置 防踢 → %@", gRTAntiKick ? @"开" : @"关");
                     }];

    [ui registerSwitchInMenu:@"roomTest"
                         key:@"rtUpMic"
                       title:@"万能上麦"
                    subtitle:@"上麦权限判断本地放行"
                        icon:@"mic.fill"
                defaultValue:gRTUpMic
                     handler:^(BOOL enabled) {
                         gRTUpMic = enabled;
                         [[NSUserDefaults standardUserDefaults] setBool:gRTUpMic forKey:@"ttforge.rtUpMic"];
                         TTLog(@"状态设置 万能上麦 → %@", gRTUpMic ? @"开" : @"关");
                     }];

    [ui registerSwitchInMenu:@"roomTest"
                         key:@"rtIsland"
                       title:@"灵动岛记录"
                    subtitle:@"只记录灵动岛容器与注册调用"
                        icon:@"bell.fill"
                defaultValue:gRTIsland
                     handler:^(BOOL enabled) {
                         gRTIsland = enabled;
                         [[NSUserDefaults standardUserDefaults] setBool:gRTIsland forKey:@"ttforge.rtIsland"];
                         TTLog(@"状态设置 灵动岛记录 → %@", gRTIsland ? @"开" : @"关");
                     }];

    [ui install];
}

static void (*origU_setBubbleId)(id, SEL, uint32_t);
static void TTU_setBubbleId(id self, SEL _cmd, uint32_t dressId) {
    if (TTMemberForgeOn() && gBubbleDressId > 0) dressId = gBubbleDressId;
    if (origU_setBubbleId) origU_setBubbleId(self, _cmd, dressId);
}

static id (*origU_getChatBgURL)(id, SEL, id);
static id TTU_getChatBgURL(id self, SEL _cmd, id targetAccount) {
    if (TTMemberForgeOn() && gChatBgDressId > 0 && TTPlayerIsSelf(self)) {
        @try {
            id dm = TTDressManager();
            if (dm && [dm respondsToSelector:@selector(chatBackgroundDressFor:)]) {
                id dress = ((id (*)(id, SEL, uint32_t))objc_msgSend)(dm, @selector(chatBackgroundDressFor:), gChatBgDressId);
                NSString *url = dress ? TTGetObj(dress, @selector(resourceURL)) : nil;
                if ([url isKindOfClass:[NSString class]] && url.length > 0) return url;
            }
        } @catch (id e) {}
    }
    return origU_getChatBgURL(self, _cmd, targetAccount);
}

static id (*origV_getRoomDress)(id, SEL);
static BOOL (*origV_roomOverdueAlert)(id, SEL);
static BOOL (*origV_micNeedAlert)(id, SEL);
static BOOL (*origV_isShowRoomDress)(id, SEL);
static void (*origV_showError)(id, SEL, id);
static void (*origV_showHint)(id, SEL, id);

static BOOL TTV_roomOverdueAlert(id self, SEL _cmd) {
    if (TTMemberForgeOn()) {
        TTLog(@"ROOM 已屏蔽房间装扮「权限过期」提示判定（getKRoomDressOverdueAlertKey）");
        return NO;
    }
    return origV_roomOverdueAlert ? origV_roomOverdueAlert(self, _cmd) : NO;
}

static BOOL TTV_micNeedAlert(id self, SEL _cmd) {
    if (TTMemberForgeOn()) return NO;
    return origV_micNeedAlert ? origV_micNeedAlert(self, _cmd) : NO;
}

static BOOL TTV_isShowRoomDress(id self, SEL _cmd) {
    if (TTMemberForgeOn()) return YES;
    return origV_isShowRoomDress ? origV_isShowRoomDress(self, _cmd) : YES;
}

static void TTV_showError(id self, SEL _cmd, id msg) {
    if (TTMemberForgeOn() && [msg isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)msg;
        if ([s rangeOfString:@"权限"].location != NSNotFound ||
            [s rangeOfString:@"5861"].location != NSNotFound ||
            [s rangeOfString:@"到期"].location != NSNotFound) {
            TTLog(@"ROOM 已屏蔽错误提示: %@", s);
            return;
        }
    }
    if (origV_showError) origV_showError(self, _cmd, msg);
}

static void TTV_showHint(id self, SEL _cmd, id msg) {
    if (TTMemberForgeOn() && [msg isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)msg;
        if ([s rangeOfString:@"权限"].location != NSNotFound ||
            [s rangeOfString:@"到期"].location != NSNotFound) {
            TTLog(@"ROOM 已屏蔽提示: %@", s);
            return;
        }
    }
    if (origV_showHint) origV_showHint(self, _cmd, msg);
}

static id TTV_getRoomDress(id self, SEL _cmd) {
    @try {
        if (TTMemberForgeActive() && gRoomDressId > 0) {
            id owner = nil;
            for (NSString *k in @[@"player", @"superPlayer", @"currentPlayer"]) {
                owner = TTGetObj(self, NSSelectorFromString(k));
                if (owner) break;
            }
            if (owner && (uintptr_t)owner > 0x1000 && [owner respondsToSelector:@selector(uid)]) {
                uint32_t ouid = TTGetU32(owner, @selector(uid));
                if (ouid && gSelfUid && ouid != gSelfUid)
                    return origV_getRoomDress ? origV_getRoomDress(self, _cmd) : nil;
            }
            id dm = TTDressManager();
            if (dm && [dm respondsToSelector:@selector(roomDressFor:)]) {
                id dress = ((id (*)(id, SEL, uint32_t))objc_msgSend)(dm, @selector(roomDressFor:), gRoomDressId);
                if (dress) return dress;
                if ([dm respondsToSelector:@selector(reqGetDressConfigs:)])
                    ((void (*)(id, SEL, int))objc_msgSend)(dm, @selector(reqGetDressConfigs:), 1);
            }
        }
    } @catch (id e) {}
    return origV_getRoomDress ? origV_getRoomDress(self, _cmd) : nil;
}

static uint32_t TTExtractUIntFromParam(id param, NSArray *keys, BOOL allowDirectNum) {
    @try {
        if (!param) return 0;
        if (allowDirectNum && [param isKindOfClass:[NSNumber class]]) return [(NSNumber *)param unsignedIntValue];
        NSDictionary *dict = nil;
        if ([param isKindOfClass:[NSDictionary class]]) {
            dict = (NSDictionary *)param;
        } else if ([param isKindOfClass:[NSString class]]) {
            NSString *s = (NSString *)param;
            NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
            if (d) {
                id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
                if ([obj isKindOfClass:[NSDictionary class]]) dict = (NSDictionary *)obj;
                else if (allowDirectNum && [obj isKindOfClass:[NSNumber class]]) return [(NSNumber *)obj unsignedIntValue];
            }
            if (allowDirectNum && !dict && [s intValue] > 0) return (uint32_t)[s intValue];
        }
        if (dict) {
            for (NSString *k in keys) {
                id v = dict[k];
                if ([v respondsToSelector:@selector(unsignedIntValue)] && [v unsignedIntValue] > 0)
                    return [v unsignedIntValue];
            }
            if ([dict[@"data"] isKindOfClass:[NSDictionary class]])
                return TTExtractUIntFromParam(dict[@"data"], keys, allowDirectNum);
        }
    } @catch (id e) {}
    return 0;
}

static uint32_t TTExtractDressIdFromParam(id param) {
    return TTExtractUIntFromParam(param, @[@"dressId", @"dress_id", @"id", @"id_p", @"bubbleId", @"bgId", @"itemId"], YES);
}

static uint32_t TTExtractDressTypeFromParam(id param) {
    return TTExtractUIntFromParam(param, @[@"dress_type", @"dressType", @"type"], NO);
}

static int64_t (*origU_bridgeBubble)(id, SEL, id, id, id);
static int64_t TTU_bridgeBubble(id self, SEL _cmd, id param, id callback, id from) {
    @try {
        uint32_t did = TTExtractDressIdFromParam(param);
        TTLog(@"H5BRIDGE data_changeMyIMBubbleDressId param=%@ 解析dressId=%u", param, did);
        TTApplyH5Dress(4, did);
    } @catch (id e) {}
    return origU_bridgeBubble ? origU_bridgeBubble(self, _cmd, param, callback, from) : 0;
}

static int64_t (*origU_bridgeChatBg)(id, SEL, id, id, id);
static int64_t TTU_bridgeChatBg(id self, SEL _cmd, id param, id callback, id from) {
    @try {
        uint32_t did = TTExtractDressIdFromParam(param);
        TTLog(@"H5BRIDGE data_changeIMBackgroundDressId param=%@ 解析dressId=%u", param, did);
        TTApplyH5Dress(3, did);
    } @catch (id e) {}
    return origU_bridgeChatBg ? origU_bridgeChatBg(self, _cmd, param, callback, from) : 0;
}

static void (*origU_jsInvoke)(id, SEL, id, id, id);
static void TTU_jsInvoke(id self, SEL _cmd, id name, id parameter, id callback) {
    @try {
        if ([name isKindOfClass:[NSString class]]) {
            NSString *nm = (NSString *)name;
            if ([nm rangeOfString:@"Bubble" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [nm rangeOfString:@"Background" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [nm rangeOfString:@"Dress" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [nm isEqualToString:@"operate_buySuperPlayer"]) {
                TTLog(@"JSBRIDGE 调用 name=%@ param=%@", nm, parameter);
            }
            if ([nm isEqualToString:@"data_changeMyIMBubbleDressId"]) {
                uint32_t did = TTExtractDressIdFromParam(parameter);
                TTApplyH5Dress(4, did);
            } else if ([nm isEqualToString:@"data_changeIMBackgroundDressId"]) {
                uint32_t did = TTExtractDressIdFromParam(parameter);
                TTApplyH5Dress(3, did);
            } else if ([nm isEqualToString:@"data_changeMySpecialConcernDressId"] || [nm isEqualToString:@"data_changeSpecialConcernDressId"]) {
                uint32_t did = TTExtractDressIdFromParam(parameter);
                TTApplyH5Dress(2, did);
            } else if ([nm isEqualToString:@"data_changeMyRoomDressId"] || [nm isEqualToString:@"data_changeRoomDressId"]) {
                uint32_t did = TTExtractDressIdFromParam(parameter);
                TTApplyH5Dress(1, did);
            } else if ([nm isEqualToString:@"data_ttforge_applyDress"] || [nm isEqualToString:@"ttforge_applyDress"]) {
                uint32_t dt = TTExtractDressTypeFromParam(parameter);
                uint32_t did = TTExtractDressIdFromParam(parameter);
                TTLog(@"H5DRESS bridge apply type=%u id=%u raw=%@", dt, did, parameter);
                TTApplyH5Dress(dt, did);
            } else if ([nm isEqualToString:@"data_ttforge_h5_ready"] || [nm isEqualToString:@"ttforge_h5_ready"]) {
                TTLog(@"H5READY 脚本已注入页面 %@", parameter);
            } else if ([nm isEqualToString:@"data_ttforge_h5_member"] || [nm isEqualToString:@"ttforge_h5_member"]) {
                TTLog(@"H5PATCH 会员中心响应已改写 %@", parameter);
            } else if ([nm isEqualToString:@"data_ttforge_h5_noble"] || [nm isEqualToString:@"ttforge_h5_noble"]) {
                TTLog(@"H5PATCH 贵族中心响应已改写 %@", parameter);
            } else if ([nm isEqualToString:@"data_ttforge_h5_ykw"] || [nm isEqualToString:@"ttforge_h5_ykw"]) {
                TTLog(@"H5PATCH 神秘人响应已改写 %@", parameter);
            }
            if ([nm hasPrefix:@"data_get"] || [nm rangeOfString:@"SuperPlayer"].location != NSNotFound ||
                [nm rangeOfString:@"Nobility"].location != NSNotFound || [nm rangeOfString:@"Vip"].location != NSNotFound) {
                static int jsLog = 0;
                if (jsLog < 30) {
                    jsLog++;
                    NSString *ps = [parameter description];
                    if (ps.length > 220) ps = [ps substringToIndex:220];
                    TTLog(@"JSBRIDGE 数据调用 %@ param=%@", nm, ps);
                }
            }
        }
    } @catch (id e) {}
    if (origU_jsInvoke) origU_jsInvoke(self, _cmd, name, parameter, callback);
}

static id (*origU_wkConfig)(id, SEL);
static id (*origV_wkInit)(id, SEL, CGRect, id);
static id (*origV_loadRequest)(id, SEL, id);

static NSString *TTH5SeedScript(void) {
    return [NSString stringWithFormat:
        @"try{var __tts=JSON.parse(localStorage.getItem('ttforge_dress_ids')||'{}');"
        @"__tts['4']=%u;__tts['3']=%u;__tts['2']=%u;__tts['1']=%u;"
        @"localStorage.setItem('ttforge_dress_ids',JSON.stringify(__tts));}catch(e){}"
        @"try{window.__ttMLV=%ld;window.__ttMVal=%llu;window.__ttNLV=%ld;window.__ttNVal=%llu;window.__ttNKeep=%llu;window.__ttNName=\"%@\";}catch(e){}",
        gBubbleDressId, gChatBgDressId, gSpecialDressId, gRoomDressId,
        (long)gMemberLevel, (unsigned long long)(gMemberLevel > 0 ? TTMemberGrowthCap(gMemberLevel) : 0ULL),
        (long)gNobleLevel, (unsigned long long)(gNobleLevel > 0 ? TTNobleValueCap(gNobleLevel) : 0ULL),
        (unsigned long long)(gNobleLevel > 0 ? TTNobleKeepCap(gNobleLevel) : 0ULL),
        TTNobleTitleForLevel(gNobleLevel)];
}

static NSString *TTH5ForgeScript(void) {
    NSString *seed = TTH5SeedScript();
    NSString *body =
        @";(function(){"
        @"if(window.__ttforgeH5V733)return;window.__ttforgeH5V733=1;"
        @"try{var __ttready=function(){try{TTJSBridge.invoke('data','ttforge_h5_ready',location.href);}catch(e){}};"
        @"if(document.readyState==='complete')setTimeout(__ttready,0);else window.addEventListener('load',__ttready);}catch(e){}"
        @"var FAR=4102444800;"
        @"function mlv(){return Number(window.__ttMLV)||0;}"
        @"function mval(){var l=mlv();if(l<=0)return 0;if(window.__ttMVal)return Number(window.__ttMVal);var t=[0,260,700,1800,4000,6700,12800,25500,25500];return t[Math.min(Math.max(l,1),8)];}"
        @"function nlv(){return Number(window.__ttNLV)||0;}"
        @"function nval(){var l=nlv();if(l<=0)return 0;if(window.__ttNVal)return Number(window.__ttNVal);var t=[0,50000,200000,500000,1000000,2000000,5000000,10000000,20000000,50000000,50000000];return t[Math.min(Math.max(l,1),10)];}"
        @"function nkeep(){var l=nlv();if(l<=0)return 0;if(window.__ttNKeep)return Number(window.__ttNKeep);var t=[0,3000,15000,60000,150000,300000,600000,1500000,3000000,6000000,2000000000];return t[Math.min(Math.max(l,1),10)];}"
        @"function rewriteUrlStr(u){if(!u||typeof u!=='string'||!(mlv()>0))return u;"
        @"return u.replace(/([?&])(status|svip_status|vip_status|vipStatus|is_svip|isSvip|is_open|isOpen|is_member|isMember|super_player_status|superPlayerStatus|year_member_status|has_open|is_unlock|can_use)=(0|false|2|3)\\b/gi,'$1$2=1')"
        @".replace(/([?&])(super_player_type|superPlayerType|vip_type)=(0|1|2|3)\\b/gi,'$1$2=4')"
        @".replace(/([?&])(level|super_player_level|superPlayerLevel|sp_level|vip_level)=0\\b/gi,'$1$2='+mlv());}"
        @"try{if(window.history&&history.replaceState){"
        @"var origReplace=history.replaceState,origPush=history.pushState;"
        @"var fixUrl=function(){try{if(!(mlv()>0))return;var u=location.href,nu=rewriteUrlStr(u);if(nu!==u)origReplace.call(history,history.state,'',nu);}catch(e){}};"
        @"history.pushState=function(s,t,u){if(u&&mlv()>0)u=rewriteUrlStr(String(u));var r=origPush.apply(this,arguments);fixUrl();return r;};"
        @"history.replaceState=function(s,t,u){if(u&&mlv()>0)u=rewriteUrlStr(String(u));return origReplace.apply(this,arguments);};"
        @"fixUrl();window.addEventListener('hashchange',fixUrl);window.addEventListener('popstate',fixUrl);}}catch(e){}"
        @"function savedIds(){var o={};try{o=JSON.parse(localStorage.getItem('ttforge_dress_ids')||'{}')||{};}catch(e){}return o;}"
        @"function saveDress(t,id){try{var o=savedIds();o[String(t)]=id;localStorage.setItem('ttforge_dress_ids',JSON.stringify(o));}catch(e){}}"
        @"function clearDress(t){try{var o=savedIds();delete o[String(t)];localStorage.setItem('ttforge_dress_ids',JSON.stringify(o));}catch(e){}}"
        @"function applyNative(dt,di){"
        @"try{TTJSBridge.invoke('data','ttforge_applyDress',JSON.stringify({dress_type:dt,dress_id:di}));}catch(e){}"
        @"try{if(dt===4)TTJSBridge.invoke('data','changeMyIMBubbleDressId',di);"
        @"else if(dt===3)TTJSBridge.invoke('data','changeIMBackgroundDressId',{dressId:di});"
        @"else if(dt===2)TTJSBridge.invoke('data','changeMySpecialConcernDressId',di);"
        @"else if(dt===1)TTJSBridge.invoke('data','changeMyRoomDressId',di);}catch(e){}}"
        @"function setOne(o,k){if(k in o)o[k]=(typeof o[k]==='boolean')?true:1;}"
        @"function setZero(o,k){if(k in o)o[k]=(typeof o[k]==='boolean')?false:0;}"
        @"function patchSP(o,force){"
        @"var LV=mlv();if(!(LV>0)||!o||typeof o!=='object'||Array.isArray(o))return;"
        @"var hit=force||('super_player_level' in o)||('svip_status' in o)||('vip_status' in o)||('superPlayerLevel' in o)||('super_player_value' in o)||('super_player_type' in o)||('superPlayerType' in o)||('svip_expire_timestamp' in o)||('super_player_status' in o);"
        @"if(!hit)return;"
        @"var MV=mval();"
        @"o.status=1;o.svip_status=1;o.vip_status=1;o.super_player_status=1;o.superPlayerStatus=1;"
        @"o.super_player_type=4;o.superPlayerType=4;o.vip_type=4;o.svip_type=2;"
        @"o.year_member_status=1;o.svip_year_member_status=1;"
        @"o.is_svip=(typeof o.is_svip==='boolean')?true:1;o.isSvip=true;"
        @"o.is_super_player=(typeof o.is_super_player==='boolean')?true:1;o.isSuperPlayer=true;"
        @"o.is_year_member=(typeof o.is_year_member==='boolean')?true:1;o.isYearMember=true;"
        @"o.super_player_level=LV;o.superPlayerLevel=LV;o.sp_level=LV;o.spLevel=LV;if('vip_level' in o)o.vip_level=LV;"
        @"o.super_player_value=MV;o.superPlayerValue=MV;if('sp_value' in o)o.sp_value=MV;if('growth_value' in o)o.growth_value=MV;"
        @"o.expire_timestamp=FAR;o.svip_expire_timestamp=FAR;o.year_member_expire_ts=FAR;o.svip_year_member_expire_timestamp=FAR;"
        @"if(!o.begin_timestamp||o.begin_timestamp>FAR)o.begin_timestamp=1700000000;"
        @"if(!o.svip_begin_timestamp||o.svip_begin_timestamp>FAR)o.svip_begin_timestamp=1700000000;"
        @"o.has_expired=false;o.is_svip_first=false;o.super_player_left_days=9999;o.svip_left_days=9999;"
        @"try{if(!o.__ttLogged){o.__ttLogged=1;TTJSBridge.invoke('data','ttforge_h5_member',JSON.stringify({status:o.status,level:o.super_player_level,value:o.super_player_value}));}}catch(e){}}"
        @"function patchFlags(o){"
        @"var LV=mlv();if(!(LV>0)||!o||typeof o!=='object')return;"
        @"var MV=mval();"
        @"var oneKeys=['is_svip','isSvip','is_super_player','isSuperPlayer','is_year_member','isYearMember','is_vip','isVip','is_member','isMember','svip_status','vip_status','vipStatus','super_player_status','superPlayerStatus','year_member_status','svip_year_member_status','is_open','isOpen','open','can_use','canUse','is_own','isOwn','owned','is_unlock','isUnlock','unlock','unlocked','is_enable','isEnable','enable','enabled','is_active','isActive','active','has_privilege','hasPrivilege','is_have','isHave','is_get','isGet','privilege_status','privilegeStatus','right_status','rightStatus','user_status','userStatus','auth_status','authStatus','is_valid','isValid'];"
        @"for(var i=0;i<oneKeys.length;i++)setOne(o,oneKeys[i]);"
        @"var zeroKeys=['has_expired','hasExpired','is_expired','isExpired','expired','is_lock','isLock','lock','locked','need_open','needOpen','need_buy','needBuy','need_svip','needSvip'];"
        @"for(var j=0;j<zeroKeys.length;j++)setZero(o,zeroKeys[j]);"
        @"if('super_player_type' in o)o.super_player_type=4;if('superPlayerType' in o)o.superPlayerType=4;"
        @"if('super_player_level' in o)o.super_player_level=LV;if('superPlayerLevel' in o)o.superPlayerLevel=LV;"
        @"if('sp_level' in o)o.sp_level=LV;if('spLevel' in o)o.spLevel=LV;"
        @"if('super_player_value' in o)o.super_player_value=MV;if('superPlayerValue' in o)o.superPlayerValue=MV;"
        @"if(('privilege_id' in o||'privilegeId' in o||'right_id' in o||'rightId' in o||'p_id' in o||'icon' in o)&&('status' in o)&&o.status===0)o.status=1;"
        @"if(('privilege_id' in o||'privilegeId' in o||'right_id' in o||'rightId' in o||'p_id' in o||'icon' in o)&&('state' in o)&&o.state===0)o.state=1;"
        @"for(var uk in o){if(/url|link/i.test(uk)&&typeof o[uk]==='string')o[uk]=rewriteUrlStr(o[uk]);}}"
        @"function patchNoble(o){"
        @"var NL=nlv();if(!(NL>0)||!o||typeof o!=='object')return;"
        @"var u=o.userInfo;"
        @"if(u&&typeof u==='object'&&('realLevel' in u||'nobilityValue' in u)){"
        @"var L=Math.min(Math.max(NL,1),10),NV=nval(),NK=nkeep();"
        @"u.level=L-1;u.realLevel=L-1;"
        @"u.nobilityValue=NV;u.relagationValue=NK;u.curTopRelagationVal=NK;"
        @"u.rechargeVal=1;u.consumeVal=1;u.remainDay=9999;u.tempNobilityRemainTs=0;"
        @"try{TTJSBridge.invoke('data','ttforge_h5_noble',JSON.stringify({level:u.level,realLevel:u.realLevel,value:u.nobilityValue}));}catch(e){}}"
        @"if(('nob_level' in o)&&(('nob_name' in o)||('ykw_conf' in o))){"
        @"o.nob_level=Math.min(Math.max(NL,1),10);o.nob_name=(window.__ttNName||'神王');"
        @"o.can_be_open=1;o.status=1;o.switch=1;o.is_open_enter_stealth=1;o.enter_notice=1;"
        @"var st=o.server_time||Math.floor(Date.now()/1000);"
        @"if(!o.expire_time||o.expire_time<st+86400)o.expire_time=st+3153600000;"
        @"if(!o.nickname)o.nickname='888888';"
        @"try{TTJSBridge.invoke('data','ttforge_h5_ykw',JSON.stringify(o));}catch(e){}}}"
        @"function patchDressList(o,t){"
        @"var d=o&&(o.data||o),l=d&&(d.info_list||d.dress_list||d.list);if(!l||!l.length)return;"
        @"var s=savedIds(),cur=s[String(t)];"
        @"for(var i=0;i<l.length;i++){var it=l[i];if(!it||typeof it!=='object')continue;"
        @"setOne(it,'can_use');setOne(it,'canUse');setOne(it,'is_own');setOne(it,'isOwn');"
        @"if(cur&&String(it.id)===String(cur))it.is_use=(typeof it.is_use==='number')?1:true;"
        @"else if(cur&&('is_use' in it))it.is_use=(typeof it.is_use==='number')?0:false;}}"
        @"function patchRootEnvelope(res,urlHint){"
        @"if(!res||typeof res!=='object')return;"
        @"var ch=(urlHint||'')+' '+location.href;"
        @"var isMemberCtx=(mlv()>0)&&/super[_-]?player|vip|member|privilege|right|dress/i.test(ch);"
        @"if(isMemberCtx){"
        @"var msgStr=String(res.msg||res.message||res.errMsg||'');"
        @"if(((res.code&&res.code!==0)||(res.ret&&res.ret!==0))&&/开通|SVIP|超级玩家|会员|特权|等级不足|未解锁|权限/i.test(msgStr)){"
        @"res.code=0;if('ret' in res)res.ret=0;res.msg='OK';if('errMsg' in res)res.errMsg='';if(!res.data)res.data={};}"
        @"if(res.data&&typeof res.data==='object'&&!Array.isArray(res.data)){"
        @"if(/getSuperPlayerInfo|super[_-]?player.*info|member.*info|vip.*info/i.test(ch))patchSP(res.data,true);"
        @"if(res.data.user_info&&typeof res.data.user_info==='object')patchSP(res.data.user_info,true);"
        @"if(res.data.userInfo&&typeof res.data.userInfo==='object'&&!('realLevel' in res.data.userInfo))patchSP(res.data.userInfo,true);"
        @"if(res.data.super_player_info&&typeof res.data.super_player_info==='object')patchSP(res.data.super_player_info,true);}}}"
        @"function walk(o,dep){if(!o||typeof o!=='object'||dep>7)return;"
        @"if(Array.isArray(o)){for(var i=0;i<o.length;i++)walk(o[i],dep+1);return;}"
        @"patchFlags(o);patchSP(o,false);patchNoble(o);"
        @"for(var k in o){if(Object.prototype.hasOwnProperty.call(o,k)&&o[k]&&typeof o[k]==='object')walk(o[k],dep+1);}}"
        @"var oj=JSON.parse;JSON.parse=function(t,r){var res=oj.call(JSON,t,r);"
        @"try{patchRootEnvelope(res,'');walk(res,0);}catch(e){}return res;};"
        @"try{var wrapBridge=function(){if(window.TTJSBridge&&window.TTJSBridge.invoke&&!window.TTJSBridge.__ttWrapped){"
        @"var origInv=window.TTJSBridge.invoke;window.TTJSBridge.__ttWrapped=1;"
        @"window.TTJSBridge.invoke=function(){var args=Array.prototype.slice.call(arguments);"
        @"try{var mod=args[0],mth=args[1];"
        @"if(mlv()>0&&mod==='operate'&&mth==='buySuperPlayer'&&location.href.indexOf('buy')<0){"
        @"if(typeof args[3]==='function'){try{args[3]({code:0,ret:0,msg:'OK'});}catch(e){}}"
        @"}if(mlv()>0&&(mth==='openWebUrl'||mth==='openUrl')&&args[2]){if(typeof args[2]==='string')args[2]=rewriteUrlStr(args[2]);else if(typeof args[2]==='object'&&args[2].url)args[2].url=rewriteUrlStr(args[2].url);}}catch(e){}"
        @"for(var i=0;i<args.length;i++){if(typeof args[i]==='function'){var fn=args[i];args[i]=function(res){"
        @"try{if(res&&typeof res==='object'){patchRootEnvelope(res,'');walk(res,0);}else if(typeof res==='string'&&res.charAt(0)==='{'){var po=oj.call(JSON,res);patchRootEnvelope(po,'');walk(po,0);res=JSON.stringify(po);}}catch(e){}"
        @"return fn.apply(this,arguments);};}}"
        @"return origInv.apply(this,args);};}};wrapBridge();setTimeout(wrapBridge,50);setTimeout(wrapBridge,300);}catch(e){}"
        @"function bodyField(p,names){if(!p||typeof p!=='object')return 0;"
        @"for(var i=0;i<names.length;i++){var v=p[names[i]];if(v!==undefined&&v!==null&&v!=='')return v;}return 0;}"
        @"function handleSetDress(url,rawBody){"
        @"var p=null;try{p=(typeof rawBody==='string')?oj.call(JSON,rawBody):rawBody;}catch(e){}"
        @"var dt=bodyField(p,['dress_type','dressType','type']),di=bodyField(p,['dress_id','dressId','id']);"
        @"if(!dt&&/SetChatSpecialDressInUse/i.test(url))dt=3;"
        @"dt=Number(dt)||0;di=Number(di)||0;if(di)saveDress(dt,di);else clearDress(dt);applyNative(dt,di);}"
        @"try{var proto=XMLHttpRequest.prototype;"
        @"var dText=Object.getOwnPropertyDescriptor(proto,'responseText');"
        @"var dResp=Object.getOwnPropertyDescriptor(proto,'response');"
        @"if(dText&&dText.get){Object.defineProperty(proto,'responseText',{configurable:true,get:function(){"
        @"if(this.__ttMockText!==undefined)return this.__ttMockText;"
        @"var raw=dText.get.call(this);"
        @"if(this.readyState===4&&raw&&typeof raw==='string'&&(raw.charAt(0)==='{'||raw.charAt(0)==='[')){"
        @"if(this.__ttPatchedText===undefined){try{var o=oj.call(JSON,raw);patchRootEnvelope(o,this.__ttUrl||'');walk(o,0);if(/GetUserDressList/i.test(this.__ttUrl||''))patchDressList(o,this.__ttDressTp||0);this.__ttPatchedObj=o;this.__ttPatchedText=JSON.stringify(o);}catch(e){this.__ttPatchedText=raw;}}"
        @"return this.__ttPatchedText;}return raw;}});}"
        @"if(dResp&&dResp.get){Object.defineProperty(proto,'response',{configurable:true,get:function(){"
        @"if(this.__ttMockResp!==undefined)return this.__ttMockResp;"
        @"var r=dResp.get.call(this);"
        @"if(this.readyState===4&&r){"
        @"if(typeof r==='string'&&(r.charAt(0)==='{'||r.charAt(0)==='[')){try{return this.responseText;}catch(e){return r;}}"
        @"if(typeof r==='object'){if(!this.__ttObjWalked){this.__ttObjWalked=1;try{patchRootEnvelope(r,this.__ttUrl||'');walk(r,0);if(/GetUserDressList/i.test(this.__ttUrl||''))patchDressList(r,this.__ttDressTp||0);}catch(e){}}return r;}}"
        @"return r;}});}}catch(e){}"
        @"var XO=XMLHttpRequest.prototype.open,XS=XMLHttpRequest.prototype.send;"
        @"XMLHttpRequest.prototype.open=function(m,u){this.__ttUrl=(u===undefined||u===null)?'':String(u);return XO.apply(this,arguments);};"
        @"XMLHttpRequest.prototype.send=function(body){var self=this,url=this.__ttUrl||'';"
        @"if(/GetUserDressList/i.test(url)){try{var bp=(typeof body==='string')?oj.call(JSON,body):body;if(bp)this.__ttDressTp=bp.type||bp.dress_type||0;}catch(e){}}"
        @"if(/SetDressInUse|SetChatSpecialDressInUse/i.test(url)){"
        @"handleSetDress(url,body);var txt=JSON.stringify({code:0,msg:'OK',data:{}});setTimeout(function(){var ok=false;try{"
        @"self.__ttMockText=txt;self.__ttMockResp=(self.responseType==='json')?{code:0,msg:'OK',data:{}}:txt;"
        @"Object.defineProperty(self,'readyState',{configurable:true,get:function(){return 4;}});"
        @"Object.defineProperty(self,'status',{configurable:true,get:function(){return 200;}});"
        @"Object.defineProperty(self,'statusText',{configurable:true,get:function(){return 'OK';}});"
        @"self.getAllResponseHeaders=function(){return 'content-type: application/json';};"
        @"self.getResponseHeader=function(k){return (String(k).toLowerCase()==='content-type')?'application/json':null;};"
        @"if(self.onreadystatechange)self.onreadystatechange();ok=true;if(self.onload)self.onload();if(self.onloadend)self.onloadend();"
        @"try{self.dispatchEvent(new Event('readystatechange'));self.dispatchEvent(new Event('load'));self.dispatchEvent(new Event('loadend'));}catch(e){}}catch(e){}"
        @"if(!ok){try{XS.call(self,body);}catch(e2){}}},10);return;}"
        @"return XS.apply(this,arguments);};"
        @"if(window.fetch&&window.Response){var of=window.fetch;window.fetch=function(input,init){"
        @"var u=(typeof input==='string')?input:((input&&input.url)?input.url:'');"
        @"if(/SetDressInUse|SetChatSpecialDressInUse/i.test(u)){"
        @"handleSetDress(u,init&&init.body);"
        @"return Promise.resolve(new Response(JSON.stringify({code:0,msg:'OK',data:{}}),{status:200,headers:{'Content-Type':'application/json'}}));}"
        @"if((mlv()>0||nlv()>0)&&!/\\.(js|css|png|jpg|jpeg|gif|webp|svg|woff|ttf|ico)(\\?|$)/i.test(u)){"
        @"var dtp=0;if(/GetUserDressList/i.test(u)){try{var bp=(init&&typeof init.body==='string')?oj.call(JSON,init.body):null;if(bp)dtp=bp.type||bp.dress_type||0;}catch(e){}}"
        @"return of.apply(this,arguments).then(function(r){try{return r.clone().text().then(function(t){try{"
        @"if(!t||(t.charAt(0)!=='{'&&t.charAt(0)!=='['))return r;"
        @"var o=oj.call(JSON,t);patchRootEnvelope(o,u);walk(o,0);if(dtp||/GetUserDressList/i.test(u))patchDressList(o,dtp);"
        @"return new Response(JSON.stringify(o),{status:r.status,statusText:r.statusText,headers:r.headers});}catch(e){return r;}});}catch(e){return r;}});}"
        @"return of.apply(this,arguments);};}"
        @"try{(function(){var h=location.href;"
        @"var reUp=/[,，、\\s]*(?:还差|距离升级|再[获充]得?)\\s*\\d[\\d,.\\s]*贵族值(?:可)?升级/g;"
        @"var reSplit1=/[,，、\\s]*还差\\s*$/,reSplit2=/^\\s*\\d[\\d,.\\s]*$/,reSplit3=/^\\s*贵族值(?:可)?升级/;"
        @"var reOpenBtn=/^(开通会员|立即开通|开通超级玩家|开通SVIP|立即开通会员|开通特权|去开通|立即续费|续费SVIP|续费会员)$/;"
        @"var fixDOM=function(){try{if(!document.body)return;var ch=location.href;"
        @"if((nlv()>0)&&/noble/i.test(ch)){"
        @"var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,null,false),n;"
        @"while((n=w.nextNode())){var v=n.nodeValue;if(!v)continue;"
        @"if(v.indexOf('贵族值')>=0&&v.indexOf('升级')>=0&&reUp.test(v)){"
        @"reUp.lastIndex=0;var hasK=(v.indexOf('已保级')>=0)||(n.parentElement&&(n.parentElement.textContent||'').indexOf('已保级')>=0);"
        @"var nv=v.replace(reUp,hasK?'':'已保级');if(nv!==v)n.nodeValue=nv;}"
        @"else if(reSplit1.test(v)){var nx=n.nextSibling,nx2=nx?nx.nextSibling:null;"
        @"var t1=nx?(nx.textContent||nx.nodeValue||''):'',t2=nx2?(nx2.textContent||nx2.nodeValue||''):'';"
        @"if(reSplit2.test(t1)&&reSplit3.test(t2)){"
        @"var hk=(v.indexOf('已保级')>=0)||(n.parentElement&&(n.parentElement.textContent||'').indexOf('已保级')>=0);"
        @"n.nodeValue=v.replace(reSplit1,hk?'':'已保级');"
        @"if(nx.nodeType===1){nx.style.display='none';nx.textContent='';}else nx.nodeValue='';"
        @"if(nx2.nodeType===3)nx2.nodeValue=t2.replace(reSplit3,'');else if(nx2.nodeType===1)nx2.textContent=t2.replace(reSplit3,'');}}}"
        @"var els=document.querySelectorAll('div,p,span,em,i,label');"
        @"for(var i=0;i<els.length;i++){var el=els[i];if(el.children.length>4)continue;"
        @"var tc=(el.textContent||'').trim();if(tc.length>0&&tc.length<80&&tc.indexOf('贵族值')>=0&&tc.indexOf('升级')>=0&&reUp.test(tc)){"
        @"var childHit=false;for(var j=0;j<el.children.length;j++){reUp.lastIndex=0;if(reUp.test(el.children[j].textContent||'')){childHit=true;break;}}"
        @"if(!childHit){reUp.lastIndex=0;var hk2=(tc.indexOf('已保级')>=0);var nt=tc.replace(reUp,hk2?'':'已保级');if(nt!==tc)el.textContent=nt;}}}}"
        @"if((mlv()>0)&&ch.indexOf('dressUpCenter')<0&&ch.indexOf('noble')<0){"
        @"var bels=document.querySelectorAll('button,a,div,span,p');"
        @"for(var k=0;k<bels.length;k++){var bel=bels[k];if(bel.children.length>2)continue;"
        @"var bt=(bel.textContent||'').trim();if(bt.length>=3&&bt.length<=8&&reOpenBtn.test(bt)){"
        @"bel.style.setProperty('display','none','important');"
        @"var bp=bel.parentElement;if(bp&&bp!==document.body&&bp.children.length<=2&&((bp.textContent||'').trim()===bt))"
        @"bp.style.setProperty('display','none','important');}}}"
        @"}catch(e){}};"
        @"var startObs=function(){try{fixDOM();var mo=new MutationObserver(fixDOM);"
        @"mo.observe(document.documentElement||document.body,{childList:true,subtree:true,characterData:true});"
        @"setInterval(fixDOM,180);}catch(e){}};"
        @"if(document.body)startObs();else document.addEventListener('DOMContentLoaded',startObs);"
        @"if(!(mlv()>0)||h.indexOf('dressUpCenter')>=0||h.indexOf('noble')>=0)return;"
        @"var css='.recharge,.packageBox,.noPackageDataTips,#halfVipPanel,.sheet-backdrop,.vip-package-item,.vip-payway,.svip-payway,.payBtn,.vip-descrption-button,.vip-description-button,.open-vip-btn,.open-member-btn,.vip-open-btn,.svip-open-btn{display:none!important}';"
        @"var add=function(){try{var st=document.createElement('style');st.type='text/css';st.appendChild(document.createTextNode(css));(document.head||document.documentElement).appendChild(st);}catch(e){}};"
        @"if(document.head)add();else document.addEventListener('DOMContentLoaded',add);})();}catch(e){}"
        @"})();";
    return [seed stringByAppendingString:body];
}

static void TTInjectH5ScriptIntoConfig(id cfg) {
    @try {
        if (!cfg || !TTH5ForgeActive()) return;
        id ucc = TTGetObj(cfg, @selector(userContentController));
        Class usCls = NSClassFromString(@"WKUserScript");
        if (!ucc || !usCls || ![ucc respondsToSelector:@selector(addUserScript:)]) return;
        BOOL hasCore = NO;
        for (id sc in (NSArray *)TTGetObj(ucc, @selector(userScripts))) {
            NSString *src = TTGetObj(sc, @selector(source));
            if ([src isKindOfClass:[NSString class]] && [src rangeOfString:@"__ttforgeH5V733"].location != NSNotFound) {
                hasCore = YES;
                break;
            }
        }
        NSString *js = hasCore ? TTH5SeedScript() : TTH5ForgeScript();
        if (!hasCore) TTLog(@"V 层 注入 H5 会员/贵族/装扮本地化脚本 %lu 字节", (unsigned long)js.length);
        id script = ((id (*)(id, SEL, id, NSInteger, BOOL))objc_msgSend)([usCls alloc],
            @selector(initWithSource:injectionTime:forMainFrameOnly:), js, 0, NO);
        if (script) {
            TTSetObj(ucc, @selector(addUserScript:), script);
            [script release];
        }
    } @catch (id e) {}
}

static id TTU_wkConfig(id self, SEL _cmd) {
    id cfg = origU_wkConfig(self, _cmd);
    TTInjectH5ScriptIntoConfig(cfg);
    return cfg;
}

static id TTV_wkInit(id self, SEL _cmd, CGRect frame, id cfg) {
    TTInjectH5ScriptIntoConfig(cfg);
    return origV_wkInit ? origV_wkInit(self, _cmd, frame, cfg) : nil;
}

static id TTV_loadRequest(id self, SEL _cmd, id req) {
    @try {
        TTInjectH5ScriptIntoConfig(TTGetObj(self, @selector(configuration)));
        if (TTH5ForgeActive() && [self respondsToSelector:@selector(evaluateJavaScript:completionHandler:)]) {
            ((void (*)(id, SEL, id, id))objc_msgSend)(self, @selector(evaluateJavaScript:completionHandler:), TTH5SeedScript(), nil);
        }
    } @catch (id e) {}
    return origV_loadRequest ? origV_loadRequest(self, _cmd, req) : nil;
}

__attribute__((constructor)) static void TTForgeInit(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    gHits = [[NSMutableDictionary alloc] init];
    gForgedPlayers = [[NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality] retain];
    gGPBOrig = [[NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality
                                      valueOptions:NSPointerFunctionsStrongMemory] retain];
    NSArray *sk = [d objectForKey:@"ttforge.specialConcernKeys"];
    gSpecialKeys = sk ? [[NSMutableSet alloc] initWithArray:sk] : [[NSMutableSet alloc] init];
    NSDictionary *hv = [d objectForKey:@"ttforge.hideVisits"];
    gHideVisits = hv ? [hv mutableCopy] : [[NSMutableDictionary alloc] init];
    gHideSent = [[NSMutableSet alloc] init];
    gLogLock = [[NSObject alloc] init];
    gTaskURL = [[NSMutableDictionary alloc] init];
    gTaskBody = [[NSMutableDictionary alloc] init];
    gTaskCode = [[NSMutableDictionary alloc] init];
    gTaskClasses = [[NSMutableSet alloc] init];
    gTaskPatchKind = [[NSMutableDictionary alloc] init];
    gMagicEchoTargets = [[NSHashTable weakObjectsHashTable] retain];
    gMagicVMs = [[NSHashTable weakObjectsHashTable] retain];
    gH5Capture = [d boolForKey:@"ttforge.h5capture"];
    gRTAntiMute  = [d boolForKey:@"ttforge.rtAntiMute"];
    gRTAntiClear = [d boolForKey:@"ttforge.rtAntiClear"];
    gRTAudio192  = [d boolForKey:@"ttforge.rtAudio192"];
    gRTSkin      = [d boolForKey:@"ttforge.rtSkin"];
    gRTAntiKick  = [d boolForKey:@"ttforge.rtAntiKick"];
    gRTUpMic     = [d boolForKey:@"ttforge.rtUpMic"];
    gRTIsland    = [d boolForKey:@"ttforge.rtIsland"];
    gRTDressId   = (uint32_t)[d integerForKey:@"ttforge.rtDressId"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TTRTInstallHooks();
    });

    NSString *lp = TTLogPath();
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:lp error:nil];
    if ([attrs[NSFileSize] unsignedLongLongValue] > 2 * 1024 * 1024) {
        NSString *old = [lp stringByAppendingString:@".old"];
        [[NSFileManager defaultManager] removeItemAtPath:old error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:lp toPath:old error:nil];
    }

    gSelfUid       = (uint32_t)[d integerForKey:@"ttforge.selfUid"];
    gBlockReport   = [d boolForKey:@"ttforge.blockReport"];
    gSneakAll      = [d objectForKey:@"ttforge.sneakAll"] ? [d boolForKey:@"ttforge.sneakAll"] : YES;

    BOOL legacyNameColor = [d objectForKey:@"ttforge.nameColor"] ? [d boolForKey:@"ttforge.nameColor"] : YES;
    if ([d objectForKey:@"ttforge.nameStyle"]) {
        gNameStyle = [d integerForKey:@"ttforge.nameStyle"];
        if (gNameStyle < 0 || gNameStyle > 3) gNameStyle = 1;
    } else if (!legacyNameColor) {
        gNameStyle = 0;
    }
    if ([d objectForKey:@"ttforge.nameColorIndex"]) {
        gNameColorIndex = [d integerForKey:@"ttforge.nameColorIndex"];
        if (gNameColorIndex < 0 || gNameColorIndex > 9) gNameColorIndex = 0;
    }

    gMemberLevel    = [d objectForKey:@"ttforge.memberLevel"]   ? [d integerForKey:@"ttforge.memberLevel"]   : 8;
    gNobleLevel     = [d objectForKey:@"ttforge.nobleLevel"]    ? [d integerForKey:@"ttforge.nobleLevel"]    : 10;
    gRichLevelVal   = [d objectForKey:@"ttforge.richLevelVal"]  ? [d integerForKey:@"ttforge.richLevelVal"]  : 0;
    gCharmLevelVal  = [d objectForKey:@"ttforge.charmLevelVal"] ? [d integerForKey:@"ttforge.charmLevelVal"] : 0;
    gBubbleDressId  = (uint32_t)[d integerForKey:@"ttforge.bubbleDressId"];
    gChatBgDressId  = (uint32_t)[d integerForKey:@"ttforge.chatBgDressId"];
    gSpecialDressId = (uint32_t)[d integerForKey:@"ttforge.specialDressId"];
    gRoomDressId    = (uint32_t)[d integerForKey:@"ttforge.roomDressId"];

    NSString *s = [d stringForKey:@"ttforge.customId"];      if (s.length) gCustomId = [s copy];
    s = [d stringForKey:@"ttforge.myRealAccount"];           if (s.length) gMyRealAccount = [s copy];
    s = [d stringForKey:@"ttforge.myNickname"];              if (s.length) gMyNickname = [s copy];

    uint64_t st = (uint64_t)[d integerForKey:@"ttforge.stealthSwitch"];
    gStealthSwitch = (st == 1 || st == 2) ? st : 2;

    Class wkViewCls = NSClassFromString(@"WKWebView");
    BOOL wv1 = TTSwizzle(wkViewCls, @selector(initWithFrame:configuration:), (IMP)TTV_wkInit, (IMP *)&origV_wkInit);
    BOOL wv2 = TTSwizzle(wkViewCls, @selector(loadRequest:), (IMP)TTV_loadRequest, (IMP *)&origV_loadRequest);
    TTLog(@"V 层 WKWebView 注入补强 init=%@ loadRequest=%@", wv1 ? @"✓" : @"✗", wv2 ? @"✓" : @"✗");

    {
        BOOL aOK = NO, bOK = NO, cOK = NO, dOK = NO, rOK = NO, nOK = NO, wOK = NO, hOK = NO, eOK = NO, kOK = NO, mOK = NO, uOK = NO;

        Class aCls = NSClassFromString(@"UserUGCInfo");
        if (aCls) {
            origA_uid = (uint32_t (*)(id, SEL))TTOrigIMP(aCls, @selector(uid));
            BOOL ok = TTSwizzle(aCls, @selector(vipLevel), (IMP)TTA_vipLevel, (IMP *)&origA_vipLevel);
            ok = TTSwizzle(aCls, @selector(nobleInfo), (IMP)TTA_nobleInfo, (IMP *)&origA_nobleInfo) && ok;
            ok = TTSwizzle(aCls, @selector(spInfo), (IMP)TTA_spInfo, (IMP *)&origA_spInfo) && ok;
            TTSwizzle(aCls, @selector(nickname), (IMP)TTA_nickname, (IMP *)&origA_nickname);
            TTSwizzle(aCls, @selector(account), (IMP)TTA_account, (IMP *)&origA_account);
            aOK = ok && origA_uid != NULL;
        }

        Class bCls = NSClassFromString(@"TTUGCUserInfo");
        if (bCls) {
            origB_uid = (uint32_t (*)(id, SEL))TTOrigIMP(bCls, @selector(uid));
            origB_nickName = (id (*)(id, SEL))TTOrigIMP(bCls, @selector(nickName));
            origB_account = (id (*)(id, SEL))TTOrigIMP(bCls, @selector(account));
            BOOL ok = TTSwizzle(bCls, @selector(vipLevel), (IMP)TTB_vipLevel, (IMP *)&origB_vipLevel);
            ok = TTSwizzle(bCls, @selector(isYearMemberhip), (IMP)TTB_isYearMemberhip, (IMP *)&origB_isYearMemberhip) && ok;
            ok = TTSwizzle(bCls, @selector(nobilityInfo), (IMP)TTB_nobilityInfo, (IMP *)&origB_nobilityInfo) && ok;
            ok = TTSwizzle(bCls, @selector(account), (IMP)TTB_account, (IMP *)&origB_account) && ok;
            TTSwizzle(bCls, @selector(displayAccount), (IMP)TTB_displayAccount, (IMP *)&origB_displayAccount);
            TTSwizzle(bCls, @selector(ttAvatarAccount), (IMP)TTB_ttAvatarAccount, (IMP *)&origB_ttAvatarAccount);
            bOK = ok && origB_uid != NULL;
        }

        Class cCls = NSClassFromString(@"TTSuperPlayer");
        Class lCls = NSClassFromString(@"TTSuperPlayerLevel");
        Class mCls = NSClassFromString(@"TTSuperPlayerManager");
        if (cCls && lCls && mCls) {
            origC_getSuperPlayerLevel = (id (*)(id, SEL))TTOrigIMP(cCls, @selector(getSuperPlayerLevel));
            BOOL ok = TTSwizzle(cCls, @selector(isSvip), (IMP)TTC_isSvip, (IMP *)&origC_isSvip);
            TTSwizzle(cCls, @selector(getLevel), (IMP)TTC_getLevel, (IMP *)&origC_getLevel);
            TTSwizzle(cCls, @selector(getLevelIconIsNeedNoOpen:), (IMP)TTC_getLevelIcon, (IMP *)&origC_getLevelIcon);
            TTSwizzle(cCls, @selector(getSuperPlayerLevel), (IMP)TTC_getSuperPlayerLevel, (IMP *)&origC_getSuperPlayerLevel);
            TTSwizzle(cCls, @selector(information), (IMP)TTC_information, (IMP *)&origC_information);
            TTSwizzle(cCls, @selector(getInformation), (IMP)TTC_getInformation, (IMP *)&origC_getInformation);
            TTSwizzle(cCls, @selector(currentDress), (IMP)TTC_currentDress, (IMP *)&origC_currentDress);
            TTSwizzle(cCls, @selector(setCurrentDress:), (IMP)TTC_setCurrentDress, (IMP *)&origC_setCurrentDress);
            TTSwizzle(cCls, @selector(getSpecialConcernSuit), (IMP)TTC_getSpecialConcernSuit, (IMP *)&origC_getSpecialConcernSuit);
            TTSwizzle(cCls, @selector(dressConfigDidUpdate:), (IMP)TTC_dressConfigDidUpdate, (IMP *)&origC_dressConfigDidUpdate);
            TTSwizzle(cCls, @selector(nobilityInfo), (IMP)TTC_nobilityInfo, (IMP *)&origC_nobilityInfo);
            TTSwizzle(cCls, @selector(getAccount), (IMP)TTC_getAccount, (IMP *)&origC_getAccount);
            TTSwizzle(cCls, @selector(account), (IMP)TTC_account, (IMP *)&origC_account);
            TTSwizzleClassMethod(cCls, @selector(getSuperLevelPngIcon:), (IMP)TTC_getSuperLevelPngIcon, (IMP *)&origC_getSuperLevelPngIcon);
            ok = TTSwizzle(cCls, @selector(isYearMembership), (IMP)TTC_isYearMembership, (IMP *)&origC_isYearMembership) && ok;
            ok = TTSwizzle(cCls, @selector(isSuperPlayerActive), (IMP)TTC_isSuperPlayerActive, (IMP *)&origC_isSuperPlayerActive) && ok;
            ok = TTSwizzle(cCls, @selector(getVipStatus), (IMP)TTC_getVipStatus, (IMP *)&origC_getVipStatus) && ok;
            ok = TTSwizzle(cCls, @selector(isSpecialConcern:), (IMP)TTSC_isSC, (IMP *)&origSC_isSC) && ok;
            ok = TTSwizzle(cCls, @selector(isSpecialConcernAccount:), (IMP)TTSC_isSCAcc, (IMP *)&origSC_isSCAcc) && ok;
            ok = TTSwizzle(cCls, @selector(addUserSpecialConcern:callback:), (IMP)TTSC_add, (IMP *)&origSC_add) && ok;
            ok = TTSwizzle(cCls, @selector(removeUserSpecialConcern:callback:), (IMP)TTSC_remove, (IMP *)&origSC_remove) && ok;
            TTSwizzle(cCls, @selector(addOrDelSpecial:isAdd:), (IMP)TTSC_addOrDel, (IMP *)&origSC_addOrDel);
            ok = TTSwizzle(cCls, @selector(superPlayerType), (IMP)TTC_superPlayerType, (IMP *)&origC_superPlayerType) && ok;
            ok = TTSwizzle(cCls, @selector(getMySvipWeekStealthRemainTime), (IMP)TTC_weekRemain, (IMP *)&origC_weekRemain) && ok;
            ok = TTSwizzle(cCls, @selector(getMySvipWeekStealthTimes), (IMP)TTC_weekTimes, (IMP *)&origC_weekTimes) && ok;
            ok = TTSwizzle(cCls, @selector(getMySvipIsTodayStealth), (IMP)TTC_isTodayStealth, (IMP *)&origC_isTodayStealth) && ok;
            ok = TTSwizzle(cCls, @selector(getMySneakilyReadSwitch), (IMP)TTC_sneakilySwitch, (IMP *)&origC_sneakilySwitch) && ok;
            ok = TTSwizzle(cCls, @selector(getMySvipOnlineSwitch), (IMP)TTC_onlineSwitch, (IMP *)&origC_onlineSwitch) && ok;
            ok = TTSwizzle(cCls, @selector(setSVipOnlineSwitch:completion:), (IMP)TTC_setOnlineSwitch, (IMP *)&origC_setOnlineSwitch) && ok;
            ok = TTSwizzle(lCls, @selector(isSvip), (IMP)TTCL_isSvip, (IMP *)&origCL_isSvip) && ok;
            ok = TTSwizzle(lCls, @selector(isSuperPlayer), (IMP)TTCL_isSuperPlayer, (IMP *)&origCL_isSuperPlayer) && ok;
            ok = TTSwizzle(lCls, @selector(superPlayerType), (IMP)TTCL_superPlayerType, (IMP *)&origCL_superPlayerType) && ok;
            ok = TTSwizzle(lCls, @selector(spLevel), (IMP)TTCL_spLevel, (IMP *)&origCL_spLevel) && ok;
            ok = TTSwizzle(mCls, @selector(isMySuperPlayerActive), (IMP)TTCM_isMySuperPlayerActive, (IMP *)&origCM_isMySuperPlayerActive) && ok;
            ok = TTSwizzle(mCls, @selector(hasPrivilege:), (IMP)TTCM_hasPrivilege, (IMP *)&origCM_hasPrivilege) && ok;
            ok = TTSwizzle(mCls, @selector(isWhiteUid:), (IMP)TTCM_isWhiteUid, (IMP *)&origCM_isWhiteUid) && ok;
            ok = TTSwizzle(mCls, @selector(playerForUid:), (IMP)TTCM_playerForUid, (IMP *)&origCM_playerForUid) && ok;
            ok = TTSwizzle(mCls, @selector(mePlayer), (IMP)TTCM_mePlayer, (IMP *)&origCM_mePlayer) && ok;
            cOK = ok && origC_getSuperPlayerLevel != NULL;
        }

        Class dCls = NSClassFromString(@"UserVisitorRecordService");
        if (dCls) dOK = TTSwizzle(dCls, @selector(reqReportUserVisitorRecord:), (IMP)TTD_report, (IMP *)&origD_report);

        {
            Class spCls = NSClassFromString(@"TTSuperPlayer");
            BOOL ok = TTSwizzle(TTFindClassWithMethod(@selector(syncFormPbPlayerInfo:needCheck:), spCls),
                                @selector(syncFormPbPlayerInfo:needCheck:), (IMP)TTR_syncInfo, (IMP *)&origR_syncInfo);
            ok = TTSwizzle(TTFindClassWithMethod(@selector(updateMySvipPrivilege:), spCls),
                           @selector(updateMySvipPrivilege:), (IMP)TTR_updateProfile, (IMP *)&origR_updateProfile) && ok;
            ok = TTSwizzle(NSClassFromString(@"TTUGCUserInfo"), @selector(initWithPbInfo:), (IMP)TTR_initWithPb, (IMP *)&origR_initWithPb) && ok;
            ok = TTSwizzle(NSClassFromString(@"TTMyGrowInfo"), @selector(updateWithPBMyGrowInfo:), (IMP)TTR_updateMyGrow, (IMP *)&origR_updateMyGrow) && ok;
            ok = TTSwizzleClassMethod(NSClassFromString(@"TTGrowInfo"), @selector(growInfoWithPBGrowInfo:), (IMP)TTR_growWithPB, (IMP *)&origR_growWithPB) && ok;
            rOK = ok;
        }

        {
            Class pCls = NSClassFromString(@"TTNobilityPrivilege");
            BOOL ok = TTSwizzle(pCls, @selector(isExclusiveNameplate), (IMP)TTN_exclusive, (IMP *)&origN_exclusive);
            ok = TTSwizzle(pCls, @selector(isOnlineInVisible), (IMP)TTN_onlineInVisible, (IMP *)&origN_onlineInVisible) && ok;
            TTSwizzle(pCls, @selector(isChatingMessageColor), (IMP)TTN_chatColor, (IMP *)&origName_chatColor);
            TTSwizzle(pCls, @selector(isMicNicknameColor), (IMP)TTN_micColor, (IMP *)&origName_micColor);
            TTSwizzle(pCls, @selector(isGodKingMicNicknameColor), (IMP)TTN_godMicColor, (IMP *)&origName_godMicColor);
            TTSwizzle(pCls, @selector(isFriendRedName), (IMP)TTN_friendRed, (IMP *)&origName_friendRed);
            TTSwizzleClassMethod(pCls, @selector(getGradientFriendRedName:), (IMP)TTN_getGradientRed, (IMP *)&origN_getGradientRed);
            TTSwizzleClassMethod(pCls, @selector(getGradientFriendRedNameV2:), (IMP)TTN_getGradientRedV2, (IMP *)&origN_getGradientRedV2);
            TTSwizzle(pCls, @selector(isNobilityFriendRedV2), (IMP)TTN_friendV2, (IMP *)&origName_friendV2);
            Class sCls = NSClassFromString(@"NobilitySyncService");
            ok = TTSwizzle(sCls, @selector(createPrivilegeWith:visible:config:), (IMP)TTN_createPriv, (IMP *)&origN_createPriv) && ok;
            TTSwizzle(sCls, @selector(useNobilityInfoGetPrivilege:), (IMP)TTN_useNobility, (IMP *)&origN_useNobility);
            Class vmCls2 = TTFindClassWithMethod(@selector(attributedNameForSuperPlayer:withTextColor:), NSClassFromString(@"RealTimeVoiceMessageHandler"));
            TTSwizzle(vmCls2, @selector(attributedNameForSuperPlayer:withTextColor:), (IMP)TTN_attrName, (IMP *)&origName_attr);
            nOK = ok;
        }

        {
            Class ccCls = TTFindClassWithMethod(@selector(send:message:resultBlock:), NSClassFromString(@"ConnectionCore"));
            if (ccCls && [NSStringFromClass(ccCls) rangeOfString:@"ConnectionCore"].location == NSNotFound) ccCls = nil;
            wOK = TTSwizzle(ccCls, @selector(send:message:resultBlock:), (IMP)TTW_send, (IMP *)&origW_send);
        }

        {
            Class lcCls = NSClassFromString(@"PersonalDetailLayoutContext");
            {
                Method initM = lcCls ? class_getInstanceMethod(lcCls, @selector(init)) : NULL;
                if (initM) {
                    origH_init = (id (*)(id, SEL))method_getImplementation(initM);
                    if (!class_addMethod(lcCls, @selector(init), (IMP)TTH_init, method_getTypeEncoding(initM))) {
                        method_setImplementation(initM, (IMP)TTH_init);
                    }
                    TTLog(@"H 层 init 安全钩子 PersonalDetailLayoutContext 子类独占 orig=%p", origH_init);
                }
            }
            TTSwizzle(lcCls, @selector(setIsMe:), (IMP)TTH_setIsMe, (IMP *)&origH_setIsMe);
            TTSwizzle(lcCls, @selector(isMe), (IMP)TTH_isMe, (IMP *)&origH_isMe);
            TTSwizzle(lcCls, @selector(IdView), (IMP)TTH_idView, (IMP *)&origH_idView);
            TTSwizzle(lcCls, @selector(setIdView:), (IMP)TTH_setIdView, (IMP *)&origH_setIdView);
            TTSwizzle(lcCls, @selector(setNobilityTipView:), (IMP)TTH_setNobilityTipView, (IMP *)&origH_setNobilityTipView);
            TTSwizzle(lcCls, @selector(handlerUpdateNickNameViewLayout), (IMP)TTH_updateNickLayout, (IMP *)&origH_updateNickLayout);
            BOOL ok = TTSwizzle(lcCls, @selector(handlerSuperPlayerViewAppear:), (IMP)TTH_appear, (IMP *)&origH_appear);
            ok = TTSwizzle(lcCls, @selector(handlerNobilityTipViewAppear:), (IMP)TTH_nobleAppear, (IMP *)&origH_nobleAppear) && ok;
            SEL reloadSel = @selector(didReloadDataWithIsShow:scanerViews:photoDetailView:pageBgView:homeBgV:);
            Class pdVcCls = TTFindClassWithMethod(reloadSel, NSClassFromString(@"_TtC13UserComponent28PersonalDetailViewController"));
            TTSwizzle(pdVcCls, reloadSel, (IMP)TTH_didReloadData, (IMP *)&origH_didReloadData);
            hOK = ok;
        }

        {
            Class mCls2 = NSClassFromString(@"TTSuperPlayerManager");
            BOOL ok = TTSwizzle(mCls2, @selector(reqGetHideStatusWithUid:callBack:), (IMP)TTD2_getStatus, (IMP *)&origD2_getStatus);
            ok = TTSwizzle(mCls2, @selector(reqGetHideListWithOffset:limit:callBack:), (IMP)TTD2_getList, (IMP *)&origD2_getList) && ok;
            dOK = dOK && ok;
        }

        eOK = TTSwizzle(TTFindClassWithMethod(@selector(realSendType), NSClassFromString(@"TTIMMessage")),
                        @selector(realSendType), (IMP)TTE_realSendType, (IMP *)&origE_realSendType);

        {
            Class swCls = TTFindLabClass(@selector(featureSwitchIsOnWithKey:defaultValue:));
            BOOL k1 = NO;
            if (swCls) {
                Method m = class_getInstanceMethod(swCls, @selector(featureSwitchIsOnWithKey:defaultValue:));
                const char *te = m ? method_getTypeEncoding(m) : NULL;
                if (te && (te[0] == 'B' || te[0] == 'c'))
                    k1 = TTSwizzle(swCls, @selector(featureSwitchIsOnWithKey:defaultValue:), (IMP)TTK_switch, (IMP *)&origK_switch);
                TTLog(@"K 子钩 feature 类=%@ 编码=%s", NSStringFromClass(swCls), te ? te : "?");
            }
            SEL hookSel = @selector(getWebHookSwitchIsOn);
            Class labCls = TTFindLabClass(hookSel);
            if (!labCls) { hookSel = @selector(webHookSwitchIsOn); labCls = TTFindLabClass(hookSel); }
            BOOL k2 = TTSwizzle(labCls, hookSel, (IMP)TTK_lab, (IMP *)&origK_lab);
            if (labCls) TTLog(@"K 子钩 webHook 类=%@ sel=%@", NSStringFromClass(labCls), NSStringFromSelector(hookSel));
            Class wkCls = TTFindClassWithMethod(@selector(webView:startURLSchemeTask:), NSClassFromString(@"TTWKWebView"));
            if (!wkCls) wkCls = TTFindClassWithMethod(@selector(webView:startURLSchemeTask:), nil);
            BOOL k3 = TTSwizzle(wkCls, @selector(webView:startURLSchemeTask:), (IMP)TTK_start, (IMP *)&origK_start);
            if (wkCls) TTLog(@"K 子钩 scheme 类=%@", NSStringFromClass(wkCls));
            kOK = (k2 && k3);
            TTLog(@"K 层子钩结果 feature=%@ webHook=%@ scheme=%@ (总状态=%@)",
                  k1 ? @"✓" : @"-(非独立ObjC类)", k2 ? @"✓" : @"✗", k3 ? @"✓" : @"✗", kOK ? @"✓" : @"✗");

            Class mgrCls = TTFindClassWithMethod(@selector(setTabArray:), NSClassFromString(@"ChannelMagicExpressionManager"));
            mOK = TTSwizzle(mgrCls, @selector(setTabArray:), (IMP)TTM_setTabs, (IMP *)&origM_setTabs);
            Class vmCls = NSClassFromString(@"MagicExpressionMicPlayerVM");
            BOOL vmOK = TTSwizzle(vmCls, @selector(initWithMicId:andEmojiLotView:andEmojiLotBgView:), (IMP)TTM_vmInit, (IMP *)&origM_vmInit);
            Class curVmCls = TTFindClassWithMethod(@selector(currentMagicExpressionVm), nil);
            BOOL curVmOK = TTSwizzle(curVmCls, @selector(currentMagicExpressionVm), (IMP)TTM_currentVM, (IMP *)&origM_currentVM);
            Class startGameCls = TTFindClassWithMethod(@selector(startGame), vmCls);
            BOOL sgOK = TTSwizzle(startGameCls, @selector(startGame), (IMP)TTM_startGame, (IMP *)&origM_startGame);
            BOOL seOK = TTSwizzle(mgrCls, @selector(getStartEmoji), (IMP)TTM_getStartEmoji, (IMP *)&origM_getStartEmoji);
            BOOL ssOK = TTSwizzle(mgrCls, @selector(startEmojiStatus), (IMP)TTM_startEmojiStatus, (IMP *)&origM_startEmojiStatus);
            TTLog(@"MAGIC 发送闸门 startGame=%@ getStartEmoji=%@ startEmojiStatus=%@", sgOK ? @"✓" : @"✗", seOK ? @"✓" : @"✗", ssOK ? @"✓" : @"✗");
            TTLog(@"MAGIC VM 钩子 类=%@ → %@ / currentVM 类=%@ → %@", vmCls ? NSStringFromClass(vmCls) : @"未找到", vmOK ? @"✓" : @"✗",
                  curVmCls ? NSStringFromClass(curVmCls) : @"未找到", curVmOK ? @"✓" : @"✗");

            BOOL u1 = TTSwizzleClassMethod(NSClassFromString(@"IMConversation"), @selector(setMsgBubbleDressId:), (IMP)TTU_setBubbleId, (IMP *)&origU_setBubbleId);
            Class spBgCls = TTFindClassWithMethod(@selector(getChatBackgroundImageUrlStringWihtTargetAccount:), NSClassFromString(@"TTSuperPlayer"));
            BOOL u2 = TTSwizzle(spBgCls, @selector(getChatBackgroundImageUrlStringWihtTargetAccount:), (IMP)TTU_getChatBgURL, (IMP *)&origU_getChatBgURL);

            Class dataApiCls = TTFindClassWithMethod(@selector(data_changeMyIMBubbleDressId:callback:from:), NSClassFromString(@"DataClientAPI"));
            TTSwizzle(dataApiCls, @selector(data_changeMyIMBubbleDressId:callback:from:), (IMP)TTU_bridgeBubble, (IMP *)&origU_bridgeBubble);
            TTSwizzle(dataApiCls, @selector(data_changeIMBackgroundDressId:callback:from:), (IMP)TTU_bridgeChatBg, (IMP *)&origU_bridgeChatBg);
            Class jbCls = TTFindClassWithMethod(@selector(_invokeClientMethod:parameter:callback:), NSClassFromString(@"JavascriptBridge"));
            TTSwizzle(jbCls, @selector(_invokeClientMethod:parameter:callback:), (IMP)TTU_jsInvoke, (IMP *)&origU_jsInvoke);
            Class ttwkCls = TTFindClassWithMethod(@selector(WKWebViewConfiguration), NSClassFromString(@"TTWKWebView"));
            TTSwizzle(ttwkCls, @selector(WKWebViewConfiguration), (IMP)TTU_wkConfig, (IMP *)&origU_wkConfig);
            uOK = u1 && u2;

            Class roomDressCls = TTFindClassWithMethod(@selector(getCurSuperplayerRoomDress), NSClassFromString(@"RealTimeMicControl"));
            BOOL v1 = TTSwizzle(roomDressCls, @selector(getCurSuperplayerRoomDress), (IMP)TTV_getRoomDress, (IMP *)&origV_getRoomDress);
            TTLog(@"V 层 房间装扮钩子 类=%@ → %@", roomDressCls ? NSStringFromClass(roomDressCls) : @"未找到", v1 ? @"✓" : @"✗");
            Class spMgrCls = TTFindClassWithMethod(@selector(getKRoomDressOverdueAlertKey), NSClassFromString(@"TTSuperPlayerManager"));
            BOOL v2 = TTSwizzle(spMgrCls, @selector(getKRoomDressOverdueAlertKey), (IMP)TTV_roomOverdueAlert, (IMP *)&origV_roomOverdueAlert);
            TTSwizzle(spMgrCls, @selector(getKIsShowRoomDressKey), (IMP)TTV_isShowRoomDress, (IMP *)&origV_isShowRoomDress);
            Class micCls2 = TTFindClassWithMethod(@selector(needShowSuperPlayerAlert), NSClassFromString(@"RealTimeMicControl"));
            BOOL v3 = TTSwizzle(micCls2, @selector(needShowSuperPlayerAlert), (IMP)TTV_micNeedAlert, (IMP *)&origV_micNeedAlert);
            TTLog(@"V 层 房间装扮过期提示屏蔽 类=%@ → %@ / micAlert=%@", spMgrCls ? NSStringFromClass(spMgrCls) : @"未找到", v2 ? @"✓" : @"✗", v3 ? @"✓" : @"✗");

            Class onCls = NSClassFromString(@"OnlineNotifyService");
            if (onCls) {
                TTSwizzle(onCls, @selector(isSuperPlayerActive), (IMP)TTON_isSPActive, (IMP *)&origON_isSPActive);
                TTSwizzle(onCls, @selector(superPlayerActiveAndSpecialConcernCountDontOverLimit), (IMP)TTON_scDontOverLimit, (IMP *)&origON_scDontOverLimit);
            }

            Class utilCls = NSClassFromString(@"TTUIUtil");
            BOOL ie = TTSwizzleClassMethod(utilCls, @selector(showError:), (IMP)TTV_showError, (IMP *)&origV_showError) ||
                      TTSwizzle(utilCls, @selector(showError:), (IMP)TTV_showError, (IMP *)&origV_showError);
            BOOL ih = TTSwizzleClassMethod(utilCls, @selector(showHint:), (IMP)TTV_showHint, (IMP *)&origV_showHint) ||
                      TTSwizzle(utilCls, @selector(showHint:), (IMP)TTV_showHint, (IMP *)&origV_showHint);
            TTLog(@"V 层 TTUIUtil 提示拦截 error=%@ hint=%@", ie ? @"✓" : @"✗", ih ? @"✓" : @"✗");
        }
        TTLog(@"TTForge v7.47 启动 层 A%@ B%@ C%@ D%@ R%@ N%@ W%@ H%@ E%@ K%@ M%@ G✗ U%@ H5抓取=%@ 会员=%@ 贵族=%@ 隐身=%@ 名字=%@ 气泡=#%u 背景=#%u 关心=#%u 房间=#%u",
              aOK ? @"✓" : @"✗", bOK ? @"✓" : @"✗", cOK ? @"✓" : @"✗", dOK ? @"✓" : @"✗",
              rOK ? @"✓" : @"✗", nOK ? @"✓" : @"✗", wOK ? @"✓" : @"✗", hOK ? @"✓" : @"✗",
              eOK ? @"✓" : @"✗", kOK ? @"✓" : @"✗", mOK ? @"✓" : @"✗",
              uOK ? @"✓" : @"✗", gH5Capture ? @"开" : @"关",
              TTMemberLevelName(), TTNobleLevelName(), gStealthSwitch == 2 ? @"隐身" : @"在线", TTNamePresetName(),
              gBubbleDressId, gChatBgDressId, gSpecialDressId, gRoomDressId);

        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                uint32_t initUid = TTStrictSelfUid();
                id initMe = TTCMePlayer();
                if (initMe) {
                    TTRegisterForgedPlayer(initMe);
                    TTMyRealAccount();
                    if (initUid > 0) TTTagNobilityInfoOnObject(initMe, initUid);
                }
                if (gBubbleDressId > 0) TTApplyBubbleDressNow();
                if (gChatBgDressId > 0) TTApplyChatBgDressNow();
                if (gSpecialDressId > 0) TTApplySpecialDressNow();
                if (gRoomDressId > 0) TTApplyRoomDressNow();
                id selfCtx = TTGetLastSelfLayoutCtx();
                if (selfCtx) TTApplySelfBadgesToContext(selfCtx);
            } @catch (id e) {}
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                TTRegisterNovaUIModules();
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (gSpecialDressId > 0) TTApplySpecialDressNow();
                if (gRoomDressId > 0) TTApplyRoomDressNow();
                TTSyncSpecialConcernToMePlayerAndContacts();
                TTApplyStealthLocally();
            });
        });
    }
}
