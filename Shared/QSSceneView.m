#import "QScreen.h"
#import <math.h>

static NSColor *QSColor(unsigned hex) {
    return [NSColor colorWithSRGBRed:((hex >> 16) & 255) / 255.0 green:((hex >> 8) & 255) / 255.0 blue:(hex & 255) / 255.0 alpha:1];
}
static void ellipse(CGFloat x, CGFloat y, CGFloat w, CGFloat h, NSColor *color) {
    [color setFill]; [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x, y, w, h)] fill];
}
static void rounded(CGFloat x, CGFloat y, CGFloat w, CGFloat h, CGFloat radius, NSColor *color) {
    [color setFill]; [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(x, y, w, h) xRadius:radius yRadius:radius] fill];
}
static void stroke(NSArray<NSValue *> *points, CGFloat width, NSColor *color) {
    NSBezierPath *path = NSBezierPath.bezierPath;
    [path moveToPoint:points.firstObject.pointValue];
    for (NSUInteger i = 1; i < points.count; i++) [path lineToPoint:points[i].pointValue];
    path.lineWidth = width; path.lineCapStyle = NSLineCapStyleRound; path.lineJoinStyle = NSLineJoinStyleRound;
    [color setStroke]; [path stroke];
}
static NSValue *pt(CGFloat x, CGFloat y) { return [NSValue valueWithPoint:NSMakePoint(x, y)]; }
static void curve(CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat cx1, CGFloat cy1, CGFloat cx2, CGFloat cy2, CGFloat width, NSColor *color) {
    NSBezierPath *p = NSBezierPath.bezierPath;
    [p moveToPoint:NSMakePoint(x1, y1)]; [p curveToPoint:NSMakePoint(x2, y2) controlPoint1:NSMakePoint(cx1, cy1) controlPoint2:NSMakePoint(cx2, cy2)];
    p.lineWidth = width; p.lineCapStyle = NSLineCapStyleRound; [color setStroke]; [p stroke];
}
static void triangle(CGFloat x, CGFloat y, CGFloat w, CGFloat h, NSColor *color) {
    NSBezierPath *p = NSBezierPath.bezierPath;
    [p moveToPoint:NSMakePoint(x, y+h)]; [p lineToPoint:NSMakePoint(x+w/2, y)]; [p lineToPoint:NSMakePoint(x+w, y+h)]; [p closePath];
    [color setFill]; [p fill];
}
static void text(NSString *string, NSRect rect, CGFloat size, NSFontWeight weight, NSColor *color) {
    NSMutableParagraphStyle *style = NSMutableParagraphStyle.new;
    style.alignment = NSTextAlignmentCenter; style.lineBreakMode = NSLineBreakByClipping;
    NSFont *base = [NSFont systemFontOfSize:size weight:weight];
    NSFontDescriptor *descriptor = [base.fontDescriptor fontDescriptorWithDesign:NSFontDescriptorSystemDesignRounded];
    NSFont *font = descriptor ? [NSFont fontWithDescriptor:descriptor size:size] : base;
    [string drawInRect:rect withAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:color, NSParagraphStyleAttributeName:style}];
}
static NSColor *bodyColor(NSString *reason) {
    return QSColor([@{@"lunch":@0xBD8865, @"meeting":@0xEBDDC9, @"coffee":@0x919DA9,
                    @"restroom":@0xF2CA67, @"away":@0x9EBF93, @"offwork":@0xDF9673}[reason] unsignedIntValue]);
}
static NSColor *backgroundColor(NSString *reason) {
    return QSColor([@{@"lunch":@0xF7F0E3, @"meeting":@0xF0EDF7, @"coffee":@0xECF0F3,
                    @"restroom":@0xEEF3F0, @"away":@0xEDF2E4, @"offwork":@0x252D45}[reason] unsignedIntValue]);
}

@implementation QSSceneView
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _session = @{@"reason":@"away", @"endsAt":@0};
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    }
    return self;
}
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return YES; }
- (void)setSession:(NSDictionary *)session { _session = [session copy]; self.needsDisplay = YES; }
- (void)setAnimationTime:(NSTimeInterval)value { _animationTime = value; self.needsDisplay = YES; }
- (void)setReferenceTime:(NSTimeInterval)value { _referenceTime = value; self.needsDisplay = YES; }
- (void)setCharacterOnly:(BOOL)value { _characterOnly = value; self.needsDisplay = YES; }

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSString *reason = self.session[@"reason"] ?: @"away";
    BOOL night = [reason isEqual:@"offwork"];
    NSColor *ink = QSColor(night ? 0xF5EDDF : 0x333C38);
    NSColor *muted = QSColor(night ? 0xC5C7D8 : 0x68746E);
    [backgroundColor(reason) setFill]; NSRectFill(self.bounds);
    CGFloat canvasW = self.characterOnly ? 500 : 1200, canvasH = self.characterOnly ? 470 : 800;
    CGFloat scale = MIN(self.bounds.size.width / canvasW, self.bounds.size.height / canvasH);
    if (scale <= 0) return;
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *transform = NSAffineTransform.transform;
    [transform translateXBy:(self.bounds.size.width - canvasW*scale)/2 yBy:(self.bounds.size.height - canvasH*scale)/2];
    [transform scaleBy:scale]; [transform concat];
    double t = self.animationTime;
    CGFloat bob = sin(t*1.8)*5;
    CGFloat cx = self.characterOnly ? 250 : 600;
    CGFloat cy = self.characterOnly ? 245 : 310;

    if (!self.characterOnly) {
        // Sparse moving details give the character space without competing with the status.
        for (NSInteger i=0; i<9; i++) {
            CGFloat x = 110 + ((i*137)%1000) + sin(t*.18+i)*12;
            CGFloat y = 100 + ((i*79)%350) + cos(t*.25+i)*9;
            NSColor *detail = [ink colorWithAlphaComponent:night ? .22 : .09];
            if (i%3 == 0) {
                stroke(@[pt(x-7,y),pt(x+7,y)], 3, detail);
                stroke(@[pt(x,y-7),pt(x,y+7)], 3, detail);
            } else ellipse(x,y, i%2 ? 7 : 11, i%2 ? 7 : 11,detail);
        }
        if (night) {
            ellipse(905,110,70,70,QSColor(0xF6D99B));
            ellipse(928,98,66,66,backgroundColor(reason));
        }
    }
    ellipse(cx-132,cy+157,264,23,[ink colorWithAlphaComponent:.08]);
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *character = NSAffineTransform.transform;
    [character translateXBy:cx yBy:cy+bob]; [character concat];
    [self drawCharacter:reason time:t];
    [NSGraphicsContext restoreGraphicsState];

    if (!self.characterOnly) {
        // Small continuous drift protects fixed lettering without making it hard to read.
        CGFloat drift = sin(t*.03)*9;
        text(QSReasonTitle(reason), NSMakeRect(80+drift,548,1040,120), 88, NSFontWeightSemibold, ink);
        NSTimeInterval now = self.referenceTime > 0 ? self.referenceTime : NSDate.date.timeIntervalSince1970;
        text(QSReturnText(self.session,now), NSMakeRect(80+drift,671,1040,65), 39, NSFontWeightMedium, muted);
    }
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawCharacter:(NSString *)reason time:(double)t {
    NSColor *body=bodyColor(reason), *dark=QSColor(0x39443F), *cream=QSColor(0xFFF6E5);
    BOOL rabbit=[reason isEqual:@"meeting"], cat=[reason isEqual:@"coffee"], frog=[reason isEqual:@"away"];
    BOOL duck=[reason isEqual:@"restroom"], fox=[reason isEqual:@"offwork"], bear=[reason isEqual:@"lunch"];
    CGFloat breathe=sin(t*1.6)*2;
    if (fox) {
        // A curled tail and pointed ears make the off-work fox a separate silhouette.
        ellipse(65,25,105,120,body); ellipse(109,34,58,67,cream);
    }
    if (cat) {
        curve(85,100,142,44,165,130,170,40,24,body);
    }
    rounded(-86,-15,172,169+breathe,72,body);
    ellipse(-72,125,62,36,body); ellipse(10,125,62,36,body);
    ellipse(-49,15,98,115, [cream colorWithAlphaComponent:.48]);
    if (rabbit) {
        rounded(-76,-203,48,137,24,body); rounded(28,-212,48,146,24,body);
        rounded(-63,-189,22,103,11,QSColor(0xDFB6B1)); rounded(41,-198,22,112,11,QSColor(0xDFB6B1));
    } else if (cat || fox) {
        triangle(-98,-151,78,95,body); triangle(20,-151,78,95,body);
        triangle(-81,-132,44,61,QSColor(cat ? 0xC7B5B6 : 0xF3C0A2));
        triangle(37,-132,44,61,QSColor(cat ? 0xC7B5B6 : 0xF3C0A2));
    } else if (bear) {
        ellipse(-105,-130,67,67,body); ellipse(38,-130,67,67,body);
        ellipse(-92,-117,41,41,QSColor(0xE5B99B)); ellipse(51,-117,41,41,QSColor(0xE5B99B));
    } else if (frog) {
        ellipse(-96,-137,75,78,body); ellipse(21,-137,75,78,body);
    } else if (duck) {
        curve(-8,-105,13,-145,-5,-140,23,-158,12,body);
    }
    ellipse(-106,-111,212,180,body);
    if (fox) {
        ellipse(-84,-43,88,83,cream); ellipse(-4,-43,88,83,cream);
    }
    if (bear) ellipse(-46,-19,92,68,QSColor(0xEED1AE));
    if (cat) {
        stroke(@[pt(-18,-100),pt(-12,-74)],7,QSColor(0x657586));
        stroke(@[pt(0,-104),pt(0,-76)],7,QSColor(0x657586));
        stroke(@[pt(18,-100),pt(12,-74)],7,QSColor(0x657586));
    }
    BOOL blink = fmod(t,5.7) > 5.48;
    CGFloat eyeY=frog ? -100 : -39;
    if (fox || blink) {
        curve(-51,eyeY,-28,eyeY,-43,eyeY+8,-36,eyeY+8,5,dark);
        curve(28,eyeY,51,eyeY,36,eyeY+8,43,eyeY+8,5,dark);
    } else {
        if (frog) { ellipse(-80,-123,44,49,cream); ellipse(36,-123,44,49,cream); }
        ellipse(frog ? -65 : -46,eyeY,12,17,dark); ellipse(frog ? 53 : 34,eyeY,12,17,dark);
        ellipse(frog ? -62 : -43,eyeY+2,4,5,NSColor.whiteColor); ellipse(frog ? 56 : 37,eyeY+2,4,5,NSColor.whiteColor);
    }
    ellipse(-78,-14,27,16,[QSColor(0xE69F91) colorWithAlphaComponent:.75]);
    ellipse(51,-14,27,16,[QSColor(0xE69F91) colorWithAlphaComponent:.75]);
    if (duck) {
        rounded(-34,-10,68,29,15,QSColor(0xDB9351));
        stroke(@[pt(-20,4),pt(20,4)],3,QSColor(0xB97645));
    } else if (frog) {
        curve(-31,-10,31,-10,-15,10,15,10,5,dark);
    } else {
        ellipse(-8,-9,16,11,dark);
        curve(-17,12,0,10,-11,21,-4,21,3,dark);
        curve(0,10,17,12,4,21,11,21,3,dark);
    }
    if (cat) {
        stroke(@[pt(-78,8),pt(-116,0)],3,dark); stroke(@[pt(-77,20),pt(-115,26)],3,dark);
        stroke(@[pt(78,8),pt(116,0)],3,dark); stroke(@[pt(77,20),pt(115,26)],3,dark);
    }
    // Each state has its own action and prop, rather than just changing its color.
    if (bear) {
        NSBezierPath *rice=NSBezierPath.bezierPath;
        [rice moveToPoint:NSMakePoint(-43,115)]; [rice curveToPoint:NSMakePoint(-45,88) controlPoint1:NSMakePoint(-55,112) controlPoint2:NSMakePoint(-55,100)];
        [rice lineToPoint:NSMakePoint(-13,42)]; [rice curveToPoint:NSMakePoint(13,42) controlPoint1:NSMakePoint(-7,30) controlPoint2:NSMakePoint(7,30)];
        [rice lineToPoint:NSMakePoint(45,88)]; [rice curveToPoint:NSMakePoint(43,115) controlPoint1:NSMakePoint(55,100) controlPoint2:NSMakePoint(55,112)];
        [rice closePath]; [cream setFill]; [rice fill]; rounded(-18,82,36,35,4,QSColor(0x4A6554));
        ellipse(-70,74+sin(t*2)*3,43,36,body); ellipse(27,74+sin(t*2)*3,43,36,body);
        ellipse(128+sin(t)*5,-42,9,9,QSColor(0xD4A260));
    } else if (rabbit) {
        rounded(-116,70,232,91,13,QSColor(0xA4A9C7));
        ellipse(-10,106,20,20,QSColor(0xDADDEC)); rounded(-130,155,260,10,5,QSColor(0x838BA9));
        ellipse(-94,53+sin(t*3)*3,37,25,body); ellipse(57,53+cos(t*3)*3,37,25,body);
        // Round spectacles.
        NSBezierPath *glasses=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(-62,-55,48,43)];
        [glasses appendBezierPathWithOvalInRect:NSMakeRect(14,-55,48,43)]; glasses.lineWidth=4; [QSColor(0x827987) setStroke]; [glasses stroke];
        stroke(@[pt(-14,-36),pt(14,-36)],4,QSColor(0x827987));
    } else if (cat) {
        NSBezierPath *handle=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(23,63,48,42)];
        handle.lineWidth=12; [QSColor(0xFAF3E6) setStroke]; [handle stroke];
        rounded(-42,54,85,75,14,QSColor(0xFAF3E6)); ellipse(-31,48,63,16,QSColor(0x8A6652));
        ellipse(-70,81,42,32,body); ellipse(29,81,35,32,body);
        for (NSInteger i=0;i<3;i++) {
            CGFloat x=-22+i*22, dy=sin(t*1.5+i)*7;
            curve(x,30,x-4,-10+dy,x-18,16,x+16,7+dy,4,[QSColor(0x7D8B8A) colorWithAlphaComponent:.45]);
        }
    } else if (duck) {
        rounded(-70,58,140,58,23,QSColor(0xF9FAEC));
        stroke(@[pt(-62,80),pt(62,80)],3,QSColor(0xC9DED3));
        ellipse(-103,41,43,31,body); ellipse(60,41,43,31,body);
        for (NSInteger i=0;i<4;i++) {
            CGFloat x=-150+i*96, y=-110-fmod(t*17+i*37,110), r=12+i*3;
            NSBezierPath *bubble=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x,y,r,r)];
            bubble.lineWidth=3; [[QSColor(0x7DAFAD) colorWithAlphaComponent:.55] setStroke]; [bubble stroke];
            ellipse(x+r*.25,y+r*.18,4,4,NSColor.whiteColor);
        }
    } else if (frog) {
        rounded(-93,21,186,26,12,QSColor(0xDBAB74));
        rounded(39,28,29,89,10,QSColor(0xDBAB74));
        ellipse(-125,70+sin(t*1.8)*12,48,37,body); ellipse(77,70-sin(t*1.8)*12,48,37,body);
        stroke(@[pt(-143,-36),pt(-162,-52)],5,QSColor(0x7FA376));
        stroke(@[pt(143,-36),pt(162,-52)],5,QSColor(0x7FA376));
    } else if (fox) {
        rounded(-101,69,202,92,40,QSColor(0xB1AECF));
        for (NSInteger i=0;i<4;i++) ellipse(-67+i*45,112,8,8,QSColor(0xD8D3EA));
        CGFloat z=-fmod(t*19,57);
        text(@"z",NSMakeRect(114,-92+z,38,45),29,NSFontWeightSemibold,QSColor(0xD8D3EA));
        text(@"z",NSMakeRect(151,-137+z,47,53),38,NSFontWeightSemibold,QSColor(0xD8D3EA));
    }
}
@end
