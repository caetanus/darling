/* OSXER APPS (WebArchive): no WebKit archive codec is available in the stub framework. */
#import <WebKit/WebArchive.h>
#include <darling/osxer-apps.h>
@implementation WebArchive
- (id)initWithMainResource:(WebResource *)resource subresources:(NSArray *)resources subframeArchives:(NSArray *)archives {
    if ((self = [super init])) {
        _mainResource = [(id)resource retain];
        _subresources = resources ? [resources copy] : [[NSArray alloc] init];
        _subframeArchives = archives ? [archives copy] : [[NSArray alloc] init];
    }
    return self;
}
- (id)initWithData:(NSData *)data {
    OSXER_APPS_STUB("WebArchive decoding unavailable");
    [self release];
    return nil;
}
- (NSData *)data {
    OSXER_APPS_STUB("WebArchive encoding unavailable");
    return nil;
}
- (WebResource *)mainResource { return _mainResource; }
- (NSArray *)subresources { return _subresources; }
- (NSArray *)subframeArchives { return _subframeArchives; }
- (id)copyWithZone:(NSZone *)zone { return [self retain]; }
- (void)dealloc {
    [(id)_mainResource release];
    [_subresources release];
    [_subframeArchives release];
    [super dealloc];
}
@end
