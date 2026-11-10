/* OSXER APPS (WebArchive): in-memory archive container; byte decoding unsupported. */
#import <Foundation/Foundation.h>
@class WebResource;
@interface WebArchive : NSObject <NSCopying> {
    WebResource *_mainResource;
    NSArray *_subresources;
    NSArray *_subframeArchives;
}
- (id)initWithMainResource:(WebResource *)resource subresources:(NSArray *)resources subframeArchives:(NSArray *)archives;
- (id)initWithData:(NSData *)data;
- (WebResource *)mainResource;
- (NSArray *)subresources;
- (NSArray *)subframeArchives;
- (NSData *)data;
@end
