// OSXER APPKIT (regression): public contracts listed in REPORT-appkit-gaps.md.
// Execute only through run.sh in Darling. No application-specific receivers.
#import <AppKit/AppKit.h>
#import <AppKit/NSCustomTouchBarItem.h>
#import <AppKit/NSTouchBar.h>
#import <AppKit/NSAnimationContext.h>
#import <AppKit/NSStackView.h>
#import <Foundation/NSProgress.h>
#import <AppKit/NSNib.h>
#import <AppKit/NSPasteboardItem.h>
#import <dispatch/dispatch.h>
// OSXER APPKIT (layering regression): observe the existing lower-level counter.
extern size_t _CFSuddenTerminationDisablingCount(void);
#import <CoreServices/CoreServices.h>
#include <errno.h>
#include <math.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr,"FAIL appkit-gaps:%d: %s\n",__LINE__,#c); exit(1); } } while (0)

// OSXER APPKIT (round 2): public Apple contracts linked in REPORT-appkit-gaps-2.md.
static void pumpUntil(BOOL (^ready)(void)) {
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!ready() && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    CHECK(ready());
}

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
        } completionHandler:^{ CHECK([NSThread isMainThread] && order == 3); order = 4; }];
        CHECK(order == 1 && [NSAnimationContext currentContext] == context); order = 3;
    } completionHandler:^{ CHECK([NSThread isMainThread] && order == 4); order = 5; }];
    CHECK(order == 3 && [NSAnimationContext currentContext] == outer && [outer duration] == 1);
    pumpUntil(^BOOL { return order == 5; });
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) { order = 6; }]; CHECK(order == 6);
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setCompletionHandler:^{ order = 7; }];
    CHECK([[NSAnimationContext currentContext] completionHandler] != nil);
    [NSAnimationContext endGrouping]; CHECK(order == 6);
    pumpUntil(^BOOL { return order == 7; });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *worker = [NSAutoreleasePool new];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            CHECK(![NSThread isMainThread]);
        } completionHandler:^{ CHECK([NSThread isMainThread]); order = 8; }];
        [worker drain];
    });
    pumpUntil(^BOOL { return order == 8; });
    CHECK([first animator] == first);

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
// OSXER APPKIT (table regressions): actual synthetic nib, delegate, reuse and KVO.
@interface OSXERTableOwner : NSObject {
@public
    NSTableView *table;
    NSTableCellView *lastCell;
    NSInteger rows, calls;
}
@property(assign) NSTableView *table;
@property(assign) NSTableCellView *lastCell;
@end
@implementation OSXERTableOwner
@synthesize table, lastCell;
- (NSInteger)numberOfRowsInTableView:(NSTableView *)sender { return rows; }
- (id)tableView:(NSTableView *)sender objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    return [NSString stringWithFormat:@"row %ld", (long)row];
}
- (NSView *)tableView:(NSTableView *)sender viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    ++calls; return [sender makeViewWithIdentifier:[column identifier] owner:self];
}
@end
static void viewTables(NSString *fixtures) {
    OSXERTableOwner *owner = [[[OSXERTableOwner alloc] init] autorelease]; owner->rows = 10;
    NSNib *cellNib = [[[NSNib alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[fixtures stringByAppendingPathComponent:@"cell.nib"]]] autorelease];
    CHECK(cellNib);
    NSTableView *table = [[[NSTableView alloc] initWithFrame:NSMakeRect(0,0,100,60)] autorelease];
    [table setHeaderView:nil]; [table addTableColumn:[[[NSTableColumn alloc] initWithIdentifier:@"cell"] autorelease]];
    [table setRowHeight:24]; [table setIntercellSpacing:NSZeroSize];
    [table setDataSource:owner]; [table setDelegate:owner];
    CHECK(![table makeViewWithIdentifier:@"missing" owner:owner]);
    [table registerNib:cellNib forIdentifier:@"cell"];
    CHECK([[table registeredNibsByIdentifier] objectForKey:@"cell"] == cellNib);
    CHECK(![table viewAtColumn:0 row:0 makeIfNecessary:NO]);
    NSTableCellView *cell = (id)[table viewAtColumn:0 row:0 makeIfNecessary:YES];
    CHECK(cell && cell == owner->lastCell && [cell textField]);
    CHECK([[cell objectValue] isEqual:@"row 0"] && [[[cell textField] stringValue] isEqual:@"row 0"]);
    CHECK([table rowForView:[cell textField]] == 0 && [table columnForView:cell] == 0);
    CHECK([table viewAtColumn:0 row:0 makeIfNecessary:YES] == cell && owner->calls == 1);
    [cell setObjectValue:@"updated"]; CHECK([[[cell textField] stringValue] isEqual:@"updated"]);
    CHECK(![table viewAtColumn:-1 row:0 makeIfNecessary:YES] && ![table viewAtColumn:0 row:10 makeIfNecessary:YES]);
    [table reloadData];
    CHECK([cell superview] == nil && [table rowForView:cell] == -1);
    CHECK([table viewAtColumn:0 row:1 makeIfNecessary:YES] == cell);
    CHECK([[cell objectValue] isEqual:@"row 1"] && [[[cell textField] stringValue] isEqual:@"row 1"]);
    [table tile]; CHECK(owner->calls > 2);
    NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,100,50)] autorelease];
    [scroll setDocumentView:table];
    [[scroll contentView] scrollToPoint:NSMakePoint(0,120)];
    [table drawRow:5 clipRect:[table visibleRect]];
    CHECK(![table viewAtColumn:0 row:0 makeIfNecessary:NO]);
    CHECK([table viewAtColumn:0 row:5 makeIfNecessary:NO]);
    [table registerNib:nil forIdentifier:@"cell"]; CHECK(![[table registeredNibsByIdentifier] count]);
    BOOL raised = NO; @try { [table endUpdates]; } @catch (NSException *e) { raised = YES; } CHECK(raised);
    [table beginUpdates]; [table reloadData]; [table endUpdates];
    NSNib *tableNib = [[[NSNib alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[fixtures stringByAppendingPathComponent:@"table.nib"]]] autorelease];
    NSArray *roots = nil; CHECK([tableNib instantiateWithOwner:owner topLevelObjects:&roots]);
    CHECK(owner->table && [roots containsObject:owner->table]);
    table = owner->table; [table setDataSource:owner];
    // No delegate view method: the table's embedded prototype supplies the cell.
    NSView *prototype = [table makeViewWithIdentifier:@"cell" owner:owner];
    NSView *other = [table makeViewWithIdentifier:@"cell" owner:owner];
    CHECK(prototype && other && prototype != other);
    [table setDelegate:owner];
    [table tile];
    cell = (id)[table viewAtColumn:0 row:0 makeIfNecessary:NO];
    CHECK(cell && [[[cell textField] stringValue] isEqual:@"row 0"]);
    CHECK([cell superview] == table && NSEqualRects([cell frame],[table frameOfCellAtColumn:0 row:0]));
    [table reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:0] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}
@interface OSXERFlippedStack : NSStackView
@end
@implementation OSXERFlippedStack
- (BOOL)isFlipped { return YES; }
@end
static void stackFrames(void) {
    NSStackView *centers = [[[NSStackView alloc] initWithFrame:NSMakeRect(0,0,200,40)] autorelease];
    for (int width = 20; width <= 60; width += 20)
        [centers addArrangedSubview:[[[NSView alloc] initWithFrame:NSMakeRect(0,0,width,10)] autorelease]];
    [centers setDistribution:NSStackViewDistributionEqualCentering]; [centers layoutSubtreeIfNeeded];
    NSArray *centerViews = [centers arrangedSubviews];
    CHECK(NSMidX([[centerViews objectAtIndex:1] frame]) == 90 && NSMaxX([[centerViews lastObject] frame]) == 200);
    for (Class cls in @[[NSStackView class], [OSXERFlippedStack class]]) {
        NSStackView *stack = [[[cls alloc] initWithFrame:NSMakeRect(0,0,200,100)] autorelease];
        NSView *a = [[[NSView alloc] initWithFrame:NSMakeRect(0,0,20,10)] autorelease];
        NSView *b = [[[NSView alloc] initWithFrame:NSMakeRect(0,0,40,20)] autorelease];
        [stack addArrangedSubview:a]; [stack addArrangedSubview:b];
        [stack setSpacing:10]; [stack setEdgeInsets:NSEdgeInsetsMake(5,10,15,20)];
        [stack setDistribution:NSStackViewDistributionFillEqually]; [stack layoutSubtreeIfNeeded];
        CHECK(fabs([a frame].size.width-80)<0.01 && fabs([b frame].origin.x-100)<0.01);
        [stack setFrameSize:NSMakeSize(300,100)]; [stack layoutSubtreeIfNeeded];
        CHECK(fabs([a frame].size.width-130)<0.01);
        [stack setOrientation:NSUserInterfaceLayoutOrientationVertical]; [stack setAlignment:NSLayoutAttributeLeading];
        [stack layoutSubtreeIfNeeded];
        CHECK(fabs([a frame].size.height-35)<0.01 && [a frame].origin.x == 10);
        CHECK([stack isFlipped] ? NSMinY([a frame]) < NSMinY([b frame]) : NSMinY([a frame]) > NSMinY([b frame]));
        [stack removeArrangedSubview:b]; [stack layoutSubtreeIfNeeded];
        CHECK([b superview] == stack && [a frame].size.height == 80);
        [stack setDistribution:NSStackViewDistributionFill]; [stack layoutSubtreeIfNeeded];
        CHECK([a frame].size.height == 80);
        [a removeFromSuperview]; [stack layoutSubtreeIfNeeded]; CHECK(![[stack arrangedSubviews] count]);
    }
}
static NSWindow *sheetWindow(void) {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(20,20,180,100)
        styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:YES] autorelease];
    [window setReleasedWhenClosed:NO]; return window;
}
static void sheetCompletions(void) {
    NSWindow *parent = sheetWindow(), *one = sheetWindow(), *two = sheetWindow(), *three = sheetWindow();
    [parent makeKeyAndOrderFront:nil]; CHECK([parent animator] == parent);
    __block int order = 0;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id saved = [[defaults objectForKey:@"NSRunAllSheetsAsModalPanel"] retain];
    [defaults setBool:YES forKey:@"NSRunAllSheetsAsModalPanel"];
    [parent beginSheet:one completionHandler:^(NSInteger result) {
        CHECK(result == 11 && order == 0 && ![parent attachedSheet] && ![one sheetParent]); order = 1;
        [parent beginSheet:three completionHandler:^(NSInteger code) { CHECK(code == 33 && order == 2); order = 3; }];
    }];
    [parent beginSheet:two completionHandler:^(NSInteger code) { CHECK(code == 22 && order == 1); order = 2; }];
    CHECK(order == 0 && [parent attachedSheet] == one && [one sheetParent] == parent && [[parent sheets] count] == 2);
    [parent endSheet:one returnCode:11]; CHECK(order == 1 && [parent attachedSheet] == two);
    [NSApp endSheet:two returnCode:22]; CHECK(order == 2 && [parent attachedSheet] == three);
    [parent endSheet:three returnCode:33]; CHECK(order == 3 && ![parent attachedSheet]);
    [NSApp endSheet:three returnCode:33]; CHECK(order == 3);
    CHECK([one styleMask] == NSTitledWindowMask);
    BOOL rejected = NO; @try { [parent endSheet:nil]; } @catch (NSException *exception) { rejected = YES; }
    CHECK(rejected);
    [parent beginSheet:one completionHandler:nil];
    __block BOOL withdrawn = NO;
    [parent beginSheet:two completionHandler:^(NSInteger code) { CHECK(code == NSCancelButton); withdrawn = YES; }];
    [NSApp endSheet:two returnCode:NSCancelButton];
    CHECK(withdrawn && [parent attachedSheet] == one && ![two sheetParent]);
    [parent endSheet:one];
    NSAlert *alert = [[[NSAlert alloc] init] autorelease]; [alert addButtonWithTitle:@"OK"];
    __block NSInteger alertResult = 0;
    [alert beginSheetModalForWindow:parent completionHandler:^(NSInteger code) { alertResult = code; }];
    CHECK([parent attachedSheet] == [alert window]);
    [[[alert buttons] objectAtIndex:0] performClick:nil]; CHECK(alertResult == 1000 && ![parent attachedSheet]);
    for (NSSavePanel *panel in @[[NSSavePanel savePanel], [NSOpenPanel openPanel]]) {
        __block int callbacks = 0;
        [panel beginSheetModalForWindow:parent completionHandler:^(NSInteger code) { CHECK(code == NSCancelButton); ++callbacks; }];
        CHECK(callbacks == 0 && [parent attachedSheet] == panel);
        [panel cancelOperation:nil]; CHECK(callbacks == 1 && ![parent attachedSheet]);
        [panel beginSheetModalForWindow:parent completionHandler:nil]; [panel cancelOperation:nil];
    }
    if (saved) [defaults setObject:saved forKey:@"NSRunAllSheetsAsModalPanel"];
    else [defaults removeObjectForKey:@"NSRunAllSheetsAsModalPanel"];
    [saved release]; [parent orderOut:nil];
}
static void secureEntries(void) {
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@"secure2" requiringSecureCoding:YES error:&error];
    CHECK(data && !error);
    NSKeyedUnarchiver *decoder = [[[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error] autorelease];
    CHECK(decoder && [decoder requiresSecureCoding] && !error);
    CHECK([[decoder decodeTopLevelObjectOfClass:[NSString class] forKey:NSKeyedArchiveRootObjectKey error:&error] isEqual:@"secure2"] && !error);
    [decoder finishDecoding];
    error = nil; CHECK(![[[NSKeyedUnarchiver alloc] initForReadingFromData:[NSData data] error:&error] autorelease] && error);
    NSData *bad = [NSPropertyListSerialization dataWithPropertyList:@[@"not an archive"] format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    error = nil; CHECK(![NSKeyedUnarchiver unarchivedObjectOfClass:[NSArray class] fromData:bad error:&error] && error);
    error = nil; CHECK(![NSKeyedArchiver archivedDataWithRootObject:@[[[[OSXERUnsafeArchive alloc] init] autorelease]] requiringSecureCoding:YES error:&error] && error);
    NSKeyedArchiver *encoder = [[[NSKeyedArchiver alloc] initRequiringSecureCoding:YES] autorelease];
    CHECK([encoder requiresSecureCoding]); [encoder encodeObject:@"value" forKey:@"value"];
    data = [encoder encodedData]; decoder = [[[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error] autorelease];
    error = nil; CHECK(![decoder decodeTopLevelObjectOfClass:[NSDate class] forKey:@"value" error:&error] && error);
    CHECK([decoder allowedClasses] == nil);
    error = nil; CHECK([[decoder decodeTopLevelObjectOfClass:[NSString class] forKey:@"value" error:&error] isEqual:@"value"] && !error);
}

// OSXER APPKIT (shared API regressions): test data stays in the script's directory.
@interface OSXERItemProvider : NSObject <NSPasteboardItemDataProvider> { @public NSUInteger calls; }
@end
@implementation OSXERItemProvider
- (void)pasteboard:(NSPasteboard *)board item:(NSPasteboardItem *)item provideDataForType:(NSString *)type {
    ++calls; CHECK(![item dataForType:type]); [item setString:@"provided" forType:type];
}
@end
@interface OSXERFileManager : NSFileManager { @public NSURL *trash; }
@end
@implementation OSXERFileManager
- (NSURL *)URLForDirectory:(NSSearchPathDirectory)which inDomain:(NSSearchPathDomainMask)domain
        appropriateForURL:(NSURL *)url create:(BOOL)create error:(NSError **)error {
    if (which == NSTrashDirectory) {
        if (create) [self createDirectoryAtURL:trash withIntermediateDirectories:YES attributes:nil error:error];
        return trash;
    }
    return [super URLForDirectory:which inDomain:domain appropriateForURL:url create:create error:error];
}
@end
// OSXER APPKIT (pasteboard reader regressions): archive-only readers do not
// implement the property-list initializer; raw readers may omit reading options.
@interface OSXERArchivePasteboardReader : NSObject <NSCoding, NSPasteboardReading> { @public BOOL decoded; }
@end
@implementation OSXERArchivePasteboardReader
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)board { return @[@"org.osxer.probe.archive"]; }
+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)board { return NSPasteboardReadingAsKeyedArchive; }
- (void)encodeWithCoder:(NSCoder *)coder { [coder encodeBool:YES forKey:@"decoded"]; }
- (id)initWithCoder:(NSCoder *)coder { if ((self = [super init])) decoded = [coder decodeBoolForKey:@"decoded"]; return self; }
@end
@interface OSXERRawPasteboardReader : NSObject <NSPasteboardReading> { @public NSData *data; }
@end
@implementation OSXERRawPasteboardReader
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)board { return @[@"org.osxer.probe.archive"]; }
- (id)initWithPasteboardPropertyList:(id)value ofType:(NSString *)type { if ((self = [super init])) data = [value retain]; return self; }
- (void)dealloc { [data release]; [super dealloc]; }
@end
// OSXER APPKIT (popover regression): exercise public event dispatch without
// entering controls' mouse-tracking loops after the popover's monitor runs.
static void clickForPopover(NSWindow *window) {
    id sink = [NSEvent addLocalMonitorForEventsMatchingMask:NSLeftMouseDownMask handler:^NSEvent *(NSEvent *event) { return nil; }];
    [NSApp sendEvent:[NSEvent mouseEventWithType:NSLeftMouseDown location:NSMakePoint(5,5)
        modifierFlags:0 timestamp:0 windowNumber:[window windowNumber] context:nil
        eventNumber:1 clickCount:1 pressure:1]];
    [NSEvent removeMonitor:sink];
}

static void sharedRoundTwo(NSString *directory) {
    NSProcessInfo *process = [NSProcessInfo processInfo];
    NSInteger before = [[process valueForKey:@"automaticTerminationOptOutCounter"] integerValue];
    size_t sudden = _CFSuddenTerminationDisablingCount();
    id activity = [process beginActivityWithOptions:NSActivityAutomaticTerminationDisabled | NSActivitySuddenTerminationDisabled reason:@"probe"];
    CHECK([[process valueForKey:@"automaticTerminationOptOutCounter"] integerValue] == before + 1);
    CHECK(_CFSuddenTerminationDisablingCount() == sudden + 1);
    [process endActivity:activity]; [process endActivity:activity];
    CHECK([[process valueForKey:@"automaticTerminationOptOutCounter"] integerValue] == before && _CFSuddenTerminationDisablingCount() == sudden);
    @try {
        [process performActivityWithOptions:NSActivitySuddenTerminationDisabled reason:@"exception probe" usingBlock:^{
            CHECK(_CFSuddenTerminationDisablingCount() == sudden + 1);
            [NSException raise:NSGenericException format:@"probe"];
        }];
    } @catch (NSException *exception) { CHECK([[exception name] isEqual:NSGenericException]); }
    CHECK(_CFSuddenTerminationDisablingCount() == sudden);
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    CFErrorRef lookupError = NULL;
    CHECK(!LSCopyDefaultApplicationURLForContentType(NULL,kLSRolesAll,&lookupError) && lookupError);
    CHECK(CFErrorGetCode(lookupError) == -50); CFRelease(lookupError);
    NSString *unknown = @"org.osxer.probe.unregistered.type";
    NSURL *lower = [(NSURL *)LSCopyDefaultApplicationURLForContentType((CFStringRef)unknown,kLSRolesAll,NULL) autorelease];
    NSURL *upper = [workspace URLForApplicationToOpenContentType:unknown];
    CHECK((!lower && !upper) || [lower isEqual:upper]);
    __block BOOL callback = NO;
    [workspace setDefaultApplicationAtURL:[NSURL URLWithString:@"https://example.invalid/app"] toOpenURLsWithScheme:@"osxer-probe"
        completionHandler:^(NSError *error) { CHECK(error && [NSThread isMainThread]); callback = YES; }];
    CHECK(!callback); pumpUntil(^BOOL { return callback; });
    NSPasteboard *board = [NSPasteboard pasteboardWithName:[[NSProcessInfo processInfo] globallyUniqueString]];
    [board clearContents];
    CHECK(![board canReadObjectForClasses:@[[NSString class]] options:nil]);
    NSMutableString *mutable = [NSMutableString stringWithString:@"first"];
    NSURL *fileURL = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"clipboard.txt"]];
    CHECK(([board writeObjects:@[mutable, @"second", fileURL]])); [mutable appendString:@" changed"];
    CHECK([[board pasteboardItems] count] == 3);
    CHECK(([[board readObjectsForClasses:@[[NSString class]] options:nil] isEqual:@[@"first", @"second"]]));
    CHECK([[NSURL URLFromPasteboard:board] isEqual:fileURL]);
    CHECK([board canReadObjectForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey:@YES}]);
    CHECK([board writeObjects:@[@"third"]] && [[board pasteboardItems] count] == 4);
    [board clearContents]; CHECK(![board pasteboardItems]);
    OSXERItemProvider *provider = [[[OSXERItemProvider alloc] init] autorelease];
    NSPasteboardItem *item = [[[NSPasteboardItem alloc] init] autorelease];
    CHECK([item setDataProvider:provider forTypes:@[NSPasteboardTypeString]]);
    CHECK(provider->calls == 0 && [[item types] count] == 1);
    CHECK([[item stringForType:NSPasteboardTypeString] isEqual:@"provided"] && provider->calls == 1);
    CHECK([board writeObjects:@[item]] && [[board stringForType:NSPasteboardTypeString] isEqual:@"provided"]);
    [board clearContents];
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:[[[OSXERArchivePasteboardReader alloc] init] autorelease]];
    NSPasteboardItem *archivedItem = [[[NSPasteboardItem alloc] init] autorelease];
    CHECK([archivedItem setData:archive forType:@"org.osxer.probe.archive"] && [board writeObjects:@[archivedItem]]);
    NSArray *readers = [board readObjectsForClasses:@[[OSXERArchivePasteboardReader class]] options:nil];
    CHECK([readers count] == 1 && ((OSXERArchivePasteboardReader *)[readers objectAtIndex:0])->decoded);
    readers = [board readObjectsForClasses:@[[OSXERRawPasteboardReader class]] options:nil];
    CHECK([readers count] == 1 && [((OSXERRawPasteboardReader *)[readers objectAtIndex:0])->data isEqual:archive]);
    [board clearContents]; [board releaseGlobally];
    OSXERFileManager *fm = [[[OSXERFileManager alloc] init] autorelease];
    fm->trash = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"trash"]];
    NSURL *old = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"replace-original"]];
    NSURL *new = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"replace-new"]];
    NSError *error = nil; NSURL *result = nil;
    CHECK([@"original" writeToURL:old atomically:NO encoding:NSUTF8StringEncoding error:&error]);
    CHECK([@"new" writeToURL:new atomically:NO encoding:NSUTF8StringEncoding error:&error]);
    BOOL replaced = [fm replaceItemAtURL:old withItemAtURL:new backupItemName:@"backup"
        options:NSFileManagerItemReplacementUsingNewMetadataOnly | NSFileManagerItemReplacementWithoutDeletingBackupItem
        resultingItemURL:&result error:&error];
    if (!replaced) fprintf(stderr, "replaceItemAtURL: %s\n", [[error description] UTF8String]);
    CHECK(replaced);
    CHECK([result isEqual:old] && ![fm fileExistsAtPath:[new path]]);
    CHECK([[NSString stringWithContentsOfURL:old encoding:NSUTF8StringEncoding error:NULL] isEqual:@"new"]);
    CHECK([[NSString stringWithContentsOfFile:[directory stringByAppendingPathComponent:@"backup"] encoding:NSUTF8StringEncoding error:NULL] isEqual:@"original"]);
    error = nil; result = nil;
    CHECK(![fm replaceItemAtURL:old withItemAtURL:new backupItemName:nil options:0 resultingItemURL:&result error:&error] && error && !result);
    CHECK([[NSString stringWithContentsOfURL:old encoding:NSUTF8StringEncoding error:NULL] isEqual:@"new"]);
    CHECK([fm setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:[old path] error:NULL]);
    CHECK([@"metadata" writeToURL:new atomically:NO encoding:NSUTF8StringEncoding error:NULL]);
    error = nil;
    CHECK([fm replaceItemAtURL:old withItemAtURL:new backupItemName:nil options:0 resultingItemURL:&result error:&error]);
    CHECK([[[fm attributesOfItemAtPath:[old path] error:NULL] objectForKey:NSFilePosixPermissions] unsignedIntegerValue] == 0600);
    error = nil; CHECK([fm trashItemAtURL:old resultingItemURL:&result error:&error] && result && !error);
    CHECK(![fm fileExistsAtPath:[old path]] && [fm fileExistsAtPath:[result path]]);
    CHECK([@"another" writeToURL:old atomically:NO encoding:NSUTF8StringEncoding error:NULL]);
    NSURL *first = result;
    CHECK([fm trashItemAtURL:old resultingItemURL:&result error:&error] && ![result isEqual:first]);
    CHECK([fm fileExistsAtPath:[first path]]);
    error = nil; CHECK(![fm trashItemAtURL:[NSURL URLWithString:@"https://example.invalid/x"] resultingItemURL:NULL error:&error] && error);
    NSWindow *window = sheetWindow(); [window makeKeyAndOrderFront:nil];
    NSViewController *controller = [[[NSViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    [controller setView:[[[NSView alloc] initWithFrame:NSMakeRect(0,0,80,40)] autorelease]];
    NSPopover *popover = [[[NSPopover alloc] init] autorelease];
    [popover setContentViewController:controller]; [popover setBehavior:NSPopoverBehaviorTransient];
    CHECK(![popover isShown] && [popover behavior] == NSPopoverBehaviorTransient);
    [popover showRelativeToRect:NSMakeRect(5,5,10,10) ofView:[window contentView] preferredEdge:NSMaxYEdge];
    CHECK([popover isShown] && [[controller view] window] != window);
    [popover performClose:nil]; CHECK(![popover isShown]); [popover close];
    NSWindow *other = sheetWindow(); [other makeKeyAndOrderFront:nil];
    [popover setBehavior:NSPopoverBehaviorSemitransient];
    [popover showRelativeToRect:NSMakeRect(5,5,10,10) ofView:[window contentView] preferredEdge:NSMaxYEdge];
    clickForPopover([[controller view] window]); CHECK([popover isShown]);
    clickForPopover(other); CHECK([popover isShown]);
    clickForPopover(window); CHECK(![popover isShown]);
    [popover setBehavior:NSPopoverBehaviorTransient];
    [popover showRelativeToRect:NSMakeRect(5,5,10,10) ofView:[window contentView] preferredEdge:NSMaxYEdge];
    clickForPopover(other); CHECK(![popover isShown]);
    [popover setBehavior:NSPopoverBehaviorApplicationDefined];
    [popover showRelativeToRect:NSMakeRect(5,5,10,10) ofView:[window contentView] preferredEdge:NSMaxYEdge];
    clickForPopover(window); CHECK([popover isShown]);
    [popover close]; [other orderOut:nil]; [window orderOut:nil];
}

int main(int argc, char **argv) {
    CHECK(argc == 3);
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *directory = [NSString stringWithUTF8String:argv[1]];
    [NSApplication sharedApplication];
    runtimeState(); foundation(directory); sharedAppKit(directory); layoutAndAnimation(); otherMethods(directory); additionalMethods();
    viewTables([NSString stringWithUTF8String:argv[2]]); stackFrames(); sheetCompletions(); secureEntries(); sharedRoundTwo(directory);
    [pool drain]; puts("PASS appkit-gaps round2"); return 0;
}
