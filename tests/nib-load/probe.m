// OSXER NIB (probe): original synthetic decoder tests and a path-based loader.
#import <AppKit/AppKit.h>
#import "NSNibArchiveUnarchiver.h"
#import "NSStoryboardPrivate.h"
#include <stdio.h>
#include <string.h>

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

static void selfTest(NSString *directory) {
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
