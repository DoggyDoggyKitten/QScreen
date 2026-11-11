#import "QScreen.h"
#import <ScreenSaver/ScreenSaver.h>
#import <dlfcn.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSString *bundlePath=[NSFileManager.defaultManager.currentDirectoryPath stringByAppendingPathComponent:@"build/QScreen.saver"];
        NSBundle *bundle=[NSBundle bundleWithPath:bundlePath];
        if (![bundle load]) { NSLog(@"Could not load saver bundle"); return 1; }
        void *handle=dlopen(bundle.executablePath.fileSystemRepresentation,RTLD_NOW | RTLD_LOCAL);
        NSArray *(*reasons)(void)=dlsym(handle,"QSReasons");
        NSDictionary *(*session)(NSString *,NSInteger,NSTimeInterval)=dlsym(handle,"QSSession");
        NSInteger (*minutes)(NSString *)=dlsym(handle,"QSDefaultMinutes");
        if (!handle || !reasons || !session || !minutes) return 1;
        NSString *output = argc>1 ? @(argv[1]) : @"build/previews";
        [NSFileManager.defaultManager createDirectoryAtPath:output withIntermediateDirectories:YES attributes:nil error:nil];
        NSTimeInterval now=1800000000;
        for (NSString *reason in reasons()) {
            QSSceneView *view=[[NSClassFromString(@"QSSceneView") alloc] initWithFrame:NSMakeRect(0,0,1440,960)];
            view.session=session(reason,minutes(reason),now);
            view.referenceTime=now+61; view.animationTime=2;
            NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
            [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
            NSData *data=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            if (![data writeToFile:[output stringByAppendingPathComponent:[reason stringByAppendingString:@".png"]] atomically:YES]) return 1;
        }
        Class principal=bundle.principalClass;
        if (![principal isSubclassOfClass:ScreenSaverView.class]) return 1;
        ScreenSaverView *preview=[[principal alloc] initWithFrame:NSMakeRect(0,0,640,400) isPreview:YES];
        [preview startAnimation]; [preview animateOneFrame]; [preview stopAnimation]; [preview animateOneFrame];
        if (!preview.isPreview || preview.isAnimating) return 1;
        puts("Passed: rendered all six scenes and loaded native screen saver lifecycle.");
    }
}
