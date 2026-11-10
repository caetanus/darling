// OSXER APPS (regression): public contracts, run only through run.sh in Darling.
// Sources: Apple CFFileDescriptor, File Manager, NSBackgroundActivityScheduler,
// CGContext transparency, and Apple Event Manager API references (see report).
#import <AppKit/AppKit.h>
#import <Foundation/NSBackgroundActivityScheduler.h>
#import <CoreFoundation/CFFileDescriptor.h>
#import <CoreServices/CoreServices.h>
#import <Carbon/Carbon.h>
#import <ImageIO/CGImageProperties.h>
#import <QuartzCore/CAEmitterLayer.h>
#import <WebKit/WebArchive.h>
#include <AudioToolbox/AudioServices.h>
#include <DiskArbitration/DiskArbitration.h>
#include <dispatch/dispatch.h>
#include <fcntl.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL app-gaps:%d: %s\n", __LINE__, #c); exit(1); } } while (0)

struct Watch { int balance, calls; CFOptionFlags bits; pthread_t thread; };
static void *retainWatch(void *info) { ((struct Watch *)info)->balance++; return info; }
static void releaseWatch(void *info) { ((struct Watch *)info)->balance--; }
static void ready(CFFileDescriptorRef fd, CFOptionFlags flags, void *info) {
    struct Watch *watch = info;
    CHECK(pthread_equal(watch->thread, pthread_self()));
    watch->calls++;
    watch->bits |= flags;
    if (flags & kCFFileDescriptorReadCallBack) {
        char byte;
        CHECK(read(CFFileDescriptorGetNativeDescriptor(fd), &byte, 1) == 1);
    }
}
static void pumpUntil(struct Watch *watch, int calls) {
    CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + 2;
    while (watch->calls < calls && CFAbsoluteTimeGetCurrent() < deadline)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, true);
    CHECK(watch->calls == calls);
}
static void descriptors(void) {
    int pipeFD[2]; CHECK(pipe(pipeFD) == 0);
    struct Watch watch = {.thread = pthread_self()};
    CFFileDescriptorContext context = {0, &watch, retainWatch, releaseWatch, NULL};
    CHECK(!CFFileDescriptorCreate(NULL, -1, false, ready, &context));
    context.version = 1;
    CHECK(!CFFileDescriptorCreate(NULL, pipeFD[0], false, ready, &context));
    context.version = 0;
    CFFileDescriptorRef fd = CFFileDescriptorCreate(NULL, pipeFD[0], true, ready, &context);
    CHECK(fd && CFFileDescriptorGetNativeDescriptor(fd) == pipeFD[0]);
    CHECK(CFGetTypeID(fd) == CFFileDescriptorGetTypeID() && watch.balance == 1);
    CFFileDescriptorEnableCallBacks(fd, kCFFileDescriptorReadCallBack);
    CHECK(write(pipeFD[1], "ab", 2) == 2);
    CFRunLoopSourceRef source = CFFileDescriptorCreateRunLoopSource(NULL, fd, 0);
    CHECK(source);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    pumpUntil(&watch, 1);
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
    CHECK(watch.calls == 1); // one-shot even though another byte remains
    CFFileDescriptorEnableCallBacks(fd, kCFFileDescriptorReadCallBack);
    pumpUntil(&watch, 2);
    CFFileDescriptorDisableCallBacks(fd, kCFFileDescriptorReadCallBack);
    CHECK(write(pipeFD[1], "c", 1) == 1);
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
    CHECK(watch.calls == 2);
    CFFileDescriptorInvalidate(fd);
    CFFileDescriptorInvalidate(fd); // idempotent
    CHECK(!CFFileDescriptorIsValid(fd) && !CFRunLoopSourceIsValid(source));
    CHECK(CFFileDescriptorGetNativeDescriptor(fd) == -1 && !CFFileDescriptorCreateRunLoopSource(NULL, fd, 0));
    CHECK(fcntl(pipeFD[0], F_GETFD) == -1 && errno == EBADF);
    CHECK(watch.balance == 0);
    CFRelease(source); CFRelease(fd); close(pipeFD[1]);

    int sockets[2]; CHECK(socketpair(AF_UNIX, SOCK_STREAM, 0, sockets) == 0);
    watch.calls = 0; watch.bits = 0;
    fd = CFFileDescriptorCreate(NULL, sockets[0], false, ready, &context);
    source = CFFileDescriptorCreateRunLoopSource(NULL, fd, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    CFFileDescriptorEnableCallBacks(fd, kCFFileDescriptorWriteCallBack);
    pumpUntil(&watch, 1);
    CHECK(watch.bits == kCFFileDescriptorWriteCallBack);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    CFRelease(fd); // source owns the last descriptor reference
    CFRelease(source); // no source/descriptor retain cycle
    CHECK(watch.balance == 0 && fcntl(sockets[0], F_GETFD) != -1);
    close(sockets[0]); close(sockets[1]);

    CHECK(pipe(pipeFD) == 0);
    fd = CFFileDescriptorCreate(NULL, pipeFD[0], true, ready, &context);
    CFRelease(fd); // no source was ever created
    CHECK(fcntl(pipeFD[0], F_GETFD) == -1 && errno == EBADF);
    CHECK(watch.balance == 0); close(pipeFD[1]);
}
static void files(NSString *directory) {
    NSString *sourcePath = [directory stringByAppendingPathComponent:@"café.txt"];
    NSString *destPath = [directory stringByAppendingPathComponent:@"copies"];
    CHECK(mkdir([destPath fileSystemRepresentation], 0700) == 0);
    CHECK([[@"payload" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:sourcePath atomically:NO]);
    FSRef source, dest, copied, parent;
    CHECK(FSPathMakeRef((const UInt8 *)[sourcePath fileSystemRepresentation], &source, NULL) == noErr);
    CHECK(FSPathMakeRef((const UInt8 *)[destPath fileSystemRepresentation], &dest, NULL) == noErr);
    FSCatalogInfo info; HFSUniStr255 name;
    CHECK(FSGetCatalogInfo(&source, kFSCatInfoDataSizes | kFSCatInfoNodeFlags | kFSCatInfoPermissions,
                           &info, &name, NULL, &parent) == noErr);
    CHECK(info.dataLogicalSize == 7 && !(info.nodeFlags & 4));
    CHECK([[[[NSString alloc] initWithCharacters:name.unicode length:name.length] autorelease] isEqual:@"café.txt"]);
    CHECK(FSGetCatalogInfo(NULL, 0, NULL, NULL, NULL, NULL) == paramErr);
    CHECK(FSGetCatalogInfo(&source, kFSCatInfoDataSizes, NULL, NULL, NULL, NULL) == paramErr);
    CHECK(FSCopyObjectSync(&source, &dest, CFSTR("copied.txt"), &copied, 0) == noErr);
    CHECK([[NSData dataWithContentsOfFile:[destPath stringByAppendingPathComponent:@"copied.txt"]]
        isEqual:[@"payload" dataUsingEncoding:NSUTF8StringEncoding]]);
    CHECK(FSCopyObjectSync(&source, &dest, CFSTR("copied.txt"), NULL, 0) != noErr);
    CHECK(FSCopyObjectSync(&source, &dest, CFSTR("../escape"), NULL, 0) == bdNamErr);
    CHECK(FSCopyObjectSync(NULL, &dest, NULL, NULL, 0) == paramErr);
    CHECK(FSCopyObjectSync(&source, &dest, NULL, NULL, 0x80000000) == unimpErr);
    FSRef top;
    CHECK(FSPathMakeRef((const UInt8 *)[directory fileSystemRepresentation], &top, NULL) == noErr);
    CHECK(FSCopyObjectSync(&top, &dest, CFSTR("recursive"), NULL, 0) == paramErr);
    CFArrayRef handlers = LSCopyApplicationURLsForURL((CFURLRef)[NSURL URLWithString:@"osxer-no-handler-test://item"], kLSRolesAll);
    CHECK(handlers && CFArrayGetCount(handlers) == 0); CFRelease(handlers);
    CHECK(!LSCopyApplicationURLsForURL(NULL, kLSRolesAll));
}
static void diskCallback(DADiskRef disk, void *context) { CHECK(0); }
static void stubs(void) {
    AEDesc desc = {123, (void *)1}; AEInitializeDesc(&desc);
    CHECK(desc.descriptorType == 'null' && !desc.dataHandle);
    CHECK(AECoercePtr('TEXT', "x", 1, 'long', &desc) == errAECoercionFail);
    CHECK(desc.descriptorType == 'null' && !desc.dataHandle);
    AppleEvent event = {'null', NULL}, reply;
    CHECK(AESendMessage(&event, &reply, 0, 0) == errAEEventNotHandled);
    CHECK(reply.descriptorType == 'null' && !reply.dataHandle);
    CHECK(AEBuildAppleEvent('aevt', 'odoc', 'null', NULL, 0, 0, 0, &reply, NULL, "") == errAEEventNotHandled);
    CFArrayRef keys = NULL;
    CHECK(CopySymbolicHotKeys(&keys) == noErr && CFArrayGetCount(keys) == 0); CFRelease(keys);
    PopSymbolicHotKeyMode(PushSymbolicHotKeyMode(0));
    __block int completed = 0;
    AudioServicesPlayAlertSound(0);
    AudioServicesPlayAlertSoundWithCompletion(0, ^{ ++completed; });
    CHECK(completed == 1);
    AudioServicesPlayAlertSoundWithCompletion(0, NULL);
    DASessionRef session = DASessionCreate(NULL);
    CHECK(session);
    DARegisterDiskAppearedCallback(session, NULL, diskCallback, NULL);
    DARegisterDiskDisappearedCallback(session, NULL, diskCallback, NULL);
    DAUnregisterCallback(session, diskCallback, NULL);
    CFRelease(session);
    WebArchive *archive = [[WebArchive alloc] initWithMainResource:nil subresources:@[] subframeArchives:@[]];
    CHECK(archive && !archive.mainResource && archive.subresources.count == 0);
    CHECK(![archive data]); [archive release];
    CHECK(![[WebArchive alloc] initWithData:[NSData data]]);
}
static void activity(void) {
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    NSBackgroundActivityScheduler *scheduler = [[NSBackgroundActivityScheduler alloc] initWithIdentifier:@"org.darling.tests.app-gaps"];
    scheduler.interval = 1e100;
    [scheduler scheduleWithBlock:^(NSBackgroundActivityCompletionHandler completion) { CHECK(0); }];
    [scheduler invalidate];
    scheduler.interval = 0.02; scheduler.tolerance = 0;
    __block int calls = 0;
    [scheduler scheduleWithBlock:^(NSBackgroundActivityCompletionHandler completion) {
        CHECK(![NSThread isMainThread]);
        if (++calls == 1) { completion(NSBackgroundActivityResultDeferred); return; }
        completion(NSBackgroundActivityResultFinished);
        completion(NSBackgroundActivityResultDeferred); // duplicate completion must not rearm
        dispatch_semaphore_signal(done);
    }];
    CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0);
    usleep(100000); CHECK(calls == 2);
    scheduler.repeats = YES;
    [scheduler scheduleWithBlock:^(NSBackgroundActivityCompletionHandler completion) {
        if (++calls >= 4) { [scheduler invalidate]; dispatch_semaphore_signal(done); }
        completion(NSBackgroundActivityResultFinished);
    }];
    CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0);
    CHECK(scheduler.shouldDefer); [scheduler release]; dispatch_release(done);
}
static void drawing(void) {
    unsigned char pixels[8 * 8 * 4] = {};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, 8, 8, 8, 8 * 4, space, kCGImageAlphaPremultipliedLast);
    CHECK(context);
    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextBeginTransparencyLayerWithRect(context, CGRectMake(0, 0, 4, 4), NULL);
    CGContextFillRect(context, CGRectMake(0, 0, 8, 8));
    CGContextEndTransparencyLayer(context);
    CGContextFlush(context);
    unsigned int alpha = 0;
    for (int i = 0; i < 64; ++i) alpha += pixels[i * 4 + 3];
    CHECK(alpha == 16 * 255);
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:context flipped:NO]];
    NSRect rects[] = {NSMakeRect(0, 0, 8, 8), NSMakeRect(0, 0, 4, 4)};
    NSColor *colors[] = {[NSColor greenColor], [NSColor blueColor]};
    NSRectFillListWithColorsUsingOperation(rects, colors, 2, NSCompositeCopy);
    CGContextFlush(context);
    alpha = 0;
    for (int i = 0; i < 64; ++i) alpha += pixels[i * 4 + 3];
    CHECK(alpha == 64 * 255); // layer clip was restored
    [NSGraphicsContext setCurrentContext:nil];
    CGContextRelease(context); CGColorSpaceRelease(space);
}
int main(int argc, char **argv) {
    CHECK(argc == 2);
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    CHECK([NSMultipleUnderlyingErrorsKey isEqual:@"NSMultipleUnderlyingErrors"]);
    CHECK([NSMaxValueBinding isEqual:@"maxValue"]);
    CHECK([NSFontDescriptorSystemDesignRounded isEqual:@"NSCTFontDesignRounded"]);
    CHECK([NSProcessInfoPowerStateDidChangeNotification isEqual:@"NSProcessInfoPowerStateDidChangeNotification"]);
    CHECK([NSWorkspaceDidRenameVolumeNotification isEqual:@"NSWorkspaceDidRenameVolumeNotification"]);
    CHECK([(NSString *)kCGImagePropertyDepth isEqual:@"Depth"] && [kCAEmitterLayerLine isEqual:@"line"]);
    descriptors(); files([NSString stringWithUTF8String:argv[1]]); stubs(); activity(); drawing();
    [pool drain]; puts("PASS app-gaps"); return 0;
}
