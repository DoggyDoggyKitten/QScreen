#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString * const QSModuleIdentifier;
FOUNDATION_EXPORT NSArray<NSString *> *QSReasons(void);
FOUNDATION_EXPORT NSString *QSReasonTitle(NSString *reason);
FOUNDATION_EXPORT NSString *QSReasonTitleInLanguage(NSString *reason, NSString *language);
FOUNDATION_EXPORT NSString *QSCharacterName(NSString *reason);
FOUNDATION_EXPORT NSString *QSCharacterNameInLanguage(NSString *reason, NSString *language);
FOUNDATION_EXPORT NSInteger QSDefaultMinutes(NSString *reason);
FOUNDATION_EXPORT NSDictionary *QSSession(NSString *reason, NSInteger minutes, NSTimeInterval now);
FOUNDATION_EXPORT NSString *QSNormalizedCustomReason(id _Nullable value);
FOUNDATION_EXPORT NSDictionary *QSCustomSession(NSString *title, NSString *character, NSInteger minutes, NSTimeInterval now);
FOUNDATION_EXPORT NSString *QSSceneTitle(NSDictionary *session, NSString *language);
FOUNDATION_EXPORT NSString *QSSceneCharacter(NSDictionary *session);
FOUNDATION_EXPORT NSDictionary *QSValidatedSession(id _Nullable value, NSTimeInterval now);
FOUNDATION_EXPORT NSString *QSReturnText(NSDictionary *session, NSTimeInterval now);
FOUNDATION_EXPORT NSString *QSReturnTextInLanguage(NSDictionary *session, NSTimeInterval now, NSString *language);
FOUNDATION_EXPORT NSTimeInterval QSDisplayDeadline(NSDictionary *session, NSInteger overtimeMinutes, NSTimeInterval now);

@interface QSStateStore : NSObject
+ (void)startPublishing;
+ (void)startReceiving;
+ (void)requestPublishedState;
+ (NSString *)language;
+ (void)setLanguage:(NSString *)language;
+ (NSString *)customReason;
+ (void)setCustomReason:(NSString *)reason;
+ (NSString *)customCharacter;
+ (void)setCustomCharacter:(NSString *)character;
+ (NSDictionary *)readSession;
+ (BOOL)writeSession:(NSDictionary *)session;
+ (void)clearSession;
+ (NSInteger)minutesForReason:(NSString *)reason;
+ (void)setMinutes:(NSInteger)minutes forReason:(NSString *)reason;
+ (NSInteger)overtimeMinutes;
+ (void)setOvertimeMinutes:(NSInteger)minutes;
@end

@interface QSSceneView : NSView
+ (void)drawGuideCharacter:(NSString *)reason atPoint:(NSPoint)origin pointingTo:(NSPoint)target;
@property (nonatomic, copy) NSDictionary *session;
@property (nonatomic) NSTimeInterval animationTime;
@property (nonatomic) NSTimeInterval referenceTime;
@property (nonatomic) BOOL characterOnly;
@end
NS_ASSUME_NONNULL_END

