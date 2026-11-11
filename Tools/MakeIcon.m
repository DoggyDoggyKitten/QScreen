#import "QScreen.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc<2) return 1;
        [NSApplication sharedApplication];
        NSString *folder=@(argv[1]);
        [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        for (NSNumber *number in @[@16,@32,@128,@256,@512]) {
            NSInteger size=number.integerValue;
            for (NSInteger multiplier=1;multiplier<=2;multiplier++) {
                NSInteger pixels=size*multiplier;
                NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:pixels pixelsHigh:pixels bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
                [NSGraphicsContext saveGraphicsState];
                NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
                NSRect bounds=NSMakeRect(0,0,pixels,pixels);
                NSBezierPath *clip=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds,pixels*.04,pixels*.04) xRadius:pixels*.21 yRadius:pixels*.21];
                [clip addClip];
                QSSceneView *view=[[QSSceneView alloc] initWithFrame:bounds];
                view.characterOnly=YES; view.session=@{@"reason":@"lunch"}; view.animationTime=2;
                // Match an NSView's flipped drawing coordinates.
                NSAffineTransform *flip=NSAffineTransform.transform;
                [flip translateXBy:0 yBy:pixels]; [flip scaleXBy:1 yBy:-1]; [flip concat];
                [view drawRect:bounds];
                [NSGraphicsContext restoreGraphicsState];
                NSString *name=[NSString stringWithFormat:@"icon_%ldx%ld%@.png",(long)size,(long)size,multiplier==2 ? @"@2x" : @""];
                [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[folder stringByAppendingPathComponent:name] atomically:YES];
            }
        }
    }
}
