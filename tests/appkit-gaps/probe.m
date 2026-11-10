// OSXER APPKIT (regression): public contracts listed in REPORT-appkit-gaps.md.
// Execute only through run.sh in Darling. No application-specific receivers.
#import <AppKit/AppKit.h>
#import <AppKit/NSCustomTouchBarItem.h>
#import <AppKit/NSTouchBar.h>
#import <AppKit/NSAnimationContext.h>
#import <AppKit/NSStackView.h>
#import <Foundation/NSProgress.h>
// OSXER APPKIT (layering regression): observe the existing lower-level counter.
extern size_t _CFSuddenTerminationDisablingCount(void);
#import <CoreServices/CoreServices.h>
#include <errno.h>
#include <math.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr,"FAIL appkit-gaps:%d: %s\n",__LINE__,#c); exit(1); } } while (0)

// A disallowed coding class must never reach its initializer during secure decode.
static int unsafeDecoded;
@interface OSXERUnsafeArchive : NSObject <NSCoding>
@end
@implementation OSXERUnsafeArchive
- (void)encodeWithCoder:(NSCoder *)coder {}
- (id)initWithCoder:(NSCoder *)coder { ++unsafeDecoded; return [super init]; }
@end

static void runtimeState(void) {
    NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect(0,0,100,100)] autorelease];
    CHECK(![view canDrawConcurrently] && [view alphaValue] == 1);
    [view setCanDrawConcurrently:YES]; CHECK([view canDrawConcurrently]);
    [view setAlphaValue:0.4]; CHECK([view alphaValue] == 0.4);
    NSView *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:view]];
    CHECK([decoded canDrawConcurrently] && [decoded alphaValue] == 0.4);
    [view setCanDrawConcurrently:NO]; CHECK(![view canDrawConcurrently]);
    [view setAlphaValue:2]; CHECK([view alphaValue] == 1);
    [view setAlphaValue:-1]; CHECK([view alphaValue] == 0);
    NSTableView *table = [[[NSTableView alloc] initWithFrame:NSMakeRect(0,0,100,100)] autorelease];
    CHECK([table draggingSourceOperationMaskForLocal:YES] == NSDragOperationEvery);
    CHECK([table draggingSourceOperationMaskForLocal:NO] == NSDragOperationNone);
    [table setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
    [table setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    CHECK([table draggingSourceOperationMaskForLocal:YES] == NSDragOperationMove);
    CHECK([table draggingSourceOperationMaskForLocal:NO] == NSDragOperationCopy);
    [table setHeaderView:nil]; [table setCornerView:nil];
    NSTableView *copy = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:table]];
    CHECK([copy draggingSourceOperationMaskForLocal:YES] == NSDragOperationMove);
    CHECK([copy draggingSourceOperationMaskForLocal:NO] == NSDragOperationCopy);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(40,50,100,100)
        styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];
    [window setReleasedWhenClosed:NO];
    NSURL *url = [NSURL fileURLWithPath:@"/nonexistent/appkit-probe"];
    [window setRepresentedURL:url];
    CHECK([[window representedURL] isEqual:url]);
    CHECK([[window representedFilename] isEqual:[url path]]);
    [window setRepresentedURL:[NSURL URLWithString:@"https://example.invalid/document"]];
    CHECK([[[window representedURL] scheme] isEqual:@"https"]);
    [window setRepresentedURL:nil]; CHECK(![window representedURL]);
    [window setRepresentedFilename:@"/nonexistent/legacy"];
    CHECK([[[window representedURL] path] isEqual:@"/nonexistent/legacy"]);
    CHECK([window standardWindowButton:NSWindowCloseButton] == nil);
    NSRect rect = NSMakeRect(3,4,5,6), screen = [window convertRectToScreen:rect];
    CHECK(NSEqualPoints(screen.origin,[window convertBaseToScreen:rect.origin]));
    CHECK(NSEqualRects([window convertRectFromScreen:screen],rect));
    [window release];
}
static void foundation(NSString *directory) {
    NSCharacterSet *query = [NSCharacterSet URLQueryAllowedCharacterSet];
    CHECK([query characterIsMember:'?'] && [query characterIsMember:'&']);
    CHECK(![query characterIsMember:'#'] && ![query characterIsMember:'%']);
    CHECK([[@"a b/é?x=1#%" stringByAddingPercentEncodingWithAllowedCharacters:query]
        isEqual:@"a%20b/%C3%A9?x=1%23%25"]);
    CHECK([[@"é" stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet letterCharacterSet]] isEqual:@"%C3%A9"]);
    NSData *data = [[NSData alloc] initWithBase64Encoding:@"Y W\nJj"];
    CHECK([data isEqual:[@"abc" dataUsingEncoding:NSUTF8StringEncoding]]);
    CHECK([[data base64Encoding] isEqual:@"YWJj"]); [data release];
    NSString *path = [directory stringByAppendingPathComponent:@"io"];
    CHECK([[NSData data] writeToFile:path atomically:NO]);
    NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingAtPath:path];
    NSError *error = nil;
    CHECK([handle writeData:[@"abcdef" dataUsingEncoding:NSUTF8StringEncoding] error:&error]);
    CHECK(!error); [handle seekToFileOffset:0];
    CHECK([[handle readDataUpToLength:2 error:&error] isEqual:[@"ab" dataUsingEncoding:NSUTF8StringEncoding]]);
    CHECK([[handle readDataUpToLength:40 error:&error] length] == 4);
    CHECK([[handle readDataUpToLength:1 error:&error] length] == 0);
    CHECK([handle closeAndReturnError:&error]);
    CHECK(![handle readDataUpToLength:1 error:&error] && [error code] == EBADF);
    CHECK(![handle writeData:[@"x" dataUsingEncoding:NSUTF8StringEncoding] error:&error]);
    CHECK([error code] == EBADF);
    int p[2]; CHECK(pipe(p) == 0);
    CHECK(write(p[1],"xyz",3) == 3);
    handle = [[[NSFileHandle alloc] initWithFileDescriptor:p[0] closeOnDealloc:YES] autorelease];
    // Writer stays open: bounded reads must not wait for EOF.
    CHECK([[handle readDataUpToLength:10 error:&error] length] == 3);
    close(p[1]); CHECK([handle closeAndReturnError:&error]);
    NSProcessInfo *info = [NSProcessInfo processInfo];
    NSInteger count = [[info valueForKey:@"automaticTerminationOptOutCounter"] integerValue];
    [info disableAutomaticTermination:@"probe"];
    CHECK([[info valueForKey:@"automaticTerminationOptOutCounter"] integerValue] == count+1);
    [info enableAutomaticTermination:@"probe"];
    CHECK([[info valueForKey:@"automaticTerminationOptOutCounter"] integerValue] == count);
    size_t sudden = _CFSuddenTerminationDisablingCount();
    [info disableSuddenTermination]; CHECK(_CFSuddenTerminationDisablingCount() == sudden+1);
    [info enableSuddenTermination]; CHECK(_CFSuddenTerminationDisablingCount() == sudden);
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:@"secure"];
    CHECK([[NSKeyedUnarchiver unarchivedObjectOfClass:[NSString class] fromData:archive error:&error] isEqual:@"secure"]);
    CHECK([[NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObject:[NSString class]] fromData:archive error:&error] isEqual:@"secure"]);
    error = nil;
    CHECK(![NSKeyedUnarchiver unarchivedObjectOfClass:[NSDate class] fromData:archive error:&error] && error);
    error = nil;
    CHECK(![NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObject:[NSString class]] fromData:[NSData data] error:&error] && error);
}
static void sharedAppKit(NSString *directory) {
    NSTouchBar *bar = [[[NSTouchBar alloc] init] autorelease];
    NSMutableString *name = [NSMutableString stringWithString:@"primary"];
    [bar setPrincipalItemIdentifier:name]; [name appendString:@"changed"];
    CHECK([[bar principalItemIdentifier] isEqual:@"primary"]);
    NSCustomTouchBarItem *item = [[[NSCustomTouchBarItem alloc] initWithIdentifier:@"item"] autorelease];
    NSViewController *controller = [[[NSViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect(0,0,10,10)] autorelease];
    [controller setView:view]; [item setViewController:controller];
    CHECK([item viewController] == controller && [item view] == view);
    [item setViewController:nil]; CHECK(![item viewController]);
    NSURL *url = [NSURL URLWithString:@"osxer-probe-no-handler://item"];
    NSURL *lower = [(NSURL *)LSCopyDefaultApplicationURLForURL((CFURLRef)url,kLSRolesAll,NULL) autorelease];
    NSURL *upper = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:url];
    CHECK((!lower && !upper) || [lower isEqual:upper]);
    CHECK(![[NSBundle mainBundle] imageForResource:@"missing-osxer-probe-image"]);
    // A bundle image exercises actual loading, template handling and @2x sizing.
    NSString *bundlePath = [directory stringByAppendingPathComponent:@"Images.bundle"];
    NSString *resources = [bundlePath stringByAppendingPathComponent:@"Contents/Resources"];
    CHECK([[NSFileManager defaultManager] createDirectoryAtPath:resources withIntermediateDirectories:YES attributes:nil error:NULL]);
    CHECK(([@{ @"CFBundleIdentifier":@"org.darling.probe.images", @"CFBundlePackageType":@"BNDL" }
        writeToFile:[bundlePath stringByAppendingPathComponent:@"Contents/Info.plist"] atomically:NO]));
    NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:4 pixelsHigh:4
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:16 bitsPerPixel:32] autorelease];
    CHECK([[rep TIFFRepresentation] writeToFile:[resources stringByAppendingPathComponent:@"TestTemplate@2x.tiff"] atomically:NO]);
    NSImage *image = [[NSBundle bundleWithPath:bundlePath] imageForResource:@"TestTemplate"];
    CHECK(image && [image isTemplate] && [image size].width == 2);
}
static void layoutAndAnimation(void) {
    NSView *parent = [[[NSView alloc] initWithFrame:NSMakeRect(0,0,300,300)] autorelease];
    NSView *first = [[[NSView alloc] initWithFrame:NSMakeRect(1,2,30,40)] autorelease];
    NSView *second = [[[NSView alloc] initWithFrame:NSMakeRect(50,60,30,40)] autorelease];
    [parent addSubview:first]; [parent addSubview:second];
    NSLayoutConstraint *c = [NSLayoutConstraint constraintWithItem:first attribute:NSLayoutAttributeWidth
        relatedBy:NSLayoutRelationEqual toItem:second attribute:NSLayoutAttributeWidth multiplier:2 constant:7];
    CHECK([c firstItem] == first && [c secondItem] == second);
    CHECK([c firstAttribute] == NSLayoutAttributeWidth && [c secondAttribute] == NSLayoutAttributeWidth);
    CHECK([c relation] == NSLayoutRelationEqual && [c multiplier] == 2 && [c constant] == 7);
    CHECK(![c isActive] && [c priority] == NSLayoutPriorityRequired);
    [c setConstant:12]; [c setPriority:700]; [c setIdentifier:@"width"];
    CHECK([c constant] == 12 && [c priority] == 700 && [[c identifier] isEqual:@"width"]);
    [NSLayoutConstraint activateConstraints:@[c]];
    CHECK([c isActive] && [[parent constraints] containsObject:c] && [parent needsLayout]);
    NSRect before = [first frame]; [parent layoutSubtreeIfNeeded];
    CHECK(![parent needsLayout] && NSEqualRects(before,[first frame]));
    [NSLayoutConstraint deactivateConstraints:@[c]]; CHECK(![c isActive] && ![[parent constraints] count]);
    [parent addConstraints:@[c]]; CHECK([c isActive]);
    [parent removeConstraints:@[c]]; CHECK(![c isActive]);
    [c setActive:YES]; CHECK([c isActive]); [c setActive:NO]; CHECK(![c isActive]);
    [parent setNeedsLayout:YES]; CHECK([parent needsLayout]); [parent layout]; CHECK(![parent needsLayout]);
    [c setActive:YES]; [second removeFromSuperview];
    CHECK(![c isActive] && ![[parent constraints] count]);
    BOOL threw = NO; @try { [c setActive:YES]; } @catch (NSException *e) { threw = YES; }
    CHECK(threw && ![c isActive]);
    NSStackView *stack = [[[NSStackView alloc] initWithFrame:NSMakeRect(0,0,200,200)] autorelease];
    [stack addArrangedSubview:second]; [stack addArrangedSubview:second];
    CHECK([[stack arrangedSubviews] count] == 1 && [second superview] == stack);
    [stack insertArrangedSubview:first atIndex:0];
    CHECK([[stack arrangedSubviews] objectAtIndex:0] == first);
    [stack setSpacing:17]; CHECK([stack spacing] == 17);
    [stack removeArrangedSubview:first]; CHECK([first superview] == stack && [[stack arrangedSubviews] count] == 1);
    [second removeFromSuperview]; CHECK(![[stack arrangedSubviews] count]);
    __block int order = 0;
    NSAnimationContext *outer = [NSAnimationContext currentContext];
    [outer setDuration:1];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        CHECK(context == [NSAnimationContext currentContext] && context != outer);
        CHECK([context duration] == 1); [context setDuration:2];
        [context setAllowsImplicitAnimation:YES]; CHECK([context allowsImplicitAnimation]);
        NSAnimationContext *copy = [context copy]; CHECK(copy != context && [copy duration] == 2); [copy release];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *nested) {
            CHECK([nested duration] == 2 && nested != context); order = 1;
        } completionHandler:^{ CHECK(order == 1); order = 2; }];
        CHECK([NSAnimationContext currentContext] == context); order = 3;
    } completionHandler:^{ CHECK(order == 3); order = 4; }];
    CHECK(order == 4 && [NSAnimationContext currentContext] == outer && [outer duration] == 1);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) { order = 5; }]; CHECK(order == 5);
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setCompletionHandler:^{ order = 6; }];
    CHECK([[NSAnimationContext currentContext] completionHandler] != nil);
    [NSAnimationContext endGrouping]; CHECK(order == 6);
}
static void otherMethods(NSString *directory) {
    CHECK([[@"hello WORLD" localizedCapitalizedString] isEqual:[@"hello WORLD" capitalizedStringWithLocale:[NSLocale currentLocale]]]);
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *a = [directory stringByAppendingPathComponent:@"a"], *b = [directory stringByAppendingPathComponent:@"b"];
    CHECK([@"same" writeToFile:a atomically:NO encoding:NSUTF8StringEncoding error:NULL]);
    CHECK([@"same" writeToFile:b atomically:NO encoding:NSUTF8StringEncoding error:NULL]);
    CHECK([fm contentsEqualAtPath:a andPath:b]);
    CHECK([@"diff" writeToFile:b atomically:NO encoding:NSUTF8StringEncoding error:NULL]);
    CHECK(![fm contentsEqualAtPath:a andPath:b] && ![fm contentsEqualAtPath:a andPath:@"/no-such-probe-file"]);
    NSString *la = [directory stringByAppendingPathComponent:@"la"], *lb = [directory stringByAppendingPathComponent:@"lb"];
    CHECK(symlink("missing-target",[la fileSystemRepresentation]) == 0);
    CHECK(symlink("missing-target",[lb fileSystemRepresentation]) == 0);
    CHECK([fm contentsEqualAtPath:la andPath:lb]);
    CHECK([fm contentsEqualAtPath:directory andPath:directory]);
    CHECK([[NSImage imageTypes] containsObject:(NSString *)kUTTypeTIFF]);
    NSScroller *scroller = [[[NSScroller alloc] initWithFrame:NSMakeRect(0,0,15,150)] autorelease];
    [scroller setFloatValue:0.7 knobProportion:0.2]; [scroller setKnobProportion:0.5];
    CHECK([scroller knobProportion] == 0.5 && fabs([scroller floatValue]-0.7) < 0.001);
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAccessoryView:nil]; [panel setAccessoryViewDisclosed:YES]; CHECK(![panel isAccessoryViewDisclosed]);
    NSView *accessory = [[[NSView alloc] initWithFrame:NSMakeRect(0,0,20,20)] autorelease];
    [panel setAccessoryView:accessory]; [panel setAccessoryViewDisclosed:NO]; CHECK([accessory isHidden]);
    [panel setAccessoryViewDisclosed:YES]; CHECK([panel isAccessoryViewDisclosed] && ![accessory isHidden]);
    [panel setAccessoryView:nil];
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:2 pixelsHigh:2
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:8 bitsPerPixel:32] autorelease];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    CHECK([context CGContext] && [context CGContext] == [context graphicsPort]);
    CHECK([NSColor textInsertionPointColor] && [[NSColor textInsertionPointColor] alphaComponent] > 0);
    NSArray *colors = @[ [NSColor systemBlueColor], [NSColor systemBrownColor], [NSColor systemCyanColor],
        [NSColor systemGrayColor], [NSColor systemGreenColor], [NSColor systemIndigoColor], [NSColor systemMintColor],
        [NSColor systemOrangeColor], [NSColor systemPinkColor], [NSColor systemPurpleColor], [NSColor systemRedColor],
        [NSColor systemTealColor], [NSColor systemYellowColor] ];
    for (NSColor *color in colors) CHECK([color alphaComponent] == 1 && [color colorUsingColorSpaceName:NSDeviceRGBColorSpace]);
    NSTableCellView *cell = [[[NSTableCellView alloc] initWithFrame:NSMakeRect(0,0,100,30)] autorelease];
    NSTextField *text = [[[NSTextField alloc] initWithFrame:NSMakeRect(0,0,60,20)] autorelease];
    NSImageView *icon = [[[NSImageView alloc] initWithFrame:NSMakeRect(60,0,20,20)] autorelease];
    [cell addSubview:text]; [cell addSubview:icon];
    [cell setTextField:text]; [cell setImageView:icon]; [cell setObjectValue:@"row"];
    CHECK([cell textField] == text && [cell imageView] == icon && [[cell objectValue] isEqual:@"row"]);
    NSTableCellView *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:cell]];
    CHECK([[decoded subviews] containsObject:[decoded textField]] && [[decoded subviews] containsObject:[decoded imageView]]);
    CHECK([[decoded objectValue] isEqual:@"row"]);
    OSXERUnsafeArchive *unsafe = [[[OSXERUnsafeArchive alloc] init] autorelease];
    NSError *error = nil;
    CHECK(![NSKeyedUnarchiver unarchivedObjectOfClass:[OSXERUnsafeArchive class]
        fromData:[NSKeyedArchiver archivedDataWithRootObject:unsafe] error:&error]);
    CHECK(error && unsafeDecoded == 0);
}

// OSXER APPKIT (additional contracts): independent state and lower-layer behavior.
static void additionalMethods(void) {
    NSURL *directory = [NSURL URLWithString:@"https://example.invalid/not-on-disk/"];
    NSURL *file = [NSURL URLWithString:@"https://example.invalid/not-on-disk"];
    CHECK([directory hasDirectoryPath] && ![file hasDirectoryPath]);
    CHECK([directory hasDirectoryPath] == CFURLHasDirectoryPath((CFURLRef)directory));
    NSScanner *scanner = [NSScanner scannerWithString:@" \n-0x1.8p+2 suffix"];
    double number = 99;
    CHECK([scanner scanHexDouble:&number] && number == -6 && [scanner scanLocation] == 11);
    scanner = [NSScanner scannerWithString:@" 12.5"];
    CHECK(![scanner scanHexDouble:&number] && [scanner scanLocation] == 0 && number == -6);
    scanner = [NSScanner scannerWithString:@"0x1p99999!"];
    CHECK([scanner scanHexDouble:&number] && isinf(number) && [scanner scanLocation] == 9);
    scanner = [NSScanner scannerWithString:@"0x1p-99999!"];
    CHECK([scanner scanHexDouble:&number] && number == 0 && [scanner scanLocation] == 10);
    scanner = [NSScanner scannerWithString:@"0X2p0"];
    CHECK([scanner scanHexDouble:NULL] && [scanner isAtEnd]);
    scanner = [NSScanner scannerWithString:@"0x."];
    CHECK(![scanner scanHexDouble:&number] && [scanner scanLocation] == 0);
    NSProgress *progress = [[[NSProgress alloc] initWithParent:nil userInfo:nil] autorelease];
    NSMutableString *kind = [NSMutableString stringWithString:NSProgressKindFile];
    [progress setKind:kind]; [kind appendString:@"changed"];
    CHECK([[progress kind] isEqual:NSProgressKindFile]);
    [progress setKind:nil]; CHECK([progress kind] == nil);
    NSViewController *controller = [[[NSViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    CHECK(![controller isViewLoaded]); [controller viewDidDisappear]; CHECK(![controller isViewLoaded]);
    NSColor *rgb = [NSColor colorWithCalibratedRed:0.2 green:0.3 blue:0.4 alpha:1];
    CHECK([rgb type] == NSColorTypeComponentBased && [rgb colorUsingType:NSColorTypeComponentBased] == rgb);
    CHECK(![rgb colorUsingType:NSColorTypeCatalog] && ![rgb colorUsingType:NSColorTypePattern]);
    CHECK([[NSColor textColor] colorUsingType:NSColorTypeComponentBased] != nil);
    NSStackView *stack = [[[NSStackView alloc] initWithFrame:NSZeroRect] autorelease];
    CHECK([stack spacing] == 8); [stack setSpacing:17];
    [stack addArrangedSubview:[[[NSView alloc] initWithFrame:NSMakeRect(1,2,3,4)] autorelease]];
    NSStackView *stackCopy = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:stack]];
    CHECK([stackCopy spacing] == 17);
    CHECK([[stackCopy arrangedSubviews] count] == 1 && [[[stackCopy arrangedSubviews] objectAtIndex:0] superview] == stackCopy);

    __block NSUInteger calls = 0;
    NSImage *procedural = [NSImage imageWithSize:NSMakeSize(8,8) flipped:YES drawingHandler:^BOOL(NSRect rect) {
        ++calls;
        CHECK(NSEqualSizes(rect.size,NSMakeSize(8,8)) && [[NSGraphicsContext currentContext] isFlipped]);
        [[NSColor redColor] setFill]; NSRectFill(rect); return YES;
    }];
    CHECK(calls == 0 && [[procedural representations] count] == 1);
    NSImageRep *rep = [[procedural representations] objectAtIndex:0];
    CHECK([rep isKindOfClass:[NSCustomImageRep class]]);
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:8 pixelsHigh:8
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:32 bitsPerPixel:32] autorelease];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
    CHECK([rep drawInRect:NSMakeRect(0,0,8,8)] && calls == 1);
    CHECK(![[NSGraphicsContext currentContext] isFlipped]);
    NSImageRep *copy = [rep copy]; CHECK([copy draw] && calls == 2); [copy release];
    [NSGraphicsContext restoreGraphicsState];
    NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(8,8)] autorelease];
    NSGraphicsContext *before = [NSGraphicsContext currentContext];
    [image lockFocusFlipped:YES]; CHECK([[NSGraphicsContext currentContext] isFlipped]);
    CHECK(![image isFlipped]); [image unlockFocus]; CHECK([NSGraphicsContext currentContext] == before);
    [image lockFocusFlipped:NO]; CHECK(![[NSGraphicsContext currentContext] isFlipped]); [image unlockFocus];
}
int main(int argc, char **argv) {
    CHECK(argc == 2);
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *directory = [NSString stringWithUTF8String:argv[1]];
    runtimeState(); foundation(directory); sharedAppKit(directory); layoutAndAnimation(); otherMethods(directory); additionalMethods();
    [pool drain]; puts("PASS appkit-gaps"); return 0;
}
