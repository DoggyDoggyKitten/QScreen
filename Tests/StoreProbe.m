#import "QScreen.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc!=2) return 1;
        NSString *mode=@(argv[1]);
        if ([mode isEqual:@"write"]) {
            [QSStateStore setLanguage:@"en"];
            [QSStateStore setMinutes:45 forReason:@"meeting"];
            return [QSStateStore writeSession:QSSession(@"coffee",10,NSDate.date.timeIntervalSince1970)] ? 0 : 1;
        }
        if ([mode isEqual:@"read"]) {
            NSDictionary *session=QSStateStore.readSession;
            if (![session[@"reason"] isEqual:@"coffee"] || [QSStateStore minutesForReason:@"meeting"]!=45) return 1;
            if (![QSStateStore.language isEqual:@"en"] || ![session[@"language"] isEqual:@"en"]) return 1;
            if (![QSReturnText(session,NSDate.date.timeIntervalSince1970) isEqual:@"Back in about 10 minutes"]) return 1;
            puts("Passed: status, deadline, duration and language persist across separate processes.");
            return 0;
        }
        if ([mode isEqual:@"clear"]) { [QSStateStore clearSession]; return 0; }
        if ([mode isEqual:@"empty"]) return QSStateStore.readSession[@"id"] ? 1 : 0;
        return 1;
    }
}
