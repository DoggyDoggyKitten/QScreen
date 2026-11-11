#import "QScreen.h"
#import <ScreenSaver/ScreenSaver.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <QuartzCore/QuartzCore.h>
#import <os/log.h>

@interface QScreenSaverView : ScreenSaverView
@property (nonatomic, strong) QSSceneView *scene;
@property (nonatomic) CFTimeInterval beganAnimating;
@property (nonatomic) NSTimeInterval lastRefresh;
@property (nonatomic) NSTimeInterval displayDeadline;
@property (nonatomic) IOPMAssertionID displayAssertion;
@end

@implementation QScreenSaverView
- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)preview {
    if ((self=[super initWithFrame:frame isPreview:preview])) {
        self.animationTimeInterval=1.0/30.0;
        _displayAssertion=kIOPMNullAssertionID;
        _scene=[[QSSceneView alloc] initWithFrame:self.bounds];
        _scene.session=QSStateStore.readSession;
        [self addSubview:_scene];
    }
    return self;
}
- (void)startAnimation {
    [super startAnimation];
    self.beganAnimating=CACurrentMediaTime();
    self.lastRefresh=0;
    self.scene.session=QSStateStore.readSession;
    os_log_with_type(OS_LOG_DEFAULT,OS_LOG_TYPE_DEFAULT,
                     "QScreen saver started preview=%{public}d reason=%{public}@ hasETA=%{public}d",
                     self.isPreview,self.scene.session[@"reason"],[self.scene.session[@"endsAt"] doubleValue]>0);
    [self refreshDisplayLease];
}
- (void)refreshDisplayLease {
    [self releaseDisplayLease];
    if (self.isPreview) return;
    NSTimeInterval now=NSDate.date.timeIntervalSince1970;
    self.displayDeadline=QSDisplayDeadline(self.scene.session,QSStateStore.overtimeMinutes,now);
    NSTimeInterval remaining=self.displayDeadline-now;
    if (remaining<=0) return;
    NSDictionary *properties=@{
        (__bridge NSString *)kIOPMAssertionTypeKey:(__bridge NSString *)kIOPMAssertionTypePreventUserIdleDisplaySleep,
        (__bridge NSString *)kIOPMAssertionNameKey:@"QScreen away status",
        (__bridge NSString *)kIOPMAssertionLevelKey:@(kIOPMAssertionLevelOn),
        (__bridge NSString *)kIOPMAssertionTimeoutKey:@(remaining),
        (__bridge NSString *)kIOPMAssertionTimeoutActionKey:(__bridge NSString *)kIOPMAssertionTimeoutActionRelease
    };
    IOPMAssertionID assertion=kIOPMNullAssertionID;
    IOReturn result=IOPMAssertionCreateWithProperties((__bridge CFDictionaryRef)properties,&assertion);
    if (result==kIOReturnSuccess) self.displayAssertion=assertion;
    else os_log_error(OS_LOG_DEFAULT,"QScreen display assertion failed result=%{public}d",result);
}
- (void)releaseDisplayLease {
    if (self.displayAssertion!=kIOPMNullAssertionID) {
        IOPMAssertionRelease(self.displayAssertion);
        self.displayAssertion=kIOPMNullAssertionID;
    }
}
- (void)animateOneFrame {
    // Some hosts call another frame after stopAnimation. Never reacquire a lease there.
    if (!self.isAnimating) return;
    NSTimeInterval now=NSDate.date.timeIntervalSince1970;
    if (now-self.lastRefresh>=1) {
        NSDictionary *session=QSStateStore.readSession;
        if (![session isEqual:self.scene.session]) {
            self.scene.session=session;
            [self refreshDisplayLease];
        }
        self.scene.referenceTime=now;
        self.lastRefresh=now;
        if (now>=self.displayDeadline) [self releaseDisplayLease];
    }
    self.scene.animationTime=CACurrentMediaTime()-self.beganAnimating;
}
- (void)stopAnimation {
    os_log_with_type(OS_LOG_DEFAULT,OS_LOG_TYPE_DEFAULT,"QScreen saver stopped preview=%{public}d",self.isPreview);
    [self releaseDisplayLease]; [super stopAnimation];
}
- (void)dealloc { [self releaseDisplayLease]; }
- (BOOL)hasConfigureSheet { return NO; }
@end
