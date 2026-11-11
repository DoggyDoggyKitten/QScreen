#import "QScreen.h"
#import <ScreenSaver/ScreenSaver.h>
#import <math.h>

#ifndef QS_PREFERENCES_DOMAIN
#define QS_PREFERENCES_DOMAIN @"com.qscreen.saver"
#endif
NSString * const QSModuleIdentifier = QS_PREFERENCES_DOMAIN;

NSArray<NSString *> *QSReasons(void) {
    return @[@"lunch", @"meeting", @"coffee", @"restroom", @"away", @"offwork"];
}
NSString *QSReasonTitle(NSString *reason) {
    return @{@"lunch": @"吃饭中", @"meeting": @"开会中", @"coffee": @"喝杯咖啡", @"restroom": @"去洗手间", @"away": @"暂时离开", @"offwork": @"今天下班啦"}[reason] ?: @"暂时离开";
}
NSString *QSCharacterName(NSString *reason) {
    return @{@"lunch": @"饭团熊", @"meeting": @"认真兔", @"coffee": @"咖啡猫", @"restroom": @"泡泡鸭", @"away": @"漫游蛙", @"offwork": @"晚安狐"}[reason] ?: @"漫游蛙";
}
NSInteger QSDefaultMinutes(NSString *reason) {
    return [@{@"lunch": @30, @"meeting": @60, @"coffee": @10, @"restroom": @5, @"away": @15, @"offwork": @0}[reason] integerValue];
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
        ![session[@"reason"] isKindOfClass:NSString.class] || ![QSReasons() containsObject:session[@"reason"]] ||
        ![session[@"startedAt"] isKindOfClass:NSNumber.class] || ![session[@"endsAt"] isKindOfClass:NSNumber.class] ||
        ![session[@"id"] isKindOfClass:NSString.class]) return fallback;
    double start = [session[@"startedAt"] doubleValue], end = [session[@"endsAt"] doubleValue];
    if (!isfinite(start) || !isfinite(end) || start <= 0 || start > now + 60 || now - start > 12 * 3600) return fallback;
    if ([session[@"reason"] isEqual:@"offwork"]) {
        if (end != 0) return fallback;
    } else if (end <= start || end - start > 480 * 60) return fallback;
    return session;
}
NSString *QSReturnText(NSDictionary *session, NSTimeInterval now) {
    if ([session[@"reason"] isEqual:@"offwork"]) return @"";
    double end = [session[@"endsAt"] doubleValue];
    if (end <= 0) return @"";
    if (end <= now) return @"还没回来，稍等一下";
    return [NSString stringWithFormat:@"约 %ld 分钟后回来", (long)MAX(1, (NSInteger)ceil((end - now) / 60))];
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
+ (ScreenSaverDefaults *)defaults {
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:QSModuleIdentifier];
    [defaults synchronize];
    return defaults;
}
+ (NSDictionary *)readSession {
    return QSValidatedSession([[self defaults] objectForKey:@"session"], NSDate.date.timeIntervalSince1970);
}
+ (BOOL)writeSession:(NSDictionary *)session {
    ScreenSaverDefaults *defaults = [self defaults];
    [defaults setObject:session forKey:@"session"];
    return [defaults synchronize];
}
+ (void)clearSession {
    ScreenSaverDefaults *defaults = [self defaults];
    [defaults removeObjectForKey:@"session"];
    [defaults synchronize];
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
    id value = [[self defaults] objectForKey:@"overtimeMinutes"];
    return value ? MAX(0, MIN([value integerValue], 60)) : 5;
}
+ (void)setOvertimeMinutes:(NSInteger)minutes {
    ScreenSaverDefaults *defaults = [self defaults];
    [defaults setInteger:MAX(0, MIN(minutes, 60)) forKey:@"overtimeMinutes"];
    [defaults synchronize];
}
@end
