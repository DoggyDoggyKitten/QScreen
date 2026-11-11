#import "QScreen.h"
#import <ScreenSaver/ScreenSaver.h>
#import <dlfcn.h>
#import <objc/runtime.h>

static IMP originalFontFactory;
static BOOL failNextFont = NO;
static NSFont *fontFactory(id receiver, SEL selector, NSFontDescriptor *descriptor, CGFloat size) {
    if (failNextFont) { failNextFont = NO; return nil; }
    return ((NSFont *(*)(id,SEL,NSFontDescriptor *,CGFloat))originalFontFactory)(receiver,selector,descriptor,size);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSString *bundlePath=[NSFileManager.defaultManager.currentDirectoryPath stringByAppendingPathComponent:argc>2 ? @(argv[2]) : @"build/QScreen.saver"];
        NSBundle *bundle=[NSBundle bundleWithPath:bundlePath];
        if (![bundle load]) { NSLog(@"Could not load saver bundle"); return 1; }
        void *handle=dlopen(bundle.executablePath.fileSystemRepresentation,RTLD_NOW | RTLD_LOCAL);
        NSArray *(*reasons)(void)=dlsym(handle,"QSReasons");
        NSDictionary *(*session)(NSString *,NSInteger,NSTimeInterval)=dlsym(handle,"QSSession");
        NSDictionary *(*customSession)(NSString *,NSString *,NSInteger,NSTimeInterval)=dlsym(handle,"QSCustomSession");
        NSInteger (*minutes)(NSString *)=dlsym(handle,"QSDefaultMinutes");
        if (!handle || !reasons || !session || !customSession || !minutes) return 1;
        NSString *output = argc>1 ? @(argv[1]) : @"build/previews";
        [NSFileManager.defaultManager createDirectoryAtPath:output withIntermediateDirectories:YES attributes:nil error:nil];
        NSTimeInterval now=1800000000;
        for (NSString *language in @[@"zh", @"en"]) {
          for (NSString *reason in reasons()) {
            QSSceneView *view=[[NSClassFromString(@"QSSceneView") alloc] initWithFrame:NSMakeRect(0,0,1440,960)];
            NSMutableDictionary *localizedSession=[session(reason,minutes(reason),now) mutableCopy];
            localizedSession[@"language"]=language;
            view.session=localizedSession;
            view.referenceTime=now+61; view.animationTime=2;
            NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
            [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
            NSData *data=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            NSString *filename=[language isEqual:@"zh"] ? [reason stringByAppendingString:@".png"] : [reason stringByAppendingString:@"-en.png"];
            if (![data writeToFile:[output stringByAppendingPathComponent:filename] atomically:YES]) return 1;
          }
        }
        NSArray *titles=@[@"Walking the dog", @"Collaborating with the team next door", @"正在参加跨部门项目讨论预计稍后返回工位请稍等我马上回来谢谢大家的耐心等候", @"👨‍👩‍👧‍👦 Walking the dog 🐕"];
        for (NSUInteger index=0; index<titles.count; index++) {
            QSSceneView *view=[[NSClassFromString(@"QSSceneView") alloc] initWithFrame:NSMakeRect(0,0,1440,960)];
            NSMutableDictionary *value=[customSession(titles[index], index==3 ? @"offwork" : @"away", 25, now) mutableCopy];
            value[@"language"]=@"en";
            view.session=value; view.referenceTime=now; view.animationTime=2;
            NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
            [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
            NSData *data=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            NSString *filename=[NSString stringWithFormat:@"custom-%lu.png",(unsigned long)index];
            if (![data writeToFile:[output stringByAppendingPathComponent:filename] atomically:YES]) return 1;
        }
        Class principal=bundle.principalClass;
        if (![principal isSubclassOfClass:ScreenSaverView.class]) return 1;
        ScreenSaverView *preview=[[principal alloc] initWithFrame:NSMakeRect(0,0,640,400) isPreview:YES];
        [preview startAnimation]; [preview animateOneFrame]; [preview stopAnimation]; [preview animateOneFrame];
        if (!preview.isPreview || preview.isAnimating) return 1;
        // A rounded descriptor can exist while fontWithDescriptor:size: returns nil.
        // Reproduce that one failure without affecting subsequent AppKit font calls.
        QSSceneView *fallbackView=[[NSClassFromString(@"QSSceneView") alloc] initWithFrame:NSMakeRect(0,0,640,400)];
        fallbackView.session=session(@"offwork",0,now);
        NSBitmapImageRep *fallbackBitmap=[fallbackView bitmapImageRepForCachingDisplayInRect:fallbackView.bounds];
        Method factory=class_getClassMethod(NSFont.class,@selector(fontWithDescriptor:size:));
        originalFontFactory=method_setImplementation(factory,(IMP)fontFactory);
        failNextFont=YES;
        BOOL failed=NO;
        @try {
            [fallbackView cacheDisplayInRect:fallbackView.bounds toBitmapImageRep:fallbackBitmap];
        } @catch (NSException *exception) {
            NSLog(@"FAIL: font fallback raised %@",exception.name);
            failed=YES;
        } @finally {
            method_setImplementation(factory,originalFontFactory);
        }
        if (failed || failNextFont) return 1;
        puts("Passed: missing rounded font falls back without crashing live rendering.");
        puts("Passed: rendered all six scenes in both languages and loaded native screen saver lifecycle.");
    }
}
