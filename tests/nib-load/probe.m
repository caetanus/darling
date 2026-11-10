// OSXER NIB (probe): original synthetic decoder tests and a path-based loader.
#import <AppKit/AppKit.h>
#import "NSNibArchiveUnarchiver.h"
#import "NSStoryboardPrivate.h"
#include <stdio.h>
#include <string.h>
// OSXER NIB (class regression)
#include <dlfcn.h>
#import <AppKit/NSLayoutGuide.h>
#import <AppKit/NSPanGestureRecognizer.h>
#import <AppKit/NSRuleEditor.h>
#import <AppKit/NSNibConnector.h>

static unsigned failures, cycleInitializations, decodedObjects;
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

@interface NibCycle : NSObject { @public id back; }
@end
@implementation NibCycle
- (id) initWithCoder: (NSCoder *) coder {
    cycleInitializations++;
    back = [coder decodeObjectForKey: @"self"];
    CHECK(back == self);
    CHECK([coder allowsKeyedCoding]);
    CHECK([[coder decodeObjectForKey: @"duplicate"] intValue] == 42);
    CHECK([coder decodeIntForKey: @"duplicate"] == 42);
    CHECK([coder decodeIntForKey: @"i8"] == -7);
    CHECK([coder decodeIntForKey: @"i16"] == -1234);
    CHECK([coder decodeInt32ForKey: @"i32"] == -1234567);
    CHECK([coder decodeInt64ForKey: @"i64"] == -(1LL << 40));
    CHECK([coder decodeIntegerForKey: @"i16"] == -1234);
    CHECK(![coder decodeBoolForKey: @"false"] && [coder decodeBoolForKey: @"true"]);
    CHECK([coder decodeFloatForKey: @"float"] == 1.25f && [coder decodeDoubleForKey: @"double"] == 2.5);
    CHECK([coder containsValueForKey: @"nil"] && ![coder containsValueForKey: @"missing"]);
    CHECK([coder decodeObjectForKey: @"nil"] == nil && [coder decodeIntForKey: @"missing"] == 0);
    NSUInteger length = 999;
    const uint8_t *bytes = [coder decodeBytesForKey: @"bytes" returnedLength: &length];
    CHECK(length == 3 && bytes && !memcmp(bytes, "A\0B", 3));
    CHECK(NSEqualPoints([coder decodePointForKey: @"point"], NSMakePoint(3, 4)));
    CHECK(NSEqualSizes([coder decodeSizeForKey: @"size"], NSMakeSize(5, 6)));
    CHECK(NSEqualRects([coder decodeRectForKey: @"rect"], NSMakeRect(1, 2, 3, 4)));
    return self;
}
@end
@interface NibFallback : NSObject
@end
@implementation NibFallback
- (id) initWithCoder: (NSCoder *) coder { return [self init]; }
@end
@interface NibSwap : NSObject
@end
@implementation NibSwap
- (id) initWithCoder: (NSCoder *) coder {
    id replacement = [NibFallback new];
    [(NSNibArchiveUnarchiver *)coder replaceObject: self withObject: replacement];
    CHECK([coder decodeObjectForKey: @"self"] == replacement);
    [self release];
    return replacement;
}
@end
@interface NibDelegate : NSObject
@end
@implementation NibDelegate
- (id) unarchiver: (id) coder didDecodeObject: (id) object { decodedObjects++; return object; }
@end
@interface NibOwner : NSObject { id _sceneController; }
@property(retain) id sceneController;
@end
@implementation NibOwner
@synthesize sceneController = _sceneController;
- (void) dealloc { [_sceneController release]; [super dealloc]; }
@end

static void printObjects(NSArray *objects) {
    for (id object in objects) {
        printf("class=%s", [NSStringFromClass([object class]) UTF8String]);
        NSWindow *window = nil;
        if ([object isKindOfClass: [NSWindow class]]) window = object;
        if ([object isKindOfClass: [NSWindowController class]]) window = [object window];
        if (window) printf(" title=%s", [[window title] UTF8String] ?: "");
        if ([object isKindOfClass: [NSViewController class]]) {
            id view = [object view];
            printf(" view=%s", view ? [NSStringFromClass([view class]) UTF8String] : "nil");
        }
        putchar('\n');
    }
}

// OSXER NIB (class regression): load each graph independently so a failed class
// cannot hide the next one. Execute only through nib-load/run.sh in Darling.
static id classFixture(NSString *directory, NSString *name) {
    NSString *path = [[directory stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"nib"];
    NSNibArchiveUnarchiver *coder = [[NSNibArchiveUnarchiver alloc] initForReadingWithData:[NSData dataWithContentsOfFile:path]];
    id object = [[coder decodeObjectForKey:@"root"] retain];
    if (!object || [coder failed]) {
        fprintf(stderr, "FAIL class fixture %s\n", [name UTF8String]); failures++;
    }
    [coder release];
    return [object autorelease];
}

static void classTests(NSString *directory) {
    void *web = dlopen("/System/Library/Frameworks/WebKit.framework/WebKit", RTLD_LAZY | RTLD_GLOBAL);
    void *ci = dlopen("/System/Library/Frameworks/CoreImage.framework/CoreImage", RTLD_LAZY | RTLD_GLOBAL);
    CHECK(web != NULL && ci != NULL);
    NSArray *classes = [NSArray arrayWithContentsOfFile:[directory stringByAppendingPathComponent:@"classes.plist"]];
    CHECK([classes count] >= 29);
    for (NSString *name in classes) {
        @try {
            id object = classFixture(directory, name);
            CHECK([object isKindOfClass:NSClassFromString(name)]);
            if ([name isEqual:@"NSTreeController"]) {
                NSTreeController *tree = object;
                CHECK([[tree childrenKeyPath] isEqual:@"children"]);
                CHECK([tree preservesSelection] && ![tree selectsInsertedObjects] && [tree isEditable]);
            } else if ([name isEqual:@"NSAttributedString"]) {
                CHECK([[object string] isEqual:@"synthetic"]);
                CHECK([[[object attributesAtIndex:0 effectiveRange:NULL] objectForKey:@"TestAttribute"] isEqual:@"value"]);
            } else if ([name isEqual:@"NSLocale"]) {
                CHECK([[object localeIdentifier] isEqual:@"en_US_POSIX"]);
            } else if ([name isEqual:@"NSSortDescriptor"]) {
                CHECK([[object key] isEqual:@"name"] && [object ascending]);
                CHECK([object selector] == @selector(compare:));
            } else if ([name isEqual:@"NSDecimalNumberHandler"]) {
                CHECK([object scale] == 3 && [object roundingMode] == NSRoundUp);
            } else if ([name isEqual:@"NSDateFormatter"]) {
                CHECK([[object dateFormat] isEqual:@"yyyy-MM-dd"]);
            } else if ([name isEqual:@"NSNumberFormatter"]) {
                CHECK(![object allowsFloats] && [[object minimum] intValue] == 2 && [[object maximum] intValue] == 8);
                CHECK([[object numberFromString:@"5"] intValue] == 5);
                CHECK([object numberFromString:@"1"] == nil && [object numberFromString:@"9"] == nil);
            } else if ([name isEqual:@"NSColorSpace"]) {
                CHECK(CGColorSpaceGetNumberOfComponents([object CGColorSpace]) == 3);
            } else if ([name isEqual:@"NSTextTab"]) {
                CHECK([object location] == 42 && [object tabStopType] == NSRightTabStopType);
            } else if ([name isEqual:@"NSFontDescriptor"]) {
                CHECK([[object objectForKey:NSFontNameAttribute] isEqual:@"Helvetica"]);
            } else if ([name isEqual:@"NSPanGestureRecognizer"]) {
                NSPanGestureRecognizer *pan = object;
                CHECK([pan buttonMask] == 2 && [pan numberOfTouchesRequired] == 2);
                CHECK([pan action] == @selector(perform:) && [pan allowedTouchTypes] == 3);
            } else if ([name isEqual:@"NSPredicateEditor"]) {
                NSRuleEditor *editor = object;
                CHECK([editor rowHeight] == 29 && [editor nestingMode] == 2 && [editor isEditable]);
            } else if ([name isEqual:@"NSComparisonPredicate"]) {
                CHECK([object evaluateWithObject:@"same"]);
            } else if ([name isEqual:@"NSNibAuxiliaryActionConnector"]) {
                [object establishConnection];
                NSTableView *source = [object source];
                CHECK([source doubleAction] == @selector(perform:));
            } else if ([name isEqual:@"NSSwitch"]) {
                CHECK([(NSCell *)[object cell] state] == 1 && ![object isEnabled]);
            } else if ([name isEqual:@"WebView"]) {
                CHECK([object isKindOfClass:[NSView class]]);
                CHECK(NSEqualSizes([object frame].size, NSMakeSize(160, 80)));
            }
        } @catch (NSException *exception) {
            fprintf(stderr, "FAIL class %s: %s\n", [name UTF8String], [[exception reason] UTF8String]); failures++;
        }
    }
    // OSXER NIB (attributed string round trip): distinct runs must survive.
    NSMutableAttributedString *rich = [[[NSMutableAttributedString alloc] initWithString:@"abcd"] autorelease];
    [rich setAttributes:@{@"TestAttribute":@"left"} range:NSMakeRange(0,2)];
    [rich setAttributes:@{@"TestAttribute":@"right"} range:NSMakeRange(2,2)];
    NSAttributedString *roundTrip = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:rich]];
    CHECK([[roundTrip string] isEqual:@"abcd"]);
    CHECK([[[roundTrip attributesAtIndex:0 effectiveRange:NULL] objectForKey:@"TestAttribute"] isEqual:@"left"]);
    CHECK([[[roundTrip attributesAtIndex:3 effectiveRange:NULL] objectForKey:@"TestAttribute"] isEqual:@"right"]);
    NSView *view = classFixture(directory, @"view-state");
    CHECK(NSEqualSizes([view frame].size, NSMakeSize(160, 80)));
    CHECK(![view translatesAutoresizingMaskIntoConstraints] && [[view identifier] isEqual:@"owned-view"]);
    CHECK([view contentHuggingPriorityForOrientation:NSLayoutConstraintOrientationHorizontal] == 251);
    CHECK([view contentCompressionResistancePriorityForOrientation:NSLayoutConstraintOrientationVertical] == 752);
    CHECK([[view layoutGuides] count] == 1 && [[view constraints] count] == 1);
    NSLayoutGuide *guide = [[[view layoutGuides] firstObject] retain];
    CHECK([guide owningView] == view && NSEqualRects([guide frame], [view bounds]));
    NSLayoutConstraint *constraint = [[view constraints] firstObject];
    CHECK([constraint firstItem] == guide && [constraint constant] == 80);
    [constraint setActive:NO]; [constraint setActive:YES];
    CHECK([[view constraints] count] == 1);
    NSView *child = [[view subviews] firstObject];
    CHECK([child isHidden] && [child superview] == view);
    [child removeFromSuperview]; // Default willRemoveSubview must not raise.
    CHECK([[view subviews] count] == 0);
    [view removeConstraint:constraint]; [view removeLayoutGuide:guide];
    CHECK([guide owningView] == nil); [guide release];
    NSView *custom = classFixture(directory, @"custom-view-cycle");
    CHECK([custom isMemberOfClass:[NSView class]] && [[custom subviews] count] == 1);
    CHECK([[[custom subviews] firstObject] superview] == custom);
    CHECK(![custom translatesAutoresizingMaskIntoConstraints] && [[custom identifier] isEqual:@"replacement"]);
    NSStackView *stack = classFixture(directory, @"stack-state");
    CHECK([[stack arrangedSubviews] count] == 1 && [stack spacing] == 13);
    CHECK([stack orientation] == NSUserInterfaceLayoutOrientationVertical && [stack distribution] == NSStackViewDistributionFillEqually);
    NSEdgeInsets insets = [stack edgeInsets];
    CHECK(insets.top == 3 && insets.left == 4 && insets.bottom == 5 && insets.right == 6);
    [stack layoutSubtreeIfNeeded];
    CHECK(NSEqualRects([[[stack arrangedSubviews] firstObject] frame], NSMakeRect(4, 5, 20, 72)));
    NSButton *control = classFixture(directory, @"control-state");
    CHECK(![control isEnabled] && [[control cell] controlSize] == NSSmallControlSize && [control alignment] == NSCenterTextAlignment);
    NSMenuItem *menu = classFixture(directory, @"menu-state");
    CHECK(![menu isEnabled] && [menu isHidden] && [menu isAlternate] && [menu state] == 1 && [menu indentationLevel] == 2);
    NSTableView *table = classFixture(directory, @"table-state");
    CHECK([table rowHeight] == 23 && NSEqualSizes([table intercellSpacing], NSMakeSize(5, 6)) && [table style] == 3);
    NSOutlineView *outline = classFixture(directory, @"outline-empty");
    CHECK([[outline tableColumns] count] == 0 && [outline indentationPerLevel] == 17);
    NSTableView *hiddenTable = classFixture(directory, @"table-hidden");
    NSTableColumn *hiddenColumn = [[hiddenTable tableColumns] firstObject];
    CHECK([hiddenColumn isHidden] && [hiddenColumn width] == 70);
    CHECK(NSEqualRects([hiddenTable rectOfColumn:0], NSZeroRect));
    CHECK([hiddenTable rectOfColumn:1].origin.x == 0 && [hiddenTable rectOfColumn:1].size.width == 93);
    CHECK([hiddenTable columnAtPoint:NSMakePoint(4,0)] == 1);
    CHECK([(NSTableHeaderView *)[hiddenTable headerView] headerRectOfColumn:1].origin.x == 0);
    [hiddenColumn setHidden:NO];
    CHECK([hiddenTable rectOfColumn:1].origin.x == 73 && [hiddenColumn width] == 70);
    CHECK(NSEqualRects([hiddenTable frameOfCellAtColumn:2 row:0], NSZeroRect));
    NSPathControl *path = classFixture(directory, @"path-state");
    NSObject *delegate = [NSObject new];
    [path setDelegate:(id)delegate]; CHECK([path delegate] == (id)delegate); [path setDelegate:nil]; [delegate release];
    [classFixture(directory, @"aux-empty") establishConnection];
    NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0,0,80,60) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:YES];
    CHECK([panel preventsApplicationTerminationWhenModal]);
    [panel setPreventsApplicationTerminationWhenModal:NO]; CHECK(![panel preventsApplicationTerminationWhenModal]);
    [panel release];
    // Handles stay loaded until the autorelease pool releases the decoded objects.
}

static void selfTest(NSString *directory) {
    classTests(directory);
    for (NSString *file in @[@"values.nib", @"coder9.nib"]) {
        NSNibArchiveUnarchiver *coder = [[NSNibArchiveUnarchiver alloc] initForReadingWithData:
                [NSData dataWithContentsOfFile: [directory stringByAppendingPathComponent: file]]];
        CHECK(coder != nil);
        NibDelegate *delegate = [NibDelegate new]; [coder setDelegate: delegate];
        unsigned before = cycleInitializations;
        NibCycle *cycle = [coder decodeObjectForKey: @"root"];
        CHECK(cycle && cycle->back == cycle);
        CHECK([coder decodeObjectForKey: @"again"] == cycle && cycleInitializations == before + 1);
        NSArray *array = [coder decodeObjectForKey: @"array"];
        CHECK([array count] == 3 && [array objectAtIndex: 1] == cycle && [array objectAtIndex: 0] == [array objectAtIndex: 2]);
        NSDictionary *dict = [coder decodeObjectForKey: @"dict"];
        CHECK([[dict objectForKey: @"Olá"] longLongValue] == (1LL << 40));
        CHECK(![dict isKindOfClass: [NSMutableDictionary class]]);
        CHECK([[coder decodeObjectForKey: @"set"] count] == 2);
        CHECK([[coder decodeObjectForKey: @"string"] isEqual: @"Olá"]);
        CHECK([[coder decodeObjectForKey: @"number"] longLongValue] == (1LL << 40));
        NSData *data = [coder decodeObjectForKey: @"data"];
        CHECK([data length] == 7 && !memcmp([data bytes], "ABC\0DEF", 7));
        CHECK(NSEqualSizes([[coder decodeObjectForKey: @"value"] sizeValue], NSMakeSize(5, 6)));
        CHECK([[coder decodeObjectForKey: @"swap"] isKindOfClass: [NibFallback class]]);
        CHECK([[coder decodeObjectForKey: @"fallback"] isKindOfClass: [NibFallback class]]);
        CHECK(![coder failed] && decodedObjects > 0);
        id replacement = [NibFallback new];
        [coder replaceObject: cycle withObject: replacement];
        CHECK([coder decodeObjectForKey: @"again"] == replacement);
        [replacement release]; [coder release]; [delegate release];
    }
    for (NSString *name in @[@"truncated-header", @"truncated-data", @"bad-version", @"bad-offset",
            @"bad-reference", @"odd-dictionary", @"unknown-class", @"bad-varint", @"unknown-type", @"invalid-utf8"]) {
        NSString *path = [[directory stringByAppendingPathComponent: name] stringByAppendingPathExtension: @"nib"];
        NSNibArchiveUnarchiver *coder = [[NSNibArchiveUnarchiver alloc] initForReadingWithData: [NSData dataWithContentsOfFile: path]];
        CHECK(!coder || ([coder decodeObjectForKey: @"root"] == nil && [coder failed]));
        [coder release];
    }
    NSNibArchiveUnarchiver *mapped = [[NSNibArchiveUnarchiver alloc] initForReadingWithData:
            [NSData dataWithContentsOfFile: [directory stringByAppendingPathComponent: @"unknown-class.nib"]]];
    [mapped setClass: [NibFallback class] forClassName: @"MissingNibClass"];
    CHECK([[mapped decodeObjectForKey: @"root"] isKindOfClass: [NibFallback class]]);
    [mapped release];
    // Existing binary-plist decoding still follows Foundation's keyed path.
    NSData *plist = [NSKeyedArchiver archivedDataWithRootObject: @[@"legacy", @42]];
    CHECK(![NSNibArchiveUnarchiver isNibArchiveData: plist]);
    CHECK([[NSKeyedUnarchiver unarchiveObjectWithData: plist] isEqual: (@[@"legacy", @42])]);
    NSNib *legacy = [[NSNib alloc] initWithContentsOfURL:
            [NSURL fileURLWithPath: [directory stringByAppendingPathComponent: @"Legacy.nib"]]];
    NSArray *legacyTop = nil;
    CHECK([legacy instantiateWithOwner: NSApp topLevelObjects: &legacyTop]);
    CHECK([legacyTop containsObject: @"legacy-top"]);
    [legacy release];
    NSString *path = [directory stringByAppendingPathComponent: @"Synthetic.storyboardc"];
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName: path bundle: nil];
    CHECK(storyboard && [storyboard _loadMainMenu]);
    NSViewController *first = [storyboard instantiateInitialController];
    NSViewController *second = [storyboard instantiateControllerWithIdentifier: @"Scene"];
    CHECK(first && second && first != second);
    CHECK([first storyboard] == storyboard && [first view] != nil);
    CHECK([storyboard instantiateControllerWithIdentifier: @"absent"] == nil);
    NSWindowController *windowController = [storyboard instantiateControllerWithIdentifier: @"Window"];
    CHECK(windowController && [[[windowController window] title] isEqual: @"Synthetic Window"]);
    CHECK([[windowController contentViewController] view] == [[windowController window] contentView]);
    for (NSString *name in @[@"flat.nib", @"Variant.nib"]) {
        NSNib *nib = [[NSNib alloc] initWithContentsOfURL:
                [NSURL fileURLWithPath: [directory stringByAppendingPathComponent: name]]];
        NibOwner *owner = [NibOwner new];
        NSMutableArray *top = [NSMutableArray array];
        CHECK(([nib instantiateNibWithExternalNameTable: @{NSNibOwner: owner, NSNibTopLevelObjects: top,
                @"NSStoryboardPlaceholder": storyboard}]));
        CHECK([owner sceneController] != nil);
        [top makeObjectsPerformSelector: @selector(release)];
        [owner release]; [nib release];
    }
    printf("nib-load: %u failures\n", failures);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc < 2) { fprintf(stderr, "usage: run.sh path.nib|path.storyboardc [identifier] OR --self-test\n"); return 2; }
        [NSApplication sharedApplication];
        @try {
            if (!strcmp(argv[1], "--self-test") && argc == 3) {
                selfTest([NSString stringWithUTF8String: argv[2]]);
                return failures ? 1 : 0;
            }
            NSString *path = [[NSString stringWithUTF8String: argv[1]] stringByStandardizingPath];
            if (![[path pathExtension] isEqual: @"storyboardc"]) {
                NSNib *nib = [[NSNib alloc] initWithContentsOfURL: [NSURL fileURLWithPath: path]];
                NSArray *objects = nil;
                if (![nib instantiateWithOwner: NSApp topLevelObjects: &objects]) { [nib release]; return 1; }
                printObjects(objects); [nib release];
            } else {
                NSStoryboard *storyboard = [NSStoryboard storyboardWithName: path bundle: nil];
                if (!storyboard || ![storyboard _loadMainMenu]) return 1;
                id controller = argc > 2 ? [storyboard instantiateControllerWithIdentifier:
                        [NSString stringWithUTF8String: argv[2]]] : [storyboard instantiateInitialController];
                if (controller) printObjects(@[controller]);
                else if ([NSApp mainMenu] && argc == 2) printObjects(@[[NSApp mainMenu]]);
                else return 1;
            }
        } @catch (NSException *e) {
            fprintf(stderr, "load failed: %s\n", [[e reason] UTF8String]); return 1;
        }
    }
    return 0;
}
