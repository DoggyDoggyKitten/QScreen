#import "QScreen.h"

static void check(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}
int main(void) {
    @autoreleasepool {
        NSTimeInterval now = 1800000000;
        NSDictionary *meeting = QSSession(@"meeting", 30, now);
        check([QSReturnText(meeting, now) isEqual:@"约 30 分钟后回来"], @"initial countdown");
        check([QSReturnText(meeting, now + 61) isEqual:@"约 29 分钟后回来"], @"elapsed wall time");
        check([QSReturnText(meeting, now + 1799) isEqual:@"约 1 分钟后回来"], @"round up last minute");
        check([QSReturnText(meeting, now + 1800) isEqual:@"还没回来，稍等一下"], @"overtime boundary");
        check([QSValidatedSession(meeting, now + 7200)[@"reason"] isEqual:@"meeting"], @"sleep does not reset ETA");
        check([QSValidatedSession(meeting, now + 43201)[@"reason"] isEqual:@"away"], @"discard stale session");
        check([QSValidatedSession(@[@1], now)[@"endsAt"] doubleValue] == 0, @"reject non-dictionary");
        check([QSValidatedSession(@{@"reason": @[]}, now)[@"reason"] isEqual:@"away"], @"reject malformed state");
        NSMutableDictionary *invalid = [meeting mutableCopy]; invalid[@"endsAt"] = @(NAN);
        check([QSValidatedSession(invalid, now)[@"endsAt"] doubleValue] == 0, @"reject non-finite date");
        invalid = [meeting mutableCopy]; invalid[@"startedAt"] = @(now + 120);
        check([QSValidatedSession(invalid, now)[@"endsAt"] doubleValue] == 0, @"reject future session");
        NSDictionary *offwork = QSSession(@"offwork", 0, now);
        check(QSReturnText(offwork, now).length == 0, @"offwork has no countdown");
        check(QSDisplayDeadline(offwork, 5, now) == now + 300, @"offwork releases display after five minutes");
        check(QSDisplayDeadline(meeting, 5, now) == now + 2100, @"display deadline includes overtime");
        check([QSSession(@"meeting", 9999, now)[@"endsAt"] doubleValue] == now + 480 * 60, @"limit duration");
        check([QSReturnTextInLanguage(meeting, now, @"en") isEqual:@"Back in about 30 minutes"], @"English countdown");
        check([QSReturnTextInLanguage(meeting, now + 1799, @"en") isEqual:@"Back in about 1 minute"], @"English singular minute");
        check([QSReturnTextInLanguage(meeting, now + 1800, @"en") isEqual:@"Running a little late"], @"English overtime");
        check(QSReturnTextInLanguage(offwork, now, @"en").length == 0, @"English offwork has no countdown");
        check(QSReturnTextInLanguage(QSValidatedSession(nil, now), now, @"en").length == 0, @"English generic away has no ETA");
        check([QSReasonTitleInLanguage(@"unknown", @"en") isEqual:@"Stepped away"], @"English fallback reason");
        invalid = [meeting mutableCopy]; invalid[@"language"] = @[@"en"];
        check([QSValidatedSession(invalid, now)[@"language"] isEqual:@"zh"], @"invalid language falls back safely");
        invalid[@"language"] = @"en";
        check([QSValidatedSession(invalid, now)[@"language"] isEqual:@"en"], @"valid session preserves language");
        check([QSReturnText(QSValidatedSession(invalid, now), now) isEqual:@"Back in about 30 minutes"], @"return text follows session language");
        check([QSValidatedSession(meeting, now)[@"language"] isEqual:@"zh"], @"legacy session remains valid in Chinese");
        NSDictionary *custom = QSCustomSession(@"  Walking\n the dog  ", @"coffee", 25, now);
        check([QSValidatedSession(custom, now)[@"reason"] isEqual:@"custom"], @"custom session validates");
        check([QSSceneTitle(custom, @"en") isEqual:@"Walking the dog"], @"custom title is normalized");
        check([QSSceneTitle(custom, @"zh") isEqual:@"Walking the dog"], @"language switch preserves user text");
        check([QSSceneCharacter(custom) isEqual:@"coffee"], @"custom character is independent of reason");
        check([custom[@"endsAt"] doubleValue] == now + 1500, @"custom typed duration sets real deadline");
        check([QSNormalizedCustomReason(@"👨‍👩‍👧‍👦 🐕") isEqual:@"👨‍👩‍👧‍👦 🐕"], @"emoji graphemes preserved");
        check(QSNormalizedCustomReason([@"长" stringByPaddingToLength:100 withString:@"长" startingAtIndex:0]).length == 40, @"custom title length bounded");
        check(!QSValidatedSession(QSCustomSession(@" \n ", @"away", 15, now), now)[@"id"], @"reject empty custom title");
        invalid = [custom mutableCopy]; invalid[@"title"] = @42;
        check(!QSValidatedSession(invalid, now)[@"id"], @"reject non-string custom title");
        invalid = [custom mutableCopy]; invalid[@"character"] = @"unknown";
        check(!QSValidatedSession(invalid, now)[@"id"], @"reject unknown custom character");
        NSDictionary *customFox = QSCustomSession(@"Be right back", @"offwork", 25, now);
        check(QSReturnText(customFox, now).length > 0 && QSDisplayDeadline(customFox, 5, now) == now + 1800, @"custom fox retains its own ETA and display deadline");
        for (NSString *reason in QSReasons()) {
            check(![QSReasonTitle(reason) isEqual:@""], @"all reasons have a label");
            check([QSValidatedSession(QSSession(reason, 15, now), now)[@"reason"] isEqual:reason], @"all presets validate");
            check(![QSReasonTitleInLanguage(reason, @"en") isEqual:QSReasonTitle(reason)], @"all six reason labels are translated");
            check(![QSCharacterNameInLanguage(reason, @"en") isEqual:QSCharacterName(reason)], @"all six character names are translated");
        }
        puts("Passed: countdown, expiry, malformed data, sleep continuity, display policy, six presets.");
    }
}

