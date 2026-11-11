#import "QScreen.h"
#import <ScreenSaver/ScreenSaver.h>
#import <math.h>

#ifndef QS_PREFERENCES_DOMAIN
#define QS_PREFERENCES_DOMAIN @"com.qscreen.saver"
#endif
NSString * const QSModuleIdentifier = QS_PREFERENCES_DOMAIN;
#ifndef QS_RUNTIME_CHANNEL
#define QS_RUNTIME_CHANNEL @"com.qscreen.saver.runtime"
#endif
static BOOL publishing = NO, receiving = NO;
static NSDictionary *receivedSession;
static NSNumber *receivedOvertime;
static NSString *receivedLanguage;

static NSString *normalizedLanguage(id value) {
    return [value isKindOfClass:NSString.class] && [value isEqual:@"en"] ? @"en" : @"zh";
}
static NSDictionary *sessionInLanguage(NSDictionary *session, NSString *language) {
    NSMutableDictionary *result = [session mutableCopy];
    result[@"language"] = normalizedLanguage(language);
    return result;
}

NSArray<NSString *> *QSReasons(void) {
    return @[@"lunch", @"meeting", @"coffee", @"restroom", @"away", @"offwork"];
}
NSString *QSReasonTitle(NSString *reason) {
    return QSReasonTitleInLanguage(reason, @"zh");
}
NSString *QSReasonTitleInLanguage(NSString *reason, NSString *language) {
    if ([language isEqual:@"en"]) {
        return @{@"lunch": @"Out for lunch", @"meeting": @"In a meeting", @"coffee": @"Coffee break",
                 @"restroom": @"Restroom break", @"away": @"Stepped away", @"offwork": @"Off for the day", @"custom": @"Custom"}[reason] ?: @"Stepped away";
    }
    return @{@"lunch": @"吃饭中", @"meeting": @"开会中", @"coffee": @"喝杯咖啡", @"restroom": @"去洗手间", @"away": @"暂时离开", @"offwork": @"今天下班啦", @"custom": @"自定义"}[reason] ?: @"暂时离开";
}
NSString *QSCharacterName(NSString *reason) {
    return QSCharacterNameInLanguage(reason, @"zh");
}
NSString *QSCharacterNameInLanguage(NSString *reason, NSString *language) {
    if ([language isEqual:@"en"]) {
        return @{@"lunch": @"Lunch Bear", @"meeting": @"Meeting Bunny", @"coffee": @"Coffee Cat",
                 @"restroom": @"Bubble Duck", @"away": @"Wandering Frog", @"offwork": @"Sleepy Fox"}[reason] ?: @"Wandering Frog";
    }
    return @{@"lunch": @"饭团熊", @"meeting": @"认真兔", @"coffee": @"咖啡猫", @"restroom": @"泡泡鸭", @"away": @"漫游蛙", @"offwork": @"晚安狐"}[reason] ?: @"漫游蛙";
}
NSInteger QSDefaultMinutes(NSString *reason) {
    return [@{@"lunch": @30, @"meeting": @60, @"coffee": @10, @"restroom": @5, @"away": @15, @"offwork": @0, @"custom": @15}[reason] integerValue];
}
NSString *QSNormalizedCustomReason(id value) {
    if (![value isKindOfClass:NSString.class]) return @"";
    NSArray *words = [value componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *singleLine = [[words filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]] componentsJoinedByString:@" "];
    // Avoid carrying invisible control characters into the public status board.
    NSMutableCharacterSet *controls = [[NSCharacterSet characterSetWithRange:NSMakeRange(0, 32)] mutableCopy];
    [controls addCharactersInRange:NSMakeRange(127, 1)];
    singleLine = [[singleLine componentsSeparatedByCharactersInSet:controls] componentsJoinedByString:@""];
    NSMutableString *result = NSMutableString.new;
    __block NSUInteger count = 0;
    [singleLine enumerateSubstringsInRange:NSMakeRange(0, singleLine.length) options:NSStringEnumerationByComposedCharacterSequences
        usingBlock:^(NSString *substring, NSRange range, NSRange enclosingRange, BOOL *stop) {
            (void)range; (void)enclosingRange;
            if (++count > 40 || result.length + substring.length > 256) { *stop = YES; return; }
            [result appendString:substring];
        }];
    return [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}
NSDictionary *QSCustomSession(NSString *title, NSString *character, NSInteger minutes, NSTimeInterval now) {
    NSMutableDictionary *session = [QSSession(@"away", minutes, now) mutableCopy];
    session[@"reason"] = @"custom";
    session[@"title"] = QSNormalizedCustomReason(title);
    session[@"character"] = [QSReasons() containsObject:character] ? character : @"away";
    return session;
}
NSString *QSSceneTitle(NSDictionary *session, NSString *language) {
    if ([session[@"reason"] isEqual:@"custom"]) {
        NSString *title = QSNormalizedCustomReason(session[@"title"]);
        return title.length ? title : ([language isEqual:@"en"] ? @"Custom reason" : @"自定义理由");
    }
    return QSReasonTitleInLanguage(session[@"reason"], language);
}
NSString *QSSceneCharacter(NSDictionary *session) {
    id character = [session[@"reason"] isEqual:@"custom"] ? session[@"character"] : session[@"reason"];
    return [QSReasons() containsObject:character] ? character : @"away";
}
NSDictionary *QSSession(NSString *reason, NSInteger minutes, NSTimeInterval now) {
    if (![QSReasons() containsObject:reason]) reason = @"away";
    NSInteger bounded = MAX(1, MIN(minutes, 480));
    return @{@"version": @1, @"reason": reason, @"id": NSUUID.UUID.UUIDString,
             @"startedAt": @(now), @"endsAt": [reason isEqual:@"offwork"] ? @0 : @(now + bounded * 60)};
}
NSDictionary *QSValidatedSession(id value, NSTimeInterval now) {
    NSDictionary *fallback = @{@"version": @1, @"reason": @"away", @"startedAt": @0, @"endsAt": @0};
    if (![value isKindOfClass:NSDictionary.class]) return fallback;
    NSDictionary *session = value;
    if (![session[@"version"] isKindOfClass:NSNumber.class] || [session[@"version"] integerValue] != 1 ||
        ![session[@"reason"] isKindOfClass:NSString.class] ||
        (![QSReasons() containsObject:session[@"reason"]] && ![session[@"reason"] isEqual:@"custom"]) ||
        ![session[@"startedAt"] isKindOfClass:NSNumber.class] || ![session[@"endsAt"] isKindOfClass:NSNumber.class] ||
        ![session[@"id"] isKindOfClass:NSString.class]) return fallback;
    double start = [session[@"startedAt"] doubleValue], end = [session[@"endsAt"] doubleValue];
    if (!isfinite(start) || !isfinite(end) || start <= 0 || start > now + 60 || now - start > 12 * 3600) return fallback;
    if ([session[@"reason"] isEqual:@"offwork"]) {
        if (end != 0) return fallback;
    } else if (end <= start || end - start > 480 * 60) return fallback;
    NSMutableDictionary *validated = [sessionInLanguage(session, normalizedLanguage(session[@"language"])) mutableCopy];
    if ([session[@"reason"] isEqual:@"custom"]) {
        NSString *title = QSNormalizedCustomReason(session[@"title"]);
        if (!title.length || ![session[@"character"] isKindOfClass:NSString.class] || ![QSReasons() containsObject:session[@"character"]]) return fallback;
        validated[@"title"] = title;
    }
    return validated;
}
NSString *QSReturnText(NSDictionary *session, NSTimeInterval now) {
    return QSReturnTextInLanguage(session, now, normalizedLanguage(session[@"language"]));
}
NSString *QSReturnTextInLanguage(NSDictionary *session, NSTimeInterval now, NSString *language) {
    if ([session[@"reason"] isEqual:@"offwork"]) return @"";
    double end = [session[@"endsAt"] doubleValue];
    if (end <= 0) return @"";
    BOOL english = [language isEqual:@"en"];
    if (end <= now) return english ? @"Running a little late" : @"还没回来，稍等一下";
    NSInteger minutes = MAX(1, (NSInteger)ceil((end - now) / 60));
    if (english) return [NSString stringWithFormat:@"Back in about %ld %@", (long)minutes, minutes == 1 ? @"minute" : @"minutes"];
    return [NSString stringWithFormat:@"约 %ld 分钟后回来", (long)minutes];
}
NSTimeInterval QSDisplayDeadline(NSDictionary *session, NSInteger overtimeMinutes, NSTimeInterval now) {
    double start = [session[@"startedAt"] doubleValue];
    if ([session[@"reason"] isEqual:@"offwork"] && start > 0) return start + 5 * 60;
    double end = [session[@"endsAt"] doubleValue];
    // Generic system-lock sessions have no ETA; hold the display for 15 minutes.
    if (end <= 0) return now + 15 * 60;
    return end + MAX(0, MIN(overtimeMinutes, 60)) * 60;
}

@implementation QSStateStore
+ (void)startPublishing {
    if (publishing) return;
    publishing = YES;
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(publishState:)
        name:[QS_RUNTIME_CHANNEL stringByAppendingString:@".request"] object:nil
        suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
}
+ (void)publishState:(NSNotification *)notification {
    (void)notification;
    if (!publishing) return;
    NSDictionary *payload = @{@"version": @1, @"session": self.readSession, @"overtime": @(self.overtimeMinutes), @"language": self.language};
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (json) {
        // Sandboxed receivers support a string object with nil userInfo. Preferences
        // remain local to each process; no access to the host's container is needed.
        [NSDistributedNotificationCenter.defaultCenter postNotificationName:[QS_RUNTIME_CHANNEL stringByAppendingString:@".state"]
            object:json userInfo:nil deliverImmediately:YES];
    }
}
+ (void)startReceiving {
    if (receiving) return;
    receiving = YES;
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(receiveState:)
        name:[QS_RUNTIME_CHANNEL stringByAppendingString:@".state"] object:nil
        suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
}
+ (void)requestPublishedState {
    if (!receiving) return;
    [NSDistributedNotificationCenter.defaultCenter postNotificationName:[QS_RUNTIME_CHANNEL stringByAppendingString:@".request"]
        object:nil userInfo:nil deliverImmediately:YES];
}
+ (void)receiveState:(NSNotification *)notification {
    // This channel carries display metadata only. It never establishes lock state.
    if (![notification.object isKindOfClass:NSString.class] || [notification.object length] > 8192) return;
    NSData *data = [notification.object dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length > 8192) return;
    id payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![payload isKindOfClass:NSDictionary.class] || ![payload[@"version"] isEqual:@1] ||
        ![payload[@"overtime"] isKindOfClass:NSNumber.class]) return;
    double overtime = [payload[@"overtime"] doubleValue];
    if (!isfinite(overtime) || overtime < 0 || overtime > 60 || floor(overtime) != overtime) return;
    if (payload[@"language"] && (![payload[@"language"] isKindOfClass:NSString.class] ||
        ![@[@"zh", @"en"] containsObject:payload[@"language"]])) return;
    receivedSession = QSValidatedSession(payload[@"session"], NSDate.date.timeIntervalSince1970);
    receivedOvertime = @(overtime);
    receivedLanguage = normalizedLanguage(payload[@"language"]);
    // Keep the last display language in the host's own preferences so generic
    // screen saver sessions retain it even when the menu app is not running.
    ScreenSaverDefaults *defaults = [self defaults];
    if (![[defaults objectForKey:@"language"] isEqual:receivedLanguage]) {
        [defaults setObject:receivedLanguage forKey:@"language"];
        [defaults synchronize];
    }
}
+ (ScreenSaverDefaults *)defaults {
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:QSModuleIdentifier];
    [defaults synchronize];
    return defaults;
}
+ (NSDictionary *)readSession {
    id value = receiving ? receivedSession : [[self defaults] objectForKey:@"session"];
    return sessionInLanguage(QSValidatedSession(value, NSDate.date.timeIntervalSince1970), self.language);
}
+ (NSString *)language {
    return normalizedLanguage(receiving && receivedLanguage ? receivedLanguage : [[self defaults] objectForKey:@"language"]);
}
+ (void)setLanguage:(NSString *)language {
    ScreenSaverDefaults *defaults = [self defaults];
    [defaults setObject:normalizedLanguage(language) forKey:@"language"];
    [defaults synchronize];
    [self publishState:nil];
}
+ (NSString *)customReason {
    return QSNormalizedCustomReason([[self defaults] objectForKey:@"customReason"]);
}
+ (void)setCustomReason:(NSString *)reason {
    ScreenSaverDefaults *defaults = [self defaults];
    [defaults setObject:QSNormalizedCustomReason(reason) forKey:@"customReason"];
    [defaults synchronize];
}
+ (NSString *)customCharacter {
    id value = [[self defaults] objectForKey:@"customCharacter"];
    return [value isKindOfClass:NSString.class] && [QSReasons() containsObject:value] ? value : @"away";
}
+ (void)setCustomCharacter:(NSString *)character {
    ScreenSaverDefaults *defaults = [self defaults];
    [defaults setObject:[QSReasons() containsObject:character] ? character : @"away" forKey:@"customCharacter"];
    [defaults synchronize];
}
+ (BOOL)writeSession:(NSDictionary *)session {
    ScreenSaverDefaults *defaults = [self defaults];
    [defaults setObject:session forKey:@"session"];
    BOOL saved = [defaults synchronize];
    if (saved) [self publishState:nil];
    return saved;
}
+ (void)clearSession {
    ScreenSaverDefaults *defaults = [self defaults];
    [defaults removeObjectForKey:@"session"];
    [defaults synchronize];
    [self publishState:nil];
}
+ (NSInteger)minutesForReason:(NSString *)reason {
    NSNumber *saved = [[self defaults] objectForKey:[@"minutes." stringByAppendingString:reason]];
    return saved ? MAX(1, MIN(saved.integerValue, 480)) : QSDefaultMinutes(reason);
}
+ (void)setMinutes:(NSInteger)minutes forReason:(NSString *)reason {
    ScreenSaverDefaults *defaults = [self defaults];
    [defaults setInteger:MAX(1, MIN(minutes, 480)) forKey:[@"minutes." stringByAppendingString:reason]];
    [defaults synchronize];
}
+ (NSInteger)overtimeMinutes {
    if (receiving) return receivedOvertime ? receivedOvertime.integerValue : 5;
    id value = [[self defaults] objectForKey:@"overtimeMinutes"];
    return value ? MAX(0, MIN([value integerValue], 60)) : 5;
}
+ (void)setOvertimeMinutes:(NSInteger)minutes {
    ScreenSaverDefaults *defaults = [self defaults];
    [defaults setInteger:MAX(0, MIN(minutes, 60)) forKey:@"overtimeMinutes"];
    [defaults synchronize];
    [self publishState:nil];
}
@end
