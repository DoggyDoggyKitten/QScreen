#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString * const QSModuleIdentifier;
FOUNDATION_EXPORT NSArray<NSString *> *QSReasons(void);
FOUNDATION_EXPORT NSString *QSReasonTitle(NSString *reason);
FOUNDATION_EXPORT NSString *QSCharacterName(NSString *reason);
FOUNDATION_EXPORT NSInteger QSDefaultMinutes(NSString *reason);
FOUNDATION_EXPORT NSDictionary *QSSession(NSString *reason, NSInteger minutes, NSTimeInterval now);
FOUNDATION_EXPORT NSDictionary *QSValidatedSession(id _Nullable value, NSTimeInterval now);
FOUNDATION_EXPORT NSString *QSReturnText(NSDictionary *session, NSTimeInterval now);
FOUNDATION_EXPORT NSTimeInterval QSDisplayDeadline(NSDictionary *session, NSInteger overtimeMinutes, NSTimeInterval now);

@interface QSStateStore : NSObject
+ (void)startPublishing;
+ (void)startReceiving;
+ (void)requestPublishedState;
+ (NSDictionary *)readSession;
+ (BOOL)writeSession:(NSDictionary *)session;
+ (void)clearSession;
+ (NSInteger)minutesForReason:(NSString *)reason;
+ (void)setMinutes:(NSInteger)minutes forReason:(NSString *)reason;
+ (NSInteger)overtimeMinutes;
+ (void)setOvertimeMinutes:(NSInteger)minutes;
@end

@interface QSSceneView : NSView
@property (nonatomic, copy) NSDictionary *session;
@property (nonatomic) NSTimeInterval animationTime;
@property (nonatomic) NSTimeInterval referenceTime;
@property (nonatomic) BOOL characterOnly;
@end
NS_ASSUME_NONNULL_END

