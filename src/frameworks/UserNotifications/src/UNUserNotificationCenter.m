/*
 This file is part of Darling.

 Copyright (C) 2021 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <UserNotifications/UNUserNotificationCenter.h>

#import <UserNotifications/UNNotificationSettings.h>
#include <dispatch/dispatch.h>

NSString * const UNErrorDomain = @"UNErrorDomain";

static NSError *UNNotAllowed(void)
{
    return [NSError errorWithDomain:UNErrorDomain code:UNErrorCodeNotificationsNotAllowed
        userInfo:@{NSLocalizedDescriptionKey: @"Notifications are not allowed (Darling has no notification service)"}];
}

static void UNCallLater(dispatch_block_t block)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}

@implementation UNUserNotificationCenter
@synthesize delegate = _delegate;

+ (UNUserNotificationCenter *)currentNotificationCenter
{
    static UNUserNotificationCenter *center;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ center = [[UNUserNotificationCenter alloc] init]; });
    return center;
}

- (BOOL)supportsContentExtensions { return NO; }

- (void)requestAuthorizationWithOptions:(UNAuthorizationOptions)options
                      completionHandler:(void (^)(BOOL, NSError *))completionHandler
{
    if (!completionHandler) return;
    completionHandler = [[completionHandler copy] autorelease];
    UNCallLater(^{ completionHandler(NO, UNNotAllowed()); });
}

- (void)getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings *))completionHandler
{
    if (!completionHandler) return;
    completionHandler = [[completionHandler copy] autorelease];
    UNCallLater(^{ completionHandler([[[UNNotificationSettings alloc] init] autorelease]); });
}

- (void)setNotificationCategories:(NSSet *)categories {}

- (void)getNotificationCategoriesWithCompletionHandler:(void (^)(NSSet *))completionHandler
{
    if (!completionHandler) return;
    completionHandler = [[completionHandler copy] autorelease];
    UNCallLater(^{ completionHandler([NSSet set]); });
}

- (void)addNotificationRequest:(UNNotificationRequest *)request
         withCompletionHandler:(void (^)(NSError *))completionHandler
{
    if (!completionHandler) return;
    completionHandler = [[completionHandler copy] autorelease];
    UNCallLater(^{ completionHandler(UNNotAllowed()); });
}

- (void)getPendingNotificationRequestsWithCompletionHandler:(void (^)(NSArray *))completionHandler
{
    if (!completionHandler) return;
    completionHandler = [[completionHandler copy] autorelease];
    UNCallLater(^{ completionHandler(@[]); });
}

- (void)getDeliveredNotificationsWithCompletionHandler:(void (^)(NSArray *))completionHandler
{
    if (!completionHandler) return;
    completionHandler = [[completionHandler copy] autorelease];
    UNCallLater(^{ completionHandler(@[]); });
}

- (void)removePendingNotificationRequestsWithIdentifiers:(NSArray *)identifiers {}
- (void)removeAllPendingNotificationRequests {}
- (void)removeDeliveredNotificationsWithIdentifiers:(NSArray *)identifiers {}
- (void)removeAllDeliveredNotifications {}

// Anything else is still logged and ignored, as before.


- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
