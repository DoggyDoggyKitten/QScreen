#import "QScreen.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 1;
        NSString *mode = @(argv[1]);
        NSDistributedNotificationCenter *center = NSDistributedNotificationCenter.defaultCenter;
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:12];
        if ([mode isEqual:@"provider"]) {
            __block BOOL finished = NO;
            [QSStateStore writeSession:QSSession(@"meeting", 5, NSDate.date.timeIntervalSince1970)];
            [QSStateStore setOvertimeMinutes:11];
            [QSStateStore startPublishing];
            id clear = [center addObserverForName:@"com.qscreen.bridge.tests.clear" object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *note) { (void)note; [QSStateStore clearSession]; }];
            id done = [center addObserverForName:@"com.qscreen.bridge.tests.done" object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *note) { (void)note; finished = YES; }];
            puts("ready"); fflush(stdout);
            while (!finished && deadline.timeIntervalSinceNow > 0)
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            [center removeObserver:clear]; [center removeObserver:done];
            [QSStateStore clearSession];
            return finished ? 0 : 1;
        }
        if ([mode isEqual:@"client"]) {
            // This binary has a DIFFERENT preferences domain from the provider.
            // Its stale local state must never override the live publisher.
            [QSStateStore writeSession:QSSession(@"offwork", 0, NSDate.date.timeIntervalSince1970)];
            [QSStateStore startReceiving];
            BOOL meeting = NO, cleared = NO;
            NSTimeInterval lastRequest = 0;
            while (deadline.timeIntervalSinceNow > 0) {
                NSTimeInterval now = NSDate.date.timeIntervalSince1970;
                if (now - lastRequest > 0.5) { [QSStateStore requestPublishedState]; lastRequest = now; }
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
                NSDictionary *session = QSStateStore.readSession;
                if (!meeting && [session[@"reason"] isEqual:@"meeting"] && QSStateStore.overtimeMinutes == 11 &&
                    [QSReturnText(session, now) isEqual:@"约 5 分钟后回来"]) {
                    meeting = YES;
                    [center postNotificationName:@"com.qscreen.bridge.tests.clear" object:nil userInfo:nil deliverImmediately:YES];
                } else if (meeting && !session[@"id"] && [session[@"reason"] isEqual:@"away"] &&
                           [session[@"endsAt"] doubleValue] == 0) { cleared = YES; break; }
            }
            [QSStateStore clearSession];
            [center postNotificationName:@"com.qscreen.bridge.tests.done" object:nil userInfo:nil deliverImmediately:YES];
            if (!meeting || !cleared) { NSLog(@"Bridge failed: meeting=%d cleared=%d", meeting, cleared); return 1; }
            puts("Passed: isolated preference domains receive live reason, ETA, overtime and reset.");
            return 0;
        }
        return 1;
    }
}
